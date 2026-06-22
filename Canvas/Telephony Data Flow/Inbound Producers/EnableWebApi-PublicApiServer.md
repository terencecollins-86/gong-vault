---
title: EnableWebApi / PublicApiServer
component_type: upstream-producer
service: EnableWebApi / PublicApiServer
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, upstream, producer, oncall, recordings, low-priority]
---

# ⬆️ EnableWebApi / PublicApiServer

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Gong's public/enablement API surfaces produce two telephony events: **`external-recordings-import-requests`** (import an externally-hosted recording) and **`low-priority-dialer-events`** (dialer call events that should not compete with real-time push traffic). The low-priority topic feeds our Supervisor's `LowPriorityTelephonyCallEventConsumer`; the recordings topic feeds a **different module**.
>
> 🔑 **Three gotchas that will burn you (verified in code):**
> 1. **`external-recordings-import-requests` is NOT consumed by the Supervisor.** Its consumer (`ExternalRecordingsImportRequestsConsumer`) is in the **TelephonySystemsRecordingsImporter** module (`telephonysystemsrecordingsimporter`). Don't grep the Supervisor for it.
> 2. **Low-priority is the same code as the main consumer, different topic/tuning.** `LowPriorityTelephonyCallEventConsumer` extends `TelephonyCallEventConsumerAbstract` (same `accept`/`processCallEvent`), but wires `KafkaTopics.LOW_PRIORITY_DIALER_EVENT` → `low-priority-dialer-events` (`KafkaTopics.java:379`) with `.onlyPersistErrors()` (`LowPriorityTelephonyCallEventConsumer.java:51`).
> 3. By design low-priority **lags behind** the real-time topic — climbing lag here is often expected backfill, not an incident. Compare against `gong-connect-dialer-events` before paging.

---

## What it is

| | |
|---|---|
| **Role** | Upstream producers (public/enable API) — recording imports + low-priority dialer events |
| **Topic A** | `external-recordings-import-requests`, cluster `TELEPHONY_SYSTEMS` → **RecordingsImporter** module |
| **Topic B** | `low-priority-dialer-events`, cluster `TELEPHONY_SYSTEMS` → Supervisor `LowPriorityTelephonyCallEventConsumer` |
| **Message types** | A: `ImportRequest` (`com.honeyfy.kafka.events.recordingsimporter`) · B: `TelephonyCallEvent` (`com.honeyfy.kafka.events.call.external.dialer`) |
| **Producer code** | In the **EnableWebApi** / **PublicApiServer** repos (not mounted here) |
| **Topic B consumer** | `LowPriorityTelephonyCallEventConsumer` → `TelephonyCallEventConsumerAbstract.accept(...)` |
| **Topic A consumer** | `ExternalRecordingsImportRequestsConsumer.accept(...)` — RecordingsImporter module |
| **Consumer cluster const** | `KafkaClusterDetails.TELEPHONY_SYSTEMS_KAFKA_CLUSTER` |
| **Service ids (logs/metrics)** | `ingestertelephonysystemssupervisor` (B) · `telephonysystemsrecordingsimporter` (A) |

---

## 👀 See it working

**Coralogix (DataPrime)** — topic B shares the main consumer's log line (`TelephonyCallEventConsumerAbstract.java:48`):
```text
source logs
| filter $l.applicationName == 'ingestertelephonysystemssupervisor'
| filter $m.message.contains('Received telephony call event') || $m.message.contains('non supported Dialer')
| limit 200
```
Topic A (recordings importer, `ExternalRecordingsImportRequestsConsumer.java:31`):
```text
source logs
| filter $l.applicationName == 'telephonysystemsrecordingsimporter'
| filter $m.message.contains('got event=')
| limit 200
```
Scope either with `| filter $d.cid == '<companyId>'`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Signals: lag on `low-priority-dialer-events` (`ingestertelephonysystemssupervisor`) and `external-recordings-import-requests` (`telephonysystemsrecordingsimporter`).

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ The **producers** are in the **EnableWebApi** / **PublicApiServer** repos (**not mounted here**). Topic A's **consumer** is in the **TelephonySystemsRecordingsImporter** module — breakpoint it there.

