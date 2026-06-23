---
title: CrmAssociator
component_type: upstream-producer
service: CrmAssociator
cluster: ACTIVITY_CRM_ASSOCIATIONS
tags: [telephony-systems, kafka, upstream, producer, oncall, crm]
---

# ⬆️ CrmAssociator

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> CrmAssociator decides which CRM objects (accounts, opportunities, contacts) a call/activity is associated with, and **produces `association-updated`** on the `ACTIVITY_CRM_ASSOCIATIONS` cluster. Our Supervisor's `TelephonySystemsAssociationUpdatedConsumer` consumes it to re-title calls, link CRM objects, and re-enqueue the call into the pipeline. If this upstream stops, **call titles and CRM links stop updating** — calls still ingest, but they look unassociated in the UI.
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **Most event types are silently ignored.** `supportedEvent(...)` keeps only `CALL` and `CALL_ACTIVITY` activity types; anything else returns immediately with no log (`TelephonySystemsAssociationUpdatedConsumer.java:92,119`). A "missing association" can simply be an unsupported `activityType`.
> 2. **Non-numeric call ids are dropped (warn only).** `updateCallAssociation` parses `activityId` as a `long`; on failure it logs a warn and skips the event — no retry (`:166`).

---

## What it is

| | |
|---|---|
| **Role** | Upstream producer — emits CRM association decisions for activities |
| **Produces topic** | `association-updated`, cluster `ACTIVITY_CRM_ASSOCIATIONS` |
| **Message type** | `AssociationUpdated` (`com.honeyfy.kafka.events.opportunity.AssociationUpdated`) |
| **Producer code** | In the **CrmAssociator** repo (not mounted here) |
| **Our consumer** | `TelephonySystemsAssociationUpdatedConsumer.accept(...)` |
| **Consumer cluster const** | `KafkaClusterDetails.ACTIVITY_CRM_ASSOCIATIONS_KAFKA_CLUSTER` |
| **Consumer config** | `.persistErrorsWithReprocessing()`, concurrency 16, retries 3 (`:245-248`) |
| **Downstream of consumer** | Re-title call, link CRM objects, enqueue `CALL_PIPELINE` work (`:198,201`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the consumer logs received events at DEBUG (`TelephonySystemsAssociationUpdatedConsumer.java:104`) and pipeline enqueue at DEBUG (`:202`):
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('got association update event for dialers') || $d.body.contains('finished handling association updated')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`, or filter on the `activityId` MDC key. Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Signal: **consumer lag on `association-updated`** + the consumer's `AssociationUpdatedConsumerMetrics` (`reportEventsHandled`, `reportCallsSentToPipeline`). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ The **producer** is in the **CrmAssociator** repo, which is **not mounted here**. Breakpoint the produce there.

Local hook on **our** side — the consumer that receives the association events:

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry (our hook)** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:90` | `accept(ConsumerRecord<Long, AssociationUpdated>)` — every `association-updated` record |
| **Supported-type gate** | `.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:92` | `if (!supportedEvent(...)) return;` — the #1 silent drop |
| **Pipeline enqueue** | `.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:198` | `sendCallToPipeline(...)` — where the call re-enters processing |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonySystemsAssociationUpdatedConsumer.java` in IntelliJ; file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 90** (or 92 to catch the supported-type gate). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger an association change for that company, read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `associationUpdatedEvent.getActivityType()` at line 92 tells you instantly whether the event is being filtered out.

---

## ▶️ Trigger the flow

There is no Supervisor HTTP twin for `association-updated`. To exercise the consumer, **produce an `AssociationUpdated` event** to `association-updated` on the `ACTIVITY_CRM_ASSOCIATIONS` cluster locally (general pattern: [[Entrypoints Within the Telephony System]] §4) with `activityType` = `CALL` or `CALL_ACTIVITY` and breakpoint `TelephonySystemsAssociationUpdatedConsumer.java:90`.

To debug the CRM lookups the consumer performs (rather than the trigger), use the `CRMInfoRetrievalTroubleshooter` against a known activity.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `CRMInfoRetrievalTroubleshooter` | CRM lookup debugging (`crmInfoRetrievalService.enrichCRMInfo`, `:105`) |
| `TelephonyIntegrationFrontTroubleshooter` / `IntegrationsTroubleshooter` | Integration / CRM config state |
| `ProviderDataAccessTroubleshooter` | Inspect raw provider/attendee data updated on association |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Call titles / CRM links not updating | (1) Is upstream producing? Lag on `association-updated`. (2) Coralogix for "got association update event" (`:104`) — absent ⇒ nothing arriving. (3) Is `activityType` supported (`CALL`/`CALL_ACTIVITY`)? See gate at `:92`. |
| Association failures persist | Errors are persisted + reprocessed (`.persistErrorsWithReprocessing()`, `:246`); a sibling `CrmAssociationRetryConsumer` retries. Persistent: `CRMInfoRetrievalTroubleshooter`, check `CRM_FIELDS`/`INTEGRATION` data (see [[06 - Runbook & Troubleshooting]] §3). |
| Event "vanished" with no error | Non-numeric `activityId` dropped with warn only (`:166`), or unsupported type silently skipped (`:92`). Grep the warn. |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[ASSOCIATION-UPDATED]] · [[Entrypoints Within the Telephony System]]
