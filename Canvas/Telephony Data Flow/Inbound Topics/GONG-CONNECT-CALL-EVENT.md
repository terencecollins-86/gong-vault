---
title: GONG-CONNECT-CALL-EVENT
component_type: inbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, inbound, oncall, gong-connect]
---

# 📥 GONG-CONNECT-CALL-EVENT

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> A Gong-Connect call event consumed by the Supervisor. **In its current state this consumer is effectively a no-op** — `accept()` only logs `"Not re-enabling Gong Connect sync job"` and does nothing else. So there is **no downstream user impact** if it lags or fails; do not chase this for "calls missing". It exists to hold the topic subscription and consumer-group offset.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Handler is a no-op.** `GongConnectCallEventConsumer.accept()` reads `companyId` and logs one line — no service call, no produce (`GongConnectCallEventConsumer.java:25-28`). Don't expect side effects.
> 2. **Lives in `services/`, not `consumers/`.** Despite being a consumer, the class is at `.../ingestertelephonysystems/services/GongConnectCallEventConsumer.java` and is wired from `IngesterTelephonySystemsSupervisorConfig` (`@Import GongConnectCallEventConsumer.Beans.class`). Grepping `consumers/` misses it.
> 3. **No `@KafkaListener`** — wired via `configureMultipleByTenant(... GONG_CONNECT_CALL_EVENT ...)` (`GongConnectCallEventConsumer.java:49-53`); batched per tenant.

---

## What it is

| | |
|---|---|
| **Role** | Inbound Gong-Connect call event (currently no-op handler) |
| **Topic** | `gong-connect-call-event` (`KafkaTopics.GONG_CONNECT_CALL_EVENT`) |
| **Cluster** | `TELEPHONY_SYSTEMS` (`TELEPHONY_SYSTEMS_KAFKA_CLUSTER`) |
| **Access (app-descriptor)** | `READ` · consumer `gong-connect-call-event-consumer` |
| **Message type** | `GroupedGongEvents<GongConnectCallEvent>` (`com.honeyfy.kafka.events.gongconnect.GongConnectCallEvent`) |
| **Consumer** | `GongConnectCallEventConsumer` (in `services/`) |
| **Handler body** | logs only — `"Not re-enabling Gong Connect sync job for companyId=…"` |
| **Producer (upstream)** | Gong Connect — external to this module |
| **Downstream** | none (no-op) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the only signal this consumer emits is its single info line (`GongConnectCallEventConsumer.java:27`):
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Not re-enabling Gong Connect sync job')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Seeing this line means the consumer is alive and receiving; absence over a busy window means it's not consuming (check lag).

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Only meaningful metric here is **consumer lag on `gong-connect-call-event`** (group health), not business throughput. Filter `service:ingestertelephonysystemssupervisor` + `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). A no-op handler rarely throws; deserialization of `GongConnectCallEvent` is the only real failure surface.

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `IngesterTelephonySystemsSupervisor/.../services/GongConnectCallEventConsumer.java:25` | `accept(ConsumerRecord<Long, GroupedGongEvents<GongConnectCallEvent>>)` — the whole handler |
| **The (only) log** | `.../services/GongConnectCallEventConsumer.java:27` | Confirms the no-op path; inspect `companyId` / batched events |
| **Wiring** | `.../services/GongConnectCallEventConsumer.java:49` | `configureMultipleByTenant(... GONG_CONNECT_CALL_EVENT ...)` — topic/cluster binding |

`accept()` does nothing past the log, so there is no deeper step-through — the value of a breakpoint here is to inspect the deserialized batch and confirm delivery.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against prod. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `GongConnectCallEventConsumer.java` in IntelliJ (match the prod build — Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 25**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Read the batched events off `longGroupedGongEventsConsumerRecord.value()`, then **delete the breakpoint.**

> A **Log** action injecting `longGroupedGongEventsConsumerRecord.value().events.size()` confirms batch sizes without snapshot overhead.

---

## ▶️ Trigger the flow

**No HTTP twin exists** for this consumer (and the handler is a no-op). To exercise the wrapper (deserialization, batching, MDC), produce a `GongConnectCallEvent` JSON to topic `gong-connect-call-event` on the `TELEPHONY_SYSTEMS` cluster via `kafka-console-producer` or the local Kafka UI — see [[Entrypoints Within the Telephony System]] §4 for the produce-to-topic pattern. Set the breakpoint at line 25 first.

> Since the consumer batches per tenant (`configureMultipleByTenant`), produce a few events for the same `companyId` to see them grouped.

---

## 🧰 Troubleshooters

There is **no dedicated troubleshooter** for this topic (no-op handler, nothing to replay). For Gong-Connect call ingestion in general, drive a real call via the push twin or sync:

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Push one Gong-Connect call event through real ingestion (§2) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Pull + ingest one Gong-Connect call (§3) |

Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| "Gong Connect calls missing" reported against this topic | It can't be the cause — handler is a no-op (`:27`). Chase [[GONG-CONNECT-DIALER-EVENTS]] (the real push path) and the sync chain instead. |
| Consumer-group lag on `gong-connect-call-event` | Cosmetic for users, but a stuck group can alarm. Confirm the consumer pod is up; check for deserialization errors on `GongConnectCallEvent`. |
| Repeated errors in `accept` | Almost certainly payload/deserialization — inspect the record value at `:25`. |
