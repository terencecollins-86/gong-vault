---
title: GongConnect WebApi / Tasks
component_type: upstream-producer
service: GongConnectWebApi / GongConnectTasks
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, upstream, producer, oncall, gong-connect]
---

# ⬆️ GongConnect WebApi / Tasks

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The other two Gong Connect services — **GongConnectWebApi** and **GongConnectTasks** — also produce `TelephonyCallEvent`s to **`gong-connect-dialer-events`**, the same topic as [[GongConnectWebhooksServer]]. They feed the **same** Supervisor consumer (`TelephonyCallEventConsumer`). If only one of the three producers misbehaves, push-path calls from that source go missing while others flow — so when triaging "some calls missing," you can't tell the three apart from the consumer side alone; correlate by `providerName`/company in the payload.
>
> 🔑 **Verified on our side:** the consumer wires `KafkaTopics.DIALER_EVENTS = of(GONG_CONNECT_DIALER_EVENTS)` → topic string `gong-connect-dialer-events` (`KafkaTopics.java:376,378`), cluster `TELEPHONY_SYSTEMS`. Wired programmatically via `configureSingle`, no `@KafkaListener`.

---

## What it is

| | |
|---|---|
| **Role** | Upstream producers (WebApi + Tasks) emitting dialer call events |
| **Produces topic** | `gong-connect-dialer-events`, cluster `TELEPHONY_SYSTEMS` |
| **Message type** | `TelephonyCallEvent` (`com.honeyfy.kafka.events.call.external.dialer.TelephonyCallEvent`) |
| **Producer code** | In the **GongConnectWebApi** / **GongConnectTasks** repos (not mounted here) |
| **Our consumer** | `TelephonyCallEventConsumer` → `TelephonyCallEventConsumerAbstract.accept(...)` |
| **Consumer cluster const** | `KafkaClusterDetails.TELEPHONY_SYSTEMS_KAFKA_CLUSTER` |
| **Downstream of consumer** | `dialerService.processCallEvent(event, CallOrigin.PUSH)` |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the consumer logs each received event at TRACE (`TelephonyCallEventConsumerAbstract.java:48`):
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Received telephony call event') || $d.body.contains('non supported Dialer')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Key signal: **consumer lag on `gong-connect-dialer-events`**. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ The **producers** live in the **GongConnectWebApi** and **GongConnectTasks** repos, which are **not mounted here**. Breakpoint the produce in those repos.

Local hook on **our** side — the consumer that receives all three Gong Connect producers:

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry (our hook)** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonyCallEventConsumerAbstract.java:46` | `accept(ConsumerRecord<Long, TelephonyCallEvent>)` — every event from `gong-connect-dialer-events` |
| **Flavor resolution** | `.../consumers/TelephonyCallEventConsumerAbstract.java:49` | `getIntegrationFlavor(event.providerName())` — maps the producer's `providerName` to a dialer service |
| **Shared core** | `.../consumers/TelephonyCallEventConsumerAbstract.java:57` | `dialerService.processCallEvent(event, Optional.of(CallOrigin.PUSH))` |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonyCallEventConsumerAbstract.java` in IntelliJ; file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 46**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call, read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `event.providerName()` at line 49 tells you which producer/provider the event came from without snapshot overhead.

---

## ▶️ Trigger the flow

Reproduce the downstream over HTTP with the `process-one-event` twin (same `processCallEvent(...)`). Full payload: [[Entrypoints Within the Telephony System]] §2.

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
- To exercise the **consumer wrapper itself**, produce a `TelephonyCallEvent` JSON to `gong-connect-dialer-events` on `TELEPHONY_SYSTEMS` (breakpoint line 46 first). See §4.
- Postman: `Push — Telephony Call Events → Process one telephony call event`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Push one event through `processCallEvent` (HTTP twin) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Pull the call from the provider instead (SYNC path) |
| `TelephonyIntegrationFrontTroubleshooter` / `IntegrationsTroubleshooter` | Check the company's Gong Connect integration config state |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Some Gong Connect calls missing, not all | One of the three producers (WebhooksServer / WebApi / Tasks) is degraded. Correlate by company + `providerName` in Coralogix; the consumer can't distinguish source. Check lag on `gong-connect-dialer-events`. |
| Event arrives but no service handles it | `accept` logs "non supported Dialer" + returns (`:53`) — flavor from `getIntegrationFlavor` (`:49`) didn't resolve a push-supporting service. |
| Defaulted to gong-connect unexpectedly | `getIntegrationFlavor` falls back to `GONG_CONNECT_API` and logs an error when no flavor matches `providerName` (`:38`). |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[GONG-CONNECT-DIALER-EVENTS]] · [[GongConnectWebhooksServer]] · [[Entrypoints Within the Telephony System]]
