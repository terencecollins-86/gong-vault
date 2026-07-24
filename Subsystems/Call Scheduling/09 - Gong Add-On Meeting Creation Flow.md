---
title: Call Scheduling — Gong Add-On Meeting Creation Flow
tags: [call-scheduling, google-meet, zoom, jump-page, consent-url, add-on, e2e, meeting-creation]
created: 2026-07-24
---

# 09 · Gong Add-On Meeting Creation Flow

> [[_dashboard|← Team Hub]] · [[07 - End-to-End User Flow]] · [[../Consent/Jump Page & DCP]]

> [!note] TL;DR
> When a user clicks "Add Gong meeting" in the Gong Google/Outlook add-on, Gong **synchronously** creates a provider meeting room (Google Meet or Zoom), wraps the URL in a `join.gong.io` consent URL, and returns it — **before** the invite is sent. The calendar ingester later picks up the sent invite and triggers call scheduling. The consent URL is resolved at click-through time via Redis.

---

## How this differs from the direct-link flow

| | [[07 - End-to-End User Flow\|07 — Direct Zoom link]] | This doc — Gong add-on flow |
|---|---|---|
| **Meeting room created by** | User (in Zoom/Google Meet directly) | Gong (via add-on at invite-compose time) |
| **URL in calendar invite** | Direct provider URL (`zoom.us/j/…`) | Gong consent URL (`join.gong.io/…`) |
| **Consent page shown** | No | Yes (or bypassed if already consented) |
| **Dedup key** | `emailinvitecode` (iCalUID) | `gongMeetingKey` in jump-page URL + `callId` |

---

## Phase 1 — Add-on click (synchronous, before invite is sent)

```
User clicks "Add Gong meeting" in Google/Outlook add-on
        │
        ▼
OutlookAddInController  GET /outlook-add-in/create-meeting-async
        │
        ▼
JumpPageAdminService.scheduleMeeting(appUser, OUTLOOK_ADD_IN, provider)
        │
        ├─ DcpJumpPageSettings loaded (company DCP policy)
        ├─ Provider chosen (Google Meet or Zoom)
        └─ isOneTimeMeeting = true  (dynamic link mode)
                │
                ▼
        scheduleOnetimeMeeting()
                │
                ▼
        createOnetimeMeetingAndUpdateRedis()
                │
                ├─ gongMeetingKey = IDGenerator.nextSecuredId()
                │
                ├─ GoogleMeetService.createMeeting()         ← calls Google Calendar API
                │     └─ creates private event with conferencing
                │     └─ returns meet.google.com/xxx-yyy-zzz
                │   — OR —
                │   ZoomService.createReoccurringMeetingWithoutTime()  ← calls Zoom API
                │     └─ returns zoom.us/j/…
                │
                ├─ Provider URL + gongMeetingKey → DB (onetime_meeting_jump_page)
                └─ Provider URL + settings      → Redis (JumpPageOnetimeMeetingSettings)
                │
                ▼
        JumpPageUrlService.onetimeMeetingUrl()
                │
                └─ returns https://join.gong.io/{profileKey}/{userKey}/{gongMeetingKey}
                │
                ▼
User pastes join.gong.io URL into the Google Calendar invite — provider URL is NEVER exposed
```

**Key fact**: the `meet.google.com` or `zoom.us` URL is stored server-side only. Participants receive only the `join.gong.io` URL.

---

## Phase 2 — User sends the invite

```
User sends calendar invite (join.gong.io URL in conferencing/location field)
        │
        ▼
Google Calendar push notification → gong-ingestion (Calendar Ingestion)
        │
        ├─ CalendarMeetingsProcessor  →  calendar-meeting-upsert-requests
        │       └─ MeetingUpsertRequestsConsumer
        │               └─ MeetingIndexerService  →  Elasticsearch  →  meetings-indexed
        │
        └─ CallSchedulingRequestProducer  →  call-scheduling-requests
               (or call-scheduling-low-priority-requests if meeting is far in future)
```

The calendar ingester does **not** know about the Gong meeting at this point. Its job is to index the event and fire call scheduling — the `join.gong.io` URL is just a URL in the event body.

---

## Phase 3 — Call scheduler processes the event

```
CallSchedulingRequestsConsumer  consumes call-scheduling-requests
        │
        ├─ Redis distributed lock per (companyId + calendarEventId)
        │
        ├─ CallInDetailsService.scanEventForKnownCallInDetails()
        │     └─ scans Location, AdditionalMeetingUrls, Description
        │     └─ detects join.gong.io by domain suffix GONG_CONSENT_DOMAIN_SUFFIX
        │
        ├─ Validation chain (provider enabled, should_record, not blacklisted…)
        │
        ├─ CallBuilder — INSERT public.call  (status=SCHEDULED)  ← canonical call record
        │
        └─ isOnetimeJumpPageUrl(callInDetails.callURL) == true
                │
                ▼
        JumpPageAdminService.connectCallToOnetimeMeetingJumpPage()
                │
                ├─ Extracts gongMeetingKey from URL path
                ├─ Looks up onetime_meeting_jump_page row (created in Phase 1)
                ├─ Sets callId on that row
                └─ dcpJumpPageRedisService.reloadOneTimeMeetingSettings()
```

