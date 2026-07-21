---
title: Jump Page & Data Capture Profile (DCP)
tags: [consent, jump-page, dcp, data-capture-profile, recording-consent, reference]
created: 2026-07-20
aliases:
  - jump page
  - consent page
  - DCP
  - data capture profile
---

# Jump Page & Data Capture Profile (DCP)

> [[_dashboard|← Team Hub]] · [[03 - Ubiquitous Language]] · [[Use Cases/A - Solicit/A1 - Render Jump Page|UC-A1]]

> [!note] TL;DR
> The **jump page** is a Gong-hosted consent notice that sits between a calendar invite and the actual meeting room. An external participant (customer, prospect) clicks the link from their invite, sees a recording disclosure, and is redirected to Zoom/Teams/Webex only after they acknowledge it. The **Data Capture Profile (DCP)** is the company-level policy that controls whether the page appears and how it behaves.

---

## The experience from the outside participant's perspective

```
Calendar invite email
        │
        │   join link = Gong jump-page URL (not a direct Zoom/Teams link)
        ▼
https://<gong-domain>/consent/<companyName>/<profileKey>/<userKey>[/<meetingKey>]
        │
        ▼
  ┌─────────────────────────────────────────┐
  │  "This meeting is being recorded        │
  │   by Gong on behalf of <Company>.       │
  │                                         │
  │   [ Accept & Join ]  [ Decline ]        │
  └─────────────────────────────────────────┘
        │                         │
        ▼                         ▼
  Redirected to              Recording suppressed
  Zoom / Teams /             for this participant
  Webex meeting room         (opt-out path)
```

Every interaction — accept, decline, skip, skipped-reason — is written to `recording_compliance.jump_page_interaction`. See [[Storage & Schema Reference]] for the schema.

---

## Data Capture Profile (DCP)

**DCP** = the company's recording-consent policy. Key fields (`DcpJumpPageSettings`):

| Field                      | Meaning                                                               |
| -------------------------- | --------------------------------------------------------------------- |
| `profileKey`               | Short identifier that appears in every jump-page URL for this company |
| `isEnabled` / `isEnforced` | Whether the consent page is shown / required                          |
| `linkType`                 | `PMI` (static) or `DYNAMIC` (per-meeting) — see below                 |
| `recordingOptOut`          | What happens when a participant declines                              |
| `logoUrl`                  | Company branding shown on the consent page                            |
| `languages`                | Supported locales for the consent page text                           |
| `historicProfileKeys`      | Old keys preserved so existing calendar links don't break             |

A company can have multiple DCP profiles. The `profileKey` in the URL selects which one applies.

---

## Jump-page URL anatomy

```
/consent/<companyName>/<profileKey>/<userKey>            ← 2 path segments after profileKey = PMI
/consent/<companyName>/<profileKey>/<userKey>/<meetingKey>  ← 3 segments = dynamic / one-time
```

| Segment | Source | Notes |
|---|---|---|
| `profileKey` | `DcpJumpPageSettings.profileKey` | Identifies the DCP profile |
| `userKey` | Derived from rep's name via `JumpPageAdminService.getUserDefaultNameForUrl()` | Customisable; min/max length enforced (`URL_KEY_VALIDATION`) |
| `meetingKey` | Only for dynamic/one-time meetings | Absent on PMI links |

**2 segments** after profileKey = PMI / static page (`JumpPageUrlService.isPmiJumpPageUrl()`).  
**3 segments** = dynamic / one-time meeting (`JumpPageUrlService.isOnetimeJumpPageUrl()`).

---

## PMI vs Dynamic meetings

| | PMI (static) | Dynamic (one-time) |
|---|---|---|
| **URL** | Never changes between meetings | New URL per scheduled meeting |
| **Use case** | Rep always uses the same personal meeting room | Per-meeting consent page with its own settings |
| **Meeting state** | None | `OneTimeMeetingStatus`: `CREATED → SCHEDULED → DELETED` |
| **Managed by** | Set once at user onboarding | `JumpPageAdminService#scheduleMeeting` / `#updateOnetimeMeeting` |
| **UC** | [[Use Cases/A - Solicit/A1 - Render Jump Page\|UC-A1]] | [[Use Cases/D - Configure/D2 - Manage One-Time Meeting\|UC-D2]] |

---

## How the URL reaches the participant

The jump-page URL is **pre-generated**, not built on demand. Three triggers:

1. **User onboarded to DCP** — `JumpPageService` (implements `UserAddOnsBuilder`) fires on add.
2. **User settings change** — `JumpPageService` (implements `UserUpdateObserver`) fires on provider/status update.
3. **Bulk Redis refresh** — `PopulateDcpJumpPageRedisTask` (scheduled, runs on startup + periodically) populates Redis for all active companies.

The generated URL lives in **Redis** (`DcpJumpPageRedisService`) as the hot-path for page renders. When a participant loads the URL, `JumpPageController` looks up `DcpJumpPageUrlSettings` from Redis — no DB hit on the critical path.

