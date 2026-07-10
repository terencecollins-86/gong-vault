---
title: Telephony Systems — Ubiquitous Language (DDD glossary)
tags: [telephony-systems, ddd, glossary, domain-model, ubiquitous-language]
created: 2026-07-08
---

# 08 · Ubiquitous Language

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · [[02 - Data Flows]] · [[04 - Providers & Dialers]] · next → [[09 - Use Cases]]

The shared vocabulary of the **IngesterTelephonySystemsSupervisor** domain — the words engineers,
support, and product should all use to mean the same thing. Every term below is a **real
type/method name in code**; the package is given so you can jump straight to the source of truth.
When a term drifts from the code, fix the code or fix this doc — don't let them diverge.

> [!info] Where the model lives
> The **core event and its value objects** (`TelephonyCallEvent`, `CallStatus`, `RecordingStatus`,
> `OwnerIdentifier`, `CallDirection`, `CallOrigin`, …) are defined in the **`honeyfy` repo**
> (`KafkaIntegration/JsonEntities`, `AppCommon`) — this service is a *consumer/producer* of them.
> The **domain logic and pull-sync model** (`IntegrationFlavor`, `SyncJob`, `CompanySyncDto`, the
> dialer services) live in `gong-telephony-systems` (`Dialers` + `IngesterTelephonySystemsShared`).
> The Shared module package is literally `com.honeyfy.ingesterselephonysystemsshared` — the
> "selephony" typo is in the real source path; preserve it.

---

## The domain in one sentence

> A **provider** emits call data → it enters as a **push** event or a scheduled **pull/sync** →
> a **dialer service**, chosen by **flavor**, resolves the **owner** and the **integration** →
> the **provider call** becomes a Gong **call** → recording and CRM association follow, all
> re-drivable through a **troubleshooter**.

---

## 1. Entities & Aggregates
*Things with identity and a lifecycle.*

| Term | Kind | Identity | Meaning (grounded in code) | Where |
|---|---|---|---|---|
| **SyncJob** | Aggregate root | `getId()` = `integrationId` (+ `.backfill` for backfills) | One unit of pull-sync work for an integration: sync window (`syncStartDate`/`syncEndDate`), `SyncType`, `backfill` flag, `callUpdateTypes`. Serialized onto SQS, re-run per company. | `dialers.services.syncjob.SyncJob` |
| **CompanySyncDto** | Entity (row of `dialers.company_sync`) | `companyId` + `integrationId` | Persistent per-company integration state: `IntegrationStatus`, `IntegrationFlavor`, initial-sync vs periodic-sync watermarks, `repChannelSide`, timezone, `importCrmCallsOnly`. The pull-sync bookkeeping. | `dialers.objects.CompanySyncDto` |
| **Integration** | Entity (conceptual) | `integrationId` | A company's connection to one provider flavor. Realized by `CompanySyncDto` + `IntegrationConfig` (`ConnectionMethodKey` + `CallProviderSetting`s). | `dialers.objects.IntegrationConfig` |
| **Call** (`gongCall`) | Entity (Gong-side aggregate) | Gong `callId` (Long) | The Gong call record produced from an ingested provider call — the hand-off unit to downstream Gong. | created via `CallService` |
| **ProviderCall** | Entity (provider-side) | `providerCallIdentifier` | The provider's representation of a call *before* it becomes a Gong `Call`. Push realization = `PushedEventCall`; pairing to a Gong call = `GongCallProviderCall`. | `dialers.generic.ProviderCallInterface`, `PushedEventCall` |
| **AppUser** | Entity (external, Gong platform) | `appUserId` | The Gong user resolved as the call **owner** via `OwnerIdentifier`. Must be `active` + `shouldImportCalls` for a call to ingest (see [[processcallevent README|the 8-path map]]). | `com.honeyfy.users.dto.AppUser` |
| **Company** | Entity (external, Gong platform) | `companyId` | The tenant. Every event, sync, and call is scoped to one company (`Tenant.evaluateForCompany`). | platform |

---

## 2. Value Objects (enums & immutable descriptors)
*No identity — defined entirely by their values. Enum members are the exact source values.*

