---
title: Calendar Ingestion — Services Reference
tags: [calendar-ingestion, services, reference]
created: 2026-06-25
---

# 03 · Services Reference

> [[_dashboard|← Team Hub]] · [[02 - Data Flows]] · next → [[04 - Providers & Sources]]

Per-service deep dive. Infra/topic details come from each module's
`src/main/resources/descriptors/app/<Module>.gong-app-descriptor.yaml`.

---

## IngesterCalendarSupervisor  ⚙️ orchestration brain

| | |
|---|---|
| **Image** | `ingestercalendarsupervisor` |
| **Type** | `api-server`, internal |
| **Main** | `…calendar.supervisor.config.IngesterCalendarSupervisorInitializer` |
| **Owner** | ariel.bloch@gong.io |
| **locks** ✅ · **scheduledTasks** ✅ | |
| **Postgres** | OPERATIONAL (r/w), INGESTER (r/w), RECRUITING (r/o), RECORDING_CONSENT (r/w) |
| **MongoDB** | CALENDAR_EVENTS (r/w) |
| **OpenSearch** | CALENDAR_EVENTS_HISTORY (r/w), MEETINGS (r/w) |
| **Redis** | GONG_PROD (r/w), CIRCUIT_BREAKERS (r/o), INGESTER_REDIS (r/w) |
| **Key upstream** | AuroraController, FeatureFlagsBroker, CrmMappings, ProviderIntegrationManager, CloudStorageController |
| **Secrets** | `google.GongApp`, `shared-mailbox-access-job`, `salesforce.integrationConnectedApp.v1` |

The largest, most important service. Hosts the **scheduled sync fan-out** (the primary
entry point), the **command producers** (`google-calendar-commands` /
`office-calendar-commands`), the deletion/backfill/mirror **REST controllers**, and the
**~18 `Troubleshooting*` controllers**. Embeds `CalendarCore`. Start here when tracing almost
any calendar behavior. See [[02 - Data Flows]].

Key scheduled tasks: `ImportGoogle/OfficeCalendarEventsTask`, `UpdateAzureUsersTask`,
`CalendarDeletionRequestsTask`, `DeleteObsoleteCalendarEventsTask`, `PurgeMeetingsTask`,
`MeetingsSnowflakeBackfiller`.

---

## GoogleCalendarIngester  🟢 Google fetcher

| | |
|---|---|
| **Image** | `googlecalendaringester` |
| **Type** | `api-server`, internal |
| **Main** | `…calendar.google.config.GoogleCalendarIngesterInitializer` |
| **Owner** | ariel.bloch@gong.io |
| **locks** ✅ · **scheduledTasks** ✅ | |
| **Postgres** | OPERATIONAL (r/w), INGESTER (r/w), RECRUITING (r/o), RECORDING_CONSENT (r/w) |
| **MongoDB** | CALENDAR_EVENTS (r/w) |
| **OpenSearch** | CALENDAR_EVENTS_HISTORY (r/w) |
| **Redis** | GONG_PROD, CIRCUIT_BREAKERS (r/o), INGESTER_REDIS |
| **Kafka** | reads `google-calendar-commands`; writes `calendar-meeting-upsert-requests`, `calendar-ingester-sync-status`, call-scheduling topics |
| **Secrets** | `google.GongApp`, `shared-mailbox-access-job` |

Consumes per-user **import commands** and fetches events from the **Google Calendar API**.
Single consumer: `GoogleCalendarCommandsConsumer` (extends `UserCalendarImporter`,
configurable concurrency, no error reprocessing — events are regenerated on the next scheduled
sync). Provider wiring: `GoogleCalendarProvider` + `GoogleAppsAuthService` / `GoogleTokenService`.
See [[04 - Providers & Sources]].

---

## OfficeCalendarIngester  🔵 Office 365 fetcher

| | |
|---|---|
| **Image** | `officecalendaringester` |
| **Type** | `api-server`, internal |
| **Main** | `…calendar.office.config.OfficeCalendarIngesterInitializer` |
| **Owner** | ariel.bloch@gong.io |
| **locks** ✅ · **scheduledTasks** ✅ | |
| **Postgres** | OPERATIONAL (r/w), INGESTER (r/w), RECRUITING (r/o), RECORDING_CONSENT (r/w) |
| **MongoDB** | CALENDAR_EVENTS (r/w) |
| **OpenSearch** | CALENDAR_EVENTS_HISTORY (r/w) |
| **Redis** | GONG_PROD, CIRCUIT_BREAKERS (r/o), INGESTER_REDIS |
| **Kafka** | reads `office-calendar-commands`; writes `calendar-meeting-upsert-requests`, `calendar-ingester-sync-status`, call-scheduling topics |
| **Upstream** | + ProviderIntegrationManager (vs Google) |
| **Secrets** | `shared-mailbox-access-job` |

Consumes per-user **import commands** and fetches events from **MS Graph / Office 365**.
Single consumer: `OfficeCalendarCommandsConsumer` (extends `UserCalendarImporter`). Provider
wiring: `OfficeCalendarProvider` + `OfficeAzureUsersService` + the `office365common`
`Office365LegacyClientFactory` / `AzureUserDao`. See [[04 - Providers & Sources]].

---

## MeetingsIndexer  🔎 search indexing

| | |
|---|---|
| **Image** | `meetingsindexer` |
| **Type** | `api-server`, internal |
| **Main** | `…calendar.meetingsIndexer.config.MeetingsIndexerInitializer` |
| **Owner** | ariel.bloch@gong.io |
| **locks** ✅ · **scheduledTasks** ✅ | |
| **Postgres** | OPERATIONAL (r/w), INGESTER (r/w), RECORDING_CONSENT (r/w) |
| **MongoDB** | CALENDAR_EVENTS (r/w) |
| **OpenSearch** | CALENDAR_EVENTS_HISTORY (r/w), **MEETINGS (r/w)** |
| **Redis** | GONG_PROD, CIRCUIT_BREAKERS (r/o) |
| **Kafka** | reads `calendar-meeting-upsert-requests`, `association-updated`, `call-scheduling-updated`; writes `meetings-indexed`, `calendar-meeting-upsert-requests` (re-upsert) |

The **sink** of the pipeline. Consumes meeting-upsert requests and writes the meeting into the
OpenSearch **MEETINGS** index (`MeetingIndexerService.indexMeetingsByOrder()`). Three consumers:

- `MeetingUpsertRequestsConsumer` — index/delete meetings (batched per company)
- `meetings-crm-association-updated-consumer` — re-enrich invitee CRM data, re-upsert
- `meetings-call-scheduler-updated-consumer` — set the scheduled call-id, re-upsert

---

## Quick "which service do I touch?" guide

| I want to… | Service |
|---|---|
| Change *when/who* gets synced (scheduling, fan-out, backfill, deletion) | IngesterCalendarSupervisor |
| Change how **Google** events are fetched/auth'd | GoogleCalendarIngester (+ CalendarCore `provider`) |
| Change how **Office 365** events are fetched/auth'd | OfficeCalendarIngester (+ CalendarCore `provider`) |
| Change the import/meeting/CRM logic shared by all | CalendarCore library |
| Change how meetings are **indexed** into OpenSearch | MeetingsIndexer |
| Inspect/replay production calendar data | Supervisor `Troubleshooting*` controllers ([[06 - Runbook & Troubleshooting]]) |
