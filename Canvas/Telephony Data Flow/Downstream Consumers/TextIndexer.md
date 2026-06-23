---
title: TextIndexer
component_type: downstream-consumer
service: TextIndexer
tags: [telephony-systems, downstream, consumer, kafka, opensearch, oncall]
---

# ⬇️ TextIndexer

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **dor.shemer@gong.io**

> [!danger] On-call TL;DR
> Consumes **`texts-ingested`** and indexes SMS / text messages into OpenSearch so they're searchable. If this stops, **texts are ingested but never searchable** — they go silent in search, no error to the producer.
>
> 🔑 **Gotchas that will burn you (verified in code):**
> 1. **This service is owned by `deal-intelligence`, not telephony-systems.** Owner **dor.shemer@gong.io**; its Sentry errors route to team **`deal-intelligence`**. Don't page telephony-systems for a TextIndexer indexing failure.
> 2. **Events arrive grouped + per-tenant.** The consumer takes `GroupedGongEvents<TextIngested>` (`TextIngestedConsumer.java:37`) and indexes the whole batch under one `companyId` — a single bad batch can stall a tenant's texts.
> 3. **Two of our services produce `texts-ingested`** — `SmsSyncService.java:157` (generic SMS) and `ZoomPhoneSmsService.java:430` (Zoom Phone). The Supervisor descriptor declares `WRITE` to `texts-ingested` (`...gong-app-descriptor.yaml:63`).

---

## What it is

| | |
|---|---|
| **Role** | Downstream consumer: ingested texts → OpenSearch index (searchable) |
| **Consumes** | `texts-ingested` (see [[TEXTS-INGESTED]]) |
| **Cluster** | `TELEPHONY_SYSTEMS` |
| **Message type** | `GroupedGongEvents<TextIngested>` (`com.honeyfy.kafka.events.text.TextIngested`) |
| **Consumer class** | `TextIngestedConsumer.accept(...)` → `textIngestedConsumer` bean |
| **Handler** | `TextIndexerService.indexMessages(companyId, texts)` |
| **Consumer config** | `configureMultipleByTenant(..., consumerConcurrency(3), consumerRetries(1), persistErrorsWithReprocessing())` |
| **Our producers** | `SmsSyncService.sendTextIngestedEvent()` · `ZoomPhoneSmsService.sendTextIngestedEvent()` |
| **Code location** | **IN THIS REPO** — `TextIndexer/` module |
| **Service id (logs/metrics)** | `textindexer` |
| **Sentry team** | ⚠️ `deal-intelligence` (NOT `telephony-systems`) |

---

## 👀 See it working

TextIndexer is **in this repo** but its logs run under its own service id **`textindexer`**, and its exceptions route to Sentry team **`deal-intelligence`**.

**Coralogix (DataPrime)** — the consume log line (`TextIngestedConsumer.java:41`, DEBUG):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'textindexer'
| filter $d.body.contains('Received TextIngested events')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Cross-boundary check on the producer side: filter `$l.subsystemname == 'ingestertelephonysystemssupervisor'` for the `Sending textIngestedEvent` info line (`SmsSyncService.java:155` / `ZoomPhoneSmsService.java:428`).

- Errors only: swap the filter for `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Cross-boundary health signal = **Kafka consumer lag on `texts-ingested`** (TextIndexer backing up) + our producer error rate. Filter `service:textindexer` (consumer) / `service:ingestertelephonysystemssupervisor` (producer) + your `g-cell`.

**Sentry** — ⚠️ TextIndexer reports to [team `deal-intelligence`](https://gong-io.sentry.io/issues/?query=assigned%3A%23deal-intelligence&statsPeriod=14d), **not** `telephony-systems`. Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ✅ **TextIndexer is IN THIS REPO** (`TextIndexer/` module) — real local breakpoint below, on the consumer's `accept(...)`.

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `TextIndexer/src/main/java/com/honeyfy/elasticsearch/indexer/text/consumer/TextIngestedConsumer.java:37` | `public void accept(ConsumerRecord<Long, GroupedGongEvents<TextIngested>> ...)` — every consumed batch lands here |
| **Index call** | `TextIndexer/.../consumer/TextIngestedConsumer.java:43` | `textIndexerService.indexMessages(companyId, texts)` — step in to follow the actual OpenSearch indexing |
| **Producer (ours)** | `IngesterTelephonySystemsSupervisor/src/main/java/com/honeyfy/ingestertelephonysystems/services/sms/SmsSyncService.java:157` | The `kafkaTemplate.send(TEXTS_INGESTED...)` that feeds this consumer |

Set the breakpoint at `TextIngestedConsumer.java:37`, then produce a `texts-ingested` event (drive an SMS sync, below) and step into `indexMessages` @43.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `TextIngestedConsumer.java` in IntelliJ; match the prod file version (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 37** (consumer entry) or **line 43** (index call). In **Source**, pick the tag for **`textindexer`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Drive a text for that company, read the snapshot (`texts.size()`, the events), then **delete the breakpoint.**

> Use a **Log** action to inject `consumerRecords.value().events.size()` on-demand without snapshot overhead.

---

## ▶️ Trigger the flow

`texts-ingested` is produced by our SMS sync paths. Drive an SMS sync for a company that has an SMS-capable integration; `sendTextIngestedEvent` then publishes to `texts-ingested`, which TextIndexer consumes. Use the **SyncJob** drivers in [[Entrypoints Within the Telephony System]] §5 for the company's SMS integration:

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/time-based-events-sync-infra/sqs/sendMessage?high-priority=true' \
  --data-urlencode 'message={"companyId":0,"integrationId":0,"integrationFlavorId":"GONG_CONNECT_API","backfill":false}'
```
- Controller `sendSqsMessage()` — `IngesterTelephonySystemsSyncInfraTroubleshooter` (Entrypoints §5).
- To re-index / inspect existing text directly, use **`TextIndexerTroubleshooter`** (below).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TextIndexerTroubleshooter` (TextIndexer module) | Re-index / inspect text in OpenSearch |
| `IngesterTelephonySystemsSyncInfraTroubleshooter` | Drive an SMS sync that produces `texts-ingested` |
| `SmsTroubleshooter` / `TelephonySystemsSmsTroubleshooter` | Inspect SMS ingestion flows on the producer side |

Discover exact live paths via Swagger: `https://textindexer-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Texts ingested but not searchable | (1) Lag on `texts-ingested` (TextIndexer backing up). (2) Coralogix `service:textindexer` for `indexMessages` errors. (3) OpenSearch index/cluster health. |
| Nothing arriving at TextIndexer | Check the **producer** side: `SmsSyncService.java:159` / `ZoomPhoneSmsService.java:432` log `Failed to send ingested event` on send failure. |
| Errors but nothing in telephony-systems Sentry | TextIndexer reports to **`deal-intelligence`** — look there, and ping owner **dor.shemer@gong.io**. |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[TEXTS-INGESTED]]
