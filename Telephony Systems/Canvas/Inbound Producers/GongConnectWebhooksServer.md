---
title: GongConnectWebhooksServer
component_type: upstream-producer
service: GongConnectWebhooksServer
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, upstream, producer, oncall, gong-connect]
---

# ⬆️ GongConnectWebhooksServer

> [[Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Gong Connect's webhook receiver. When a dialer (RingCentral, Dialpad, etc.) calls Gong Connect's webhook, this server turns it into a `TelephonyCallEvent` and **produces it to `gong-connect-dialer-events`**, which our Supervisor's `TelephonyCallEventConsumer` consumes. If this upstream stops producing, **push-path calls never reach the ingester** — they only show up later via the slower scheduled SYNC pull (entrypoint #5), if at all.
>
> 🔑 **Verified on our side:**
> - The consumer wires `KafkaTopics.DIALER_EVENTS`, which is defined as `of(GONG_CONNECT_DIALER_EVENTS)` → both resolve to the **same** topic string `gong-connect-dialer-events` (`KafkaTopics.java:376,378`). Don't go looking for a separate "dialer-events" topic.
> - The consumer is wired **programmatically** (no `@KafkaListener`) in `TelephonyCallEventConsumer.Beans` — grep for `configureSingle`, not annotations.

---

## What it is

|                               |                                                                                           |
| ----------------------------- | ----------------------------------------------------------------------------------------- |
| **Role**                      | Upstream producer — webhook receiver that emits dialer call events                        |
| **Produces topic**            | `gong-connect-dialer-events`, cluster `TELEPHONY_SYSTEMS`                                 |
| **Message type**              | `TelephonyCallEvent` (`com.honeyfy.kafka.events.call.external.dialer.TelephonyCallEvent`) |
| **Producer code**             | In the **GongConnectWebhooksServer** repo (not mounted here)                              |
| **Our consumer**              | `TelephonyCallEventConsumer` → handler `TelephonyCallEventConsumerAbstract.accept(...)`   |
| **Consumer cluster const**    | `KafkaClusterDetails.TELEPHONY_SYSTEMS_KAFKA_CLUSTER`                                     |
| **Downstream of consumer**    | `dialerService.processCallEvent(event, CallOrigin.PUSH)` → full ingestion                 |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor`                                                      |

---

## 👀 See it working

**Coralogix (DataPrime)** — our consumer logs the received event at TRACE (`TelephonyCallEventConsumerAbstract.java:48`). Watch ingestion of pushed calls:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Received telephony call event') || $d.body.contains('non supported Dialer')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). The #1 health signal is **Kafka consumer lag on `gong-connect-dialer-events`** (we're falling behind, or upstream stopped producing). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ The **producer** (the webhook receiver) is in the **GongConnectWebhooksServer** repo, which is **not mounted here**. You cannot breakpoint the produce locally from this repo.

Local hook on **our** side of the boundary — the consumer that receives what they send:

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry (our hook)** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonyCallEventConsumerAbstract.java:46` | `accept(ConsumerRecord<Long, TelephonyCallEvent>)` — every event from `gong-connect-dialer-events` lands here |
| **Shared core** | `.../consumers/TelephonyCallEventConsumerAbstract.java:57` | `dialerService.processCallEvent(event, Optional.of(CallOrigin.PUSH))` — the real ingestion |
| **Wiring** | `.../consumers/TelephonyCallEventConsumer.java:42` | `configureSingle(... KafkaTopics.DIALER_EVENTS ...)` — confirms topic/cluster |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonyCallEventConsumerAbstract.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 46** (or 57 for the processed event). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call for that company (below), read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `telephonyCallEventConsumerRecord.value()` avoids snapshot overhead.

---

## ▶️ Trigger the flow

You can't easily reproduce the upstream webhook locally, but you can drive the **identical downstream path** over HTTP via the `process-one-event` twin (it calls the same `processCallEvent(...)`). Full payload + params: [[Entrypoints Within the Telephony System]] §2.

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
- To exercise the **consumer wrapper itself**, produce a `TelephonyCallEvent` JSON to `gong-connect-dialer-events` on the `TELEPHONY_SYSTEMS` cluster (set the breakpoint at line 46 first). See §4.
- Postman: `Push — Telephony Call Events → Process one telephony call event`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Push one event through the same `processCallEvent` path (the HTTP twin) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Pull the same call from the provider instead (SYNC path) |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the scheduled sync that backs up the push path |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Push calls missing, sync calls fine | Upstream produce likely stopped. (1) Lag on `gong-connect-dialer-events` (flat consumption = no inbound). (2) Coralogix for "Received telephony call event" (`:48`) — absent ⇒ nothing arriving. |
| Calls arrive but skipped | `accept` logs "non supported Dialer" and returns (`:53`) if no `EventPushSupportingDialerService` resolves for the flavor — check `getIntegrationFlavor` mapping. |
| Lag climbing | Consumer-side slow vs. upstream burst — see [[06 - Runbook & Troubleshooting]] §2; check `feign.*` downstream deps. |

> Related: [[Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[Call Scheduling/Canvas/Telephony Systems/Inbound Topics/GONG-CONNECT-DIALER-EVENTS]] · [[Entrypoints Within the Telephony System]]