Local hook on **our** side — the topic-B (low-priority) consumer in the Supervisor:

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Topic B consumer (our hook)** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonyCallEventConsumerAbstract.java:46` | `accept(...)` — shared by both `TelephonyCallEventConsumer` and `LowPriorityTelephonyCallEventConsumer`; every `low-priority-dialer-events` record lands here |
| **Low-priority wiring** | `.../consumers/LowPriorityTelephonyCallEventConsumer.java:42` | `configureSingle(... KafkaTopics.LOW_PRIORITY_DIALER_EVENT ...).onlyPersistErrors()` — confirms topic + error policy |
| **Topic A consumer (other module)** | `TelephonySystemsRecordingsImporter/.../consumer/ExternalRecordingsImportRequestsConsumer.java:30` | `accept(...)` → `recordingsImporterService.processRequest(...)` (run the importer to hit this) |

> Because the `accept` is shared, breakpoint line 46 catches **both** the main and low-priority consumers — read the topic on `telephonyCallEventConsumerRecord.topic()` to tell them apart.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonyCallEventConsumerAbstract.java` (topic B) or `ExternalRecordingsImportRequestsConsumer.java` (topic A) in IntelliJ; file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at line **46** (B) / **30** (A). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`** (B) or **`telephonysystemsrecordingsimporter`** (A).
3. Scope to one company:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Read the snapshot, then **delete the breakpoint.**

---

## ▶️ Trigger the flow

The low-priority path runs the **identical** `processCallEvent(...)` as the main consumer, so the `process-one-event` HTTP twin exercises the same downstream logic (full payload: [[Entrypoints Within the Telephony System]] §2):

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=GONG_CONNECT_API' \
  -H 'Content-Type: application/json' \
  -d '{
    "companyId": 0,
    "providerIdentifier": "REPLACE_PROVIDER_CALL_ID",
    "providerIdentifierType": "ENGAGE_DIALER",
    "providerName": "gong-connect",
    "direction": "OUTBOUND"
  }'
```
- To exercise the **low-priority consumer wrapper itself**, produce a `TelephonyCallEvent` JSON to `low-priority-dialer-events` on `TELEPHONY_SYSTEMS` (breakpoint line 46 first). See §4.
- For **topic A**, produce an `ImportRequest` to `external-recordings-import-requests` and debug the RecordingsImporter, or replay via `RecordingsImporterTroubleshooter`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `RecordingsImporterTroubleshooter` (RecordingsImporter module) | Replay/inspect a single external recording import (topic A) |
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Push one event through the same `processCallEvent` path (topic B downstream) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Pull a single call from the provider (compare SYNC vs low-priority push) |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Low-priority lag climbing | Often **expected** (backfill/non-realtime). Compare to `gong-connect-dialer-events` lag before paging. Errors are persisted not retried inline (`.onlyPersistErrors()`, `LowPriorityTelephonyCallEventConsumer.java:51`). |
| Low-priority calls skipped | Same `accept` logic — "non supported Dialer" + return (`TelephonyCallEventConsumerAbstract.java:53`) if flavor doesn't resolve. |
| External recording never imports | Wrong service — check **`telephonysystemsrecordingsimporter`**, not the Supervisor. Coralogix "got event=" (`:31`); `RecordingsImporterTroubleshooter`; media/CMK access (see [[06 - Runbook & Troubleshooting]] §4). |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[LOW-PRIORITY-DIALER-EVENTS]] · [[EXTERNAL-RECORDINGS-IMPORT-REQUESTS]] · [[FrontEndApi-WebFrontEnd]] · [[Entrypoints Within the Telephony System]]
