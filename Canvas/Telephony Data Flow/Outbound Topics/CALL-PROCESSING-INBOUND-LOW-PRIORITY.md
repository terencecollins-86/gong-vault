---
title: CALL-PROCESSING-INBOUND-LOW-PRIORITY
component_type: outbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: CALL_PROCESSOR
tags: [telephony-systems, kafka, outbound, oncall, call-processing]
---

# 📤 CALL-PROCESSING-INBOUND-LOW-PRIORITY

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The *declared* low-priority twin of [[CALL-PROCESSING-INBOUND]] — meant to carry **backfill / low-urgency ingested calls** into the AI call-processing pipeline. If the real hand-off stops, **backfilled calls land in Gong but never get transcribed / processed.**
>
> 🔑 **The one gotcha that will burn you (verified in code):**
> 1. The Supervisor's app-descriptor declares `WRITE` to `call-processing-inbound-low-priority` (`IngesterTelephonySystemsSupervisor.gong-app-descriptor.yaml:86`) **but NO Supervisor code produces to it.** A repo-wide grep for `call-processing-inbound-low-priority` / `CALL_PROCESSING_INBOUND_LOW_PRIORITY` returns **only that descriptor line** — zero `.send(...)` call sites. Same story as the high-priority topic.
> 2. The real ingested-call hand-off (high *and* low priority) goes out on **`dialer-calls-updates`** (`SYNC_COMMUNICATIONS` cluster) via `DialerCallsUpdatesProducer.send()`. Backfill priority is decided **upstream of the topic** (low-priority sync chain → `LowPrioritySyncJobMsgExecutor`), not by a separate Supervisor topic. Chase `dialer-calls-updates` when backfilled calls don't reach processing — see [[DIALER-CALLS-UPDATES]].

---

## What it is

| | |
|---|---|
| **Role** | Declared (canvas) outbound hand-off for **low-priority / backfill** ingested calls |
| **Canvas label / declared topic** | `call-processing-inbound-low-priority`, cluster `CALL_PROCESSOR` (descriptor line 86, `WRITE`) |
| **Actual topic produced by Supervisor** | **none** — no producer exists; real hand-off is `dialer-calls-updates` (`SYNC_COMMUNICATIONS`) |
| **Message type (declared)** | call-processing event (consumed downstream by the call processor) |
| **Producer** | ⚠️ **none in this repo.** Real producer: `DialerCallsUpdatesProducer.send()` → topic `dialer-calls-updates` |
| **Façade** | `GdmCallEventSender.sendDialerCall(companyId, callId, supplier)` (FF-gated) |
| **Feature flag** | `SEND_DIALER_CALL_CREATION_EVENT` (per-company) — gates the *real* send |
| **Downstream** | call-processing pipeline (the call processor consumes `call-processing-inbound*`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Why the descriptor lies:** the `WRITE` grant on `call-processing-inbound-low-priority` is a leftover/intended capability. Low vs. high priority is selected on the **sync side** (`LowPrioritySyncJobMsgExecutor` reads `SQSQueues.DIALERS_SYNC_LOW_PRIORITY` — see [[Entrypoints Within the Telephony System]] §5); the resulting call still leaves on `dialer-calls-updates`.

---

## 👀 See it working

There is **no Supervisor log line for this topic** (nothing produces to it). Watch the real hand-off instead — `dialer-calls-updates` (`DialerCallsUpdatesProducer.java:31`, DEBUG) and the GDM façade success (`GdmCallEventSender.java:45`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('event to kafka') || $d.body.contains('call creation event to GDM')
| limit 200
```
Scope one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). The health signal is Kafka consumer lag on **`dialer-calls-updates`** (not on the low-priority topic, which gets nothing). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

> ⚠️ There is **no producer for `call-processing-inbound-low-priority`** in this repo, so there is no breakpoint *for this topic*. Set the breakpoint on the **real** hand-off (`dialer-calls-updates`) — that is what actually carries the call.

| Where | File : line | Why |
|---|---|---|
| **The real produce** | `CallEventCommon/.../dialer/DialerCallsUpdatesProducer.java:26` | The actual `kafkaTemplate.send(...)` for every outbound ingested call |
| **The FF gate** | `CallEventCommon/.../GdmCallEventSender.java:40` | If the flag short-circuits, the call is silently never forwarded |
| **Low-priority origin** | `IngesterTelephonySystemsSupervisor/.../syncInfra/AbstractSyncJobMsgExecutor.java:80` | Where a backfill `SyncJob` (low-priority queue) starts the sync that ends in the send |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialerCallsUpdatesProducer.java` in IntelliJ (the low-priority topic has no code to snapshot).
2. Gutter → **Snapshot** at **line 26**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a backfill for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action instead of a Snapshot to inject `event.getCallId()` on-demand.

---

## ▶️ Trigger the flow

To exercise the **low-priority/backfill** path that this topic was meant to represent, drive the **low-priority SyncJob** (`is-backfill=true`) — it routes to `DIALERS_SYNC_LOW_PRIORITY` and runs the full ingest → GDM-send. (Details: [[Entrypoints Within the Telephony System]] §5.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/time-based-events-sync-infra/syncJobInfra/SyncJobChain/runChainNow?company-id=0&integration-id=0&is-backfill=true'
```
- Controller: `IngesterTelephonySystemsSyncInfraTroubleshooter.runSyncJobChainNow()` (line 238). `is-backfill=true` → low-priority (backfill) queue.
- For a single known call, use **Sync one call** instead (§3) — same `dialer-calls-updates` hand-off.
- Set `company-id` to one with `SEND_DIALER_CALL_CREATION_EVENT` **enabled**, or the GDM send is skipped.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsSyncInfraTroubleshooter.runSyncJobChainNow` (`is-backfill=true`) | Drive the low-priority/backfill sync chain on demand |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the GDM send) |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic sync that feeds ingestion |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| "Should be on `call-processing-inbound-low-priority`" confusion | It isn't — Supervisor emits **`dialer-calls-updates`**; grep proves no producer for the low-priority topic. Trace `dialer-calls-updates` ([[DIALER-CALLS-UPDATES]]). |
| Backfilled calls never processed | (1) Is `SEND_DIALER_CALL_CREATION_EVENT` on for the company? (`GdmCallEventSender.java:40`). (2) Did the low-priority `SyncJob` run? (`AbstractSyncJobMsgExecutor.java:80`, queue `DIALERS_SYNC_LOW_PRIORITY`). (3) Lag on `dialer-calls-updates`. |
| Intermittent drops | Producer send failure is **logged warn, not thrown** (`DialerCallsUpdatesProducer.java:29`) — grep that warn; the call won't be retried automatically. |
