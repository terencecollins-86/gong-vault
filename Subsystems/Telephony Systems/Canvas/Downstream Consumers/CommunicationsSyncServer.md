---
title: CommunicationsSyncServer
component_type: downstream-consumer
service: CommunicationsSyncServer
tags: [telephony-systems, downstream, consumer, kafka, oncall]
---

# ⬇️ CommunicationsSyncServer

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Downstream consumer that ingests our **dialer call** and **web-conference call** updates into the communications sync layer. If our two producers stop, **dialer + web-conference call updates stop flowing** to it.
>
> 🔑 **Gotchas that will burn you (verified in code):**
> 1. **Two separate topics, two separate producers, same cluster.** Dialer calls → `dialer-calls-updates`; web-conference calls → `webconference-call-events`; **both on `SYNC_COMMUNICATIONS`**. A drop on one does not imply the other — check the right producer.
> 2. **Sends are warn-logged, not thrown.** Both producers swallow send failures into a `log.warn` (`DialerCallsUpdatesProducer.java:29`, `WebConfCallsUpdatesProducer.java:30`) — no retry, no exception. A burst of those warns = silent gap downstream.
> 3. **This service's Sentry team is `mail-cal-ingestion`, not `telephony-systems`.** Errors *inside* CommunicationsSyncServer route there.

---

## What it is

| | |
|---|---|
| **Role** | Downstream consumer of our dialer + web-conference call updates |
| **Consumes** | `dialer-calls-updates` (see [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]]) **+** `webconference-call-events` (see [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/WEBCONFERENCE-CALL-EVENTS]]) |
| **Cluster (both)** | `SYNC_COMMUNICATIONS` |
| **Message types** | `DialerCallEvent` / `WebConferenceCallEvent` (`com.honeyfy.appcommon.call.event.*`) |
| **Our producers** | `DialerCallsUpdatesProducer.send()` · `WebConfCallsUpdatesProducer.send()` |
| **Consumer code** | **In another repo** (CommunicationsSyncServer) — not mounted here |
| **Service id — OURS (producer-side)** | `ingestertelephonysystemssupervisor` |
| **Service id — theirs (consumer logs)** | `communicationssyncserver` |
| **Sentry team — theirs** | ⚠️ `mail-cal-ingestion` (not `telephony-systems`) |

---

## 👀 See it working

The consumer runs in **CommunicationsSyncServer**, so its consume logs are under **`communicationssyncserver`** and its exceptions land in Sentry team **`mail-cal-ingestion`** — not us. From our side, watch the **produce** logs + **downstream consumer lag** as the cross-boundary health signal.

**Coralogix (DataPrime)** — our produce log lines (`DialerCallsUpdatesProducer.java:31` / `WebConfCallsUpdatesProducer.java:32`, both DEBUG) on the Supervisor side:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Sent') && $d.body.contains('event to kafka')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`.

- Errors only: swap the message filter for `| filter $m.severity == ERROR` (or grep the `Failed sending ... event to kafka` warn).
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Cross-boundary health signal = **Kafka consumer lag on `dialer-calls-updates` and `webconference-call-events`** + our producer error rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — our producer side: [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). The consumer side reports to **`mail-cal-ingestion`**.

---

## 🔌 Set a breakpoint (local)

> ⚠️ **The consumer is in another repo** (CommunicationsSyncServer) — not mounted here. The hooks below are **our two producers** on our side of the boundary.

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Dialer produce** | `CallEventCommon/src/main/java/com/honeyfy/telephony/callevent/common/dialer/DialerCallsUpdatesProducer.java:26` | The actual `kafkaTemplate.send(...)` for `dialer-calls-updates` |
| **Web-conf produce** | `CallEventCommon/src/main/java/com/honeyfy/telephony/callevent/common/webconf/WebConfCallsUpdatesProducer.java:27` | The actual `kafkaTemplate.send(...)` for `webconference-call-events` |
| **FF gate (dialer)** | `IngesterTelephonySystemsSupervisor/.../GdmCallEventSender.java:40` (verify line) | `SEND_DIALER_CALL_CREATION_EVENT` short-circuit (silent drop) |

Break at the relevant `send()` to confirm the event is published before it crosses to CommunicationsSyncServer.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialerCallsUpdatesProducer.java` (or `WebConfCallsUpdatesProducer.java`) in IntelliJ; match the prod file version (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 26** (dialer) / **line 27** (web-conf). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject `event.getCallId()` on-demand without snapshot overhead.

---

## ▶️ Trigger the flow

Drive a real call hand-off with the **Sync one call** troubleshooter — pulls one call and runs the full ingest → produce path. (Details + payloads: [[Entrypoints Within the Telephony System]] §3.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- For web-conference flows, use the conference call path (`UploadedCallEventService` `sendWebConfCall(...)`).
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Alternatives: **Process one telephony call event** (§2, push path) or driving the **SyncJob** chain (§5).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one call (re-fires the produce) |
| `TelephonyCallEventsTroubleshooter` | Inspect/push dialer call events |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic sync that feeds ingestion |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Dialer call updates missing downstream | (1) Coralogix for `Failed sending ... event to kafka` warn (`DialerCallsUpdatesProducer.java:29`). (2) Lag on `dialer-calls-updates`. (3) Is `SEND_DIALER_CALL_CREATION_EVENT` on? (`GdmCallEventSender.java:40`). |
| Web-conf call updates missing | Check the **other** producer/topic: `WebConfCallsUpdatesProducer.java:30` warn + lag on `webconference-call-events`. Don't assume it's the dialer path. |
| Errors but nothing in our Sentry | The consumer's exceptions report to **`mail-cal-ingestion`**, not `telephony-systems` — look there. |

> Related: [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/WEBCONFERENCE-CALL-EVENTS]]
