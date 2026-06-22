---
title: ProcessorJobSupervisor (status feedback)
component_type: upstream-producer
service: ProcessorJobSupervisor
cluster: CALL_PROCESSOR
tags: [telephony-systems, kafka, upstream, producer, oncall, call-processing, feedback]
---

# ⬆️ ProcessorJobSupervisor (status feedback)

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> This is the **feedback loop** that closes the call-processing pipeline. After Telephony Systems hands a call off for processing (see [[CALL-PROCESSING-INBOUND]]), `ProcessorJobSupervisor` reports back on **`call-processing-status-event`** (cluster `CALL_PROCESSOR`). Our Supervisor's `TsNonRecordedCallsProcessingStatusConsumer` listens for the **failure/skip** outcomes and emits a "call ingested (pipeline-skipped)" notification so the call doesn't sit in limbo. If this stops, **calls that were skipped/failed downstream never get their final ingestion notification.**
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **Only four event types matter; everything else is dropped.** The consumer keeps only `ANALYSIS_FAILED`, `CAPTURE_SKIPPED`, `CAPTURE_FAILED`, `ANALYSIS_SKIPPED` (`TsNonRecordedCallsProcessingStatusConsumer.java:49-53`). A "missing notification" is usually a success/other status that's intentionally ignored.
> 2. **Error reprocessing never stops on its own.** Per the in-code note, error processing keeps retrying — the **Gong Kafka circuit breaker** (error-rate based) is what actually halts it (`:114`). Don't expect a fixed max-retries cutoff.

---

## What it is

| | |
|---|---|
| **Role** | Upstream producer — call-processing status feedback to Telephony Systems |
| **Produces topic** | `call-processing-status-event`, cluster `CALL_PROCESSOR` |
| **Message type** | `CallProcessingStatusKafkaEvent` (grouped: `GroupedGongEvents<CallProcessingStatusKafkaEvent>`) |
| **Producer code** | In the **ProcessorJobSupervisor** repo (not mounted here) |
| **Our consumer** | `TsNonRecordedCallsProcessingStatusConsumer.accept(...)` |
| **Consumer wiring** | `configureMultipleByTenant(... CALL_PROCESSING_STATUS_EVENT ...)` — batched per tenant (`:106`) |
| **Consumer cluster const** | `KafkaClusterDetails.CALL_PROCESSOR_KAFKA_CLUSTER` |
| **Downstream of consumer** | Build `GongConnectCallIngested` (`PIPELINE_SKIPPED`) → `ingestionNotificationService.notifyCallIngestion(...)` (`:62,65`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the consumer logs consumed/sent counts at DEBUG (`TsNonRecordedCallsProcessingStatusConsumer.java:60,64`):
```text
source logs
| filter $l.applicationName == 'ingestertelephonysystemssupervisor'
| filter $m.message.contains("'call processing status' events consumed") || $m.message.contains('Sending ingestion events')
| limit 200
```
Scope to one company with `| filter $d.cid == '<companyId>'`. Errors only: `| filter $m.severity == 'ERROR'`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Signals: **consumer lag on `call-processing-status-event`** (cluster `CALL_PROCESSOR`) and the per-tenant batch metrics (`registerTenantBatchMetrics(true)`, `:127`). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ The **producer** is in the **ProcessorJobSupervisor** repo, which is **not mounted here**. Breakpoint the produce there.

Local hook on **our** side — the consumer that receives the status feedback:

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry (our hook)** | `IngesterTelephonySystemsSupervisor/.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:43` | `accept(ConsumerRecord<Long, GroupedGongEvents<CallProcessingStatusKafkaEvent>>)` — every status batch |
| **Relevance filter** | `.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:47` | The `filter(...)` keeping only the 4 failed/skipped types — the #1 "no notification" cause |
| **Notification emit** | `.../consumers/TsNonRecordedCallsProcessingStatusConsumer.java:65` | `ingestionNotificationService.notifyCallIngestion(event)` — the final ingestion signal |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TsNonRecordedCallsProcessingStatusConsumer.java` in IntelliJ; file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 43** (or 47 to inspect which events survive the filter). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a processing-status event for that company, read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `relevantEvents.size()` after line 54 shows whether anything passed the filter, without snapshot overhead.

---

## ▶️ Trigger the flow

There is no Supervisor HTTP twin for `call-processing-status-event`. To exercise the consumer, **produce a `CallProcessingStatusKafkaEvent`** (grouped) to `call-processing-status-event` on the `CALL_PROCESSOR` cluster locally (general pattern: [[Entrypoints Within the Telephony System]] §4), with `callWorkflowEvent` set to one of `ANALYSIS_FAILED` / `CAPTURE_SKIPPED` / `CAPTURE_FAILED` / `ANALYSIS_SKIPPED` (otherwise the filter drops it). Breakpoint `TsNonRecordedCallsProcessingStatusConsumer.java:43`.

To exercise the **outbound** hand-off this loop reports on, drive an ingest via `process-one-event` / `syncOneCall` (see [[CALL-PROCESSING-INBOUND]] and [[Entrypoints Within the Telephony System]] §2/§3).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Re-drive a call into ingestion (then watch the status feedback return) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the processing hand-off) |
| `CallActivityStoreIngesterTroubleshooter` | Activity-store hand-off state for processed calls |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Skipped/failed calls get no "ingested" notification | (1) Is upstream producing? Lag on `call-processing-status-event`. (2) Coralogix for "events consumed" (`:60`) then "Sending ingestion events" (`:64`). (3) Did events pass the 4-type filter (`:47`)? |
| Status events consumed but none sent | `relevantEvents` is empty — the statuses weren't one of the 4 failed/skipped types; logged "No 'call processing status' events consumed" (`:57`). Expected for success outcomes. |
| Lag climbing / retry storm | Error reprocessing doesn't self-stop; the **Gong Kafka circuit breaker** halts on error-rate (`:114`). Check downstream `notifyCallIngestion` / `IngestionEventProcessingService` health. |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[CALL-PROCESSING-STATUS-EVENT]] · [[CALL-PROCESSING-INBOUND]] · [[Entrypoints Within the Telephony System]]
