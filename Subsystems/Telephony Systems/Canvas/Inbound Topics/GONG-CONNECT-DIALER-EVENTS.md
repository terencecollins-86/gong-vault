---
title: GONG-CONNECT-DIALER-EVENTS
component_type: inbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, inbound, oncall, call-ingestion]
---

# 📥 GONG-CONNECT-DIALER-EVENTS

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The **main push path** into the Telephony Systems ingester (Entrypoints §4). A dialer (Gong Connect & friends) produces a `TelephonyCallEvent` here as a call happens; the Supervisor consumes it and runs the full single-call ingestion via `dialerService.processCallEvent(...)`. **If this consumer stalls, pushed calls never get ingested** — they don't appear in Gong, never reach transcription.
>
> 🔑 **Gotchas (verified in code):**
> 1. **No `@KafkaListener`.** The consumer is wired programmatically in `TelephonyCallEventConsumer.Beans` (`configureSingle(... KafkaTopics.DIALER_EVENTS ...)`, lines 42–46). Grepping for the annotation finds nothing — chase the `Beans` class.
> 2. **Unknown provider ⇒ silent drop.** If `getEventSupportingDialerServiceByFlavor(flavor)` returns `null`, `accept()` logs `error` and `return`s — the event is **acked and discarded**, not retried (`TelephonyCallEventConsumerAbstract.java:52-55`).
> 3. **Flavor fallback.** No flavor for the provider name ⇒ defaults to `GONG_CONNECT_API` with only an `error` log (`:37-40`), so a mis-named provider is processed as Gong Connect.

---

## What it is

| | |
|---|---|
| **Role** | Inbound push: dialer call event → single-call ingestion |
| **Topic** | `gong-connect-dialer-events` (`KafkaTopics.DIALER_EVENTS`) |
| **Cluster** | `TELEPHONY_SYSTEMS` (`TELEPHONY_SYSTEMS_KAFKA_CLUSTER`) |
| **Access (app-descriptor)** | `READ` · consumer `telephony-call-event-consumer` |
| **Message type** | `TelephonyCallEvent` (`com.honeyfy.kafka.events.call.external.dialer.TelephonyCallEvent`) |
| **Consumer** | `TelephonyCallEventConsumer` → handler in `TelephonyCallEventConsumerAbstract` |
| **Core call** | `dialerService.processCallEvent(event, Optional.of(CallOrigin.PUSH))` |
| **Producer (upstream)** | Dialer services (Gong Connect API et al.) — external to this module |
| **Downstream** | Ingest → forward on `dialer-calls-updates` ([[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/CALL-PROCESSING-INBOUND]]) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

HTTP twin (same `processCallEvent` core, no Kafka): `process-one-event` — see [[Entrypoints Within the Telephony System]] §2.

---

## 👀 See it working

**Coralogix (DataPrime)** — the consumer trace line (`TelephonyCallEventConsumerAbstract.java:48`, TRACE) and any "non supported Dialer" drop (`:53`, ERROR):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Received telephony call event') || $d.body.contains('non supported Dialer')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). #1 health signal = **Kafka consumer lag on `gong-connect-dialer-events`**. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d) (⚠️ TextIndexer routes to `deal-intelligence`). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---


## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonyCallEventConsumerAbstract.java:46` | `accept(ConsumerRecord<Long, TelephonyCallEvent>)` — every consumed record |
| **Flavor resolution** | `.../consumers/TelephonyCallEventConsumerAbstract.java:49` | `getIntegrationFlavor(event.providerName())` — watch the fallback to `GONG_CONNECT_API` |
| **Silent-drop guard** | `.../consumers/TelephonyCallEventConsumerAbstract.java:52` | `dialerService == null` ⇒ event discarded |
| **Shared core** | `.../consumers/TelephonyCallEventConsumerAbstract.java:57` | `processCallEvent(event, PUSH)` — identical to the HTTP twin (§2) |
| **Wiring** | `.../consumers/TelephonyCallEventConsumer.java:42` | `configureSingle(... DIALER_EVENTS ...)` — proves topic/cluster binding |

Step from `:46` → `:49` (flavor) → `:57` (core). To debug downstream logic without Kafka, hit the HTTP twin (`§2`, breakpoint reaches the same `processCallEvent`).

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonyCallEventConsumerAbstract.java` in IntelliJ (match the prod build — Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 46** (or `:57` for the core). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Produce a call for that company (below), read the snapshot stack/vars, then **delete the breakpoint.**

> A **Log** action at `:49` injecting `flavor` / `event.providerName()` is the cheapest way to confirm flavor resolution without snapshot overhead.

---

## ▶️ Trigger the flow

**Easiest (HTTP twin, no Kafka):** `process-one-event` drives the same `processCallEvent` core — see [[Entrypoints Within the Telephony System]] §2.
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
- Controller `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent()` (`IngesterTelephonySystemsSupervisor/.../rest/TelephonyCallEventsTroubleshooter.java:45`); core at `:50`.
- Postman: `Push — Telephony Call Events → Process one telephony call event`.

**Exercise the consumer wrapper itself** (deserialization, `accept`): produce a `TelephonyCallEvent` JSON (same shape) to topic `gong-connect-dialer-events` on the `TELEPHONY_SYSTEMS` cluster via `kafka-console-producer` / the local Kafka UI. Set the breakpoint at line 46 first (Entrypoints §4).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Replay one push event over HTTP (hits `processCallEvent`) |
| `TelephonyCallEventsTroubleshooter.clearCompanyEvents` | Delete stored call events for a company/flavor (`DELETE .../clear-events`) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Pull + re-ingest one call (the SYNC counterpart, §3) |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Pushed calls not ingested | (1) Consumer lag on `gong-connect-dialer-events` (Datadog). (2) Coralogix for "non supported Dialer" ERROR (`:53`) — flavor not resolving. (3) Is the producing dialer actually sending? |
| Calls processed under wrong provider | Flavor fallback to `GONG_CONNECT_API` (`:38`) — grep that ERROR; check `providerName` on the event. |
| Consumer lag climbing | Runbook §2: errors vs slow? Check upstream `feign.*` (FileUpload / ProviderIntegrationManager). Poison message ⇒ find offset, skip vs replay. |
