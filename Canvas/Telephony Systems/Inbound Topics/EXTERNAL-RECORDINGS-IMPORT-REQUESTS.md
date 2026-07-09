---
title: EXTERNAL-RECORDINGS-IMPORT-REQUESTS
component_type: inbound-kafka-topic
service: TelephonySystemsRecordingsImporter
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, inbound, oncall, recordings-import]
---

# 📥 EXTERNAL-RECORDINGS-IMPORT-REQUESTS

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Import requests for **external (non-dialer) recordings** — e.g. recordings dropped/imported by integrations other than the live dialers. The consumer pulls each `ImportRequest` and runs `recordingsImporterService.processRequest(...)`, which fetches the media and feeds it into ingestion. If this stalls, **external recordings never get imported / transcribed** for affected tenants.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Consumer is in a different module.** It runs in **`TelephonySystemsRecordingsImporter`** (`ExternalRecordingsImportRequestsConsumer`), *not* the Supervisor — but same repo (`gong-telephony-systems`). The Supervisor's app-descriptor still declares the topic `READ_WRITE`, which is why it shows on the Supervisor canvas.
> 2. **DIALER vs EXTERNAL routing.** The producer (`RecordingsImporterTroubleshooter`) sends to `EXTERNAL_RECORDINGS_IMPORT_REQUESTS` **only when `importRequestType != DIALER`**; default `consumerType=DIALER` routes to `telephony-recordings-import-requests` instead (`RecordingsImporterTroubleshooter.java:128`). Pass `consumerType=EXTERNAL` to hit *this* topic.
> 3. **No `@KafkaListener`** — wired via `configureSingle(... EXTERNAL_RECORDINGS_IMPORT_REQUESTS ...)` (`ExternalRecordingsImportRequestsConsumer.java:54-56`). Key type is `String` (callId), not `Long`.

---

## What it is

| | |
|---|---|
| **Role** | Inbound import request for external recordings → media fetch + ingest |
| **Topic** | `external-recordings-import-requests` (`KafkaTopics.EXTERNAL_RECORDINGS_IMPORT_REQUESTS`) |
| **Cluster** | `TELEPHONY_SYSTEMS` (`TELEPHONY_SYSTEMS_KAFKA_CLUSTER`) |
| **Access (Supervisor app-descriptor)** | `READ_WRITE` (line 59-60) |
| **Message type** | `ImportRequest` (`com.honeyfy.kafka.events.recordingsimporter.ImportRequest`), key `String` |
| **Consumer** | `ExternalRecordingsImportRequestsConsumer` (**module `TelephonySystemsRecordingsImporter`**) |
| **Core call** | `recordingsImporterService.processRequest(record.value())` |
| **Producer** | `RecordingsImporterTroubleshooter` (on-demand) + `ImportRescheduleService` (retry/reschedule) |
| **Downstream** | Media import → call ingestion pipeline |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` (Supervisor) — RecordingsImporter logs under its own image |

---

## 👀 See it working

**Coralogix (DataPrime)** — the consumer's per-event line (`ExternalRecordingsImportRequestsConsumer.java:31`, INFO `"got event=…"`). Note: that line is emitted by the **RecordingsImporter** service, so filter its application name:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('got event')
| limit 200
```
> ⚠️ If the RecordingsImporter deploys under a distinct image name, swap `applicationName` accordingly. Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). #1 health signal = **consumer lag on `external-recordings-import-requests`**. Watch `feign.*` to the media/file services for import slowness.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate via *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally). The consumer below is in the **RecordingsImporter module of the same repo** — its breakpoint is fully local.

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `TelephonySystemsRecordingsImporter/.../consumer/ExternalRecordingsImportRequestsConsumer.java:30` | `accept(ConsumerRecord<String, ImportRequest>)` — every import request |
| **Core call** | `.../consumer/ExternalRecordingsImportRequestsConsumer.java:32` | `recordingsImporterService.processRequest(...)` — step in for the import |
| **Wiring** | `.../consumer/ExternalRecordingsImportRequestsConsumer.java:54` | `configureSingle(... EXTERNAL_RECORDINGS_IMPORT_REQUESTS ...)` |
| **Producer (our side)** | `TelephonySystemsRecordingsImporter/.../troubleshooter/RecordingsImporterTroubleshooter.java:128` | The `kafkaTemplate.send(... EXTERNAL ...)` — catch what's emitted |

Step from `:30` → `:32` into `processRequest(...)` to follow the media fetch + ingest.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against prod. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `ExternalRecordingsImportRequestsConsumer.java` in IntelliJ (match the prod build — Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 30**. In **Source**, pick the tag for the **RecordingsImporter** service (its own tag, not the Supervisor's).
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger an import (below), read `importRequestRecord.value()`, then **delete the breakpoint.**

> A **Log** action injecting `importRequestRecord.value().callId` confirms which call is importing without snapshot overhead.

---

## ▶️ Trigger the flow

Use the **RecordingsImporter troubleshooter** with `consumerType=EXTERNAL` so the request lands on *this* topic (default `DIALER` goes to `telephony-recordings-import-requests`):
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/recordings-importer/requestImport?callId=REPLACE_CALL_ID&companyId=0&consumerType=EXTERNAL&forceImport=true' \
  -F 'file=;type=text/csv'
```
- Controller `RecordingsImporterTroubleshooter.requestImport()` (`TelephonySystemsRecordingsImporter/.../troubleshooter/RecordingsImporterTroubleshooter.java:64`); the topic decision is at `:128`.
- Provide either `callId`+`companyId` query params **or** a CSV `<callId,companyId>` upload (the `file` part). `consumerType=EXTERNAL` is the key to route here.
- Postman: `Other Troubleshooters → Recordings Importer → requestImport` (set `consumerType=EXTERNAL`).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `RecordingsImporterTroubleshooter.requestImport` | Re-drive one/many imports by callId (CSV); set `consumerType=EXTERNAL` for this topic |
| `RecordingsImporterTroubleshooter.requestImportForSpecificIntegrationId` | Re-import for a specific integration id |
| `ImportRescheduleService` | The internal reschedule that re-emits to EXTERNAL vs TELEPHONY (`:50`) |

Swagger (RecordingsImporter): `https://<recordingsimporter>-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[06 - Runbook & Troubleshooting|Runbook]] §4 and [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| External recordings not imported | (1) Lag on `external-recordings-import-requests` (Datadog). (2) Coralogix "got event" (`:31`) — are requests arriving? (3) Runbook §4: media access (`CustomerS3AssumedRoleAccessor`) + external CMK (`externalCmkAccessNeeded: true`). |
| Requests went to the wrong topic | `consumerType` defaulted to `DIALER` ⇒ landed on `telephony-recordings-import-requests` (`:128`). Re-send with `EXTERNAL`. |
| Import retries looping | Check `ImportRescheduleService` (`:50`) and `maxAllowedRetries` on the `ImportRequest`. |
