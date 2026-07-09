---
title: Aircall
component_type: external-provider
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, provider, dialer, pull-sync, oncall]
---

# 📞 Aircall

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External provider polled on a schedule via `AircallDialerService` (a `DialerService` in the `Dialers` module). If this breaks, **Aircall calls stop importing for the company** — already-imported calls are unaffected.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Recording URLs expire in 10 minutes.** The list-calls URL embeds Aircall's callId; `downloadRecording` re-queries `/v1/calls/{id}` for a *fresh* recording URL before downloading (`AircallDialerService.java:301-312`, see comment @304). A stale-URL 403 at download time is expected → it re-fetches.
> 2. **Deleted-in-Aircall calls are silently filtered, not errored.** A deleted recording surfaces as `unavailable.mp3` / `deleted.mp3`; `filterCall` drops it as `MISSING_RECORDING` (`:259-280`, see comment @266). "Call missing in Gong" may just mean it was deleted upstream.
> 3. **Rate limit (HTTP 429) → 2-minute back-off** thrown as `RateLimitExceededException` (`:244-245`).

---

## What it is

| | |
|---|---|
| **Role** | External dialer provider; Supervisor **pulls** calls via REST (SYNC origin) |
| **Local class** | `AircallDialerService extends AbstractDialerService` |
| **IntegrationFlavor** | `AIRCALL_API` (`aircall_api`, `IntegrationFlavor.java:20`) |
| **Provider API** | REST `https://api.aircall.io/v1/calls` (`API_ROOT`/`LIST_CALLS_REQUEST`, `:60-61`) |
| **Auth** | HTTP **Basic** — `Authorization: Basic base64(apiId:apiToken)` via `addAuthorizationHeader(tokenOwner, token, request)` (`:212`) |
| **Creds source** | `CompanyRecordingImportService` — `tokenOwner` = API ID, `token` = API token (`saveCredentials :147-152`) |
| **Recording** | `recording` field (mp3), 10-min URL; voicemail in `voicemail` (`CallData :441-445`) |
| **SMS** | None — Aircall integration is calls-only |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — list-calls + filtered/deleted calls for this provider:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Listing calls') || $d.body.contains('unavailable-recording')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch `feign.*` / provider-sync error rate and the `DIALERS_SYNC_*` queue depth. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **List calls (REST)** | `Dialers/.../services/AircallDialerService.java:213` | `request.getForObject(ListCallsResponse.class)` — the actual provider call. Auth header set @212 |
| **Auth header** | `Dialers/.../services/AircallDialerService.java:212` | Confirm Basic `apiId:token` is built (`addAuthorizationHeader`) |
| **Recording re-fetch** | `Dialers/.../services/AircallDialerService.java:311` | Fresh recording URL fetch (`/v1/calls/{id}`) — the 10-min-URL workaround |
| **Filter / silent drop** | `Dialers/.../services/AircallDialerService.java:275` | Where a deleted/unavailable recording is dropped as `MISSING_RECORDING` |

Step from `:213` (list) → per-call `filterCall` @259 → on import, `downloadRecording` @301 → re-fetch @311.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `AircallDialerService.java` in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 213** (list calls) or **line 311** (recording re-fetch). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject `companyCache.lastProviderCallMade` without snapshot overhead.

---

## ▶️ Trigger the flow

Pull one Aircall call through the full provider-fetch path with the **Sync one call** troubleshooter — flavor is derived from `company-id` + `integration-id` (no `integration-flavor` param here). Details + payloads: [[Entrypoints Within the Telephony System]] §3.

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_AIRCALL_CALL_ID'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- `integration-id` must point to an **AIRCALL_API** integration, else `getIntegrationFlavor` (`:479`) returns the "enabled integrations" helper instead.
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Alternative (push path doesn't apply — Aircall is pull-only): drive the periodic SyncJob chain (§5).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one Aircall call |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic sync that polls Aircall |
| `ProviderDataAccessTroubleshooter` | Raw provider-data access for the company |
| `IntegrationsTroubleshooter` | Verify the AIRCALL_API integration config/creds |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[04 - Providers & Dialers]] and [[IngesterTelephonySystemsSupervisor]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| All Aircall calls stopped importing | (1) Creds valid? Basic-auth 401 in Coralogix. (2) 429 back-off — `RateLimitExceededException` (`:244`). (3) Did the SyncJob run? `TroubleshootingScheduledTaskController`. |
| One call missing in Gong | Likely deleted upstream → filtered as `MISSING_RECORDING` (`filterCall :275`). Check the "unavailable-recording" debug log. |
| Recording download 403/empty | Expected if URL expired; verify the re-fetch @311 ran. Aircall recording URLs live only 10 min. |
| Wrong user on call | Association is by **email** only (`USER_ASSOCIATION_STRATEGY :68`); `aircallParticipant.email` must match a Gong user. |
