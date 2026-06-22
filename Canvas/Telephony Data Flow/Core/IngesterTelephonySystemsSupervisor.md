---
title: IngesterTelephonySystemsSupervisor
component_type: service
service: IngesterTelephonySystemsSupervisor
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, service, core, hub, oncall]
---

# ☎️ IngesterTelephonySystemsSupervisor (core)

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> **Start here.** The Supervisor is the **core ingestion hub** for telephony: every dialer/PBX call enters Gong through it (push via Kafka, pull via scheduled SQS syncs, or on-demand via REST), gets created + CRM-associated, and is handed off to call processing. If the Supervisor is down, **no new dialer/PBX calls reach Gong**, regardless of provider.
>
> 🔑 **Gotchas (verified in code):**
> 1. The hand-off to processing is **feature-flag gated** — `SEND_DIALER_CALL_CREATION_EVENT` per company. Off ⇒ call is ingested fine but **silently never forwarded** (e.g. `PbxRecordingImportService.java:195`).
> 2. The descriptor declares `WRITE` to `call-processing-inbound` (`IngesterTelephonySystemsSupervisor.gong-app-descriptor.yaml:84/86`) but the real outbound hand-off goes on **`dialer-calls-updates`** (`SYNC_COMMUNICATIONS`, `:112`). Chase *that* topic — see [[DIALER-CALLS-UPDATES]] / [[CALL-PROCESSING-INBOUND]].

---

## What it is

| | |
|---|---|
| **Role** | Core telephony **ingestion hub** — create calls from dialers/PBX, CRM-associate, hand off to processing |
| **Module** | `IngesterTelephonySystemsSupervisor` (`moduleType: api-server`, `publicFacing: False`, Crossplane-managed) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |
| **Base URL (local)** | `http://localhost:8097` (no app-level auth locally) |
| **Inbound topics** | `gong-connect-dialer-events`, `low-priority-dialer-events`, `gong-connect-call-event` (`TELEPHONY_SYSTEMS`); `call-processing-status-event` (`CALL_PROCESSOR`); `association-updated`, `app-user-changes` |
| **Outbound topics** | `dialer-calls-updates`, `webconference-call-events` (`SYNC_COMMUNICATIONS`); recordings-import topics (`TELEPHONY_SYSTEMS`) |
| **Data stores** | Postgres (`INGESTER`, `DIALERS`, `OPERATIONAL`, `DATA_CAPTURE`, …), OpenSearch (`TROUBLESHOOTING_TS`, `AUDITS`, `PERSON`), Redis (`GONG_PROD`), Mongo (`CRM_MIRROR`) |
| **Flags** | `locks: true`, `scheduledTasks: true`, `externalCmkAccessNeeded: true` |
| **Owner / Sentry team** | yossi.rizgan@gong.io / `telephony-systems` |

---

## 🧭 The 4 entrypoint types

How calls / events enter the Supervisor. Walkthroughs, payloads, and exact breakpoints: [[Entrypoints Within the Telephony System]].

| Type | What enters | Production trigger | On-demand REST twin |
|---|---|---|---|
| **REST** (inbound controllers) | Provisioning + reads + recording import | Feign/HTTP from PublicApiServer, CallPipeline, Orchestrator, WebFrontEnd | the `rest/` controllers below |
| **Kafka** (consumers) | Pushed dialer call events | produce to `gong-connect-dialer-events` (`TELEPHONY_SYSTEMS`) | `process-one-event` (Entrypoints §2) |
| **Scheduled** (timed sync) | Periodic provider polls | `TroubleshootingScheduledTaskController` / SyncJob chain | `runChainNow` (Entrypoints §5A) |
| **SQS** (sync executor) | Per-company sync jobs | `SyncJob` on `DIALERS_SYNC_HIGH/LOW_PRIORITY` | `sendMessage` / `syncOneCall` (Entrypoints §3/§5B) |

**Inbound REST controllers** (on-call canvas pages):

| Controller | Page | Caller |
|---|---|---|
| `DialpadController` (+ advice, troubleshooter) | [[Dialpad-Webhook-Controller]] | internal Feign / `DialpadTroubleshooter` · [[Dialpad]] |
| `PbxRecordingImportController` | [[PBX-Recording-Import]] | PublicApiServer / WebFrontEnd |
| `TelephonySystemsCallDataController` | [[CallData-Controller]] | CallPipelineExecutor |
| `TelephonySystemsCallDataProviderController` | [[CallData-Provider-Controller]] | Orchestrator |

---

## 👀 See it working

**Coralogix (DataPrime)** — all Supervisor logs; narrow by message or company:
```text
source logs
| filter $l.applicationName == 'ingestertelephonysystemssupervisor'
| filter $m.severity == 'ERROR'
| limit 200
```
Scope one company with `| filter $d.cid == '<companyId>'`; follow one call by its `trace_id` / call id in the MDC. Guided: *"use the coralogix-debug-expert"* or the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). The #1 health signal is **Kafka consumer lag** on `gong-connect-dialer-events` / `*-recordings-import-requests`, plus outbound `feign.*` and `kubernetes.*` (pod restarts / HPA). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`). ⚠️ `TextIndexer` reports to `deal-intelligence`, **not** telephony-systems.

