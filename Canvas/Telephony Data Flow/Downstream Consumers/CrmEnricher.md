---
title: CrmEnricher
component_type: downstream-consumer
service: CrmEnricher
tags: [telephony-systems, downstream, consumer, kafka, oncall]
---

# ⬇️ CrmEnricher

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Downstream consumer of **`comment-update`** — call/email comment add/update/delete events it uses to enrich CRM. If the `comment-update` stream stops, **comment changes stop propagating to CRM enrichment.**
>
> 🔑 **The gotcha that will burn you (verified in code):**
> 1. The Supervisor's app-descriptor declares `WRITE` to `comment-update` (`...gong-app-descriptor.yaml:107`, cluster `NOTIFICATIONS`) **but no telephony-systems code produces to it.** The Supervisor only *imports* `CommentUpdateKafkaConfig` (`IngesterTelephonySystemsSupervisorConfig.java:148`) from **FrontEndCommon**. The **real producer is `CommentService.send(...)` in `FrontEndCommon` (external)** — `CommentService.java:912` (add/update) and `:1381` (delete). Chase *that* when comments don't reach CrmEnricher; don't hunt for a `.send` in this repo.
> 2. The producer send is **best-effort** — wrapped in `Robust.tryAndLog(...)` (`CommentService.java:911/920`): a failure is logged ("Failed to send comment update event"), **not thrown**. Silent drop.

---

## What it is

| | |
|---|---|
| **Role** | Downstream consumer of comment add/update/delete events for CRM enrichment |
| **Consumes** | `comment-update` (see [[COMMENT-UPDATE]]) |
| **Cluster** | `NOTIFICATIONS` |
| **Message type** | `CommentUpdate` (`com.honeyfy.kafka.events.comments.CommentUpdate`) |
| **Producer** | ⚠️ **NOT us** — `CommentService.send(...)` in **FrontEndCommon** (`CommentService.java:912` / `:1381`) |
| **Our wiring** | Supervisor imports `CommentUpdateKafkaConfig` (`IngesterTelephonySystemsSupervisorConfig.java:148`); descriptor declares `WRITE` (`...gong-app-descriptor.yaml:107`) — **no local `.send`** |
| **Consumer code** | **In another repo** (CrmEnricher) — not mounted here |
| **Service id — theirs (consumer logs)** | `crmenricher` |
| **Service id — producer (FrontEndCommon host)** | whichever service hosts `CommentService` (e.g. the front-end/web tier) |

---

## 👀 See it working

Neither side of `comment-update` is the telephony Supervisor: the **producer** is `CommentService` in FrontEndCommon, the **consumer** is CrmEnricher (logs under **`crmenricher`**). The cross-boundary health signal is **consumer lag on `comment-update`**.

**Coralogix (DataPrime)** — the consumer side (CrmEnricher):
```text
source logs
| filter $l.applicationName == 'crmenricher'
| filter $m.severity == 'ERROR'
| limit 200
```
Producer-side drop signal: grep `Failed to send comment update event` in the FrontEndCommon host service's logs (the `Robust.tryAndLog` message at `CommentService.java:920`). Scope to one company with `| filter $d.cid == '<companyId>'`.

- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard) (telephony context). Cross-boundary health signal = **Kafka consumer lag on `comment-update`** (CrmEnricher backing up). Note: this topic is *not* on a telephony cluster — the producer is FrontEndCommon, so the producer-side metrics are under that host service.

**Sentry** — telephony's own errors: [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). CrmEnricher's own exceptions report under its service/team. Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ **Both producer and consumer of `comment-update` are outside this repo.** The producer `.send` lives in **FrontEndCommon** (`CommentService.java:912`); the consumer is in **CrmEnricher**. Neither is mounted under `gong-telephony-systems`.
>
> The only `comment-update` touch-point in **this** repo is the **config wiring** the Supervisor pulls in — that's the real local hook on our side.

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Our wiring (local)** | `IngesterTelephonySystemsSupervisor/src/main/java/com/honeyfy/ingestertelephonysystems/config/IngesterTelephonySystemsSupervisorConfig.java:148` | `CommentUpdateKafkaConfig.class` import — the Supervisor's entire relationship to `comment-update` is this one line; break/inspect here to confirm the config bean is on the context |
| **The real produce** | `FrontEndCommon` → `com/honeyfy/frontendcommon/comments/CommentService.java:912` (add/update), `:1381` (delete) | `commentUpdateKafkaTemplate.send(new ProducerRecord<>(COMMENT_UPDATE.topic(), ...))` — set the breakpoint **in the FrontEndCommon repo** |
| **Producer bean def** | `FrontEndCommon` → `com/honeyfy/frontendcommon/config/CommentUpdateKafkaConfig.java:19` | `COMMENT_UPDATE_KAFKA_PRODUCER` bean — where the `comment-update` template is built |

To actually debug a produce, open **FrontEndCommon** and break at `CommentService.java:912`.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `CommentService.java` (**FrontEndCommon**) in IntelliJ; match the prod file version (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 912** (the `send`). In **Source**, pick the tag for the **FrontEndCommon host service** (the front-end/web tier that runs `CommentService`), **not** `ingestertelephonysystemssupervisor`.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Add or edit a comment on a call for that company, read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject the `CommentUpdate` fields on-demand without snapshot overhead.

---

## ▶️ Trigger the flow

`comment-update` is emitted when a user **adds / updates / deletes a comment** on a call — driven from the product UI / comment API in the FrontEndCommon-hosted service, not from a telephony troubleshooter. To exercise it:

- **Product path:** add or edit a comment on a call in the Gong app for a test company → `CommentService` publishes a `CommentUpdate` to `comment-update`.
- **There is no telephony-systems endpoint** that produces `comment-update`; the Supervisor only consumes association/CRM events (e.g. `association-updated` via `TelephonySystemsAssociationUpdatedConsumer`).

For local telephony debugging of the adjacent CRM-association path, see [[Entrypoints Within the Telephony System]] (the `association-updated` consumer) — but note that is a **different** topic from `comment-update`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `CRMInfoRetrievalTroubleshooter` | CRM lookup / enrichment debugging on the telephony side |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | Integration config state for CRM enrichment |
| (FrontEndCommon comment API) | Produce a real `comment-update` — outside this repo |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Comment changes not reaching CRM enrichment | (1) Lag on `comment-update` (CrmEnricher backing up). (2) Producer-side `Failed to send comment update event` warn (`CommentService.java:920`, FrontEndCommon host logs). (3) Did the comment actually persist? |
| "Telephony should produce `comment-update`" confusion | It doesn't — the descriptor `WRITE` (`...gong-app-descriptor.yaml:107`) is declared but **no telephony code sends it**. The producer is `CommentService.java:912` in FrontEndCommon. |
| Silent drops on produce | The send is `Robust.tryAndLog(...)` (`CommentService.java:911`) — failures are logged, not thrown, and not retried. |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[COMMENT-UPDATE]]