### Call state
| Term | Values | Meaning | Where |
|---|---|---|---|
| **CallStatusType** | `STARTED, IN_PROGRESS, COMPLETED, FAILED` | Lifecycle stage of a call. Only `COMPLETED`/`FAILED` are *processable*; `STARTED`/`IN_PROGRESS` are skipped. | `kafka.events.call.external.dialer` (honeyfy) |
| **RecordingStatusType** | `IN_PROGRESS, RECORDED, NON_RECORDED, ONE_SIDE_RECORDING` | State of the call's audio. `NON_RECORDED` still ingests metadata (see `TsNonRecordedCallsProcessingStatusConsumer`). | same (honeyfy) |
| **CallDirection** | `INBOUND, OUTBOUND, CONFERENCE, UNKNOWN` | Direction of the call. | `appcommon.call.CallDirection` (honeyfy) |
| **CallStatus** | `{ CallStatusType type, SkipCode callSkipReason }` | The status VO carried on the event. | `…external.dialer.CallStatus` (honeyfy) |
| **RecordingStatus** | `{ RecordingStatusType type, SkipCode recordingSkipReason }` | The recording-status VO. | `…external.dialer.RecordingStatus` (honeyfy) |
| **SkipCode** | (reason enum) | Why a call/recording was skipped — embedded in `CallStatus`/`RecordingStatus`. | `appcommon.status.SkipCode` (honeyfy) |
| **RepChannel** | `LEFT, RIGHT, UNKNOWN, MONO` | Which stereo track carries the rep's audio (`repChannelSide`, `setStereoTracks`). | `…external.dialer.RepChannel` (honeyfy) |

### Identity & ownership
| Term | Values | Meaning | Where |
|---|---|---|---|
| **OwnerIdentifier** | `{ String value, IdentifierType type }` | How a provider call's rep maps to a Gong `AppUser`. | `…external.dialer.OwnerIdentifier` (honeyfy) |
| **IdentifierType** | `APPUSER_ID, EMAIL` | Interpretation of `OwnerIdentifier.value`. | `…external.dialer.IdentifierType` (honeyfy) |
| **ProviderIdentifierType** | `UNKNOWN, ENGAGE_DIALER, CALL_ID` | Interpretation of `providerIdentifier`. | `…external.dialer.ProviderIdentifierType` (honeyfy) |
| **CallOrigin** | `UNKNOWN, BACKFILL, TROUBLESHOOTER, UPDATED_CALL, SYNC, PUSH, MANUAL_UPLOAD` | **Why/how** a call entered the pipeline. The single tag that distinguishes push from pull from replay. | `appcommon.call.CallOrigin` (honeyfy) |

### Integration & sync
| Term | Values | Meaning | Where |
|---|---|---|---|
| **IntegrationFlavor** | ~65 values, e.g. `GONG_CONNECT_API, DIAL_PAD_API, RINGCENTRAL_API_OAUTH, FIVE9_FTP, AMAZON_CONNECT_S3, MS_TEAMS_API, ZOOM_PHONE_API_OAUTH, PUBLIC_API_EVENT_PUSH`, deprecated `*_SFDC` | **The primary dispatch key of the whole domain** — provider + connection variant. Carries flags: `isSalesForceFlavor`, `isAudioUploadedTo{Gong,External}Storage`, `isSms`, `sqsInfraSupported`, `nextScheduleInterval`. Maps to an `Identifier.Descriptor`. | `dialers.generic.IntegrationFlavor` |
| **ConnectionMethodKey** | e.g. `DIALPAD_OAUTH, RINGCENTRAL_OAUTH, AMAZON_S3, TALKDESK_USER_PASS, GONG_CONNECT` | The **auth/connection mechanism** for an integration — distinct from flavor (one flavor → one connection method). | `dialers.objects.ConnectionMethodKey` |
| **IntegrationStatus** | `CONNECTED, DISCONNECTED, REMOVED` | Whether an integration is live. Only `CONNECTED` is synced/pushed. | `dialers.generic.IntegrationStatus` |
| **ImportationMode** | `PROCESSOR, TS_IMPORTER_GA, TS_IMPORTER_TEST` | Which recording-import path handles the call. | `dialers.generic.ImportationMode` |
| **SyncType** | `USER_BACKFILL, PERIODIC_SYNC, NEW_CONNECTION_BACKFILL, MANUAL_BACKFILL, INTEGRATION_RESET_BACKFILL` | The kind of pull-sync a `SyncJob` performs. | `dialers.objects.SyncType` |
| **CallUpdateType** | `ASSOCIATE_AND_UPDATE_TITLE, UPDATE_PROSPECT_PHONE_NUMBER, ADD_PROVIDER_CALL_ID_REFERENCE` | An after-the-fact update applied to an already-ingested call. | `dialers.objects.CallUpdateType` |
| **SyncJobStatus** | `COMPLETED_SYNC, CONTINUOUS_SYNC, RETRYABLE_ERROR, PERMANENT_ERROR` | Outcome of running a `SyncJob` (in `SyncJobResults`). | `dialers.services.syncjob` |

