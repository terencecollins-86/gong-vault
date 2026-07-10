---
title: Call Scheduling — Ubiquitous Language (DDD glossary)
tags: [call-scheduling, ddd, glossary, domain-model, ubiquitous-language]
created: 2026-07-09
---

# 03 · Ubiquitous Language

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · [[02 - Entry Points (Inbound & Outbound)]] · next → [[04 - Use Cases]]

The shared vocabulary of the **Call Scheduling** domain — the words engineers, support, and product
should all use to mean the same thing. Every term below is a **real type/enum/method name in code**;
the path is given so you can jump to the source of truth. When a term drifts from the code, fix one
or the other — don't let them diverge.

> [!info] Where the model lives
> The **engine, webhook servers, DAOs, and validators** live in **`gong-call-schedulers`**
> (`CallScheduler`, `InviteHandlerWebhooksServer`, `CallSchedulingCommon`). But the **core domain
> types** — `Call`, `CallCreationMechanism`, `Resolution`, `CallInDetails`, `Identifier.Descriptor`,
> `CallSchedulingRequest`, and the produced events — are defined in the shared **`honeyfy`** modules
> (`AppCommon`, `CallScheduling`, `KafkaIntegration/JsonEntities`) and consumed here. Those shared
> types are still the canonical vocabulary; they're just owned via `gong-clients`.

---

## The domain in one sentence

> A meeting is discovered — via the **calendar-sync feed** or an **email invite** — carrying a
> **`CallCreationMechanism`**; it runs a **validation chain** chosen by that mechanism; if it passes,
> a **`Call`** (the scheduled recording) is **added / rescheduled / cancelled / restored** in Postgres,
> resolved to a conferencing **provider** (`CallInDetails`), and the decision (`Resolution`) is
> published downstream as a **`CallSchedulingUpdated`** event keyed by `callId`.

---

## 1 · Entities & Aggregates
*Things with identity and a lifecycle.*

| Term | Class / table | Identity | Meaning (grounded in code) | Where |
|---|---|---|---|---|
| **Call** (aggregate root) | `Call` | `long id` (secured id), tenant `long companyId` | The scheduled call-recording aggregate: `plannedStartDateTime`, `organizerId`, `emailInviteCode`, `callCreationMechanism`, `recurringId`, `isInterview`. The thing that gets scheduled / rescheduled / cancelled / restored. | `honeyfy/AppCommon/.../call/Call.java:21` |
| **scheduled_calls row** | table `call_scheduler.scheduled_calls` | PK `(enhanced_ical_id, company_id)` | Idempotency record that a recording was scheduled for a given **enhanced iCal id** (row-level security by tenant). | DAO `CallScheduler/.../dao/ScheduledCallsDao.java:10`; DDL `…/V20230304_0810__add_scheduled_calls_table.sql` |
| **calendar_recurring_event row** | table `call_scheduler.calendar_recurring_event` | PK `(company_id, ical_uid)` + `should_cancel_recurring_event` | Per-tenant cancellation state of a recurring series, keyed by **iCal UID**; audit-triggered. | DAO `CallScheduler/.../dao/CalendarRecurringEventsDao.java:19`; DDL `…/V20220830_0942__add_calendar_recurring_event_tables.sql` |
| **RecurringEventDto** | `RecurringEventDto` | `long id`, `companyId`, `String icalUid` | Full recurring-series record: recurrence window, `nextTimeToCheck`, `isCancelled`/`manuallyCancelled`, `cancellationReason`, `creationMechanism`, `eventOrigin`. | `CallSchedulingCommon/.../recurring/RecurringEventDto.java:14` |
| **RecurringEventSetDto** | `RecurringEventSetDto` | `icalUid` + `companyId` | A recurrence set = `initialEvent` + `eventExceptions`; expands to occurrences. | `CallSchedulingCommon/.../recurring/RecurringEventSetDto.java:12` |
| **updated_calendar_event row** | table `call_scheduler.updated_calendar_event` | unique `(enhanced_ical_id, company_id)` | Tracks last-seen create/modified timestamps to dedup re-processing; TTL-pruned by a scheduled task. | DAO `CallSchedulingCommon/.../common/UpdatedCalendarEventDao.java:15` |
| **CalendarEvent** | `CalendarEvent` (interface) | `getICalId()` / `getEnhancedCalendarEventId()` | The parsed calendar event flowing through processing — start/end, summary, invitees, `isCancellationEvent`, `isRecurrent`. | `com.honeyfy.callscheduling.calendar.CalendarEvent` |
| **EnrichedCalendarEvent** | `EnrichedCalendarEvent` | value wrapper | A `CalendarEvent` + `creationMechanism`, `eventOrigin`, `eventEmailRecipients`, description URLs — the unit fed into recurring scheduling. | `CallSchedulingCommon/.../recurring/EnrichedCalendarEvent.java:11` |
| **InviteEmailRequest** | `InviteEmailRequest` | no persistent id (keyed by iCal id downstream) | The raw inbound Mailgun invite: `creationMechanism`, `bodyMimeMessage`, `recipient`, `sender`, `subject`, Mailgun `timestamp/token/signature`. | `InviteHandlerWebhooksServer/.../inviteemail/InviteEmailRequest.java:5` |
| **EventProcessingContext** | `EventProcessingContext` | mutable per-request context | The context threaded through the pipeline: companyId, callId, event, invitees, `creationMechanism`, `resolution`, CRUD operation. | `CallSchedulingCommon/.../processingcontext/EventProcessingContext.java` |

