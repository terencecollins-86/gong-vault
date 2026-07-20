---
title: Consent — Ubiquitous Language (DDD glossary)
tags: [consent, recording-consent, ddd, glossary, domain-model, ubiquitous-language]
created: 2026-07-09
---

# 03 · Ubiquitous Language

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · [[02 - Data Flow]] · [[Storage & Schema Reference]] · next → [[04 - Use Cases]]

The shared vocabulary of the **Recording Consent** domain — the words engineers, support, product,
and legal/compliance should all use to mean the same thing. Every term below is a **real
type/enum/method name in code**; the path lets you jump to the source of truth. Prefixes: **GDC/** =
`gong-data-capture`, **HF/** = `honeyfy` monolith.

> [!info] Where the model lives
> The **services** (jump-page web server, DCP settings API, tasks, change orchestration) live in
> **`gong-data-capture`**. The **consent-email, consent-settings, and compliance model** lives in the
> **honeyfy** modules `ConsentProfile` (`com.honeyfy.consentemail`, `com.honeyfy.consentsettings`),
> `RecordingCompliance` (`com.honeyfy.recordingcompliance`), and `AppCommon`
> (`com.honeyfy.appcommon.compliance` — `JumpPageUrlService`, `ConsentFeatureDao`). Those shared types
> are still the canonical vocabulary; they're consumed by the data-capture services.

---

## The domain in one sentence

> A company's **Data Capture Profile (DCP)** defines whether recording needs consent; ahead of a call
> a participant is routed to a **jump page** (a.k.a. "consent page") — reached by a **jump-page URL**
> (`profileKey/userKey[/meetingKey]`) or a **pre-call consent email** — where they **accept / skip**;
> the decision is **audited** (`audit-meeting-consent`) and tells the **RecordingSupervisor** whether
> to **restrict or stop** recording, while **DcpChangeManager** propagates settings changes across
> users through a **change-request** state machine.

---

## 1 · Entities & Aggregates
*Things with identity and a lifecycle.*

| Term                                | Class / table                                                                                     | Identity                                 | Meaning (grounded in code)                                                                                             | Where                                                                                                           |
| ----------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Data Capture Profile (DCP)**      | `DcpJumpPageSettings` / `DcpJumpPageUrlSettings`                                                  | `profileKey` (+ company)                 | Company-level recording-consent configuration — what the jump page enforces, per provider.                             | gong-clients dto; used `MeetingFrontEnd/.../JumpPageController.java:248`                                        |
| **Jump page** ("consent page")      | rendered by `JumpPageController`                                                                  | `profileKey/userKey[/meetingKey]`        | The participant-facing consent artifact. 2 URL segments = **PMI / static**; 3 = **dynamic / one-time meeting**.        | `GDC/MeetingFrontEnd/.../controller/JumpPageController.java:286`                                                |
| **AppUser consent settings**        | `recording_consent_settings.appuser_consent_settings` (DAO `DcpConsentSettingsDao`)               | `(company, appUserId)`                   | Per-user consent/provider-default resolution.                                                                          | `HF/ConsentProfile/.../consentsettings/service/DcpConsentSettingsDao.java:35`                                   |
| **User settings**                   | `recording_consent_settings.user_settings` (DAO `UserSettingsDao`)                                | `(company, userId)`                      | Per-user default meeting provider.                                                                                     | `GDC/RecordingConsentTasks/.../service/UserSettingsDao.java:18`                                                 |
| **Consent email**                   | `ConsentEmailPageData`                                                                            | `emailId` (has `isEmailIdObsolete` flag) | A pre-call consent email + its landing-page state; obsoletion is its lifecycle.                                        | `HF/ConsentProfile/.../consentemail/dto/ConsentEmailPageData.java:26`                                           |
| **Consent email call**              | `ConsentEmailCall` / `ConsentEmailCallDetails`                                                    | `(companyId, callId)`                    | The call a consent email is about; `ConsentEmailCallDetails` derives a `MeetingStatus` from `CallStatus` + `SkipCode`. | `HF/ConsentProfile/.../consentemail/dto/ConsentEmailCall.java:17`                                               |
| **Change request**                  | `DcpChangeRequestEvent` + change-request tables (DAO `DcpChangeManagerDao`)                       | `changeRequestId`                        | A DCP settings change propagating across users; driven by the `ChangeRequestLifecycle` state machine.                  | `GDC/DcpChangeManager/.../service/DcpChangeManagerDao.java`; lifecycle `.../ChangeRequestLifecycle.java`        |
| **Jump-page session / interaction** | `recording_compliance.jump_page_session` / `jump_page_interaction` (DAO `RecordingComplianceDao`) | session id                               | The audit record of a participant viewing/answering a jump page.                                                       | `GDC/RecordingConsentTasks/.../dao/RecordingComplianceDao.java:35`                                              |
| **Calendar event (consent mirror)** | `recording_consent_settings.calendar_event` / `GoogleCalendarEvent` / `CalendarEventData`         | `iCalId` / `iCalUID`                     | The calendar-event mirror consent keeps to know which meetings need a jump page.                                       | `HF/RecordingCompliance/.../service/ConsentMeetingUpdatesDao.java:31`; `.../google/GoogleCalendarEvent.java:19` |
| **Consent-page request**            | `ConsentPageRequestData` (aggregates `ConsentPageRequestResult`)                                  | in-flight request                        | The in-flight state of one consent-page render/answer.                                                                 | `HF/ConsentProfile/.../consentemail/dto/ConsentPageRequestData.java:14`                                         |

---

## 2 · Value Objects & Enums
*No identity — defined by their values. Members are the exact source values.*

| Enum | Members | Meaning | Where |
|---|---|---|---|
| **MeetingStatus** | `RECORDING, RECORDING_CANCELLED, CALL_CANCELLED` | The consent-side status of a call's recording, derived from `CallStatus` + `SkipCode`. | `HF/…/datacaptureprofile/dto/MeetingStatus.java:3` |
| **URL_KEY_VALIDATION** | `OK, INVALID_CHARACTERS, LENGTH_ISSUE, EXIST` | Result of validating a custom jump-page URL key. | nested in `HF/RecordingCompliance/.../service/JumpPageAdminService.java:1225` |
| **OneTimeMeetingStatus** | `CREATED, SCHEDULED, DELETED` | Lifecycle of a one-time (dynamic) meeting's jump page. | nested in `HF/ConsentProfile/.../CheckAndFixConsentPageRedisConsumer` |
| **AuthorizationFailureType** | `CALENDAR_EMAIL_UNDEFINED, EMPTY_TOKEN, INVALID_TOKEN` | Why a consent-page authorization failed. | nested in `ConsentPageMetricsHelper` |
| **RecordingConsentFeatureName** | `FOR_TEST` (only) | Feature-flag names for consent features — effectively scaffolding today. | `HF/AppCommon/.../compliance/ConsentFeatureDao.java` |
| **DataCaptureProfileException.ErrorCode / Operation** | (error taxonomy) | DCP operation error codes. | `DataCaptureProfileException` |

**URL-segment constants** (the jump-page URL grammar): `PROFILE_KEY_PART_INDEX=0`, `USER_KEY_PART_INDEX=1`,
`MEETING_KEY_PART_INDEX=2` (`HF/AppCommon/.../compliance/JumpPageUrlService.java:157/37/38`). PMI URL = 2
segments; one-time/dynamic = 3.

---

## 3 · Domain Events (Kafka)
*The messages that carry domain meaning. Full topic map in [[02 - Data Flow]].*

| Event | Direction | Topic | Where |
|---|---|---|---|
| **JumpPageInteractionEvent** | Produced by MeetingFrontEnd, consumed by Tasks | `audit-meeting-consent` | producer `JumpPageController.java:765`; consumer `AuditMeetingConsentConsumer.java:26` |
| **ConsentEmailAuditEvent** | Produced by MeetingFrontEnd | `consent-email-audit` | `UiConsentEmailService.java:207` |
| **ConsentEmailPageInteractionEvent** | Consumed by Tasks (produced elsewhere) | `consent-email-page-interaction` | `ConsentEmailPageInteractionConsumer.java:22` |
| **StopRecordingEvent** | Consumed by Tasks | `audit-stop-recording` | `AuditStopRecordingConsumer.java:25` |
| **CalendarUpdateEvent** | Consumed by Tasks | `calendar-updates-for-consent` | `CalendarUpdatesForConsentConsumer.java:24` |
| **ResetConsentRedisForCompanyEvent** | Consumed by Tasks | `reset-consent-redis-for-company` | `ResetConsentRedisForCompanyConsumer.java:17` |
| **DcpChangeRequestEvent** | Produced + consumed by DcpChangeManager | `change-request-executor`, `batch-users-change-executor`, `single-user-change-executor` | `ChangeRequestLifecycle.java:50`; `ChangeRequestExecutorConsumer.java:24` |
| **DcpUserChangeRequestDoneEvent** | Produced + consumed by DcpChangeManager | `single-user-change-request-done` | `ChangeRequestLifecycle.java:107` |
| **CallSchedulingUpdated** | **Consumed** (from Call Scheduling) | `call-scheduling-updated` | `HF/ConsentProfile/.../callschedulingupdated/ConsentCallSchedulingUpdatedConsumer.java:26` |
| **PurgeCompany** | Consumed (GDPR) | `purge-company` | `RecordingConsentPurgeCompanyConsumer.java:23` |

---

## 4 · Domain Services / Processes
*The verbs — what actually happens. `Class#method`, grounded.*

| Process | Class#method · `:line` | What it does |
|---|---|---|
| **Render the jump page** | `JumpPageController#viewJumpPage` `GDC/MeetingFrontEnd/.../controller/JumpPageController.java:286` | Serves the participant consent page (dynamic or PMI). |
| **Record a consent answer** | `JumpPageController#acceptAnswer:614` / `#skipAnswer:653` | Captures accept / skip, publishes `JumpPageInteractionEvent`, restricts recording. |
| **Build the jump-page URL** | `JumpPageUrlService` `HF/AppCommon/.../compliance/JumpPageUrlService.java` | Builds `profileKey/userKey[/meetingKey]` URL — **used by [[Subsystems/Call Scheduling/03 - Ubiquitous Language|Call Scheduling]]** for the consent link. |
| **Schedule / manage a jump-page meeting** | `JumpPageAdminService#scheduleMeeting:507`, `#updateOnetimeMeeting:669`, `#deleteOnetimeMeeting:1172`, `#chooseMeetingProvider:562`, `#validateUserUrlKey:292` | The meeting-scheduling engine behind the jump page (honeyfy). |
| **Read / write DCP settings** | `DcpConsentSettingsController#readDcpJumpPageSettingsWithUser:53` / `#saveUserProviderDefault:61`; `DcpAppUserConsentService` (monolith) | The DCP consent-settings API. |
| **Audit compliance** | `AuditService#addJumpPageSession:72`, `#addJumpPageInteraction:85`, `#auditCallStoppingStatus:122`, `#countAnswers:180` `HF/RecordingCompliance/.../service/AuditService.java:39` | Writes the compliance audit trail (mirrored by `RecordingComplianceDao` in data-capture). |
| **React to calendar updates** | `ConsentMeetingUpdatesService#handleUpdate(companyId, appUserId, CalendarUpdateEvent):44` | Updates the consent calendar mirror from the calendar feed. |
| **Send pre-call consent email** | `PreCallEmailService#sendEmail:457` (Mailgun send `:481`); enqueue `ConsentEmailSender#sendConsentEmail:55` | Sends / enqueues the pre-call consent email. |
| **Orchestrate DCP changes** | `DcpChangeActionsOrchestrator`, `DcpSingleUserChangeActionOrchestrator`, `DcpBatchUserChangeActionOrchestrator`, `ChangeRequestLifecycle` | Propagate a settings change across users via the change-request state machine. |
| **Change actions** | `CancelNonCompliantCallsAction`, `ConsentEmailSettingsChangeAction`, `SyncMeetingPmiAction`, `ConsentEmailBackFillAction` | The concrete batch/single-user actions a change request runs. |
| **Consent → scheduling reaction** | `DcpConsentEmailSchedulingService#handleEvent(CallSchedulingUpdated):69` `HF/ConsentProfile` | Reacts to a `CallSchedulingUpdated` (schedule/cancel consent email). |
| **Feature gating** | `ConsentFeatureDao#isFeatureEnabled(RecordingConsentFeatureName):41` `HF/AppCommon/.../compliance/ConsentFeatureDao.java:18` | Consent feature flags (Guava-cached). |

---

## 5 · Bounded-context boundaries
*How consent connects to the outside — and the concept that organizes everything.*

### The central concept — the Data Capture Profile (DCP) + jump page

The DCP is the company's recording-consent policy; the **jump page** is where that policy meets a
participant. Everything orbits this: the URL grammar (`JumpPageUrlService`), the settings API
(`DcpConsentSettingsController`), the audit trail (`AuditService`), and the change propagation
(`DcpChangeManager`). The **two consent-capture channels** are the secondary axis:

| Channel | Artifact | Entry |
|---|---|---|
| **Jump page** (in-meeting-join) | `profileKey/userKey[/meetingKey]` URL | `JumpPageController` |
| **Pre-call consent email** | `ConsentEmailPageData` (`emailId`) | `ConsentEmailController` + `PreCallEmailService` |

### Neighbours

- **Upstream — Call Scheduling:** consumes **`call-scheduling-updated`** (`CallSchedulingUpdated`) to know a call was scheduled/cancelled and schedule the consent email. See [[Subsystems/Call Scheduling/02 - Entry Points (Inbound & Outbound)]] — this is the exact downstream hand-off documented there.
- **Upstream — calendar feed:** `calendar-updates-for-consent` (`CalendarUpdateEvent`) keeps the consent calendar mirror current.
- **Downstream — recording infrastructure:** `RecordingSupervisorClient#restrictCallRecording / markRecordingStop` — the consent decision tells the recorder to restrict/stop. Note: no direct caller found in the consent packages; the recorder wiring is **event-mediated** (`StopRecordingEvent` / `audit-stop-recording`).
- **Feature flags:** `FeatureFlagsClient` (REST polling) + `ConsentFeatureDao`.
- **Owned datastore:** the `recording_consent` DB — schemas `recording_consent_email`, `recording_consent_settings`, `recording_compliance` ([[Storage & Schema Reference]]).

---

## 6 · Recurring jargon (say these, not synonyms)

| Say this | Not | Because |
|---|---|---|
| **Jump page** (internal) / **consent page** (user-facing) | using them interchangeably in code | Code is overwhelmingly `JumpPage*` (~50 files, ~2183 textual mentions) vs `ConsentPage*` (4 files, ~222). Same artifact; "consent page" is the customer-facing name, "jump page" is the code name. |
| **DCP** / **Data Capture Profile** | "consent config", "recording settings" | The `Dcp*` prefix is everywhere (`DcpJumpPageSettings`, `DcpChangeManager`, `DcpConsentSettingsController`). |
| **profileKey / userKey / meetingKey** | "the URL params" | Exact URL-segment names with fixed indices (`JumpPageUrlService.java:157/37/38`). 2 keys = PMI, 3 = dynamic. |
| **PMI / static** vs **dynamic / one-time** meeting | "the two page types" loosely | PMI = 2-segment URL (personal meeting id); dynamic = 3-segment (per-meeting). Drives `OneTimeMeetingStatus`. |
| **Consent** (settings/decision) vs **compliance** (audit) | treating them as one | `recording_consent_settings` = the policy/decision; `recording_compliance` = the audit trail (`AuditService`, `jump_page_session`). |
| **Change request** | "settings update job" | `DcpChangeRequestEvent` + `ChangeRequestLifecycle` — a first-class state machine. |
| **MeetingStatus** (`RECORDING` / `*_CANCELLED`) | "recording status" | The consent-side derived status; distinct from the recorder's own status. |

---

## Caveats (flagged during extraction)

- The consent→recorder link (`RecordingSupervisorClient.restrictCallRecording`) had **no direct caller** in the four consent packages — the wiring is event-mediated via `StopRecordingEvent` / `audit-stop-recording`, or lives outside those roots.
- Three API controllers implement **gong-clients contracts** (not mounted), so their HTTP verbs/paths are defined on the interfaces, not in these files.
- Redis logical DB is `RECORDING_COMPLIANCE` in code (descriptors say `CONSENT_REDIS`).
- `RecordingConsentFeatureName` currently has only `FOR_TEST` — the consent feature-flag enum is scaffolding.

## See also
- [[00 - Overview]] — the mental model in prose
- [[02 - Data Flow]] — every inbound/outbound point + the topic map
- [[01 - Services & Modules]] · [[Storage & Schema Reference]]
- [[Subsystems/Call Scheduling/03 - Ubiquitous Language]] — the upstream domain that hands off `call-scheduling-updated`
