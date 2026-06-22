---
title: TEXTS-INGESTED
component_type: outbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: TELEPHONY_SYSTEMS
tags: [telephony-systems, kafka, outbound, oncall, sms]
---

# 📤 TEXTS-INGESTED

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> The hand-off of an ingested **SMS / text message** from the telephony ingester to the text-indexing pipeline. If this stops, **SMS land in Gong but never get indexed / searchable.**
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **Two producers, one topic.** `texts-ingested` is produced from **two** different SMS services — `SmsSyncService.java:157` (generic SMS: Dialpad, etc.) and `ZoomPhoneSmsService.java:430` (Zoom Phone). If only one provider's texts go missing, you're in the wrong producer — check which `sendTextIngestedEvent` ran.
> 2. **Ownership boundary** — the producer is ours (`ingestertelephonysystemssupervisor`, team `telephony-systems`), but the **downstream consumer [[TextIndexer]] reports to team `deal-intelligence`** (owner dor.shemer@gong.io), *not* telephony-systems. Search the right Sentry team when indexing breaks vs. when the produce breaks.

---

## What it is

| | |
|---|---|
| **Role** | Outbound hand-off: ingested SMS/text → text-indexing pipeline |
| **Topic / cluster** | `texts-ingested`, cluster **`TELEPHONY_SYSTEMS`** (descriptor `WRITE`, line 63) |
| **Message type** | `TextIngested` (`com.honeyfy.kafka.events.text.TextIngested`); consumed as `GroupedGongEvents<TextIngested>` |
| **Producers (2)** | `SmsSyncService.sendTextIngestedEvent` (`:157`) · `ZoomPhoneSmsService.sendTextIngestedEvent` (`:430`) |
| **Send style** | `Robust.robust(() -> kafkaTemplate.send(...).get(), ...)` — **blocks on the ack** (`.get()`), failure logged `error` |
| **Downstream** | [[TextIndexer]] → `TextIngestedConsumer.accept` → `textIndexerService.indexMessages` |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` (producer) · `textindexer` (consumer) |

**Where the hand-off fires** (after an SMS finishes ingesting):
- `SmsSyncService.java:157` — generic SMS path (`sendTextIngestedEvent`, `kafkaTemplate.send(TEXTS_INGESTED...)`)
- `ZoomPhoneSmsService.java:430` — Zoom Phone path (`sendTextIngestedEvent`, same topic)

---

## 👀 See it working

**Coralogix (DataPrime)** — both producers log INFO `"Sending textIngestedEvent="` before the send (`SmsSyncService.java:155` / `ZoomPhoneSmsService.java:428`):
```text
source logs
| filter $l.applicationName == 'ingestertelephonysystemssupervisor'
| filter $m.message.contains('Sending textIngestedEvent') || $m.message.contains('Failed to send ingested event')
| limit 200
```
Scope to one company with `| filter $d.cid == '<companyId>'`. For the **consumer** side (indexing), switch `applicationName` to `'textindexer'` and look for `"Received TextIngested events"` (`TextIngestedConsumer.java:41`).

- Errors only: `| filter $m.message.contains('Failed to send ingested event')` (the `error` log at `SmsSyncService.java:159` / `ZoomPhoneSmsService.java:432`).
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch the Supervisor SMS-sync metrics + **Kafka consumer lag on `texts-ingested`** (TextIndexer backing up). Filter `service:ingestertelephonysystemssupervisor` (produce) or `service:textindexer` (index) + your `g-cell`.

**Sentry** — produce side: [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). ⚠️ **Index side ([[TextIndexer]]) is team `deal-intelligence`** — search `assigned:#deal-intelligence` for indexing errors. Investigate with `observability:sentry-investigation`.

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Produce (generic SMS)** | `IngesterTelephonySystemsSupervisor/.../services/sms/SmsSyncService.java:157` | The `kafkaTemplate.send(TEXTS_INGESTED...)` for Dialpad & generic SMS |
| **Produce (Zoom Phone)** | `IngesterTelephonySystemsSupervisor/.../services/zoomphonesms/ZoomPhoneSmsService.java:430` | The Zoom Phone SMS send to the same topic |
| **Consume (index)** | `TextIndexer/.../text/consumer/TextIngestedConsumer.java:37` | The downstream `accept(...)` — set here to see what TextIndexer received |

Break on `SmsSyncService.java:154` (`sendTextIngestedEvent` entry) to inspect the `TextIngested` before it serializes; step to `:157` for the actual send. The send **blocks on `.get()`**, so a slow/failed ack surfaces synchronously here.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `SmsSyncService.java` (or `ZoomPhoneSmsService.java`) in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 157** (or `430` for Zoom). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger an SMS sync for that company (below), read the snapshot, then **delete the breakpoint.**

> To debug the **index** side without a redeploy, snapshot `TextIngestedConsumer.java:37` and pick the **`textindexer`** tag instead.

---

## ▶️ Trigger the flow

SMS sync is driven from the **Telephony Systems SMS troubleshooter** (`TelephonySystemsSmsTroubleshooter`, base path `/troubleshooting/telephony-systems-sms`). Use it to inspect/replay SMS for a company+provider; a processed SMS then fires `sendTextIngestedEvent`. (See [[06 - Runbook & Troubleshooting]] → SMS troubleshooters.)

```bash
# List SMS sessions/messages for a Zoom Phone integration (verify provider id), as a starting point
curl -X GET \
  'http://localhost:8097/troubleshooting/telephony-systems-sms/generic/sms?company-id=0&integration-id=0&messages-provider=ZOOM_PHONE&from=2024-01-01&to=2024-01-02'
```
- Controller file: `IngesterTelephonySystemsSupervisor/.../rest/TelephonySystemsSmsTroubleshooter.java`.
- For Dialpad stats/processing: `POST /troubleshooting/telephony-systems-sms/dialpad/stats/initiate-processing` (`dialpadSmsStatsInitiateProcessing`, line 302).
- Discover the exact replay/sync endpoint for your provider via Swagger (below) — the SMS troubleshooter exposes provider-specific paths.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonySystemsSmsTroubleshooter` | Inspect/list SMS, add/delete SMS integration, set initial-sync times, Dialpad stats |
| `SmsTroubleshooter` | Additional SMS flow debugging (Supervisor `rest/` package) |
| `TextIndexerTroubleshooter` (TextIndexer) | Re-index / inspect indexed text on the **consumer** side |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| SMS ingested but not searchable | (1) Did the produce happen? Coralogix `"Sending textIngestedEvent"` on `ingestertelephonysystemssupervisor`. (2) Lag on `texts-ingested`. (3) Index errors → **TextIndexer** logs (`textindexer`) + Sentry team **`deal-intelligence`**. |
| Only one provider's texts missing | Two producers — confirm which path ran: `SmsSyncService.java:157` (generic/Dialpad) vs `ZoomPhoneSmsService.java:430` (Zoom). |
| Produce fails | Send **blocks on `.get()`** and logs `error` `"Failed to send ingested event"` (`SmsSyncService.java:159`); `Robust.robust` swallows the throw — grep that error, the SMS won't auto-retry. |
