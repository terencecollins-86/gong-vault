---
title: ProcessorJobSupervisor
component_type: downstream-consumer
service: ProcessorJobSupervisor
tags: [telephony-systems, downstream, consumer, kafka, oncall, call-processing]
---

# ⬇️ ProcessorJobSupervisor

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The **AI call-processing pipeline** — it consumes the fully-ingested-call hand-off from the telephony Supervisor and runs transcription / processing. If our hand-off stops, **calls land in Gong but never get transcribed / processed.**
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. The Supervisor's app-descriptor declares `WRITE` to `call-processing-inbound` (`IngesterTelephonySystemsSupervisor.gong-app-descriptor.yaml:84/86`, cluster `CALL_PROCESSOR`) **but no Supervisor code produces to it.** The real hand-off goes out on **`dialer-calls-updates`** (`SYNC_COMMUNICATIONS` cluster) via `DialerCallsUpdatesProducer.send()`. Chase *that* topic when calls don't reach processing. See [[CALL-PROCESSING-INBOUND]].
> 2. The send is **feature-flag gated** — `SEND_DIALER_CALL_CREATION_EVENT`. Flag off for a company ⇒ call is ingested fine but **silently never forwarded**, no error.

---

## What it is

| | |
|---|---|
| **Role** | Downstream consumer: ingested call → AI call-processing pipeline |
| **Consumes (canvas label / declared)** | `call-processing-inbound` (+ `-low-priority`), cluster `CALL_PROCESSOR` |
| **Topic our code actually produces** | `dialer-calls-updates`, cluster `SYNC_COMMUNICATIONS` (see [[DIALER-CALLS-UPDATES]]) |
| **Message type** | `DialerCallEvent` (`com.honeyfy.appcommon.call.event.DialerCallEvent`) |
| **Our producer** | `DialerCallsUpdatesProducer.send()` → bean `dialerCallsUpdatesProducerBean` |
| **Façade** | `GdmCallEventSender.sendDialerCall(companyId, callId, supplier)` |
| **Feature flag** | `SEND_DIALER_CALL_CREATION_EVENT` (per-company) |
| **Consumer code** | **In another repo** (ProcessorJobSupervisor service) — not mounted here |
| **Service id — OURS (producer-side logs/metrics)** | `ingestertelephonysystemssupervisor` |
| **Service id — theirs (consumer logs)** | `processorjobsupervisor` |

---

## 👀 See it working

The consumer runs in the **ProcessorJobSupervisor** service, so its consume logs are under **`processorjobsupervisor`** — not us. From our side, watch the **produce** and the **downstream consumer lag** as the cross-boundary health signal.

**Coralogix (DataPrime)** — our produce log line (`DialerCallsUpdatesProducer.java:31`, DEBUG) on the Supervisor side:
```text
source logs
| filter $l.applicationName == 'ingestertelephonysystemssupervisor'
| filter $m.message.contains('event to kafka') || $m.message.contains('call creation event to GDM')
| limit 200
```
Scope to one company with `| filter $d.cid == '<companyId>'`.

- Errors only: swap the message filter for `| filter $m.severity == 'ERROR'`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). The cross-boundary health signal is **Kafka consumer lag on `dialer-calls-updates`** (ProcessorJobSupervisor backing up) and our outbound producer error rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d) for our producer side. Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ **The consumer is in another repo** (ProcessorJobSupervisor) — not mounted here. The local hook below is **our producer** on our side of the boundary.

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **The produce** | `CallEventCommon/src/main/java/com/honeyfy/telephony/callevent/common/dialer/DialerCallsUpdatesProducer.java:26` | The actual `kafkaTemplate.send(...)` — catches every outbound event handed to ProcessorJobSupervisor |
| **The FF gate** | `IngesterTelephonySystemsSupervisor/.../GdmCallEventSender.java:40` (verify line) | See if `SEND_DIALER_CALL_CREATION_EVENT` short-circuits the send (the #1 "silent drop") |
| **Hand-off trigger** | `IngesterTelephonySystemsSupervisor/src/main/java/com/honeyfy/ingestertelephonysystems/services/PbxRecordingImportService.java:198` (verify line) | Where ingestion decides to forward the call |

Step into `DialerCallsUpdatesProducer.send()` @26 to confirm the event is published before it crosses to ProcessorJobSupervisor.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialerCallsUpdatesProducer.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 26**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call for that company (below), read the snapshot stack/vars, then **delete the breakpoint.**

> Use a **Log** action instead of a Snapshot to inject `event.getCallId()` on-demand without snapshot overhead.

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
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the hand-off) |
| `deleteCallProviderDataRecordsToAllowReimport` / `maskCallsToAllowReimport` | Clear prior state so a call can be re-ingested |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic sync that feeds ingestion |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Calls ingested but never processed | (1) Is `SEND_DIALER_CALL_CREATION_EVENT` on for the company? (`GdmCallEventSender.java:40`). (2) Coralogix for the "Failed sending ... event to kafka" warn (`DialerCallsUpdatesProducer.java:29`). (3) Lag on `dialer-calls-updates`. |
| Intermittent drops | Producer send failure is **logged warn, not thrown** (`DialerCallsUpdatesProducer.java:29`) — grep that warn; the call won't be retried automatically. |
| "Should be on `call-processing-inbound`" confusion | It isn't — Supervisor emits `dialer-calls-updates`; an intermediary routes to `call-processing-inbound`. Trace the topic the code actually uses. See [[CALL-PROCESSING-INBOUND]]. |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[DIALER-CALLS-UPDATES]] · [[CALL-PROCESSING-INBOUND]]