---

## 2 · Value Objects & Enums
*No identity — defined entirely by their values. Members are the exact source values.*

### The central organizing enum

| Enum | Members | Meaning | Where |
|---|---|---|---|
| **CallCreationMechanism** | `MANUAL, CALL_PROVIDER_API, CALENDAR_SYNC_EMAIL, OPT_IN_EMAIL, IMPORT, AUTOMATIC_IMPORT, CALENDAR_SYNC` (legacy), `COORDINATOR_EMAIL, CALENDAR_INGESTER, RECRUITING_CALENDAR_INGESTER` (@Deprecated) | **The domain's central dispatch key** — *how* a call came to be scheduled. Carries `importRequired`; predicates `isEmail()` (= sync-email ∥ opt-in ∥ coordinator), `isOptIn()`, `isCoordinator()`, `isInviteHandler()` (= `CALENDAR_SYNC_EMAIL`), `isFromCalendarIngester()`. | `honeyfy/AppCommon/.../call/CallCreationMechanism.java:3` (predicates `:26`–`:44`) |

### Status / operation / outcome

| Enum | Members (sample) | Meaning | Where |
|---|---|---|---|
| **Resolution** | 60+, e.g. `NEW_CALL, CALL_UPDATED, RESCHEDULED, CANCELLED, CANCEL_BY_OWNER, CANCEL_BY_COMPLIANCE_EMAIL, RESTORED_BY_OWNER, USER_NOT_MARKED_FOR_RECORDING, COMPLIANCE_ENFORCING, CALL_BLACKLISTED, INTERNAL_MEETING_RECORDING_DISABLED, CALL_PROVIDER_DISABLED_FOR_COMPANY, NEW_CALL_RECURRING` | The **outcome/decision code** of processing one event — the domain's rich "why" vocabulary. Each carries `(success, shouldCancelCall, description, parents…)` and a precedence hierarchy (`isMorePrecise`). | `honeyfy/CallScheduling/.../processingcontext/Resolution.java:9` |
| **CallSchedulingCRUDOperation** | `NEW, UPDATE, CANCEL, NONE` | The lifecycle operation stamped on every produced `CallSchedulingUpdated`. | `honeyfy/AppCommon/.../callscheduling/common/CallSchedulingCRUDOperation.java:3` |
| **CallSchedulingEventType** | `CALENDAR_EVENT, EMAIL_EVENT` | Discriminates the two payload shapes on an inbound `CallSchedulingRequest` (calendar-sync feed vs email invite). | `honeyfy/CallScheduling/.../kafka/events/CallSchedulingEventType.java:3` |
| **CancellationReason** | `NO_EVENTS_FOUND, USER_NOT_FOUND, USER_NOT_ACTIVE, CANCELLED_MAIN_EVENT` | Why a recurring series was cancelled (persisted on `RecurringEventDto.cancellationReason`). | `CallSchedulingCommon/.../recurring/CancellationReason.java:3` |
| **RecurringEventService.RecurringEventChange** | `Irrelevant, CancelledMainEvent, UpdatedMainEvent, UpdatedEventOccurrence, CancelledEventOccurrence` | Classifies what changed in a recurring series during processing. | `CallScheduler/.../service/RecurringEventService.java:580` |
| **OptInEmailResponseSender.EmailType** | `Onetime_Successful, Onetime_Cancellation, Onetime_Failure, Recurring_Succeeded, Occurrence_Changed, Occurrence_Cancellation, Recurring_Cancelled, Request_To_Record_By_Non_Gong_User` | The opt-in email reply variants. | `CallSchedulingCommon/.../service/OptInEmailResponseSender.java:439` |