### Location & association
| Term | Shape | Meaning | Where |
|---|---|---|---|
| **RecordingLocation** | abstract; `S3RecordingLocation`, `UrlRecordingLocation` | Polymorphic pointer to where the audio lives (`getFullPath()`). | `…external.dialer.RecordingLocation` (honeyfy) |
| **CRMEntity** | `{ CRMType type, CRMObjectType objectType, String value }` | A CRM association carried on the event (account/opportunity/…). | `…external.dialer.CRMEntity` (honeyfy) |
| **CallNote** | `{ commentText, VisibilityType, visibilityAppUserIds }` | A note/comment attached to a call. | `…external.dialer.CallNote` (honeyfy) |
| **Identifier.Descriptor** | e.g. `DIAL_PAD, RINGCENTRAL, FIVE9` | Canonical provider identity a flavor maps to (`IntegrationFlavor.descriptor`). | `appcommon.callproviders.identifiers.api` (honeyfy) |

---

## 3. Domain Events
*The Kafka messages that carry domain meaning. Full topic map in [[02 - Data Flows]].*

| Event | Topic (const) | Consumer | Meaning |
|---|---|---|---|
| **TelephonyCallEvent** | `KafkaTopics.DIALER_EVENTS` = `gong-connect-dialer-events` | `TelephonyCallEventConsumer` | **The central domain event.** A pushed telephony call: `providerIdentifier(+Type)`, `providerName`, `ownerIdentifier[]`, `startTime`/`endTime`, `fromNumber`/`toNumber`, `recordingUrl` (`RecordingLocation`), `disposition`, `direction`, `recordingStatus`, `callStatus`, `additionalData`. Extends `GongEvent` (scoped to `companyId`). | 
| (low-priority lane) | `KafkaTopics.LOW_PRIORITY_DIALER_EVENT` = `low-priority-dialer-events` | `LowPriorityTelephonyCallEventConsumer` | Same payload, low-priority lane (public-API-sourced events). |
| (Gong Connect) | `gong-connect-call-event` | `GongConnectCallEventConsumer` | Call event from Gong's own calling product. |
| (CRM re-assoc) | `association-updated` | `TelephonySystemsAssociationUpdatedConsumer` | A CRM association changed → re-associate the call. |
| (CRM retry) | `telephony-crm-association-retry` | `CrmAssociationRetryConsumer` | Retry a failed CRM association. |
| (company change) | `ts-company-updated` | `CompanyUpdatedConsumer` / `…Producer` | Company/account metadata changed. |
| (non-recorded status) | `call-processing-status-event` | `TsNonRecordedCallsProcessingStatusConsumer` | Processing-status feedback for non-recorded calls. |
| (MS Teams users) | `app-user-changes` | `MsTeamsAppUserChangesConsumer` | MS Teams user added/removed/changed. |

> **Downstream hand-off:** the Supervisor writes ingested calls to `call-processing-inbound`
> (+ low-priority) — the boundary where Telephony Systems ends and core Gong processing begins.

---

## 4. Domain Services / Processes
*The verbs — what actually happens to a call. Class#method, grounded.*

| Process | Class#method | What it does |
|---|---|---|
| **Accept a pushed event** | `TelephonyCallEventConsumerAbstract#accept(ConsumerRecord<Long,TelephonyCallEvent>)` | Push entry point: resolves flavor by descriptor, picks the `EventPushSupportingDialerService`, delegates to `processCallEvent`. |
| **Process one call event** | `EventPushSupportingDialerService#processCallEvent(TelephonyCallEvent, Optional<CallOrigin>)` | **Core push ingestion.** Filters irrelevant statuses, resolves the owner `AppUser`, resolves the integration, dedupes, creates/finalizes the Gong call. Returns `PushCallReportInfo` (whose `sendToErrorTopic` decides the HTTP result — see [[processcallevent README|8-path map]]). |
| **Run a sync job** | `SyncJobExecutionService#runSyncJobForCompany(SyncJob, handler, CompanySyncDto)` | **Core pull ingestion.** Executes a `SyncJob`: lists calls from the provider, handles them in batches, advances watermarks. Returns `SyncJobResults`. |
| **Handle one/many provider calls** | `SyncJobExecutionService#handleOneCall(...)` / `#handleCalls(...)` | Per-call work inside a sync: attendees, app-user association, `CallOrigin`, `CallUpdateType`. |
| **Pick the dialer service** | `DialerServiceProvider#getEventSupportingDialerServiceByFlavor(...)` / `#getDialerServiceByFlavor(...)` | Factory/registry mapping an `IntegrationFlavor` → concrete `AbstractDialerService` (push / sync / troubleshooter variant). |
| **Per-provider strategy** | `AbstractDialerService` (+ `AbstractOAuthDialerService`, `AbstractS3EventsDialerService`, `AbstractSFTPDialerService`, `AbstractTokenSupportedDialerService`) | Base classes: login, list calls, download recordings, `INITIAL_SYNC_DAYS_BACK` vs `PERIODIC_SYNC_DAYS_BACK`, `isInitialSyncSeparated()`. |
| **Sync one call (ops)** | `IngesterTelephonySystemsTroubleshooter#syncOneCall(...)` | Manual re-sync of a single known call for support/debug. |
| **Backfill users** | `IngesterTelephonySystemsTroubleshooter#backfillMarkedUsers()`, `TsUserBackfillService#markChangedUsersForBackfill()` | Mark changed users' integrations for backfill (except Gong Connect / Chorus), then drive the backfill. |
| **Import a PBX recording** | `PbxRecordingImportService#importPhoneCall(companyId, appUserId, CallMetaData, s3ObjectKey, audioFileHash)` | Import a phone-call recording from S3 into Gong. |
| **Reimport / mask** | `IngesterTelephonySystemsTroubleshooter#deleteCallProviderDataRecordsToAllowReimport(...)` / `#maskCallsToAllowReimport(...)` | Clear/mask provider-call metadata to allow a clean reimport. |
| **Maintenance** | `TelephonySystemsTasksService#disableInactiveIntegrations()` / `#troubleshootingTsRetention(daysBack)` | Scheduled housekeeping. |

