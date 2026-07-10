---
title: COMMENT-UPDATE
component_type: outbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: NOTIFICATIONS
tags: [telephony-systems, kafka, outbound, oncall, crm]
---

# 📤 COMMENT-UPDATE

> [[Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> A notification that a **CRM comment** tied to a call/activity has been updated — fanned out to downstream **CrmEnricher**. If this stops, **CRM comment edits made during call association don't propagate to enrichment.**
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **The producer is NOT in this repo.** A repo-wide grep for `comment-update` / `COMMENT_UPDATE` finds only: the descriptor `WRITE` grant (`IngesterTelephonySystemsSupervisor.gong-app-descriptor.yaml:107`, cluster `NOTIFICATIONS`), the **config import** (`IngesterTelephonySystemsSupervisorConfig.java:148`), and a **test** that wires the bean. The actual `KafkaTemplate.send(...)` lives in **`com.honeyfy.frontendcommon`** (`CommentUpdateKafkaConfig` + its sender), which the Supervisor pulls in as a dependency. Message type: `com.honeyfy.kafka.events.comments.CommentUpdate`.
> 2. **Our local trigger is the association consumer, not a "comment producer".** Comment-update is emitted as a side-effect of CRM sync during `TelephonySystemsAssociationUpdatedConsumer` → `DialerCRMSynchronizer`. There is no Supervisor class named `*CommentProducer` — chase the association/CRM-sync path.

---

## What it is

| | |
|---|---|
| **Role** | Outbound notification: CRM comment updated (during call association) → CrmEnricher |
| **Topic / cluster** | `comment-update`, cluster **`NOTIFICATIONS`** (descriptor `WRITE`, line 107) |
| **Message type** | `CommentUpdate` (`com.honeyfy.kafka.events.comments.CommentUpdate`) |
| **Producer** | ⚠️ **external** — `frontendcommon` `CommentUpdateKafkaConfig` (bean `COMMENT_UPDATE_KAFKA_PRODUCER`); imported here at `IngesterTelephonySystemsSupervisorConfig.java:148` |
| **Local trigger (our side)** | `TelephonySystemsAssociationUpdatedConsumer.accept` → CRM sync (`DialerCRMSynchronizer`) on `ActivityType.CALL` association updates |
| **Downstream** | CrmEnricher (consumes `comment-update`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Wiring (our side):**
- `IngesterTelephonySystemsSupervisorConfig.java:32` — `import ...frontendcommon.config.CommentUpdateKafkaConfig;`
- `IngesterTelephonySystemsSupervisorConfig.java:148` — `CommentUpdateKafkaConfig.class` added to the Spring `@Import` set (brings in the producer bean)

---

## 👀 See it working

**Coralogix (DataPrime)** — the produce itself is logged by the `frontendcommon` sender; our side logs the association-update handling that precedes it. Watch both via the topic name and the association consumer:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('comment-update') || $d.body.contains('CommentUpdate') || $d.body.contains('association update event for dialers')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'` (the consumer sets `cid`, `activityId`, `actionType` in MDC — `TelephonySystemsAssociationUpdatedConsumer.java:98`). Errors only: `| filter $m.severity == ERROR`.

- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch the association-updated consumer metrics (`AssociationUpdatedConsumerMetrics`) + **Kafka consumer lag on `comment-update`** (CrmEnricher backing up). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

> ⚠️ The **actual `comment-update` producer is in another repo/library (`frontendcommon`)**, not mounted as Supervisor source. Local breakpoints stop at **our** boundary — the association/CRM-sync path that triggers the comment update.

| Where | File : line | Why |
|---|---|---|
| **Our trigger (consumer)** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:90` | `accept(...)` — the entry that handles an association update and drives CRM sync |
| **Call-association branch** | `IngesterTelephonySystemsSupervisor/.../consumers/TelephonySystemsAssociationUpdatedConsumer.java:188` | `dialerCRMSynchronizer.updateAttendeesAndLinkCrmObjects(...)` — the CRM sync that leads to a comment update |
| **Producer wiring** | `IngesterTelephonySystemsSupervisor/.../config/IngesterTelephonySystemsSupervisorConfig.java:148` | Where `CommentUpdateKafkaConfig` (the external producer bean) is imported |

To follow the **actual send**, step into `DialerCRMSynchronizer` from `:188` and on into the `frontendcommon` comment sender (decompiled/library source) — set the breakpoint on the library `CommentUpdate` send if your IDE has the `frontendcommon` sources attached.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TelephonySystemsAssociationUpdatedConsumer.java` in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 188** (the CRM-sync call). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a call-association update for that company, read the snapshot, then **delete the breakpoint.**

> The `frontendcommon` producer also runs inside `ingestertelephonysystemssupervisor` at runtime — if you have the library source, you can snapshot its send line directly under the same agent tag.

---

## ▶️ Trigger the flow

`comment-update` is emitted downstream of an **association-updated** event (`ActivityType.CALL`). The consumer subscribes to `association-updated` (`ACTIVITY_CRM_ASSOCIATIONS` cluster) — produce one to that topic to drive the path. There is **no dedicated HTTP troubleshooter** for the comment-update produce itself; the realistic local driver is to feed an `AssociationUpdated` event, or to run a call through ingestion + CRM association so the consumer fires.

```bash
# Drive an ingested call first (which gets associated and triggers CRM sync); see Entrypoints §3.
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```
- Then produce an `AssociationUpdated` (`com.honeyfy.kafka.events.opportunity.AssociationUpdated`, `activityType=CALL`) to topic `association-updated` on the `ACTIVITY_CRM_ASSOCIATIONS` cluster to hit `TelephonySystemsAssociationUpdatedConsumer.accept` (breakpoint line 90). See [[Entrypoints Within the Telephony System]] for the Kafka-produce pattern (§4 covers producing to a consumer's topic).
- The CRM-association playbook in [[06 - Runbook & Troubleshooting]] §3 covers the same consumer chain.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `CRMInfoRetrievalTroubleshooter` | Debug the CRM lookup/enrichment that feeds comment updates |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-ingest a call so it gets associated (upstream of comment-update) |
| CrmEnricher troubleshooters (downstream repo) | Inspect what CrmEnricher does with the `comment-update` event |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| CRM comment edits don't reach enrichment | (1) Did the association update arrive? Coralogix `"association update event for dialers"` (`TelephonySystemsAssociationUpdatedConsumer.java:104`). (2) Lag on `comment-update` (CrmEnricher). (3) CRM sync errors in `DialerCRMSynchronizer`. |
| Can't find the producer in this repo | There isn't one — the `comment-update` send is in **`frontendcommon`** (`CommentUpdateKafkaConfig`), imported at `IngesterTelephonySystemsSupervisorConfig.java:148`. Our trigger is the association consumer. |
| Association consumer not firing | It reads `association-updated` (`ACTIVITY_CRM_ASSOCIATIONS`) and only handles `CALL` / `CALL_ACTIVITY` types (`:119`). Other activity types are dropped at `supportedEvent(...)`. |
