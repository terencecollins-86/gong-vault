---
title: Telephony Systems — Services Reference
tags: [telephony-systems, services, reference]
created: 2026-06-19
---

# 03 · Services Reference

> [[_dashboard|← Team Hub]] · [[02 - Data Flows]] · next → [[04 - Providers & Dialers]]

Per-service deep dive. Infra/topic details come from each module's
`src/main/resources/descriptors/app/<Module>.gong-app-descriptor.yaml`.

---

## TelephonySystemsWebApi  🌐 public

| | |
|---|---|
| **Image** | `telephonysystemswebapi` |
| **Type** | `webapi-server`, `publicFacing: true`, prefix `/telephonysystemswebapi` |
| **Main** | `com.honeyfy.telephonysystemswebapi.TelephonySystemsWebApi` |
| **Owner** | adi.magen@gong.io |
| **Postgres** | OPERATIONAL, USER_AUTH |
| **Redis** | WFE_SESSION, GONG_PROD |
| **Kafka** | APP_USER (write) |
| **Key upstream** | GlobalDirectory, Permissions, FeatureFlagsBroker, AuroraController, CollectiveIntegrations, IngesterTelephonySystemsSupervisor |

The thin, customer-facing layer. Configures telephony integrations and runs the OAuth
handshake with providers. Controllers: `TelephonyIntegrationController`,
`TelephonyOAuthController`, `TestController`.

---

## IngesterTelephonySystemsSupervisor  ⚙️ ingestion brain

| | |
|---|---|
| **Image** | `ingestertelephonysystemssupervisor` |
| **Type** | `api-server`, internal |
| **Main** | `…ingestertelephonysystems.init.IngesterTelephonySystemsSupervisorInitializer` |
| **Owner** | yossi.rizgan@gong.io |
| **locks** | ✅ · **scheduledTasks** ✅ · **externalCmkAccessNeeded** ✅ |
| **Postgres** | INGESTER, DIALERS, OPERATIONAL |
| **Key upstream** | ProviderIntegrationManager, FileUpload, Orchestrator, CallActivityStoreGateway, GongConnectTasks, PurgeOrchestrator, PublicApiBackend, GlobalDirectory, Permissions, CloudStorageController, +more |

The largest, most important service. Hosts the bulk of the **Kafka consumers**,
**scheduled sync tasks**, **producers**, and the largest set of **REST + troubleshooter
controllers**. Embeds the `RecordingsImporter` and `IngesterTelephonySystemsShared`
libraries. Start here when tracing almost any ingestion behavior. See [[02 - Data Flows]].

---

## TelephonySystemsTroubleshooters  🩺 diagnostics

| | |
|---|---|
| **Image** | `telephonysystemstroubleshooters` |
| **Type** | `api-server`, internal |
| **Main** | `…TelephonySystemsTroubleshooters.init.TelephonySystemsTroubleshootersInitializer` |
| **Owner** | yossi.rizgan@gong.io |
| **locks** | ✅ · **externalCmkAccessNeeded** ✅ |
| **Postgres** | DIALERS, OPERATIONAL, DATA_CAPTURE, RECORDING_CONSENT, CALL_QUEUES, CRM_FIELDS (r/o), DWH, INTEGRATION |
| **OpenSearch** | AUDITS, TROUBLESHOOTING_TS (read+write) |
| **Redis** | GONG_PROD |
| **Kafka (write)** | `gong-connect-call-ingested`, `comment-update`, `dialer-calls-updates`, `webconference-call-events` |

Broad **read** access across many databases so support/engineering can inspect production
state, plus write access to a few topics to **replay/re-drive** ingestion. Auth model:
[[Architecture/Troubleshoot Endpoints]].

---

## TextIndexer  🔎 search indexing  *(deal-intelligence owned)*

| | |
|---|---|
| **Image** | `textindexer` |
| **Type** | `api-server`, internal |
| **Main** | `…elasticsearch.indexer.text.init.TextIndexerInitializer` |
| **Owner** | dor.shemer@gong.io (team: deal-intelligence) |
| **locks** | ✅ · **scheduledTasks** ✅ |
| **Postgres** | OPERATIONAL, SCHEDULED_TASKS_01/02 |
| **OpenSearch** | TEXTS (read+write) |
| **Redis** | CIRCUIT_BREAKERS (r/o) |
| **Kafka** | reads `texts-ingested`, `association-updated`, `delete-texts`; writes `texts-indexed`, `texts-deleted` |

Lives in our repo but is **owned by deal-intelligence** — coordinate with that team for
changes. Consumes call text and maintains the OpenSearch `TEXTS` index. Consumers:
`TextIngestedConsumer`, `TextIndexerAssociationUpdatedConsumer`, `DeleteTextConsumer`.

---

## Quick "which service do I touch?" guide

| I want to… | Service |
|---|---|
| Change how an integration is configured / OAuth | TelephonySystemsWebApi |
| Change how a call/recording is ingested or converted | IngesterTelephonySystemsSupervisor (+ Dialers / RecordingsImporter libs) |
| Add a provider integration | Dialers library (driven by Supervisor) — see [[04 - Providers & Dialers]] |
| Inspect/replay production call data | TelephonySystemsTroubleshooters |
| Change call-text search indexing | TextIndexer *(loop in deal-intelligence)* |