This is where Phase 1 and Phase 3 converge: the pre-created `onetime_meeting_jump_page` record gets its `callId` stamped, completing the link between the meeting room and the scheduled call.

---

## Phase 4 — Participant clicks join.gong.io

```
Participant clicks join.gong.io/{profileKey}/{userKey}/{gongMeetingKey}
        │
        ▼
JumpPageController (MeetingFrontEnd / gong-data-capture)
        │
        ├─ Redis hot-path lookup: DcpJumpPageRedisService
        │     └─ returns JumpPageOnetimeMeetingSettings (provider URL, consent settings)
        │
        ├─ Consent page rendered  (or bypassed if already consented)
        │
        ├─ Participant accepts → JumpPageInteractionEvent → audit-meeting-consent topic
        │
        └─ Redirect to meet.google.com/xxx-yyy-zzz  (or zoom.us/j/…)
```

See [[../Consent/Jump Page & DCP]] for the full consent interaction flow.

---

## Full timeline

| Time | Event | System |
|---|---|---|
| T₀ | User clicks "Add Gong meeting" | Add-on → `OutlookAddInController` |
| T₀ + ~500ms | Google Meet / Zoom room created | `GoogleMeetService` / `ZoomService` |
| T₀ + ~500ms | `onetime_meeting_jump_page` row inserted; Redis populated | `JumpPageAdminService` |
| T₀ + ~500ms | `join.gong.io` URL returned to user | `JumpPageUrlService` |
| T₁ | User sends invite | Google Calendar |
| T₁ + seconds | Google push notification → ingestion | Calendar Ingestion |
| T₁ + seconds | `calendar-meeting-upsert-requests` produced | `CalendarMeetingsProcessor` |
| T₁ + seconds | Meeting indexed in Elasticsearch | `MeetingIndexerService` |
| T₁ + seconds | `call-scheduling-requests` produced | `CallSchedulingRequestProducer` |
| T₁ + seconds | `public.call` row created (status=SCHEDULED) | `CallBuilder` |
| T₁ + seconds | `onetime_meeting_jump_page.callId` stamped | `JumpPageAdminService.connectCallToOnetimeMeetingJumpPage` |
| T₂ | Participant clicks join link | `JumpPageController` |
| T₂ | Consent page served from Redis | `DcpJumpPageRedisService` |
| T₂ | Participant redirected to provider room | `JumpPageController` |
| T_meeting | Recording starts | Recording Infrastructure |

---

## Database writes summary

| Table | Schema / DB | Written at | Written by |
|---|---|---|---|
| `onetime_meeting_jump_page` | `recording_consent_settings` / recording_consent | Phase 1 | `JumpPageAdminService.createOnetimeMeetingAndUpdateRedis` |
| `public.call` | `public` / operational | Phase 3 | `CallBuilder` |
| `call_scheduler.scheduled_calls` | `call_scheduler` / operational | Phase 3 | `ScheduledCallsDao` |
| `onetime_meeting_jump_page.call_id` | `recording_consent_settings` / recording_consent | Phase 3 | `JumpPageAdminService.connectCallToOnetimeMeetingJumpPage` |
| `jump_page_session` / `jump_page_interaction` | `recording_compliance` / recording_consent | Phase 4 | `AuditMeetingConsentConsumer` |

---

## Key classes

| Class | Repo / module | Role |
|---|---|---|
| `OutlookAddInController` | `gong-frontend / WebFrontEnd` | Add-on HTTP endpoint |
| `JumpPageAdminService` | `honeyfy / RecordingCompliance` | Orchestrates meeting creation + URL wrapping |
| `GoogleMeetService` | `honeyfy / GoogleMeetIntegration` | Creates Google Meet room via Calendar API |
| `ZoomService` | `honeyfy / ZoomIntegration` | Creates Zoom room via Zoom API |
| `JumpPageUrlService` | `honeyfy / AppCommon` | Builds/parses `join.gong.io` URLs |
| `CallInDetailsService` | `gong-call-schedulers / CallSchedulingCommon` | Scans event fields for known URLs incl. `join.gong.io` |
| `CallBuilder` | `gong-call-schedulers / CallScheduler` | Creates `public.call`; calls `connectCallToOnetimeMeetingJumpPage` |
| `JumpPageController` | `gong-data-capture / MeetingFrontEnd` | Serves consent page; redirects to provider |
| `DcpJumpPageRedisService` | `honeyfy / DataCaptureProfile` | Redis hot-path for consent page data |

---

## See also

- [[07 - End-to-End User Flow]] — the simpler direct-link flow (no add-on, no consent URL)
- [[../Consent/Jump Page & DCP]] — jump-page URL anatomy, DCP settings, Redis layout, audit trail
- [[../Consent/Meeting Providers & Multi-Provider DCP]] — provider selection logic
- [[02 - Entry Points (Inbound & Outbound)]] — all inbound entrypoints for call scheduling
- [[08 - Data Access & Storage]] — DB schemas for `public.call`, `scheduled_calls`
