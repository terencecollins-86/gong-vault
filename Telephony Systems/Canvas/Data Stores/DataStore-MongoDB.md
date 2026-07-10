---
title: DataStore-MongoDB
component_type: data-store
service: IngesterTelephonySystemsSupervisor
cluster: CRM_MIRROR
tags: [telephony-systems, mongodb, crm-mirror, data-store, oncall]
---

# 🗄️ MongoDB (CRM_MIRROR)

> [[Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> MongoDB `CRM_MIRROR` is a **read-mostly mirror of the customer's CRM** (accounts, contacts, leads). The Supervisor reads it to **enrich a call's CRM associations** with names/titles/phones/emails. If the mirror is unavailable or empty, **calls still ingest but lack enriched CRM detail** — degraded, not broken.
>
> 🔑 **Gotchas (verified in code):**
> 1. The mirror fetcher is **`@Autowired(required = false)`** — `CRMInfoRetrievalService.java:51`. If `CrmMirrorFetcherService` isn't wired, enrichment **silently returns the un-enriched info** after a single warn (`:89–90`: *"CrmMirrorFetcherService is not wired !"*). Missing enrichment ≠ Mongo down — first check whether the bean is wired.
> 2. The whole enrichment block is wrapped in a **catch-all** (`:135` `catch (Exception)`) that logs and returns the original `crmInfos`. A Mongo read failure degrades quietly; grep `Failed to enrich crm info`.
> 3. **All CRM_MIRROR accessor code is in an external repo** (`Honeyfy/CrmMirrorAccessor`, package `com.honeyfy.crm.mirror.*`), not in `gong-telephony-systems`. Our local boundary is `CRMInfoRetrievalService`.

---

## What it is

| | |
|---|---|
| **Role** | Document store mirroring customer CRM objects, for call enrichment |
| **Cluster / declaration** | `mongodb: CRM_MIRROR: READ_WRITE` (descriptor line 117) |
| **What's stored** | Mirrored CRM entities — accounts, contacts, leads (enriched name/title/phone/email) keyed by `crmId` per company+integration |
| **Local accessor (our side)** | `CRMInfoRetrievalService` (Dialers) → `crmMirrorFetcherService.fetchEnriched*ByCrmIds(...)` |
| **External accessor (CRM_MIRROR repo)** | `CrmMirrorFetcherService`, `MirroredEntityPersistencyService` (extends `AbstractSingleTenantMongoAccessor`), collection `crm.mirrored_entities` — **not mounted here** |
| **Access pattern** | Telephony reads only (READ_WRITE granted, but the Supervisor path reads to enrich); writes are owned by the CRM-mirror service |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the enrichment read counts / not-wired warn:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('enriched accounts') || $d.body.contains('enriched contacts') || $d.body.contains('CrmMirrorFetcherService is not wired') || $d.body.contains('Failed to enrich crm info')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). For Mongo, watch the **MongoDB / DocumentDB metric family** (`mongodb.*` / `aws.docdb.*` — opcounters, query latency, connections). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

> **External repo.** The Mongo accessor (`CrmMirrorFetcherService`, `MirroredEntityPersistencyService`, collection `crm.mirrored_entities`) lives in `Honeyfy/CrmMirrorAccessor` (`com.honeyfy.crm.mirror.*`), **not mounted here**. The breakpoints below are on **our side of the boundary** — the read call site in the Dialers module.

| Where | File : line | Why |
|---|---|---|
| **Mirror read (accounts)** | `Dialers/.../services/crm/CRMInfoRetrievalService.java:96` | `crmMirrorFetcherService.fetchEnrichedAccountsByCrmIds(...)` — the actual CRM_MIRROR read |
| **Mirror read (contacts)** | `Dialers/.../services/crm/CRMInfoRetrievalService.java:101` | `fetchEnrichedContactsByCrmIds(...)` |
| **Mirror read (leads)** | `Dialers/.../services/crm/CRMInfoRetrievalService.java:106` | `fetchEnrichedLeadsByCrmIds(...)` |
| **Not-wired guard** | `Dialers/.../services/crm/CRMInfoRetrievalService.java:89` | `if (crmMirrorFetcherService == null)` — the silent-skip branch (gotcha 1) |
| **Enrich entry** | `Dialers/.../services/crm/CRMInfoRetrievalService.java:74` | `enrichCRMInfo(...)` — step in from here |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `CRMInfoRetrievalService.java` in IntelliJ; match the file version to prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 96**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Inspect locally (below), read `accountCrmIds` and the returned `enrichedAccounts` size, then **delete the breakpoint.**

> Use a **Log** action to inject `enrichedAccounts.size()` vs requested without snapshot overhead.

---

## 🔍 Inspect locally

CRM_MIRROR is read during call enrichment — drive a call for a company with a connected CRM integration and the `fetchEnriched*` reads fire.

**Process one call event (reaches CRM enrichment)** — see [[Entrypoints Within the Telephony System]] §2:
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=GONG_CONNECT_API' \
  -H 'Content-Type: application/json' \
  -d '{"companyId":0,"providerIdentifier":"REPLACE_PROVIDER_CALL_ID","providerIdentifierType":"ENGAGE_DIALER","providerName":"gong-connect","direction":"OUTBOUND"}'
```
- Enrichment only runs if a CRM integration is connected (`getIntegrationId`, `:142`) **and** `crmMirrorFetcherService` is wired (`:89`). Locally the bean may be absent — expect the "not wired" warn.
- To inspect the collection directly on a local Mongo: `mongosh` → `db.getCollection('crm.mirrored_entities').find({companyId: <id>}).limit(5)`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `CRMInfoRetrievalTroubleshooter` | CRM lookup/enrichment debugging — exercises the mirror read path |
| `CRMInfoRetrievalService.getFullCrmInfoForCall` | Programmatic entry the troubleshooter drives (`:65`) |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Calls missing enriched CRM names/titles | (1) Is `CrmMirrorFetcherService` wired? Coralogix for "CrmMirrorFetcherService is not wired" (`:90`). (2) "got N enriched accounts out of requested M" — N=0 means the mirror has no matching `crmId`s. |
| Enrichment errors swallowed | Catch-all at `:135` logs "Failed to enrich crm info" and returns un-enriched — grep that, then check Mongo/DocumentDB health in Datadog. |
| No association at all | Upstream of Mongo — `crmAssociatorClient.findAssociation` returned empty (`:170`); use `CRMInfoRetrievalTroubleshooter`. |
| Mongo unreachable | Datadog `mongodb.*`/`aws.docdb.*` connections + latency; enrichment degrades but ingestion continues. |