---

## 🔌 Set a breakpoint (local)

Run the service:
```bash
gong-module-run --debug up --subsystem-names gong-telephony-systems
```
Base URL `http://localhost:8097`, no app-level auth locally.

**Smoke test** — the zero-arg breakpoint that proves the whole debug loop (request → Tomcat → controller → service):

| Where | File : line | Why |
|---|---|---|
| **Smoke-test breakpoint** | `IngesterTelephonySystemsShared/src/main/java/com/honeyfy/ingesterselephonysystemsshared/troubleshooters/IngesterTelephonySystemsTroubleshooter.java:291` | `int backfillMarkedUsers = userBackfillService.backfillMarkedTss();` — first executable line of `backfillMarkedUsers()` (method @290, mapping @289) |
| **Core single-call** | `IngesterTelephonySystemsSupervisor/.../rest/TelephonyCallEventsTroubleshooter.java:50` | `dialerService.processCallEvent(...)` — the shared core path (HTTP twin of the Kafka consumer) |
| **GDM hand-off** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:198` | `gdmCallEventSender.sendDialerCall(...)` — boundary into call processing |

Fire the smoke test (200 OK `Backfilled <n> TSs`):
```bash
curl -X POST \
  http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/backfill/backfillMarkedTSs
```

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open the target class in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** on the line. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call for that company, read the snapshot, then **delete the breakpoint.**

> A **Log** action injects a value without snapshot overhead.

---

## ▶️ Trigger the flow

Pick the entrypoint you're debugging — full payloads in [[Entrypoints Within the Telephony System]]:

```bash
# Smoke test (zero-arg) — proves the local debug loop
curl -X POST \
  http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/backfill/backfillMarkedTSs

# Push path twin — drives processCallEvent() over HTTP (Entrypoints §2)
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=GONG_CONNECT_API' \
  -H 'Content-Type: application/json' \
  -d '{"companyId":0,"providerIdentifier":"REPLACE_PROVIDER_CALL_ID","providerIdentifierType":"ENGAGE_DIALER","providerName":"gong-connect","direction":"OUTBOUND"}'

# Pull path twin — fetch + ingest one call from the provider (Entrypoints §3)
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```
Postman collection: `gong-telephony-systems/postman/IngesterTelephonySystemsSupervisor.postman_collection.json`.

---

## 🧰 Troubleshooters

Internal, production-active REST endpoints (VPN + `troubleshootersAuthJWT` cookie). They live in the Supervisor `rest/` package and `IngesterTelephonySystemsShared/.../troubleshooters/`. The two on-demand **call drivers**: `syncOneCall` (PCI-Compliant troubleshooter, pull one call) and `process-one-event` (`TelephonyCallEventsTroubleshooter`, push one event).

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter` (PCI-Compliant) | `syncOneCall`, `backfillMarkedTSs`, mask/delete-to-reimport |
| `TelephonyCallEventsTroubleshooter` | `process-one-event` — push one dialer call event |
| `IngesterTelephonySystemsSyncInfraTroubleshooter` | `runChainNow`, `sendMessage` — drive the scheduled/SQS sync |
| `TroubleshootingScheduledTaskController` | Inspect/trigger periodic syncs |
| `SalesforceTroubleshooter` / `S3EventsTroubleshooter` / `SftpTroubleshooter` | Provider-specific inspect/replay |
| `ProviderDataAccessTroubleshooter` / `CallActivityStoreIngesterTroubleshooter` | Raw provider data / activity-store hand-off |

Swagger (prod): `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html`. Full pattern: [[Architecture/Troubleshoot Endpoints]] · [[06 - Runbook & Troubleshooting]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Calls from a provider aren't showing up | Did the event/request arrive? Kafka → Coralogix by consumer + cid; scheduled → `TroubleshootingScheduledTaskController`; S3 → `S3EventsTroubleshooter`. See [[06 - Runbook & Troubleshooting]] playbook 1. |
| Calls ingested but never processed | Is `SEND_DIALER_CALL_CREATION_EVENT` on for the company? Then Coralogix for the GDM-send warn; lag on `dialer-calls-updates` ([[DIALER-CALLS-UPDATES]]). |
| Consumer lag climbing | Datadog Kafka lag → Coralogix (erroring vs slow) → upstream `feign.*` deps → poison-message decision. Playbook 2. |
| CRM association failures | `TelephonySystemsAssociationUpdatedConsumer` retries; persistent → `CRMInfoRetrievalTroubleshooter`. Playbook 3. |
| Recording import failing | `RecordingsImporterTroubleshooter` to replay; check customer S3 assumed-role + external CMK. Playbook 4. |
