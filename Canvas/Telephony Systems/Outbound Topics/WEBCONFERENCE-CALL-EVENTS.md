---
title: WEBCONFERENCE-CALL-EVENTS
component_type: outbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: SYNC_COMMUNICATIONS
tags: [telephony-systems, kafka, outbound, oncall, call-processing]
---

# 📤 WEBCONFERENCE-CALL-EVENTS

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The web-conference sibling of [[DIALER-CALLS-UPDATES]] — hand-off of an ingested **conference call** to the downstream comms-sync / call-processing pipeline. If this stops, **conference calls land in Gong but never get forwarded for processing.**
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **Same feature-flag gate as the dialer path** — `SEND_DIALER_CALL_CREATION_EVENT` (`GdmCallEventSender.java:40`). The flag name says "dialer" but it gates **both** `sendDialerCall` and `sendWebConfCall` (they share the private `send(...)` at `:39`). Flag off ⇒ conference call **silently never forwarded**.
> 2. Send failures are **logged `warn`, not thrown** (`WebConfCallsUpdatesProducer.java:29`, wrapped by `GdmCallEventSender.tryAndLog` @43). A Kafka hiccup ⇒ call dropped with only a warn, no retry.

---

## What it is

| | |
|---|---|
| **Role** | Outbound hand-off: ingested **web-conference** call → downstream comms-sync / call processing |
| **Topic / cluster** | `webconference-call-events`, cluster **`SYNC_COMMUNICATIONS`** |
| **Message type** | `WebConferenceCallEvent` (`com.honeyfy.appcommon.call.event.WebConferenceCallEvent`) |
| **Producer** | `WebConfCallsUpdatesProducer.send()` → bean `webConfCallsUpdatesProducerBean` (`GongEventTenantBasedKafkaTemplate`) |
| **Façade** | `GdmCallEventSender.sendWebConfCall(companyId, callId, supplier)` (lines 35–37) |
| **Feature flag** | `SEND_DIALER_CALL_CREATION_EVENT` (per-company; shared with the dialer path) |
| **Key** | `event.getCallId()` (per-call partitioning) |
| **Downstream** | [[CommunicationsSyncServer]] (consumes `webconference-call-events`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Where the hand-off fires** (after a conference call finishes ingesting):
- `UploadedCallEventService.java:44` — `gdmCallEventSender.sendWebConfCall(...)` (the dialer sibling at `:63` goes to [[DIALER-CALLS-UPDATES]] instead)

---

## 👀 See it working

**Coralogix (DataPrime)** — the actual send log line (`WebConfCallsUpdatesProducer.java:32`, DEBUG `"Sent ... event to kafka"`) and the GDM façade success (`GdmCallEventSender.java:45`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('WebConferenceCallEvent') || $d.body.contains('call creation event to GDM')
| limit 200
```
Scope to one call by adding `| filter $d.mdc.cid == '<companyId>'` or filtering on the `callId` in the MDC. (The producer logs `event.getClass().getSimpleName()`, so `WebConferenceCallEvent` distinguishes these from dialer sends on the shared façade line.)

- Errors / drops: `| filter $d.body.contains('Failed sending')` (producer warn at `:29`) or `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch **Kafka consumer lag on `webconference-call-events`** + the Supervisor producer error rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **The produce** | `CallEventCommon/.../webconf/WebConfCallsUpdatesProducer.java:27` | The actual `kafkaTemplate.send(...)` for every conference event |
| **The FF gate** | `CallEventCommon/.../GdmCallEventSender.java:40` | Shared `SEND_DIALER_CALL_CREATION_EVENT` gate — the #1 silent drop |
| **Façade entry** | `CallEventCommon/.../GdmCallEventSender.java:35` | `sendWebConfCall(...)` → routes into the shared `send(...)` @39 |
| **Hand-off trigger** | `IngesterTelephonySystemsSupervisor/.../services/UploadedCallEventService.java:44` | Where an uploaded conference call is forwarded |

Step from `GdmCallEventSender:35` → `send()` @39 → if the flag returns `true`, into `WebConfCallsUpdatesProducer.send()` @27 (callback @28, success @32 / warn @29).

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `WebConfCallsUpdatesProducer.java` in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 27**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a conference call for that company, read the snapshot, then **delete the breakpoint.**

> Use a **Log** action on `GdmCallEventSender.java:41` to confirm a **silent FF drop** without snapshot overhead.

---

## ▶️ Trigger the flow

A conference-call hand-off fires from `UploadedCallEventService.processUploadedCall`. The most direct on-demand driver is the **Process one telephony call event** troubleshooter (push path), or **Sync one call** for a pulled conference recording. (Details + payloads: [[Entrypoints Within the Telephony System]] §2/§3.)

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
- Controller: `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent()` (breakpoint at `TelephonyCallEventsTroubleshooter.java:50`, then step into `processCallEvent`).
- Set `company-id`/`companyId` to one with `SEND_DIALER_CALL_CREATION_EVENT` **enabled**, or the GDM send is skipped.
- A conference recording routes to `sendWebConfCall`; a plain dialer call routes to `sendDialerCall`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent` | Re-run one call event end-to-end (re-fires the GDM send) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one (conference) call |
| `deleteCallProviderDataRecordsToAllowReimport` / `maskCallsToAllowReimport` | Clear prior state so a call can be re-ingested |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Conference calls ingested but never processed | (1) Is `SEND_DIALER_CALL_CREATION_EVENT` on for the company? (`GdmCallEventSender.java:40`). (2) Coralogix for the "Failed to send call creation event to GDM" warn (`GdmCallEventSender.java:46`). (3) Lag on `webconference-call-events` ([[CommunicationsSyncServer]]). |
| Intermittent drops | Producer send failure is **logged warn, not thrown** (`WebConfCallsUpdatesProducer.java:29`) — grep that warn; the call won't be retried automatically. |
| Dialer calls work, conference calls don't (or vice-versa) | They share the FF gate but use **different producers/topics** — confirm which `send*` ran (`GdmCallEventSender.java:35` vs `:31`) and check lag on the right topic. |
