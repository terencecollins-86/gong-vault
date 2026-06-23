---
title: ProspectingManager
component_type: downstream-consumer
service: ProspectingManager
tags: [telephony-systems, downstream, consumer, kafka, oncall]
---

# ⬇️ ProspectingManager

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Downstream consumer of **`gong-connect-call-ingested`** — our notification that a Gong-Connect call finished ingesting. If our producer stops, **ProspectingManager never learns a call was ingested** and its prospecting follow-ups stall.
>
> 🔑 **Gotchas that will burn you (verified in code):**
> 1. **The producer retries then gives up — it does NOT throw past the retry budget.** `IngestionNotificationService.notifyCallIngestion()` calls `KafkaUtils.sendKafkaEventWithRetries(..., 3, ...)`; after 3 attempts it logs `Failed sending ... event to kafka` warn (`KafkaUtils.java:26`) and moves on. A flapping cluster = silently dropped notifications.
> 2. **2-second send timeout per attempt** (`KafkaUtils.java:13`, `DEFAULT_SEND_EVENT_TIMEOUT_MS = 2000`). Slow broker ⇒ each attempt times out ⇒ all 3 retries burn fast ⇒ drop.
> 3. **Key is the `callId` as a String** (`String.valueOf(event.callId)`), not a Long — partitioning differs from the dialer-event topics.

---

## What it is

| | |
|---|---|
| **Role** | Downstream consumer of the "call ingested" notification |
| **Consumes** | `gong-connect-call-ingested` (see [[GONG-CONNECT-CALL-INGESTED]]) |
| **Cluster** | `TELEPHONY_SYSTEMS` |
| **Message type** | `GongConnectCallIngested` (`com.honeyfy.kafka.events.call.GongConnectCallIngested`) |
| **Our producer** | `IngestionNotificationService.notifyCallIngestion()` → `KafkaUtils.sendKafkaEventWithRetries(...)` |
| **Producer bean** | `CALL_INGESTED_EVENTS_PRODUCER` (`TELEPHONY_SYSTEMS` cluster) |
| **Descriptor** | `READ_WRITE` to `gong-connect-call-ingested` (`...gong-app-descriptor.yaml:65`) |
| **Consumer code** | **In another repo** (ProspectingManager) — not mounted here |
| **Service id — OURS (producer-side)** | `ingestertelephonysystemssupervisor` |
| **Service id — theirs (consumer logs)** | `prospectingmanager` |

---

## 👀 See it working

The consumer runs in **ProspectingManager**, so its consume logs are under **`prospectingmanager`** — not us. From our side, watch the **produce** log + **downstream consumer lag** as the cross-boundary health signal.

**Coralogix (DataPrime)** — our produce log line (`KafkaUtils.java:22`, DEBUG, shared util) on the Supervisor side:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Sent') && $d.body.contains('event to kafka')
| filter $d.body.contains('GongConnectCallIngested')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`.

- Errors only: grep the `Failed sending ... event to kafka` warn (`KafkaUtils.java:26`).
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Cross-boundary health signal = **Kafka consumer lag on `gong-connect-call-ingested`** (ProspectingManager backing up) + our producer error rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — our producer side: [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ **The consumer is in another repo** (ProspectingManager) — not mounted here. The hooks below are **our producer** on our side of the boundary.

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **The notify call** | `Dialers/src/main/java/com/honeyfy/dialers/services/notifier/IngestionNotificationService.java:27` | `sendKafkaEventWithRetries(..., GONG_CONNECT_CALL_INGESTED, ...)` — where ingestion fires the notification |
| **The actual produce** | `Dialers/src/main/java/com/honeyfy/dialers/utils/KafkaUtils.java:20` | `kafkaTemplate.send(topic.topic(), key, event)` — the real publish + ack, inside the retry loop |
| **Retry give-up** | `Dialers/src/main/java/com/honeyfy/dialers/utils/KafkaUtils.java:26` | The `log.warn` after the timeout — confirms a drop after 3 attempts |

Break at `IngestionNotificationService.java:27`, step into `KafkaUtils.sendKafkaEventWithRetries` → the `send(...)` @20.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `KafkaUtils.java` (or `IngestionNotificationService.java`) in IntelliJ; match the prod file version (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 20** (the `send`) or **line 26** (the give-up warn). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call ingestion for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject `event.callId` on-demand without snapshot overhead.

---

## ▶️ Trigger the flow

Drive a Gong-Connect call ingestion end-to-end, then the notification fires. The cleanest single-call driver is **Sync one call** (Entrypoints §3); for the push path use **Process one telephony call event** (§2):

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- Use a Gong-Connect integration so the `gong-connect-call-ingested` notification path is exercised.
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the notification) |
| `TelephonyCallEventsTroubleshooter` | Push one Gong-Connect call event through ingestion |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic sync that feeds ingestion |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| ProspectingManager not reacting to ingested calls | (1) Coralogix for the `Failed sending ... event to kafka` warn (`KafkaUtils.java:26`). (2) Lag on `gong-connect-call-ingested`. (3) Did ingestion actually complete for the call? |
| Intermittent missed notifications | Send retries **3×** then gives up warn-only (`KafkaUtils.java:26`); 2s timeout/attempt (`KafkaUtils.java:13`). Slow broker burns the budget fast — check broker latency. |
| Notifications land on wrong partition | Key is `String.valueOf(event.callId)` (`IngestionNotificationService.java:27`) — String, not Long. |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[GONG-CONNECT-CALL-INGESTED]]
