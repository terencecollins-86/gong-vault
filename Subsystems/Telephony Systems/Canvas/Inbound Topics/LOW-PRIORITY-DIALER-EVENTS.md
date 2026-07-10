---
title: LOW-PRIORITY-DIALER-EVENTS
component_type: inbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, inbound, oncall, call-ingestion]
---

# 📥 LOW-PRIORITY-DIALER-EVENTS

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The **low-priority twin** of [[Subsystems/Consent/Canvas 1/Telephony Systems/Inbound Topics/GONG-CONNECT-DIALER-EVENTS]]. Same `TelephonyCallEvent` payload, same handler (`LowPriorityTelephonyCallEventConsumer` extends `TelephonyCallEventConsumerAbstract`), same `processCallEvent(... PUSH)` core — but on a separate topic so backfill / bulk push traffic can't starve live calls. If this stalls, **low-priority pushed calls back up** but live ingestion on the main topic is unaffected.
>
> 🔑 **Gotchas (verified in code):**
> 1. **`.onlyPersistErrors()`** is set on this consumer (`LowPriorityTelephonyCallEventConsumer.java:51`) — the *only* config difference from the main consumer. Failed records are persisted (not retried inline), so a poison message here surfaces as a stored error, not a tight retry loop.
> 2. **Shared silent-drop.** It inherits `accept()` from the abstract: unknown provider flavor ⇒ `error` log + `return`, event discarded (`TelephonyCallEventConsumerAbstract.java:52-55`).
> 3. **No `@KafkaListener`** — wired in `LowPriorityTelephonyCallEventConsumer.Beans` (`configureSingle(... LOW_PRIORITY_DIALER_EVENT ...)`, lines 42–46).

---

## What it is

| | |
|---|---|
| **Role** | Inbound push (low priority): backfill/bulk dialer events → ingestion |
| **Topic** | `low-priority-dialer-events` (`KafkaTopics.LOW_PRIORITY_DIALER_EVENT`) |
| **Cluster** | `TELEPHONY_SYSTEMS` (`TELEPHONY_SYSTEMS_KAFKA_CLUSTER`) |
| **Access (app-descriptor)** | `READ` · consumer `low-priority-telephony-call-event-consumer` |
| **Message type** | `TelephonyCallEvent` (`com.honeyfy.kafka.events.call.external.dialer.TelephonyCallEvent`) |
| **Consumer** | `LowPriorityTelephonyCallEventConsumer` → handler in `TelephonyCallEventConsumerAbstract` |
| **Core call** | `dialerService.processCallEvent(event, Optional.of(CallOrigin.PUSH))` |
| **Producer (upstream)** | Dialer services routing low-priority pushes — external to this module |
| **Downstream** | Same as main path: ingest → `dialer-calls-updates` ([[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/CALL-PROCESSING-INBOUND]]) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — handler trace line (`TelephonyCallEventConsumerAbstract.java:48`) and drops (`:53`). Both consumers share the abstract class, so scope by topic/lag in Datadog to tell them apart; logs are identical text:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Received telephony call event') || $d.body.contains('non supported Dialer')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch **consumer lag on `low-priority-dialer-events`** specifically (vs the main topic). Filter `service:ingestertelephonysystemssupervisor` + `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate via *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonyCallEventConsumerAbstract.java:46` | `accept(...)` — shared by both consumers; entry for every record |
| **Silent-drop guard** | `.../consumers/TelephonyCallEventConsumerAbstract.java:52` | `dialerService == null` ⇒ discarded |
| **Shared core** | `.../consumers/TelephonyCallEventConsumerAbstract.java:57` | `processCallEvent(event, PUSH)` |
| **Low-prio wiring** | `.../consumers/LowPriorityTelephonyCallEventConsumer.java:42` | `configureSingle(... LOW_PRIORITY_DIALER_EVENT ...)` — binds this topic |
| **`onlyPersistErrors`** | `.../consumers/LowPriorityTelephonyCallEventConsumer.java:51` | The behavioural difference from the main consumer |

> Both consumers share `accept()` at `:46`. To confirm you're on the **low-priority** path, breakpoint the bean factory at `LowPriorityTelephonyCallEventConsumer.java:40` or filter by topic, since the abstract handler can't tell you which subclass invoked it.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against prod. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonyCallEventConsumerAbstract.java` in IntelliJ (match the prod build — Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 46** (or `:57`). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Produce a low-priority event (below), read the snapshot, then **delete the breakpoint.**

> Because both consumers hit the same line, add `&&` your `cid` filter to a known low-priority company so you only catch this path.

---

## ▶️ Trigger the flow

There is **no dedicated HTTP twin for the low-priority topic** — the `process-one-event` troubleshooter ([[Entrypoints Within the Telephony System]] §2) exercises the same `processCallEvent` core regardless of priority:
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
- Controller `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent()` (`.../rest/TelephonyCallEventsTroubleshooter.java:45`).
- Postman: `Push — Telephony Call Events → Process one telephony call event`.

**To exercise this consumer specifically**, produce a `TelephonyCallEvent` JSON to topic `low-priority-dialer-events` on the `TELEPHONY_SYSTEMS` cluster (Entrypoints §4 lists this consumer in the same-pattern table). Set the breakpoint at `:46` first.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Replay one push event over HTTP (shared core) |
| `TelephonyCallEventsTroubleshooter.clearCompanyEvents` | Delete stored call events for a company/flavor |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Pull + re-ingest one call (SYNC counterpart, §3) |

Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Low-priority calls lagging, live calls fine | Expected isolation — check lag on `low-priority-dialer-events` only. Backfill burst? Let it drain or scale consumer concurrency. |
| Errors persisted, not retried | `.onlyPersistErrors()` (`:51`) is intended — inspect persisted error records rather than expecting inline retries. |
| Calls processed under wrong provider | Flavor fallback to `GONG_CONNECT_API` (`TelephonyCallEventConsumerAbstract.java:38`) — check `providerName`. |
