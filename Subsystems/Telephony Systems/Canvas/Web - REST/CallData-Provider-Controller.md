---
title: Call Data Provider Controller
component_type: inbound-rest-controller
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, rest, inbound, feign, call-data, oncall]
---

# 🌐 Call Data Provider Controller

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Inbound Feign endpoint that serves **provider call data** (raw per-provider call records) by call id, from the Dialers DB. Read-only. If it breaks, **the Orchestrator can't fetch provider call data** — call ingestion is unaffected.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Hard cap of 2500 call ids** — `getCallsProviderData` throws `PAYLOAD_TOO_LARGE` (413) above `MAX_CALL_IDS_SIZE = 2500` (`TelephonySystemsCallDataProviderController.java:31`). The Feign caller must chunk.
> 2. **Fully-typed Feign contract** — unlike the sibling `TelephonySystemsCallDataController`, this controller's path **is** source-verified: `GET /telephony-systems/v2/calls/provider-data` (`TelephonySystemsCallDataProviderApi.java:14/20`).
> 3. **Feign fallback throws 503** — the client's `FallbackFactory` rethrows as `SERVICE_UNAVAILABLE` (`TelephonySystemsCallDataProviderClient.java:18-19`); a transient Supervisor blip surfaces to the Orchestrator as 503, not a silent null.

---

## What it is

| | |
|---|---|
| **Role** | Inbound Feign: read provider call data by id (Dialers DB) |
| **Controller class** | `TelephonySystemsCallDataProviderController implements TelephonySystemsCallDataProviderApi` (`@RestController`, `rest/TelephonySystemsCallDataProviderController.java:21`) |
| **Backed by** | `CallDataDialersDao.getCallProviderData(...)` (Dialers DB) |
| **HTTP path (verified)** | `GET /telephony-systems/v2/calls/provider-data` (`TelephonySystemsCallDataProviderApi.java:12-20`) |
| **Query params** | `company-id`, `call-ids` (`List<Long>`) |
| **Response type** | `CallProviderDataResponse` |
| **Batch limit** | `MAX_CALL_IDS_SIZE = 2500` (`:24`) |
| **Feign client** | `TelephonySystemsCallDataProviderClient` (`telephony-systems-call-data-client`, role `IngesterTelephonySystemsSupervisor`) |
| **Feign caller** | **Orchestrator** (orchestrator repo — not mounted here) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the oversize error line (`TelephonySystemsCallDataProviderController.java:32`, `"List of callIds is too large"`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('List of callIds is too large') || $d.body.contains('provider-data')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: add `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Synchronous read surface — watch **inbound request latency / error rate** on `/telephony-systems/v2/calls/provider-data` and Dialers-DB query time. From the **caller** side, watch `feign.*` on `telephony-systems-call-data-client`. Filter `service:ingestertelephonysystemssupervisor` + `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

> ⚠️ The Feign **caller** `Orchestrator` (via `TelephonySystemsCallDataProviderClient`) lives in the orchestrator repo, **not mounted here**. Our side of the boundary is this controller — set the breakpoint here.

| Where | File : line | Why |
|---|---|---|
| **Controller entry** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsCallDataProviderController.java:30` | `getCallsProviderData(...)` — the request from the Orchestrator lands here |
| **Size guard** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsCallDataProviderController.java:31` | The `> 2500` check that throws `413` |
| **DB read** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsCallDataProviderController.java:36` | `callDataDialersDao.getCallProviderData(...)` inside `Tenant.evaluateForCompany` |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonySystemsCallDataProviderController.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 30** (entry) or **36** (DB read). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Have the Orchestrator (or your curl) hit it, read the snapshot, then **delete the breakpoint.**

> Use a **Log** action at `:36` to inject `callIds.size()` and the result count without snapshot overhead.

---

## ▶️ Trigger the flow

Normally called by the **Orchestrator** over Feign (`TelephonySystemsCallDataProviderClient`). The path is source-verified, so you can call it directly — no app-level auth locally:

```bash
curl -X GET \
  'http://localhost:8097/telephony-systems/v2/calls/provider-data?company-id=0&call-ids=1001&call-ids=1002'
```
- Repeat `call-ids` per id; keep the list ≤ **2500** or you get `413 PAYLOAD_TOO_LARGE` (`:31`).
- Returns a `CallProviderDataResponse` with `callsProviderData`.
- Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie); tag `telephony-systems-call-data-provider-controller` (`:25`).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `ProviderDataAccessTroubleshooter` | Inspect raw provider call data directly (same Dialers-DB source) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-ingest a call so its provider data is (re)populated |
| `deleteCallProviderDataRecordsToAllowReimport` | Clear provider-data rows to allow a clean re-import |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie).

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Orchestrator gets `413 PAYLOAD_TOO_LARGE` | Batch > 2500 ids (`TelephonySystemsCallDataProviderController.java:31`) — caller must chunk. |
| Orchestrator gets `503 SERVICE_UNAVAILABLE` | Feign fallback fired (`TelephonySystemsCallDataProviderClient.java:18`) — Supervisor pod/health issue; check pod restarts + inbound error rate. |
| Provider data empty | `callDataDialersDao.getCallProviderData(...)` (`:36`) found nothing — verify Dialers DB rows for those call ids; re-`syncOneCall`. |
| Slow lookups | Datadog inbound latency + Dialers-DB query time; large `call-ids` lists dominate. |