### Provider & mailbox

| Term | Sample members | Meaning | Where |
|---|---|---|---|
| **Identifier.Descriptor** | Recorders: `ZOOM, WEBEX, MICROSOFT_TEAMS, GO_TO_MEETING, GOOGLE_MEET, RING_CENTRAL_VIDEO, CHIME, BLUE_JEANS` (~100 total incl. dialers). `PROVIDERS_SUPPORTING_ONE_TIME_MEETING_URLS = {ZOOM, GOOGLE_MEET, MICROSOFT_TEAMS, WEBEX}` | The **conferencing/call provider** value object — the provider-abstraction axis. `CallInDetails.callProvider` is of this type. | `honeyfy/AppCommon/.../callproviders/identifiers/api/Identifier.java:29` |
| **CallInDetails** | `{ callProvider (Descriptor), callURL, password, meetingIdentifier }` | The **generic conferencing-provider abstraction** every integration resolves to. equals/hashCode by URL + meetingIdentifier. | `honeyfy/AppCommon/.../callproviders/common/CallInDetails.java:14` |
| **MailboxProviderCode** | `OFFICE365, GOOGLE_APPS, ASSISTANT, FORWARDED_MAIL, GMAIL_EXTENSION` | The **calendar/mailbox provider** (distinct from conferencing provider) — drives Office-vs-Google recurring-cancellation branching. | `honeyfy/AppCommon/.../mailbox/MailboxProviderCode.java:6` |

---

## 3 · Domain Events (Kafka)
*The messages that carry domain meaning. Full topic map in [[02 - Entry Points (Inbound & Outbound)]].*

The three produced "updated" events form one Jackson polymorphic hierarchy on `call-scheduling-updated`:

| Event | Direction | Topic | Key | Where |
|---|---|---|---|---|
| **CallSchedulingUpdated** (base) | Produced (downstream hand-off) | `call-scheduling-updated` | `Long callId` | type `honeyfy/KafkaIntegration/JsonEntities/.../call/CallSchedulingUpdated.java:16`; sent `CallScheduler/.../producer/CallSchedulingUpdatedProducer.java:262` |
| **CallSchedulingCalendarEventUpdated** | Produced (calendar-sourced subtype) | same | `callId` | `…UpdatedProducer.sendCallSchedulingCalendarEventUpdated:94` |
| **ManualCallEventUpdated** | Produced (manual-schedule subtype) | same | `callId` | `…UpdatedProducer.sendManualCallUpdated:239` |
| **CallSchedulingRequest** | Consumed (upstream request); also **produced** by webhook server | `call-scheduling-requests` (+ low-priority) | `String` iCal id | type `honeyfy/CallScheduling/.../kafka/events/CallSchedulingRequest.java:16`; produced `InviteHandlerWebhooksServer/.../CallSchedulingRequestProducer.java:45`; consumed `CallScheduler/.../CallSchedulingRequestsConsumer.java:119` |
| **CalendarEventHistoryItem** | Produced (history / ES indexing) | `call-scheduling-history` | — | producer `CallSchedulingCommon/.../kafka/CallSchedulingHistoryProducer.java` |

Consumed-only operational events (part of the context, not core domain): `PurgeCompany` (`purge-company`),
`SyncUsersFromProviderEvent` (`sync-users-from-web-conferencing-provider`).

---

## 4 · Domain Services / Processes
*The verbs — what actually happens to a call. `Class#method`, grounded (all in `gong-call-schedulers`).*

