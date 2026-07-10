---
title: CALL-PROCESSING-INBOUND
component_type: outbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: CALL_PROCESSOR
tags: [telephony-systems, kafka, outbound, oncall, call-processing]
---

# 📤 CALL-PROCESSING-INBOUND

> [[Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The hand-off of a **fully-ingested call** from the telephony ingester to the AI call-processing pipeline. If this stops, **calls land in Gong but never get transcribed / processed.**
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. The Supervisor's app-descriptor declares `WRITE` to `call-processing-inbound` (lines 84/86) **but no Supervisor code produces to it.** The real hand-off goes out on **`dialer-calls-updates`** (`SYNC_COMMUNICATIONS` cluster) via `DialerCallsUpdatesProducer.send()`. Chase *that* topic when calls don't reach processing.
> 2. The send is **feature-flag gated** — `SEND_DIALER_CALL_CREATION_EVENT`. Flag off for a company ⇒ call is ingested fine but **silently never forwarded**, no error.

---

## What it is

| | |
|---|---|
| **Role** | Outbound hand-off: ingested call → downstream call processing |
| **Canvas label / declared topic** | `call-processing-inbound` (+ `-low-priority`), cluster `CALL_PROCESSOR` |
| **Actual topic produced by Supervisor** | `dialer-calls-updates`, cluster `SYNC_COMMUNICATIONS` |
| **Message type** | `DialerCallEvent` (`com.honeyfy.appcommon.call.event.DialerCallEvent`) |
| **Producer** | `DialerCallsUpdatesProducer.send()` → bean `dialerCallsUpdatesProducerBean` |
| **Façade** | `GdmCallEventSender.sendDialerCall(companyId, callId, supplier)` |
| **Feature flag** | `SEND_DIALER_CALL_CREATION_EVENT` (per-company) |
| **Downstream** | `ProcessorJobSupervisor` (AI call-processing pipeline) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Where the hand-off fires** (after a call finishes ingesting):
- `PbxRecordingImportService.java:198` — `gdmCallEventSender.sendDialerCall(...)` (from `sendToGdm()` @191)
- `UploadedCallEventService.java:63` — dialer call; `:44` — `sendWebConfCall(...)` for conference calls

---

## 👀 See it working

**Coralogix (DataPrime)** — the actual send log line (`DialerCallsUpdatesProducer.java:31`, DEBUG) and the GDM façade success (`GdmCallEventSender.java:45`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('event to kafka') || $d.body.contains('call creation event to GDM')
| limit 200
```
Scope to one call by adding `| filter $d.mdc.cid == '<companyId>'` or filter on the `callId` in the MDC.

- Errors only: swap the message filter for `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). The #1 health signal is **Kafka consumer lag on `dialer-calls-updates`** (downstream backing up) and the Supervisor's outbound `feign.*` / producer error rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **The produce** | `CallEventCommon/.../dialer/DialerCallsUpdatesProducer.java:26` | The actual `kafkaTemplate.send(...)` — catches every outbound event |
| **The FF gate** | `CallEventCommon/.../GdmCallEventSender.java:40` | See if the flag short-circuits the send (the #1 "silent drop") |
| **Hand-off trigger** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:198` | Where ingestion decides to forward the call |

Step from `:40` → if the flag returns `true`, into `send()` @44 → `DialerCallsUpdatesProducer.send()` @26.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialerCallsUpdatesProducer.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 26**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call for that company (below), read the snapshot stack/vars, then **delete the breakpoint.**

> Use a **Log** action instead of a Snapshot to inject `event.getCallId()` on-demand without the snapshot overhead.

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
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the GDM send) |
| `deleteCallProviderDataRecordsToAllowReimport` / `maskCallsToAllowReimport` | Clear prior state so a call can be re-ingested |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic sync that feeds ingestion |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Calls ingested but never processed | (1) Is `SEND_DIALER_CALL_CREATION_EVENT` on for the company? (`GdmCallEventSender.java:40`). (2) Coralogix for the "Failed to send ... to GDM" warn (`:46`). (3) Lag on `dialer-calls-updates`. |
| Intermittent drops | Producer send failure is **logged warn, not thrown** (`DialerCallsUpdatesProducer.java:29`) — grep that warn; the call won't be retried automatically. |
| "Should be on `call-processing-inbound`" confusion | It isn't — Supervisor emits `dialer-calls-updates`; an intermediary routes to `call-processing-inbound`. Trace the topic the code actually uses. |
