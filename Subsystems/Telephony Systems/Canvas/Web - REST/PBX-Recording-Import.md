---
title: PBX Recording Import
component_type: inbound-rest-controller
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, rest, inbound, pbx, recording-import, oncall]
---

# 🌐 PBX Recording Import

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Inbound REST entry that **imports a PBX / public-API phone-call recording** (audio already in S3) into Gong: dedup → create the call → CRM-associate → hand off to GDM for processing. If it breaks, **uploaded PBX recordings land in S3 but never become Gong calls.**
>
> 🔑 **Gotchas (verified in code):**
> 1. The GDM hand-off is **feature-flag gated** — `sendToGdm()` returns early if `SEND_DIALER_CALL_CREATION_EVENT` is off for the company (`PbxRecordingImportService.java:195`). Flag off ⇒ call is created in Gong but **silently never sent to processing**, no error.
> 2. The GDM send is wrapped in `Robust.tryAndLog(...)` (`:134`) — a send failure is **logged at error, not thrown**; `importPhoneCall` still returns the new `callId`. Grep `"Failed to send call to GDM"` to catch it.
> 3. **Silent skips return `Optional.empty()`** — duplicate by `pbxCallId` (`:98`), duplicate by audio-file hash (`:107`), or unknown user email (`:117`). A "missing call" is often a dedup/no-user skip, not a crash.

---

## What it is

| | |
|---|---|
| **Role** | Inbound REST: import one PBX/public-API recording → Gong call → GDM |
| **Controller class** | `PbxRecordingImportController implements PbxRecordingImportApi` (`@RestController`, `rest/PbxRecordingImportController.java:21`) |
| **Service** | `PbxRecordingImportService.importPhoneCall(...)` (`services/PbxRecordingImportService.java:82`) |
| **Request type** | `companyId`, `appUserId`, `CallMetaData phoneCallMetaData`, `s3ObjectKey`, `audioFileHash` |
| **GDM hand-off** | `gdmCallEventSender.sendDialerCall(companyId, callId, supplier)` (`:198`, via `sendToGdm()` @191) |
| **Feature flag** | `SEND_DIALER_CALL_CREATION_EVENT` (`SEND_DIALER_CALL_CREATION_EVENT_FF_NAME`, gate @195) |
| **Callers** | `PublicApiServer` / `WebFrontEnd` (REST) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Flow** (one import): `importPhoneCall` @82 → dedup by id @86 / by hash @101 → resolve app user @110 → CRM sync @123 → `callService.importPbxCallAndReport(...)` @151 → insert recording row @179/@298 → `sendToGdm()` @135 → (FF on) `sendDialerCall(...)` @198.

---

## 👀 See it working

**Coralogix (DataPrime)** — successful import (`PbxRecordingImportService.java:186` debug `"Successfully import call"`) and the GDM-send failure path (`:137` error `"Failed to send call to GDM"`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Successfully import call') || $d.body.contains('Failed to send call to GDM')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Dedup skips log at debug — search `"already exists - skipping"`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch `feign.*` to FileUpload / GDM downstream and Kafka lag on `dialer-calls-updates` (where the GDM send ultimately lands — see [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]]). Filter `service:ingestertelephonysystemssupervisor` + `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Controller entry** | `IngesterTelephonySystemsSupervisor/.../rest/PbxRecordingImportController.java:27` | `importPhoneCall(...)` — request reaches controller; wraps service in `Tenant.evaluateForCompany` (`:28`) |
| **Service entry** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:82` | Start of import — step through dedup (@86/@101) and the user lookup (@110) |
| **The FF gate** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:195` | `if (!featureFlagsClient.isEnabled(SEND_DIALER_CALL_CREATION_EVENT...))` — the #1 silent drop |
| **The GDM hand-off** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:198` | `gdmCallEventSender.sendDialerCall(...)` — the boundary into call processing |

Step `:195` → if FF true, into `sendDialerCall(...)` @198 → then the event lands on `dialer-calls-updates` (see [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]]).

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `PbxRecordingImportService.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 195** (FF gate) or **198** (GDM send). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger an import for that company, read the snapshot, then **delete the breakpoint.**

> Use a **Log** action at `:198` to inject `callId` and confirm the call reached the GDM hand-off without snapshot overhead.

---

## ▶️ Trigger the flow

The controller's `@RequestMapping` path is in `PbxRecordingImportApi` (interface not source-mounted), and the call requires a multipart-style payload + an audio object already in S3 — so the cleanest local repro is the **Sync one call** / **Process one event** troubleshooter chain that exercises the same `importPbxCallAndReport → sendDialerCall` path. (Details + payloads: [[Entrypoints Within the Telephony System]] §2/§3.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```
- Set `company-id` to one with `SEND_DIALER_CALL_CREATION_EVENT` **enabled**, or the GDM send is skipped (`:195`).
- Production callers are `PublicApiServer` / `WebFrontEnd` posting to the `PbxRecordingImportApi` path — no app-level auth locally.
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the GDM send @198) |
| `deleteCallProviderDataRecordsToAllowReimport` / `maskCallsToAllowReimport` | Clear prior state so a recording can be re-imported past the dedup guards (@86/@101) |
| `RecordingsImporterTroubleshooter` (RecordingsImporter) | Replay a single recording import |
| `ProviderDataAccessTroubleshooter` | Inspect raw provider/recording data |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie).

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Recording uploaded but no Gong call | Dedup or no-user skip — debug logs `"already exists - skipping"` (@95/@103) or warn `"Cannot find app user by email"` (@113). Returns `Optional.empty()`. |
| Call created but never processed | (1) Is `SEND_DIALER_CALL_CREATION_EVENT` on? (`PbxRecordingImportService.java:195`). (2) Coralogix `"Failed to send call to GDM"` (@137). (3) Lag on `dialer-calls-updates`. |
| Duplicate calls created | Hash/`pbxCallId` mismatch upstream — both dedup queries (@298 SQL `tryInsertCallRecording`, `findDuplicateCallRecordingBy*`) keyed on those. |
| Bad call times rejected | `validateCallTime(...)` (@256) throws `IllegalArgumentException` for future/inverted timestamps. |
