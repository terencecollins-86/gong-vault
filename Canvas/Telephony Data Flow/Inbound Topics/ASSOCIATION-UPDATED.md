---
title: ASSOCIATION-UPDATED
component_type: inbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: ACTIVITY_CRM_ASSOCIATIONS
tags: [telephony-systems, kafka, inbound, oncall, crm-association]
---

# 📥 ASSOCIATION-UPDATED

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> CRM-association updates for activities. When a call/activity's CRM links change, this consumer re-enriches CRM info, updates attendees + call title, and re-enqueues the call into the pipeline. If it stalls, **calls show stale/missing CRM associations and titles** (wrong/empty contacts & accounts on the call). Runbook §3 is the playbook for CRM-association failures.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Only CALL / CALL_ACTIVITY are handled.** `supportedEvent()` returns early for any other `ActivityType` (`TelephonySystemsAssociationUpdatedConsumer.java:92-93,119-122`) — the event is acked and ignored.
> 2. **Retries are silent & capped.** Failures here are picked up by the sibling **`CrmAssociationRetryConsumer`**, which on error re-schedules via `CrmAssociationRetryService.send()` — but that **caps at `MAX_ALLOWED_RETRIES = 5` then `return`s with only an `error` log** (`CrmAssociationRetryService.java:31,45-48`). After 5 tries the association is abandoned, no exception.
> 3. **Two clusters.** This topic is on `ACTIVITY_CRM_ASSOCIATIONS`; the retry topic `telephony-crm-association-retry` is on `TELEPHONY_SYSTEMS`. Don't look for the retry on the same cluster.

---

## What it is

| | |
|---|---|
| **Role** | Inbound CRM-association update → re-enrich + re-pipeline the call |
| **Topic** | `association-updated` (`KafkaTopics.ASSOCIATION_UPDATED`) |
| **Cluster** | `ACTIVITY_CRM_ASSOCIATIONS` (`ACTIVITY_CRM_ASSOCIATIONS_KAFKA_CLUSTER`) |
| **Access (app-descriptor)** | `READ` · consumer `telephony-systems-association-updated-consumer` |
| **Message type** | `AssociationUpdated` (`com.honeyfy.kafka.events.opportunity.AssociationUpdated`) |
| **Consumer** | `TelephonySystemsAssociationUpdatedConsumer` |
| **Retry consumer** | `CrmAssociationRetryConsumer` on `telephony-crm-association-retry` (cluster `TELEPHONY_SYSTEMS`) |
| **Downstream** | `persistentQueueService.enqueueWorkForCompany(... CALL_PIPELINE ...)` → call pipeline |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the consume + finish lines (`TelephonySystemsAssociationUpdatedConsumer.java:104` and `:114`), plus retry scheduling (`CrmAssociationRetryService.java:51`):
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('got association update event') || $d.body.contains('finished handling association updated') || $d.body.contains('Scheduling CRM association retry')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'` (the consumer sets `COMPANY_ID`, `ACTIVITY_ID`, `ACTION_TYPE` into MDC at `:98-102`). Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Lag on `association-updated` + the consumer's own `AssociationUpdatedConsumerMetrics` (events handled `:115`, calls sent to pipeline `:214`). Filter `service:ingestertelephonysystemssupervisor` + `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate via *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).


## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:90` | `accept(ConsumerRecord<Long, AssociationUpdated>)` — every association update |
| **Support filter** | `.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:92` | `supportedEvent()` early-return for non-CALL types |
| **CRM enrich** | `.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:105` | `crmInfoRetrievalService.enrichCRMInfo(...)` |
| **Re-pipeline** | `.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:198` | `sendCallToPipeline(...)` → enqueue work |
| **Retry entry** | `.../consumers/CrmAssociationRetryConsumer.java:67` | `accept(...)` — the retry consumer; `catch (Throwable)` → `send()` at `:85` |
| **Wiring** | `.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:241` | `configureSingle(... ASSOCIATION_UPDATED ...)` |

Step from `:90` → `:92` (filter) → CALL branch `updateCallAssociation()` `:165` → `:198` enqueue. For retry behaviour, breakpoint `CrmAssociationRetryConsumer.java:82` (the `catch`).

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against prod. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonySystemsAssociationUpdatedConsumer.java` in IntelliJ (match the prod build — Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 90** (or `CrmAssociationRetryConsumer.java:67` for retries). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger an association update for that company, read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `associationUpdatedEvent.getActivityType()` at `:91` shows whether events are being filtered out at `supportedEvent()`.

---

## ▶️ Trigger the flow

There is **no Supervisor HTTP twin that produces an `AssociationUpdated`** — the event originates upstream in the CRM-associations service (another repo/module) and lands on the `ACTIVITY_CRM_ASSOCIATIONS` cluster. On our side the local hook is the consumer above.

**To exercise this consumer:** produce an `AssociationUpdated` JSON (type `CALL` or `CALL_ACTIVITY`, a real `companyId` + `activityId`) to topic `association-updated` on the `ACTIVITY_CRM_ASSOCIATIONS` cluster via `kafka-console-producer` / the local Kafka UI — see [[Entrypoints Within the Telephony System]] §4 for the produce-to-topic pattern. Breakpoint `:90` first.

**For CRM-association debugging in general** (Runbook §3): use `CRMInfoRetrievalTroubleshooter` and inspect `CRM_FIELDS` / `INTEGRATION` data.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `CRMInfoRetrievalTroubleshooter` | CRM lookup debugging for persistent association failures (Runbook §3) |
| `ProviderDataAccessTroubleshooter` | Raw provider-data inspection behind an association |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-ingest a call to rebuild its association from scratch (§3) |

Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Calls show stale / wrong CRM associations | (1) Lag on `association-updated`. (2) Coralogix for the consume line (`:104`) — arriving? (3) Runbook §3: `CRMInfoRetrievalTroubleshooter`, `CRM_FIELDS`/`INTEGRATION` data. |
| Associations silently never fixed | Retry capped at 5 then abandoned (`CrmAssociationRetryService.java:45-47`) — grep "Reached CRM association retry limit". |
| Only some event types update | By design — non CALL/CALL_ACTIVITY are dropped (`:92`, `supportedEvent` `:119`). |
