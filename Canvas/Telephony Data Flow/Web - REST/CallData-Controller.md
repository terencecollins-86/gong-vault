---
title: Call Data Controller
component_type: inbound-rest-controller
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, rest, inbound, feign, call-data, oncall]
---

# 🌐 Call Data Controller

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Inbound REST/Feign endpoint that serves **call activity metadata + provider call data** by call id. Read-only lookups backed by the activity store and the Dialers DB. If it breaks, **callers (the call pipeline) can't enrich calls with telephony metadata** — but call ingestion itself is unaffected.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Hard cap of 2500 call ids** — `listCallsMetadata` throws `PAYLOAD_TOO_LARGE` (413) if the set exceeds `MAX_CALL_IDS_SIZE = 2500` (`TelephonySystemsCallDataController.java:41`). Batch callers must chunk.
> 2. **Not-found is not an error** — for call ids missing from the activity store, the controller returns a `CallActivityMetadata` with only `callId` set (`:54-55`). An "empty metadata" row means the activity wasn't found, not a failure.
> 3. The `@RequestMapping` paths are on the `TelephonySystemsCallDataApi` interface (`com.honeyfy.ingester.telephony.systems.supervisor.api`), which is **not source-mounted here** — cite the controller methods below; verify exact paths in Swagger.

---

## What it is

| | |
|---|---|
| **Role** | Inbound REST/Feign: read call activity metadata + provider call data by id |
| **Controller class** | `TelephonySystemsCallDataController implements TelephonySystemsCallDataApi` (`@RestController`, `rest/TelephonySystemsCallDataController.java:27`) |
| **Backed by** | `DialerCallActivitiesService` (activity store) + `CallDataDialersDao` (Dialers DB) |
| **Response types** | `CallActivityMetadata`, `CallProviderDataResponse` |
| **Batch limit** | `MAX_CALL_IDS_SIZE = 2500` (`:30`) |
| **Feign caller** | **CallPipelineExecutor** (call-pipeline repo — not mounted here) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Endpoints** (method → `TelephonySystemsCallDataController` line; HTTP verb/path in the un-mounted `TelephonySystemsCallDataApi`):

| Operation | `…CallDataController.java` | Inputs |
|---|---|---|
| `listCallsMetadata` | `:38` | `@RequestParam company-id`, `@RequestBody Set<Long> callIds` (≤ 2500) |
| `getCallMetadata` | `:60` | `@RequestParam company-id`, `@RequestParam call-id` |
| `getCallsProviderData` | `:79` | `companyId`, `List<Long> callIds` (provider call data) |

---

## 👀 See it working

**Coralogix (DataPrime)** — the controller's timer debug lines (`"listCallsMetadata(long, Set) completed"` @57, `"getCallMetadata(long, Long) completed"` @76) and the oversize error (`:42`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('listCallsMetadata') || $d.body.contains('getCallMetadata') || $d.body.contains('List of callIds is too large')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: add `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). This is a synchronous read surface — watch **inbound request latency / error rate** and the activity-store + Dialers-DB query time. Filter `service:ingestertelephonysystemssupervisor` + `g-cell`. Lag isn't relevant (no Kafka here).

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

> ⚠️ The Feign **caller** `CallPipelineExecutor` lives in the call-pipeline repo, **not mounted here**. Our side of the boundary is this controller — set the breakpoint here.

| Where | File : line | Why |
|---|---|---|
| **Batch entry** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsCallDataController.java:38` | `listCallsMetadata(...)` — first thing the caller hits; step past the size guard (@41) |
| **Single entry** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsCallDataController.java:60` | `getCallMetadata(...)` — single-call lookup |
| **Activity fetch** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsCallDataController.java:47` | `dialerCallActivitiesService.getFullActivitiesForCallIds(...)` — the activity-store read |
| **Provider data** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsCallDataController.java:82` | `callDataDialersDao.getProviderCallData(...)` inside `Tenant.evaluateForCompany` |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonySystemsCallDataController.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 38** (batch) or **60** (single). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Have the caller (or your curl) hit it, read the snapshot, then **delete the breakpoint.**

> Use a **Log** action at `:47` to inject `callIds.size()` and the found-count without snapshot overhead.

---

## ▶️ Trigger the flow

Normally called by **CallPipelineExecutor** over Feign. The exact `@RequestMapping` path is in the un-mounted `TelephonySystemsCallDataApi`; discover it in Swagger, then call it directly (no app-level auth locally). Shape of a batch metadata request:

```bash
# Path from TelephonySystemsCallDataApi (confirm in Swagger UI) — body is a JSON array of call ids
curl -X POST \
  'http://localhost:8097/<TelephonySystemsCallDataApi path>?company-id=0' \
  -H 'Content-Type: application/json' \
  -d '[1001, 1002, 1003]'
```
- Keep the array ≤ **2500** ids or you get `413 PAYLOAD_TOO_LARGE` (`:41`).
- For the single-call variant, supply `company-id` + `call-id` query params (hits `getCallMetadata` @60).
- Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `CallActivityStoreIngesterTroubleshooter` | Inspect / re-drive the activity-store hand-off this controller reads from |
| `ProviderDataAccessTroubleshooter` | Inspect raw provider call data (what `getCallsProviderData` returns) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-ingest a call so its activity/provider data is (re)populated |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie).

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Caller gets `413 PAYLOAD_TOO_LARGE` | Batch > 2500 ids (`TelephonySystemsCallDataController.java:41`) — caller must chunk. |
| Metadata returned but fields empty | Call id not in activity store — controller back-fills a `callId`-only row (`:54`). Check the call was ingested + activity-store hand-off (`CallActivityStoreIngesterTroubleshooter`). |
| Provider data empty | `callDataDialersDao.getProviderCallData(...)` (`:82`) found nothing — verify Dialers DB rows for those call ids; re-`syncOneCall` if needed. |
| Slow / timing out | Datadog inbound latency + activity-store / Dialers-DB query time; large batches dominate (timer logs @57). |