---

## 5. Bounded-context boundaries
*How this context connects to the outside — and the one distinction that organizes everything.*

### Push vs Pull — the central axis
| | **Push** | **Pull / Sync** |
|---|---|---|
| `CallOrigin` | `PUSH` | `SYNC`, `BACKFILL` |
| Trigger | Provider/webhook emits `TelephonyCallEvent` → Kafka | Scheduled `SyncJob` on SQS |
| Entry | `TelephonyCallEventConsumer` → `EventPushSupportingDialerService.processCallEvent` | `SyncJobExecutionService.runSyncJobForCompany` → `AbstractDialerService` |
| Sub-modes | — | **initial sync** vs **periodic sync** (separate watermarks in `CompanySyncDto`) |
| Flavors | those with an `EventPushSupportingDialerService` (e.g. `GONG_CONNECT_API`) | FTP/S3/API sync flavors |

### Neighbours
- **Inbound (providers):** dialer/telephony vendors + Gong Connect + Public API. Flavor → connection
  style: API, OAuth API, SFDC-mediated (`*_SFDC`), FTP/S3, scraping, SMS. Catalog: [[04 - Providers & Dialers]].
- **CRM / ATS:** a call is either `SALES` (CRM data / `DialersActivityAssociation`) or `INTERVIEW`
  (ATS). `CRMEntity` associations; retries on `telephony-crm-association-retry`.
- **Downstream Gong:** `CallService` (call creation) → Activity Store → hand-off on
  `call-processing-inbound`; [[03 - Services Reference|RecordingsImporter]] for audio; TextIndexer for text.
- **Storage / keys:** S3 recording locations; BYOK via `CompanyOwnedKeyRetrieval`
  (`externalCmkAccessNeeded`, see [[01 - Architecture & Modules]]).

---

## 6. Recurring jargon (say these, not synonyms)

| Say this | Not | Because |
|---|---|---|
| **Flavor** | "provider type", "integration kind" | `IntegrationFlavor` is the exact dispatch key everywhere. |
| **Dialer service** | "provider handler", "adapter" | `AbstractDialerService` / `DialerServiceProvider` — the per-flavor strategy. |
| **TS** / **Telephony System** | "phone integration" | `Ts*` / `TelephonySystems*` prefix throughout. |
| **Troubleshooter** | "admin endpoint", "debug API" | `*Troubleshooter` REST surface for re-sync/backfill/reimport. See [[Entrypoints Within the Telephony System]]. |
| **Backfill** | "historical import", "re-sync" | A specific `SyncType.*_BACKFILL` — retroactive fetch, distinct from ongoing sync. |
| **Initial sync** vs **periodic sync** | "first sync"/"regular sync" | Separate watermarks (`initialSync*` vs `periodicSync*`); don't conflate. |
| **Provider call** | "raw call", "external call" | `ProviderCallInterface` / `PushedEventCall` — the pre-Gong representation. |
| **Owner** | "agent", "user", "rep" (loosely) | The `AppUser` resolved from `OwnerIdentifier`; `extractAppUser`. |
| **Non-recorded** | "no-audio call" | `RecordingStatusType.NON_RECORDED` — a real, ingestable state. |
| **Connection method** | "auth type" | `ConnectionMethodKey` — the auth mechanism, distinct from flavor. |

---

## See also
- [[00 - Overview]] — the mental model in prose
- [[02 - Data Flows]] — every entry point + the Kafka topic map
- [[04 - Providers & Dialers]] — the flavor catalog
- [[Entrypoints Within the Telephony System]] — triggering each process by hand
- [[processcallevent README]] *(in the gong-entrypoints repo)* — the 8-path map of `processCallEvent`
