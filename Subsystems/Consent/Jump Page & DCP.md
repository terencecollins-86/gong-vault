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

| Field | Meaning |
|---|---|
| `profileKey` | Short identifier that appears in every jump-page URL for this company |
| `isEnabled` / `isEnforced` | Whether the consent page is shown / required |
| `linkType` | `PMI` (static) or `DYNAMIC` (per-meeting) — see below |
| `recordingOptOut` | What happens when a participant declines |
| `logoUrl` | Company branding shown on the consent page |
| `languages` | Supported locales for the consent page text |
| `historicProfileKeys` | Old keys preserved so existing calendar links don't break |

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
    → JumpPageController#acceptAnswer
    → publishes JumpPageInteractionEvent on audit-meeting-consent
    → RecordingSupervisorClient signals recording allowed
    → redirect to provider meeting URL (Zoom / Teams / Webex)

Participant clicks Decline / opts out
    → JumpPageController#skipAnswer
    → same audit event, denied_recording = true
    → recording suppressed for this participant
```

See [[Use Cases/B - Capture/B1 - Accept Recording|UC-B1]] and [[Use Cases/B - Capture/B2 - Skip Or Decline|UC-B2]] for the full flows.

---

## Redis layout (hot path)

`DcpJumpPageRedisService` stores three kinds of data in the `RECORDING_COMPLIANCE` Redis logical DB:

| Data | Key shape | Content |
|---|---|---|
| Per-user settings | user key → `RedisDcpJumpPageUserSettings` | Provider URI, consent settings |
| Per-company DCP profile | company → `RedisDcpJumpPageSettings` | DCP profile + company name |
| One-time meeting settings | meeting key → `JumpPageOnetimeMeetingSettings` | Per-meeting provider + state |

`TroubleshootingDcpJumpPageRedis` is an admin REST endpoint (`RecordingConsentTasks`) for inspecting this Redis state in non-prod environments.

---

## Audit trail

Every participant interaction is logged in two tables (`recording_compliance` schema):

| Table | Captures |
|---|---|
| `jump_page_session` | One row per consent-page visit |
| `jump_page_interaction` | `denied_recording`, `got_access`, `per_meeting_consent`, `skipped_consent_page`, `skipped_consent_reason` |

Written by `AuditService` (honeyfy `RecordingCompliance`) via `AuditMeetingConsentConsumer` consuming the `audit-meeting-consent` Kafka topic.

---

## Key classes at a glance

| Class | Repo / module | What it does |
|---|---|---|
| `JumpPageController` | `gong-data-capture / MeetingFrontEnd` | Serves the HTML consent page; handles accept/skip |
| `JumpPageUiService` | `gong-data-capture / MeetingFrontEnd` | Renders Thymeleaf templates |
| `DcpJumpPageRedisService` | `honeyfy / DataCaptureProfile` | Redis read/write for all jump-page state |
| `JumpPageUrlService` | `honeyfy / AppCommon` | URL construction, parsing, segment constants |
| `MultipleProviderJumpPageUrlService` | `honeyfy / ComplianceCommon` | Multi-provider URL building |
| `JumpPageService` | `honeyfy / RecordingCompliance` | URL lifecycle hooks (`UserAddOnsBuilder`, `UserUpdateObserver`) |
| `JumpPageAdminService` | `honeyfy / RecordingCompliance` | Schedule/update/delete one-time meetings; URL key validation |
| `DcpJumpPageSettings` | `honeyfy / AppCommon` | Core DCP entity |
| `DcpJumpPageUrlSettings` | `honeyfy / DataCaptureProfile` | Assembled Redis DTO (company + profile + user + meeting) |
| `PopulateDcpJumpPageRedisTask` | `gong-data-capture / RecordingConsentTasks` | Scheduled bulk Redis refresh |
| `TroubleshootingDcpJumpPageRedis` | `gong-data-capture / RecordingConsentTasks` | Admin Redis diagnostics endpoint |

---

## See also

- [[03 - Ubiquitous Language]] — full domain glossary including URL-segment constants
- [[Use Cases/A - Solicit/A1 - Render Jump Page|UC-A1]] — use-case card for rendering the page
- [[Use Cases/B - Capture/B1 - Accept Recording|UC-B1]] · [[Use Cases/B - Capture/B2 - Skip Or Decline|UC-B2]] — what happens after the participant answers
- [[Use Cases/D - Configure/D2 - Manage One-Time Meeting|UC-D2]] — managing dynamic meetings
- [[Storage & Schema Reference]] — `jump_page_session` / `jump_page_interaction` table schema
- [[02 - Data Flow]] — Kafka topic map including `audit-meeting-consent`
