---
title: DIALER-CALLS-UPDATES
component_type: outbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: SYNC_COMMUNICATIONS
tags: [telephony-systems, kafka, outbound, oncall, call-processing]
---

# 📤 DIALER-CALLS-UPDATES

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> **THE real hand-off** of a fully-ingested dialer call from the telephony ingester to the downstream communications-sync / call-processing pipeline. If this stops, **calls land in Gong but never get forwarded for transcription / processing.** This is the topic to chase first when "calls aren't processing" — *not* [[Subsystems/Consent/Canvas 1/Telephony Systems/Outbound Topics/CALL-PROCESSING-INBOUND]] (the descriptor declares that one but nothing produces to it).
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. The send is **feature-flag gated** — `SEND_DIALER_CALL_CREATION_EVENT` (`GdmCallEventSender.java:40`). Flag **off** for a company ⇒ call is ingested fine but **silently never forwarded**, no error, no log past the early `return`.
> 2. Send failures are **logged `warn`, not thrown** (`DialerCallsUpdatesProducer.java:29`) and the façade wraps the send in `Robust.tryAndLog` (`GdmCallEventSender.java:43`). A Kafka hiccup ⇒ the call is **dropped with only a warn**, no automatic retry.

---

## What it is

| | |
|---|---|
| **Role** | Outbound hand-off: ingested **dialer** call → downstream comms-sync / call processing |
| **Topic / cluster** | `dialer-calls-updates`, cluster **`SYNC_COMMUNICATIONS`** |
| **Message type** | `DialerCallEvent` (`com.honeyfy.appcommon.call.event.DialerCallEvent`) |
| **Producer** | `DialerCallsUpdatesProducer.send()` → bean `dialerCallsUpdatesProducerBean` (`GongEventTenantBasedKafkaTemplate`) |
| **Façade** | `GdmCallEventSender.sendDialerCall(companyId, callId, supplier)` |
| **Feature flag** | `SEND_DIALER_CALL_CREATION_EVENT` (per-company) |
| **Key** | `event.getCallId()` (per-call partitioning) |
| **Downstream** | [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Downstream Consumers/CommunicationsSyncServer]] (consumes `dialer-calls-updates`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Where the hand-off fires** (after a call finishes ingesting):
- `PbxRecordingImportService.java:198` — `gdmCallEventSender.sendDialerCall(...)` (from `sendToGdm()` @191)
- `UploadedCallEventService.java:63` — dialer call (the conference-call sibling at `:44` goes to [[Subsystems/Consent/Canvas 1/Telephony Systems/Outbound Topics/WEBCONFERENCE-CALL-EVENTS]] instead)

---

## 👀 See it working

**Coralogix (DataPrime)** — the actual send log line (`DialerCallsUpdatesProducer.java:31`, DEBUG `"Sent ... event to kafka"`) and the GDM façade success (`GdmCallEventSender.java:45`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('event to kafka') || $d.body.contains('call creation event to GDM')
| limit 200
```
Scope to one call by adding `| filter $d.mdc.cid == '<companyId>'` or filtering on the `callId` in the MDC.

- Errors / drops: swap the message filter for `| filter $d.body.contains('Failed sending')` (the producer warn at `:29`) or `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). The #1 health signal is **Kafka consumer lag on `dialer-calls-updates`** (CommunicationsSyncServer backing up) plus the Supervisor's producer error rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **The produce** | `CallEventCommon/.../dialer/DialerCallsUpdatesProducer.java:26` | The actual `kafkaTemplate.send(...)` — catches every outbound dialer event |
| **The FF gate** | `CallEventCommon/.../GdmCallEventSender.java:40` | See if `SEND_DIALER_CALL_CREATION_EVENT` short-circuits the send (the #1 silent drop) |
| **Hand-off trigger** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:198` | Where ingestion decides to forward the recording-import call |
| **Upload hand-off** | `IngesterTelephonySystemsSupervisor/.../services/UploadedCallEventService.java:63` | The uploaded-call dialer send path |

Step from `GdmCallEventSender:40` → if the flag returns `true`, into `send()` @44 → `DialerCallsUpdatesProducer.send()` @26 → the `kafkaTemplate.send(...)` callback at `:27` (success @31 / warn @29).

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialerCallsUpdatesProducer.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 26**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call for that company (below), read the snapshot stack/vars, then **delete the breakpoint.**

> To confirm a **silent FF drop** without snapshot overhead, put a **Log** action on `GdmCallEventSender.java:41` (inside the `!isEnabled` branch) printing `companyId` — if it fires, the flag is off.

---

## ▶️ Trigger the flow

The cleanest way to drive a real ingested-call hand-off is the **Sync one call** troubleshooter — it pulls one call from the provider and runs the full ingest → GDM-send path. (Details + payloads: [[Entrypoints Within the Telephony System]] §3.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- Set `company-id` to one with `SEND_DIALER_CALL_CREATION_EVENT` **enabled**, or the GDM send is skipped.
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Alternatives: **Process one telephony call event** (§2, push path) or driving the **SyncJob** chain (§5).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the dialer-calls-updates send) |
| `deleteCallProviderDataRecordsToAllowReimport` / `maskCallsToAllowReimport` | Clear prior state so a call can be re-ingested |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic sync that feeds ingestion |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Calls ingested but never processed | (1) Is `SEND_DIALER_CALL_CREATION_EVENT` on for the company? (`GdmCallEventSender.java:40`). (2) Coralogix for the "Failed to send call creation event to GDM" warn (`GdmCallEventSender.java:46`). (3) Lag on `dialer-calls-updates` ([[Subsystems/Call Scheduling/Canvas/Telephony Systems/Downstream Consumers/CommunicationsSyncServer]]). |
| Intermittent drops | Producer send failure is **logged warn, not thrown** (`DialerCallsUpdatesProducer.java:29`, `"Failed sending ... event to kafka"`) — grep that warn; the call won't be retried automatically. |
| "Should be on `call-processing-inbound`" confusion | It isn't — Supervisor emits `dialer-calls-updates`; the `call-processing-inbound*` descriptor grants have no producer. See [[Subsystems/Consent/Canvas 1/Telephony Systems/Outbound Topics/CALL-PROCESSING-INBOUND]] / [[Subsystems/Consent/Canvas 1/Telephony Systems/Outbound Topics/CALL-PROCESSING-INBOUND-LOW-PRIORITY]]. |