---

## What fires when the participant answers

```
Participant clicks Accept
    → JumpPageController#acceptAnswer                     (MeetingFrontEnd)
    → publishes JumpPageInteractionEvent
          cluster: RECORDING_CONSENT  topic: audit-meeting-consent  key: companyId
    → RecordingSupervisorClient#restrictCallRecording     (outbound HTTP)
    → redirect to provider meeting URL (Zoom / Teams / Webex)

Participant clicks Decline / opts out
    → JumpPageController#skipAnswer
    → same Kafka event, denied_recording = true
    → recording suppressed for this participant
```

See [[Use Cases/B - Capture/B1 - Accept Recording|UC-B1]] and [[Use Cases/B - Capture/B2 - Skip Or Decline|UC-B2]] for the full flows.

---

## Kafka topics — jump page lifecycle

All topics use the **`RECORDING_CONSENT`** Kafka cluster unless noted.

### Produced by MeetingFrontEnd (participant interaction)

| Topic | Event type | Producer | Consumed by | Purpose |
|---|---|---|---|---|
| `audit-meeting-consent` | `JumpPageInteractionEvent` | `JumpPageController#publishInteractionEvent:765` | `AuditMeetingConsentConsumer` (RecordingConsentTasks) | Records every accept / skip / decline decision; drives the compliance audit trail |

### Consumed by RecordingConsentTasks (async processing)

| Topic | Cluster | Event type | Consumer | Purpose |
|---|---|---|---|---|
| `audit-meeting-consent` | `RECORDING_CONSENT` | `JumpPageInteractionEvent` | `AuditMeetingConsentConsumer:26` | Writes `jump_page_session` + `jump_page_interaction` rows |
| `audit-stop-recording` | `RECORDING_CONSENT` | `StopRecordingEvent` | `AuditStopRecordingConsumer:25` | Writes `stop_recording_audit` when recording is halted |
| `reset-consent-redis-for-company` | `RECORDING_CONSENT` | `ResetConsentRedisForCompanyEvent` | `ResetConsentRedisForCompanyConsumer:17` | Evicts a company's jump-page data from Redis (triggered by DCP settings change) |
| `calendar-updates-for-consent` | `RECORDING_CONSENT` | `CalendarUpdateEvent` | `CalendarUpdatesForConsentConsumer:24` | Keeps the `calendar_event` mirror current (drives which meetings need a jump page) |
| `call-scheduling-updated` | `CALL_SCHEDULER_V2` | `CallSchedulingUpdated` | `ConsentCallSchedulingUpdatedConsumer:26` (HF/ConsentProfile) | Reacts to a call being scheduled/cancelled — schedules the pre-call consent email |
| `check-and-fix-consent-page-redis` | `RECORDING_CONSENT` | — | `CheckAndFixConsentPageRedisConsumer` (HF/ConsentProfile) | Repairs stale Redis consent-page state |

### Produced by DcpChangeManager (DCP settings propagation)

When a DCP profile changes (e.g. company enables/disables consent, changes provider), `ChangeRequestLifecycle` fans changes out to all affected users via three topics:

| Topic | Cluster | Event type | Purpose |
|---|---|---|---|
| `batch-users-change-executor` | `DATA_CAPTURE` | `DcpChangeRequestEvent` | Fan-out one change request to all users in parallel |
| `single-user-change-executor` | `DATA_CAPTURE` | `DcpChangeRequestEvent` | Apply change to one user |
| `single-user-change-request-done` | `DATA_CAPTURE` | `DcpUserChangeRequestDoneEvent` | Signal that a single-user change completed |

After propagation, `ResetConsentRedisForCompanyConsumer` evicts the company's Redis cache so the next page render picks up the new DCP settings.

---

## Database tables — jump page & DCP

All tables live in the `recording_consent` Postgres database. See [[Storage & Schema Reference]] for the schema-level map; use `kb_table(action=schema)` for column-level detail.

### `recording_compliance` schema — audit / compliance

| Table | Written by | Columns of interest |
|---|---|---|
| `jump_page_session` | `RecordingComplianceDao#insertJumpPageSession` (RecordingConsentTasks) | One row per consent-page visit |
| `jump_page_interaction` | `RecordingComplianceDao#insertJumpPageInteraction:43` | `denied_recording`, `got_access`, `per_meeting_consent`, `skipped_consent_page`, `skipped_consent_reason` |
| `stop_recording_audit` | `RecordingComplianceDao#auditCallStoppingStatus:93` | Written when recording is stopped on decline |

Also cross-writes `public.call` (operational DB) via `RecordingComplianceDao#updateInteractionsCountInCall:84`.

### `recording_consent_settings` schema — per-user / per-company state

