---
title: CALL-PROCESSING-STATUS-EVENT
component_type: inbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: CALL_PROCESSOR
tags: [telephony-systems, kafka, inbound, oncall, call-processing]
---

# 📥 CALL-PROCESSING-STATUS-EVENT

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The **feedback loop from the AI call-processing pipeline** back into Telephony Systems. The pipeline emits per-call workflow status; this consumer listens for the *failure/skip* outcomes on **non-recorded calls** and emits a `GongConnectCallIngested` notification with status `PIPELINE_SKIPPED` so Gong Connect knows the call won't be processed further. If it stalls, **Gong Connect never learns that a non-recorded call was skipped/failed** — the call sits in an ambiguous state for the customer.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Only 4 workflow outcomes are acted on.** It filters to `ANALYSIS_FAILED`, `CAPTURE_SKIPPED`, `CAPTURE_FAILED`, `ANALYSIS_SKIPPED` (`TsNonRecordedCallsProcessingStatusConsumer.java:49-53`). Everything else is counted as "no relevant events" and dropped (`:56-59`).
> 2. **It's the inbound counterpart of [[CALL-PROCESSING-INBOUND]].** The Supervisor *sends* calls to processing on `dialer-calls-updates`; processing reports *back* here on the `CALL_PROCESSOR` cluster. Don't confuse the two directions.
> 3. **No `@KafkaListener`** — per-tenant batched via `configureMultipleByTenant(... CALL_PROCESSING_STATUS_EVENT ...)` (`:106-110`). Error-reprocessing runs hourly; the comment at `:114` notes Gong's Kafka circuit-breaker (not retry count) is what ultimately stops retries.

---

## What it is

| | |
|---|---|
| **Role** | Inbound pipeline status → notify Gong Connect that a non-recorded call was skipped |
| **Topic** | `call-processing-status-event` (`KafkaTopics.CALL_PROCESSING_STATUS_EVENT`) |
| **Cluster** | `CALL_PROCESSOR` (`CALL_PROCESSOR_KAFKA_CLUSTER`) |
| **Access (app-descriptor)** | `READ` (line 88-89) |
| **Message type** | `GroupedGongEvents<CallProcessingStatusKafkaEvent>` (`com.honeyfy.kafka.events.call.CallProcessingStatusKafkaEvent`) |
| **Consumer** | `TsNonRecordedCallsProcessingStatusConsumer` |
| **Core call** | `ingestionEventBuilderService.generateIngestionEventsForCallsIds(... PIPELINE_SKIPPED)` → `ingestionNotificationService.notifyCallIngestion(event)` |
| **Upstream producer** | AI call-processing pipeline (`ProcessorJobSupervisor` family) — external to this module |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the "events consumed" and "Sending ingestion events" debug lines (`TsNonRecordedCallsProcessingStatusConsumer.java:60` and `:64`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('call processing status') || $d.body.contains('Sending ingestion events')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`. The "No 'call processing status' events consumed" line (`:57`) means a batch arrived but none of the 4 relevant outcomes were present.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Lag on `call-processing-status-event` + per-tenant batch metrics (`registerTenantBatchMetrics(true)`, `:127`). Filter `service:ingestertelephonysystemssupervisor` + `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate via *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `IngesterTelephonySystemsSupervisor/.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:43` | `accept(ConsumerRecord<Long, GroupedGongEvents<CallProcessingStatusKafkaEvent>>)` — every batch |
| **Relevance filter** | `.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:47` | The filter to the 4 failure/skip outcomes |
| **Build notifications** | `.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:62` | `generateIngestionEventsForCallsIds(... PIPELINE_SKIPPED)` |
| **Send notifications** | `.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:65` | `notifyCallIngestion(event)` — the outbound notify per call |
| **Wiring** | `.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:106` | `configureMultipleByTenant(... CALL_PROCESSING_STATUS_EVENT ...)` |

Step from `:43` → `:47` (filter) → `:62` (build) → `:65` (send). If `relevantEvents` is empty you exit at `:58`.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against prod. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TsNonRecordedCallsProcessingStatusConsumer.java` in IntelliJ (match the prod build — Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 43**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a pipeline status event for that company, read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `relevantEvents.size()` at `:55` shows whether the batch contained any of the 4 actionable outcomes without snapshot overhead.

---

## ▶️ Trigger the flow

There is **no Supervisor HTTP twin** that produces a `CallProcessingStatusKafkaEvent` — it originates in the AI call-processing pipeline (another subsystem) and lands on the `CALL_PROCESSOR` cluster. On our side the local hook is the consumer above.

**To exercise this consumer:** produce a `GroupedGongEvents<CallProcessingStatusKafkaEvent>` whose events carry one of the 4 actionable `callWorkflowEvent`s (`ANALYSIS_FAILED`, `CAPTURE_SKIPPED`, `CAPTURE_FAILED`, `ANALYSIS_SKIPPED`) and valid `callId`s, to topic `call-processing-status-event` on the `CALL_PROCESSOR` cluster — see [[Entrypoints Within the Telephony System]] §4 for the produce-to-topic pattern. Anything else is filtered out (`:47`). Breakpoint `:43` first.

---

## 🧰 Troubleshooters

There is **no dedicated troubleshooter** for this status topic. Related drivers for the call-ingest notify path:

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-ingest a non-recorded call to regenerate its pipeline + notify state (§3) |
| `RecordingsImporterTroubleshooter.requestImport` | Re-drive a call's import (RecordingsImporter) when status is stuck |

Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Gong Connect not told a call was skipped | (1) Lag on `call-processing-status-event`. (2) Coralogix for "Sending ingestion events" (`:64`) — are notifications going out? (3) Was the outcome one of the 4 actionable events (`:49-53`)? |
| Batches arrive but nothing happens | Expected when no relevant outcome present — see "No 'call processing status' events consumed" (`:57`). |
| Retries never stop | By design retries don't stop on count — the Kafka circuit-breaker on error-rate does (`:114`). Check error rate / cooldown. |
