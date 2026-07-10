---
title: DataStore-PostgreSQL
component_type: data-store
service: IngesterTelephonySystemsSupervisor
cluster: RDS
tags: [telephony-systems, postgresql, rds, data-store, oncall]
---

# 🗄️ PostgreSQL (dialers / ingester / data_capture)

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Postgres holds the Supervisor's **system-of-record state**: provider credentials & integration config, the call-event-id dedup map, and company/user sync state. If a DAO can't read/write, **ingestion can't resolve integrations, dedup calls, or record sync progress** — calls silently fail or re-import.
>
> 🔑 **Gotchas (verified in code):**
> 1. The "call event ids" (provider→Gong id map, dedup) live in the **DIALERS** db, not a separate `ingester` schema — `TelephonyCallEventDao` is wired to `DialersDb.SingleTenant.WRITER` (`TelephonyCallEventDao.java:18`) and writes `call_event_external_id`. The descriptor *also* grants `INGESTER` (line 39), but the call-id dedup path is DIALERS.
> 2. Almost every DAO is **tenant-scoped** via `.company(companyId)` (e.g. `DialerIntegrationDao.java:23`). Forget the `Tenant.evaluateForCompany(...)` wrapper and the query runs against the wrong/empty tenant — looks like "data missing".
> 3. **Company sync state = the `company_sync` table** (DIALERS, root FK for everything). It's updated through `DialersConnectService.updateIntegrationParameters` (`:218`), not a table called `sync_state`.

---

## What it is

| | |
|---|---|
| **Role** | Relational system-of-record: credentials, integration config, call-id dedup, sync state |
| **Logical DBs** (descriptor `dataSources.postgres`, lines 37–47) | `DIALERS`, `INGESTER`, `DATA_CAPTURE` (focus) + OPERATIONAL, CALL_QUEUES, CRM_FIELDS, RECORDING_CONSENT, DIALERS_TIMED_EVENTS, DWH, INTEGRATION |
| **`dialers`** | Provider creds, integrations, call-event ids, S3-event metadata, per-provider sync tables. DAOs: `DialerIntegrationDao`, `TelephonyCallEventDao`, `S3EventsDaoImpl`, `DialersConnectService` |
| **`ingester`** | Granted `INGESTER: GENERIC_READ_WRITE` (line 39); wired via `IngesterDb` framework (e.g. scheduled-tasks store) |
| **`data_capture`** | Company/app-user data; accessed through `DataCaptureService` (`com.honeyfy.datacapture.service`) |
| **DB framework** | `SingleTenantDbAccess` / `CrossTenantDbAccess` + `DialersDb`/`IngesterDb`/`OperationalDb` (`com.honeyfy.appcommon.db`) |
| **Local seed** | `dev/seed-dialers-local.sql` — TRUNCATEs + seeds the `dialers` schema (companies 9001/9002/9003) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — query/connection errors for this service:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('sql') || $d.body.contains('JDBC') || $d.body.contains('connection')
| filter $m.severity == ERROR || $m.severity == WARNING
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). For Postgres, watch the **RDS / Postgres / Aurora metric family** (`aws.rds.*` — connections, CPU, replica lag, deadlocks) and the Supervisor connection-pool gauges. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why (DB) |
|---|---|---|
| **Call-id dedup write** | `Dialers/.../dao/TelephonyCallEventDao.java:26` | `insertCallExternalIdentifier(...)` → `call_event_external_id` (**dialers**) — the dedup map |
| **Was-call-ingested check** | `Dialers/.../dao/TelephonyCallEventDao.java:37` | `wasCallIngested(...)` — the dedup read on the ingestion path (**dialers**) |
| **Integration lookup** | `Dialers/.../dao/DialerIntegrationDao.java:22` | `getAllIntegrationsForCompany(...)` → `company_sync` (**dialers**) |
| **Sync-state update** | `Dialers/.../connect/DialersConnectService.java:218` | `updateIntegrationParameters(...)` — writes company sync state (**dialers**) |
| **S3-event metadata write** | `Dialers/.../importcalls/S3EventsDaoImpl.java:34` | `storeCallDetails(...)` → `s3_events` (**dialers**) |
| **data_capture read** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:110` | `dataCaptureService.getAppUser(...)` — app-user lookup (**data_capture**) |

> The DB-access base framework (`SingleTenantDbAccess`, `DialersDb`, `IngesterDb`, `DataCaptureService`) lives in external Gong libs (`com.honeyfy.appcommon.db`, `com.honeyfy.datacapture`) — **not mounted here**. The DAOs above are our local subclasses/call sites. SQL text lives in `src/main/resources/sql/dialers/...` referenced by each `.sql(...)` call.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonyCallEventDao.java` in IntelliJ; match the file version to prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 26** (or `:37` for the dedup read). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Inspect locally (below), read the params (`externalIdentifier`, `companyId`), then **delete the breakpoint.**

> Use a **Log** action to inject `externalIdentifier` without snapshot overhead.

---

## 🔍 Inspect locally

The DAOs run as part of call processing — drive one call and the dedup + integration reads/writes fire.

**Process one call event (hits dedup + integration DAOs)** — see [[Entrypoints Within the Telephony System]] §2:
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=GONG_CONNECT_API' \
  -H 'Content-Type: application/json' \
  -d '{"companyId":0,"providerIdentifier":"REPLACE_PROVIDER_CALL_ID","providerIdentifierType":"ENGAGE_DIALER","providerName":"gong-connect","direction":"OUTBOUND"}'
```

**Seed local Postgres first** so reads resolve:
```bash
psql -U postgres -d dialers_dev -f /Users/terence.collins@gong.io/develop/code/gong-telephony-systems/dev/seed-dialers-local.sql
```
The seed populates the `dialers` schema — `company_sync` (root), `recording_import_credentials`, `external_oauth_credentials`, `call_provider_data`, `call_event_external_id`, `s3_buckets`, `s3_events`, plus per-provider tables (RingCentral, MS Teams, Salesforce, SMS) — for companies 9001/9002/9003. To inspect rows directly: `psql -U postgres -d dialers_dev -c 'SELECT * FROM dialers.company_sync;'`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `ProviderDataAccessTroubleshooter` | Raw provider-data access / inspect & delete provider credentials |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | Integration config state (`company_sync`) |
| `S3EventsTroubleshooter` | Inspect/edit `s3_events` rows (`:61`/`:114`) |
| `IngesterTelephonySystemsSyncInfraTroubleshooter` | Sync-job chain + sync state |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Calls re-import / duplicate | Dedup map gap — check `call_event_external_id` (DIALERS); breakpoint `TelephonyCallEventDao.java:37` (`wasCallIngested`). |
| "Integration not found" / sync skipped | `company_sync` row missing/removed — `DialerIntegrationDao.getAllIntegrationsForCompany` (`:22`); confirm `Tenant.evaluateForCompany` wrapper. |
| Data "missing" but rows exist | Tenant scoping — query ran against wrong company; verify `.company(companyId)` and MDC `cid`. |
| Connection exhaustion / slow queries | Datadog `aws.rds.*` connections + pool gauges; Coralogix JDBC/connection errors. |
