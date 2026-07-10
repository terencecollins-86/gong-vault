---
title: FrontEndApi / WebFrontEnd
component_type: upstream-producer
service: FrontEndApi / WebFrontEnd
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, upstream, producer, oncall, gong-connect, recordings]
---

# ⬆️ FrontEndApi / WebFrontEnd

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The Gong app front-end services produce two telephony-relevant events: **`gong-connect-call-event`** (Gong Connect call lifecycle) and **`external-recordings-import-requests`** (a user/app-initiated request to import an external recording). Two different consumers, in **two different modules**, receive them.
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **`gong-connect-call-event` is effectively a no-op on our side.** `GongConnectCallEventConsumer.accept(...)` only logs `"Not re-enabling Gong Connect sync job for companyId=..."` and does nothing else (`GongConnectCallEventConsumer.java:27`). It lives in the **`services/`** package, **not** `consumers/`. Don't expect call processing from this topic.
> 2. **`external-recordings-import-requests` is NOT consumed by the Supervisor.** Its consumer (`ExternalRecordingsImportRequestsConsumer`) lives in the **TelephonySystemsRecordingsImporter** module (service `telephonysystemsrecordingsimporter`), not `ingestertelephonysystemssupervisor`.

---

## What it is

| | |
|---|---|
| **Role** | Upstream producers (app front-end) emitting call-lifecycle + recording-import events |
| **Topic A** | `gong-connect-call-event`, cluster `TELEPHONY_SYSTEMS` → our `GongConnectCallEventConsumer` (no-op) |
| **Topic B** | `external-recordings-import-requests`, cluster `TELEPHONY_SYSTEMS` → **RecordingsImporter** module's `ExternalRecordingsImportRequestsConsumer` |
| **Message types** | A: `GongConnectCallEvent` (`com.honeyfy.kafka.events.gongconnect`) · B: `ImportRequest` (`com.honeyfy.kafka.events.recordingsimporter`) |
| **Producer code** | In the **FrontEndApi** / **WebFrontEnd** repos (not mounted here) |
| **Topic A consumer** | `GongConnectCallEventConsumer.accept(...)` — Supervisor `services/` package |
| **Topic B consumer** | `ExternalRecordingsImportRequestsConsumer.accept(...)` — RecordingsImporter module |
| **Service ids (logs/metrics)** | `ingestertelephonysystemssupervisor` (A) · `telephonysystemsrecordingsimporter` (B) |

---

## 👀 See it working

**Coralogix (DataPrime)** — topic A (the no-op consumer logs at INFO, `GongConnectCallEventConsumer.java:27`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Not re-enabling Gong Connect sync job')
| limit 200
```
Topic B (recording-import requests land in the importer, `ExternalRecordingsImportRequestsConsumer.java:31`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'telephonysystemsrecordingsimporter'
| filter $d.body.contains('got event=')
| limit 200
```
Scope either with `| filter $d.mdc.cid == '<companyId>'`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Signals: lag on `gong-connect-call-event` (`ingestertelephonysystemssupervisor`) and on `external-recordings-import-requests` (`telephonysystemsrecordingsimporter`).

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ The **producers** are in the **FrontEndApi** / **WebFrontEnd** repos (**not mounted here**). Topic B's **consumer** is in the **TelephonySystemsRecordingsImporter** module (also outside the Supervisor) — breakpoint it there.

Local hook on **our** side — the topic-A consumer in the Supervisor:

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Topic A consumer (our hook)** | `IngesterTelephonySystemsSupervisor/.../services/GongConnectCallEventConsumer.java:25` | `accept(ConsumerRecord<Long, GroupedGongEvents<GongConnectCallEvent>>)` — every `gong-connect-call-event` lands here |
| **No-op body** | `.../services/GongConnectCallEventConsumer.java:27` | Confirms it only logs and returns — no downstream work |
| **Topic B consumer (other module)** | `TelephonySystemsRecordingsImporter/.../consumer/ExternalRecordingsImportRequestsConsumer.java:30` | `accept(ConsumerRecord<String, ImportRequest>)` → `recordingsImporterService.processRequest(...)` (run the importer to hit this) |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `GongConnectCallEventConsumer.java` (topic A) or `ExternalRecordingsImportRequestsConsumer.java` (topic B) in IntelliJ; file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at line **25** (A) / **30** (B). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`** (A) or **`telephonysystemsrecordingsimporter`** (B).
3. Scope to one company:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Read the snapshot, then **delete the breakpoint.**

---

## ▶️ Trigger the flow

There is no Supervisor HTTP twin for these two topics specifically. To exercise them, **produce to the topic** on the `TELEPHONY_SYSTEMS` cluster locally (the general pattern in [[Entrypoints Within the Telephony System]] §4):

- **Topic A:** produce a `GongConnectCallEvent` JSON to `gong-connect-call-event` (breakpoint `GongConnectCallEventConsumer.java:25`).
- **Topic B:** produce an `ImportRequest` JSON to `external-recordings-import-requests`, then debug the **RecordingsImporter** module (breakpoint `ExternalRecordingsImportRequestsConsumer.java:30`). To replay a single import, use `RecordingsImporterTroubleshooter` (§Troubleshooters).

For comparison, the main call-ingestion HTTP twin (`process-one-event`) is in [[Entrypoints Within the Telephony System]] §2.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `RecordingsImporterTroubleshooter` (RecordingsImporter module) | Replay/inspect a single external recording import (topic B) |
| `TelephonyIntegrationFrontTroubleshooter` / `IntegrationsTroubleshooter` | Gong Connect integration config state (topic A) |
| `TelephonyCallEventsTroubleshooter` | Push one telephony call event through the main ingestion path |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| "gong-connect-call-event isn't doing anything" | Correct — the consumer is a deliberate no-op (`GongConnectCallEventConsumer.java:27`). Nothing downstream fires from this topic. |
| External recording never imports | Wrong service — check **`telephonysystemsrecordingsimporter`**, not the Supervisor. Lag on `external-recordings-import-requests`; Coralogix for "got event=" (`:31`); then `RecordingsImporterTroubleshooter`. See [[06 - Runbook & Troubleshooting]] §4 (media access / external CMK). |
| Lag on `external-recordings-import-requests` | Import is slow/erroring in the importer; check `RecordingsImporterService.processRequest` + customer S3 / CMK access. |

> Related: [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Inbound Topics/GONG-CONNECT-CALL-EVENT]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Inbound Topics/EXTERNAL-RECORDINGS-IMPORT-REQUESTS]] · [[Subsystems/Consent/Canvas 1/Telephony Systems/Inbound Producers/EnableWebApi-PublicApiServer]] · [[Entrypoints Within the Telephony System]]
