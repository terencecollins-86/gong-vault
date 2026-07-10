---
title: DataStore-OpenSearch
component_type: data-store
service: IngesterTelephonySystemsSupervisor
cluster: OpenSearch
tags: [telephony-systems, opensearch, elasticsearch, data-store, oncall]
---

# 🗄️ OpenSearch (audits / person / troubleshooting-ts)

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> OpenSearch holds three indexes the Supervisor uses: **`troubleshooting-ts`** (per-call ingestion/importation status — the data behind the TS troubleshooting UI), **`audits`** (who changed integration config / credentials), and **`person`** (people search). If `troubleshooting-ts` writes fail, **support loses per-call visibility into why a call was rejected** — ingestion itself keeps working.
>
> 🔑 **Gotchas (verified in code):**
> 1. The `troubleshooting-ts` write is **best-effort and per-call**: `troubleshootingTsService.send(...)` is called inside the sync path (`SdrSyncWithPipelineEnqueueService.java:619`) — failures don't stop the call, so a missing TS record ≠ the call failed.
> 2. Retention runs as a scheduled task that **deletes** old TS docs (`TelephonySystemsTasksService.troubleshootingTsRetention` → `deleteOldRecordsForCompany`, `:70`), each company wrapped in `Robust.robust(...)` (swallows errors). A company's TS history vanishing is usually retention, not a bug.
> 3. **All index-accessor code is in external repos** (`Honeyfy/ElasticSearch` `MetaClient*`, `Honeyfy/TroubleshootingTs`, `Honeyfy/AppCommon` schemas), not in `gong-telephony-systems`. The audit write goes through `GeneralAuditService` (`com.honeyfy.generalaudit`). Our local boundary is in the services below.

---

## What it is

| | |
|---|---|
| **Role** | Search/audit indexes: per-call troubleshooting, config audit trail, person search |
| **Indexes** (descriptor `elasticsearch`, lines 48–51) | `TROUBLESHOOTING_TS [WRITE, READ]` → `troubleshooting-ts` · `AUDITS [WRITE, READ]` → `audits` · `PERSON [WRITE, READ]` → `person` |
| **`troubleshooting-ts`** | Per-call ingestion/importation status (companyId, integrationId, provider, gongCallId, rejection reasons, timestamps) |
| **`audits`** | Audit records for config/credential changes (table snapshots of `company_sync`, credentials), routed by `companyId` |
| **`person`** | People search documents (READ/WRITE granted to the deployment unit; written by higher-level person services, not the Supervisor's own call path) |
| **Local hooks (our side)** | `SdrSyncWithPipelineEnqueueService` (TS write), `TelephonySystemsTasksService` (audit write + TS retention) |
| **External accessors** | `TroubleshootingTsService` (`com.honeyfy.troubleshootingTs`), `GeneralAuditService` (`com.honeyfy.generalaudit`), `MetaClient*` index reader/writers (`Honeyfy/ElasticSearch`) — **not mounted here** |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — TS retention + audit activity:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('troubleshooting') || $d.body.contains('audit') || $d.body.contains('Disabled Inactive')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: swap the message filter for `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). For OpenSearch, watch the **OpenSearch / Elasticsearch metric family** (`aws.es.*` / `opensearch.*` — indexing rate, search latency, 4xx/5xx, cluster status). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

> **External repo.** The index reader/writer framework (`MetaClientIndexWriter`, `ElasticsearchIndexWriter`, the `audits`/`person`/`troubleshooting-ts` index beans + schemas) lives in `Honeyfy/ElasticSearch`, `Honeyfy/TroubleshootingTs`, `Honeyfy/AppCommon` — **not mounted here**. The breakpoints below are on **our side of the boundary** — the write/read call sites in this repo.


| Where | File : line | Why |
|---|---|---|
| **TS index write (per call)** | `Dialers/.../importcalls/SdrSyncWithPipelineEnqueueService.java:619` | `troubleshootingTsService.send(...)` — writes a `troubleshooting-ts` doc during sync |
| **TS index write (reported call)** | `Dialers/.../importcalls/SdrSyncWithPipelineEnqueueService.java:707` | second `troubleshootingTsService.send(...)` site for the reported-call branch |
| **TS retention (delete)** | `IngesterTelephonySystemsSupervisor/.../services/TelephonySystemsTasksService.java:70` | `troubleshootingTsService.deleteOldRecordsForCompany(...)` |
| **Audit write** | `IngesterTelephonySystemsSupervisor/.../services/TelephonySystemsTasksService.java:50` | `generalAuditService.executeWithAudit(...)` → `audits` index (config-change audit) |

> `person` index writes don't originate from the Supervisor's call path; set a conditional breakpoint at the framework `MetaClientIndexWriter` level (external repo) if you must trace a person write.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `SdrSyncWithPipelineEnqueueService.java` in IntelliJ; match the file version to prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 619**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Inspect locally (below), read the TS DTO (provider call id, rejection reason), then **delete the breakpoint.**

> Use a **Log** action to inject the rejection reason / gongCallId without snapshot overhead.

---

## 🔍 Inspect locally

The `troubleshooting-ts` write fires during a sync; the `audits` write fires when integration config/credentials change.

**Drive a sync (writes troubleshooting-ts docs)** — see [[Entrypoints Within the Telephony System]] §3 / §5:
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```
- Each processed/ignored call results in a `troubleshootingTsService.send(...)` (`SdrSyncWithPipelineEnqueueService.java:619`).
- The audit write path is exercised by `TelephonySystemsTasksService.disconnectDialer` (`:50`) — driven by the disable-inactive-integrations scheduled task or `ProviderDataAccessTroubleshooter` credential deletion.
- To inspect indexed docs on a local OpenSearch: `curl 'localhost:9200/troubleshooting-ts/_search?q=companyId:<id>'`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `ProviderDataAccessTroubleshooter` | Deletes credentials **with audit** → writes `audits` index |
| `TextIndexerTroubleshooter` (TextIndexer) | Re-index/inspect text (separate index path) |
| TS troubleshooting UI (reads `troubleshooting-ts`) | Per-call ingestion/importation status |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Call missing from TS troubleshooting view | TS write is best-effort (`SdrSyncWithPipelineEnqueueService.java:619`) — grep that call in Coralogix; the call may have ingested fine but the TS send failed. |
| TS history disappeared for a company | Retention deleted it — `TelephonySystemsTasksService.troubleshootingTsRetention` (`:70`); confirm `daysBack` window. |
| Audit record missing for a config change | The change path must call `generalAuditService.executeWithAudit` (`:50`); changes outside that wrapper aren't audited. |
| OpenSearch cluster red / indexing failing | Datadog `aws.es.*`/`opensearch.*` cluster status + indexing rate; TS/audit writes fail soft, search degrades. |
