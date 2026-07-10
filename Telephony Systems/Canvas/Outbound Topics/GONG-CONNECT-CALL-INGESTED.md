---
title: GONG-CONNECT-CALL-INGESTED
component_type: outbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, outbound, oncall, gong-connect]
---

# 📤 GONG-CONNECT-CALL-INGESTED

> [[Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> A completion notification — fired when a **Gong Connect** call has finished ingesting — that tells downstream **ProspectingManager** the call is ready. If this stops, **Gong Connect calls ingest fine but prospecting/dialer follow-up never gets notified.**
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **The producer lives in the `Dialers` module, not the Supervisor's `producers/` package** — `IngestionNotificationService.notifyCallIngestion()` (`Dialers/.../services/notifier/IngestionNotificationService.java:27`). Don't grep only `IngesterTelephonySystemsSupervisor/producers` or you'll miss it.
> 2. **Producer-bean / message-type mismatch (cosmetic but confusing):** the bean `CALL_INGESTED_EVENTS_PRODUCER` is declared returning `GongEventTenantBasedKafkaTemplate<String, ImportRequest>` (`IngestionNotificationService.java:36`) yet is injected as `KafkaTemplate<String, GongConnectCallIngested>` (`:24`). It works (same underlying template), but don't be thrown by the `ImportRequest` generic when reading the bean def.

---

## What it is

| | |
|---|---|
| **Role** | Outbound completion event: Gong Connect call ingested → notify prospecting/dialer |
| **Topic / cluster** | `gong-connect-call-ingested`, cluster **`TELEPHONY_SYSTEMS`** (descriptor `READ_WRITE`, line 65) |
| **Message type** | `GongConnectCallIngested` (`com.honeyfy.kafka.events.call.GongConnectCallIngested`) |
| **Producer** | `IngestionNotificationService.notifyCallIngestion(event)` (`Dialers` module) → bean `CALL_INGESTED_EVENTS_PRODUCER` |
| **Send style** | `KafkaUtils.sendKafkaEventWithRetries(..., 3, logger)` — **3 retries** then logs |
| **Key** | `String.valueOf(event.callId)` (per-call partitioning) |
| **Downstream** | ProspectingManager (consumes `gong-connect-call-ingested`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Where the hand-off fires:**
- `Dialers/.../services/notifier/IngestionNotificationService.java:27` — `KafkaUtils.sendKafkaEventWithRetries(kafkaTemplate, GONG_CONNECT_CALL_INGESTED, ...)`

---

## 👀 See it working

**Coralogix (DataPrime)** — the send is wrapped by `KafkaUtils.sendKafkaEventWithRetries` (logs on failure/retry). Filter for the topic name and any send failures:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('gong-connect-call-ingested') || $d.body.contains('GongConnectCallIngested')
| limit 200
```
Scope to one call with `| filter $d.mdc.cid == '<companyId>'` or the `callId` in the MDC. Errors only: `| filter $m.severity == ERROR`.

- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch the Supervisor producer error rate + **Kafka consumer lag on `gong-connect-call-ingested`** (ProspectingManager backing up). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **The produce** | `Dialers/.../services/notifier/IngestionNotificationService.java:27` | The `sendKafkaEventWithRetries(...)` for the ingested-call notification |
| **Method entry** | `Dialers/.../services/notifier/IngestionNotificationService.java:26` | `notifyCallIngestion(GongConnectCallIngested event)` — inspect the event before send |

> ⚠️ The **downstream consumer (ProspectingManager) is in another repo** (not mounted here). Local breakpoint stops at our boundary — the producer `IngestionNotificationService.java:27`. To inspect what ProspectingManager does with the event, debug that service separately.

Step into `KafkaUtils.sendKafkaEventWithRetries` from `:27` to watch the 3-retry loop and the final ack/failure log.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `IngestionNotificationService.java` in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 27**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`** (the Dialers module deploys inside the Supervisor).
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a Gong Connect call (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject `event.callId` without snapshot overhead.

---

## ▶️ Trigger the flow

Drive a Gong Connect call through ingestion and the notification fires at the end. The cleanest single-call drivers are **Process one telephony call event** (push, `integration-flavor=GONG_CONNECT_API`) or **Sync one call**. (Details + payloads: [[Entrypoints Within the Telephony System]] §2/§3.)

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
- Controller: `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent()` (breakpoint `TelephonyCallEventsTroubleshooter.java:50`, step into `processCallEvent`).
- For a single pulled call: **Sync one call** (`/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall`, §3).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Re-run one Gong Connect call event end-to-end |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the notification) |
| `GongConnectCallEventConsumer` topic `gong-connect-call-event` | The inbound Gong Connect push consumer (upstream of this notification) |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Gong Connect calls ingested but no prospecting follow-up | (1) Did the notification produce? Coralogix on `ingestertelephonysystemssupervisor` for the topic. (2) Lag on `gong-connect-call-ingested` (ProspectingManager). (3) Confirm ProspectingManager (other repo) is consuming. |
| Intermittent missing notifications | Send retries **3×** (`IngestionNotificationService.java:27`) then gives up — grep `KafkaUtils.sendKafkaEventWithRetries` failure logs; no further auto-retry after the 3rd. |
| Can't find the producer | It's in the **`Dialers`** module (`IngestionNotificationService`), not the Supervisor `producers/` package. |