| Table | Written by | Purpose |
|---|---|---|
| `user_settings` | `UserSettingsDao#upsert` (RecordingConsentTasks) | Per-user default meeting provider |
| `appuser_consent_settings` | `DcpConsentSettingsDao#upsertAppUserConsentSettings` (HF/ConsentProfile) | Per-user consent preferences backing the DCP settings API |
| `calendar_event` | `ConsentMeetingUpdatesDao#upsertEventData` (HF/RecordingCompliance) | Calendar-event mirror — which meetings need a jump page; updated via `calendar-updates-for-consent` |

### `data_capture_profile` schema — DCP change requests (DcpChangeManager)

| What | Written by | Purpose |
|---|---|---|
| Change-request tables | `DcpChangeManagerDao` (DcpChangeManager) | Tracks the `ChangeRequestLifecycle` state machine (`DcpChangeRequestEvent`) as it propagates a DCP settings change across all users |

---

## Redis layout (hot path)

`DcpJumpPageRedisService` stores three kinds of data in the **`RECORDING_COMPLIANCE`** Redis logical DB (descriptor name: `CONSENT_REDIS`):

| Data | Content | Refreshed by |
|---|---|---|
| Per-user settings | Provider URI, consent settings (`RedisDcpJumpPageUserSettings`) | `PopulateDcpJumpPageRedisTask` (every 5 min) + `JumpPageService` on user change |
| Per-company DCP profile | DCP profile + company name (`RedisDcpJumpPageSettings`) | Same task + `ResetConsentRedisForCompanyConsumer` on settings change |
| One-time meeting settings | Per-meeting provider + `OneTimeMeetingStatus` (`JumpPageOnetimeMeetingSettings`) | `JumpPageAdminService#scheduleMeeting` / `#updateOnetimeMeeting` |

`TroubleshootingDcpJumpPageRedis` (32 endpoints, `RecordingConsentTasks`) is the admin surface for inspecting and repairing this Redis state.

---

## Audit trail

Every participant interaction is logged synchronously (via the `audit-meeting-consent` Kafka round-trip) into:

| Table | Schema | Captures |
|---|---|---|
| `jump_page_session` | `recording_compliance` | One row per consent-page visit |
| `jump_page_interaction` | `recording_compliance` | `denied_recording`, `got_access`, `per_meeting_consent`, `skipped_consent_page`, `skipped_consent_reason` |

Written by `AuditMeetingConsentConsumer` (RecordingConsentTasks) consuming `audit-meeting-consent`.

---

## Key classes at a glance

| Class | Repo / module | What it does |
|---|---|---|
| `JumpPageController` | `gong-data-capture / MeetingFrontEnd` | Serves the HTML consent page; handles accept/skip |
| `JumpPageUiService` | `gong-data-capture / MeetingFrontEnd` | Renders Thymeleaf templates |
| `DcpJumpPageRedisService` | `honeyfy / DataCaptureProfile` | Redis read/write for all jump-page state |
| `JumpPageUrlService` | `honeyfy / AppCommon` | URL construction, parsing, segment constants |
| `MultipleProviderJumpPageUrlService` | `honeyfy / ComplianceCommon` | Multi-provider URL building — generates one URL per provider with `?provider=<code>`; see [[Meeting Providers & Multi-Provider DCP]] |
| `JumpPageService` | `honeyfy / RecordingCompliance` | URL lifecycle hooks (`UserAddOnsBuilder`, `UserUpdateObserver`) |
| `JumpPageAdminService` | `honeyfy / RecordingCompliance` | Schedule/update/delete one-time meetings; URL key validation |
| `DcpJumpPageSettings` | `honeyfy / AppCommon` | Core DCP entity |
| `DcpJumpPageUrlSettings` | `honeyfy / DataCaptureProfile` | Assembled Redis DTO (company + profile + user + meeting) |
| `PopulateDcpJumpPageRedisTask` | `gong-data-capture / RecordingConsentTasks` | Scheduled bulk Redis refresh |
| `TroubleshootingDcpJumpPageRedis` | `gong-data-capture / RecordingConsentTasks` | Admin Redis diagnostics endpoint |

---

## See also

- [[Meeting Providers & Multi-Provider DCP]] — provider enum list, per-provider DCP settings (`DcpJumpPageSettingsProvider`), `?provider=` URL discriminator, user provider default
- [[03 - Ubiquitous Language]] — full domain glossary including URL-segment constants
- [[Use Cases/A - Solicit/A1 - Render Jump Page|UC-A1]] — use-case card for rendering the page
- [[Use Cases/B - Capture/B1 - Accept Recording|UC-B1]] · [[Use Cases/B - Capture/B2 - Skip Or Decline|UC-B2]] — what happens after the participant answers
- [[Use Cases/D - Configure/D2 - Manage One-Time Meeting|UC-D2]] — managing dynamic meetings
- [[Storage & Schema Reference]] — `jump_page_session` / `jump_page_interaction` table schema
- [[02 - Data Flow]] — complete Kafka topic map, all Kafka consumers, DB writes, and Redis producers for the full Consent subsystem