| Process | Class#method · `file:line` | What it does |
|---|---|---|
| **Add / schedule a call** | `SchedulingCallService#addCallFromCalendarAndReport` `CallScheduler/.../service/SchedulingCallService.java:130` | Schedules a new call from a calendar event, transactionally; reports analytics. |
| **Reschedule** | `SchedulingCallService#rescheduleCallUpdateAndReport:77` | Updates an existing call → `Resolution.RESCHEDULED` / `TOO_LATE_TO_RESCHEDULE`. |
| **Cancel on resolution change** | `SchedulingCallService#cancelExistingCallDueToResolutionChange:186` | Cancels a scheduled (non-opt-in) call when the calendar resolution changes. |
| **Manual schedule** | `ManualSchedulingCallService#scheduleNewCallManually:91` | UI/API scheduling with `CallCreationMechanism.MANUAL`; emits `ManualCallEventUpdated` (`NEW`). |
| **Cancel (owner)** | `CancelCallService#cancelByOwnerScheduledCall:132` | Cancel one call from UI (`SkipCode.CANCELED_BY_OWNER`, `Resolution.CANCEL_BY_OWNER`). |
| **Cancel recurring** | `CancelCallService#cancelScheduledRecurringCall:73` | Branches by `callCreationMechanism.isEmail()` vs `isFromCalendarIngester()` and by `MailboxProviderCode` (Google vs Office). |
| **Cancel (compliance / provider / internal)** | `CancelCallService#cancelByComplianceEmailScheduledCall:137`, `#cancelScheduledCalls:225`, `#cancelScheduledInternalMeetingsCallsRecordings:236` | The other cancellation paths. |
| **Restore** | `RestoreCancelledCallService#restoreCancelledCallByOwner:51`, `#restoreCancelledRecurringCallByOwner:66` | Restore a previously-cancelled call/series (`Resolution.RESTORED_BY_OWNER`), emits `UPDATE`. |
| **Recurring engine** | `RecurringEventService#addEvent:117`, `#processRecurringEventBatches:357`, `#markRecurringEventAsCancelled:297` | Record + batch-scan/schedule upcoming recurring occurrences (background task). |
| **Recurring cancel-state** | `CalendarRecurringEventsService#markRecurringEventAsCancelledByIcal:25`, `#markOfficeCalendarRecurringEventAsCancelled:29`, `#shouldCancelRecurringOfficeEvent:63` | Owns `calendar_recurring_event` state + Office iCal↔recurringId mapping + "should cancel" cache. |
| **Build the call** | `CallBuilder#addNonOwnerInviteesToCall` `CallScheduler/.../handler/CallBuilder.java:578` | Builds the call's participant set (register/cancel from email **or** calendar). |
| **Handle inbound email (webhook)** | `EmailHandlerService#handle` `InviteHandlerWebhooksServer/.../inviteemail/EmailHandlerService.java:40` | Validate → normalize invite → (if from GGE) produce `CallSchedulingRequest`; persists MIME to S3. |
| **Handle inbound email (engine)** | `IncomingEmailInviteHandler#handleIncomingEmail` `CallScheduler/.../handler/IncomingEmailInviteHandler.java:79` | Turns a raw email into an `EventProcessingContext`. |
| **Handle calendar event** | `IncomingEventHandler#handleIncomingEvent` `CallScheduler/.../handler/IncomingEventHandler.java:123` | Core per-event handler (calendar path). |
| **Route consumer payload** | `CallSchedulingRequestsService#callIncomingEmailInviteHandler` `CallScheduler/.../service/CallSchedulingRequestsService.java:67` | Routes email payload through the invite handler, sends history to ES. |
| **Validation chain** | `EventValidationFactory#getEventValidation(creationMechanism, isCancellation)` `CallScheduler/.../validation/EventValidationFactory.java:30` | Picks one of **three** checkers: `cancellationEventValidation`, `optInEventValidation`, `generalEventValidation`. |
| **Resolve the provider** | `CallInDetailsService` `CallSchedulingCommon/.../processingcontext/CallInDetailsService.java:50` | Resolves a raw event/URL into the generic `CallInDetails` (provider + URL + meeting id); handles consent jump-page URLs. |

**Individual validators** (in `CallScheduler/.../validation/`): `CheckEventRelevance`, `CheckBlockTitle`,
`CheckBlockParticipnat` *(sic)*, `CheckUrlValidity`, `CheckOrganizer`, `CheckProviderEnabled`,
`CheckDoNotRecordUsers`, `CheckDoNotRecordInterviewUsers`, `CheckInternalMeetingAllowed`,
`CheckCompliance`, `CheckInterviewValidity`, `CheckRecordingOnlyFromOrganizerCalendar`; opt-in-only rules
wrapped by `ConditionalValidation`.

---

## 5 · Bounded-context boundaries
*How this context connects to the outside — and the axis that organizes everything.*

### The central axis — `CallCreationMechanism`

Everything branches on it: validation selection (`EventValidationFactory.getEventValidation:30`),
cancel/restore branching (`CancelCallService.cancelScheduledRecurringCall:73`), reject-email behaviour
(`RejectionGenericAddressUsageValidator:101-105`), and event production. It resolves into two secondary axes:

| Axis | Split | Grounded in |
|---|---|---|
| **How the call is discovered (ingress)** | `CALENDAR_EVENT` (calendar-sync feed, `CALENDAR_INGESTER`) vs `EMAIL_EVENT` (invites: `CALENDAR_SYNC_EMAIL` = invite-handler, `OPT_IN_EMAIL`, `COORDINATOR_EMAIL`) | `CallSchedulingEventType`; consumer switch `CallSchedulingRequestsConsumer.java:119` |
| **Which provider records it (egress)** | `Identifier.Descriptor` (Zoom/WebEx/Teams/GoToMeeting/Google Meet/…) surfaced through the single `CallInDetails` VO | `CallInDetails.java:14` |

### Neighbours

- **Upstream — calendar ingestion:** produces `CallSchedulingRequest` on `call-scheduling-requests`
  (calendar path). Map: [[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion]].
- **Upstream — email invites:** `InviteHandlerWebhooksServer` produces the email path via
  `CallSchedulingRequestProducer.send:45`.
- **Consent / compliance gating:** enforced in the validation chain (`CheckCompliance`,
  `JumpPageUrlService`) and consent-link handling in `CallInDetailsService`
  (`GONG_CONSENT_DOMAIN_SUFFIX = "join.gong.io"`, `:55`); resolutions `COMPLIANCE_ENFORCING`,
  `INVALID_CONSENT_LINK`, `CANCEL_BY_COMPLIANCE_EMAIL`. See [[Subsystems/Consent/_dashboard|Consent]].
- **Conferencing providers:** the `CallInDetails` / `Identifier.Descriptor` abstraction; provider tokens
  synced via `sync-users-from-web-conferencing-provider` + `WebexRefreshTokenService` / `ZoomSyncService`.
- **Downstream hand-off:** `call-scheduling-updated` carrying the three `CallSchedulingUpdated` subtypes,
  keyed by `callId` — the boundary into recording infrastructure.

---

## 6 · Recurring jargon (say these, not synonyms)

| Say this | Not | Because |
|---|---|---|
| **CallCreationMechanism** / "creation mechanism" | "flow type", "schedule type", "source" | It's the actual field name everywhere (`creationMechanism` / `callCreationMechanism`). |
| **Flow** = the *generic-vs-tenant* webhook routing | "flow" for opt-in/coordinator/calendar-sync | In code "flow" is `getGenericFlowHandler` vs `getTenantFlowHandler` (`IncomingInviteEmailRequestHandlerProvider.java:21,25`). The opt-in/coordinator/calendar-sync distinction is a **mechanism**, not a flow. |
| **Invite-handler** = `CALENDAR_SYNC_EMAIL` | "calendar sync" (ambiguous) | `isInviteHandler()` returns `== CALENDAR_SYNC_EMAIL`. Distinct from `CALENDAR_SYNC` (legacy Orchestrator) and `CALENDAR_INGESTER` (new ingester path). |
| **Resolution** | "status", "result" | The enum is literally `Resolution`; "status" collides with recording status. |
| **CallSchedulingCRUDOperation** (NEW/UPDATE/CANCEL) | "action", "operation type" | Exact type on every produced event. |
| **enhanced iCal id** (`enhanced_ical_id`) vs **iCal UID** (`ical_uid`) | "calendar id", "event id" | Two distinct keys: `scheduled_calls`/`updated_calendar_event` use `enhanced_ical_id`; `calendar_recurring_event` uses `ical_uid`. Don't conflate. |
| **MailboxProviderCode** (Office365 / Google Apps) vs **Identifier.Descriptor** (Zoom / Teams / …) | "provider" (ambiguous) | Two different provider concepts: calendar/mailbox provider vs conferencing provider. |

---

## Caveats (flagged during extraction)

- Core types (`Call`, `CallCreationMechanism`, `Resolution`, `CallInDetails`, `Identifier.Descriptor`,
  the produced events) are **defined in shared `honeyfy` modules**, not physically in this repo.
- There is **no dedicated `CallStatus` enum** here — scheduled/cancelled state is expressed via `SkipCode`
  + `Resolution` + boolean predicates (`Call.isStatusScheduled()`, `Call.isOptIn()`).
- `RECRUITING_CALENDAR_INGESTER` and `CALENDAR_SYNC` are `@Deprecated`/legacy in `CallCreationMechanism`.
- The repo `CLAUDE.md` cites some stale line numbers (e.g. `SchedulingCallService.java:85`) — trust this doc.

## See also
- [[00 - Overview]] — the mental model in prose
- [[02 - Entry Points (Inbound & Outbound)]] — every inbound/outbound point + the topic map
- [[01 - Services & Modules]] — per-module reference
- [[Acronyms]] — org-wide glossary
