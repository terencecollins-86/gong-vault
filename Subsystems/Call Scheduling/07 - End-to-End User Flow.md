---
title: Call Scheduling — End-to-End User Flow
tags: [call-scheduling, explainer, onboarding, e2e, recording]
created: 2026-07-13
---

# 07 · End-to-End User Flow

> [[_dashboard|← Team Hub]] · [[06 - Local Dev Seed Data]] · [[02 - Entry Points (Inbound & Outbound)]]

What actually happens — from a calendar save to a recording in Gong — and which systems are responsible for each step.

---

## What the user did

**The user created a Google Calendar event with a Zoom link** — that's it. They:

1. Opened Google Calendar and created a new meeting
2. Added a Zoom URL in the description (e.g. `https://zoom.us/j/123456789`)
3. Invited external guests
4. Saved the event

> No interaction with Gong's UI at all. The user doesn't visit Gong, create anything in the app, or even know Gong is involved. The trigger is a calendar save in a third-party tool.

---

## What fired the Kafka event

The user's Google Calendar is continuously synced by **gong-ingestion** (Calendar Ingestion subsystem). When Google pushes a change notification:

1. gong-ingestion fetches the updated calendar event
2. Sees a Zoom URL — a recordable conference
3. Determines the calendar owner is a Gong user with `should_record=true`
4. Produces `CallSchedulingRequest` (`callSchedulingEventType=CALENDAR_EVENT`, `callCreationMechanism=CALENDAR_SYNC_EMAIL`) onto **`call-scheduling-requests`** Kafka topic

See [[Canvas/Upstream/Calendar-Ingestion]] for the gong-ingestion side.

---

## What gong-call-schedulers did

```
Kafka message consumed (CallSchedulingRequestsConsumer)
  → Redis distributed lock acquired — prevents duplicate processing for same meeting
  → User loaded from DB by userId (alice, company 9001)
  → Validation chain:
      ✓ Provider enabled (zoom/enabled=true in company_recorder_properties)
      ✓ URL valid (Zoom URL extracted from description)
      ✓ should_record=true
      ✓ Not blacklisted, not internal meeting, not do-not-record
  → Resolution = NEW_CALL:
      → INSERT public.call           (status=SCHEDULED)
      → INSERT call_scheduler.scheduled_calls
      → UPDATE public.call SET external_meeting_update_required=TRUE
      → Zoom upcoming meeting record upserted (maps callId → Zoom meetingId)
      → Pre-call email queued (FirstRecordedCallEmailType)
  → Produce → call-scheduling-updated  (CallSchedulingCalendarEventUpdated, op=NEW)
  → Produce → call-scheduling-history
  → Redis lock released
```

The `call-scheduling-updated` event is the **handoff point** — where scheduling ends and recording infrastructure begins.

---

## What happens downstream

### 1. Recording Infrastructure consumes `call-scheduling-updated`

The event carries `callId`, `companyId`, `callURL`, `startTime`, `endTime`, `CRUDOperation=NEW`. Recording infrastructure uses this to schedule the actual capture:

- **Zoom cloud recording** — the `external_meeting_update_required=TRUE` flag + the Zoom upcoming meeting record triggers a Zoom API call to enable cloud recording for that meeting
- **Gong bot (legacy)** — recording infrastructure schedules a bot to join at `startTime`

See [[Canvas/Downstream/Recording-Infrastructure]] and [[Canvas/Outbound Topics/CALL-SCHEDULING-UPDATED]].

### 2. Pre-call email

The `FirstRecordedCallEmailType` queue entry sends the meeting owner a "this call will be recorded" notification before the meeting starts.

### 3. At meeting time

The recording bot (or Zoom cloud recording) joins at `startTime`. Raw audio/video is captured.

### 4. After the meeting ends

The call flows into the telephony/ingestion pipeline: audio → transcription → AI analysis → the recording appears in the user's Gong workspace with transcript, scorecards, and AI insights.

---

## What the user sees in Gong

| When | What |
|------|------|
| Shortly after saving the calendar event | Nothing — Gong is working in the background |
| Before the meeting | "This call will be recorded" notification email |
| After the meeting ends | Recording, transcript, and AI analysis appear automatically in their call feed |

The user never visits Gong to make any of this happen.

---

## Flow diagram

```
User saves Google Calendar event with Zoom link
        │
        ▼
gong-ingestion (Calendar Ingestion)
  · Google push notification → fetch event
  · Produce → call-scheduling-requests
        │
        ▼
gong-call-schedulers (CallScheduler)
  · Validate: provider enabled, URL valid, user should_record
  · INSERT public.call (status=SCHEDULED)
  · INSERT call_scheduler.scheduled_calls
  · Produce → call-scheduling-updated (op=NEW)
        │
        ▼
Recording Infrastructure
  · Enable cloud recording via Zoom API  ──→  (at meeting time) Bot joins / cloud records
        │
        ▼
gong-ingestion (Telephony/Processing)
  · Audio → transcription → AI analysis
        │
        ▼
Gong UI — recording appears in user's call feed
```

---

## Key data written per event

| Table | What's written |
|-------|----------------|
| `public.call` | New row: `status=SCHEDULED`, `callprovidercode=zoom`, `callurl`, `owner_appuser_id`, `emailinvitecode` (the dedup key), `external_meeting_update_required=TRUE` |
| `call_scheduler.scheduled_calls` | `enhanced_ical_id` + `company_id` — dedup/idempotency record |
| `zoom_integration.zoom_upcoming_meetings` (operational) | Maps `callId` → Zoom `meetingId` — used by recording infra to enable cloud recording |
| `public.invitee` | Non-owner attendees linked to the call |

---

## Related docs

- [[06 - Local Dev Seed Data]] — how to seed the DB and fire this flow locally
- [[02 - Entry Points (Inbound & Outbound)]] — full inbound/outbound map
- [[Canvas/Upstream/Calendar-Ingestion]] — the gong-ingestion upstream producer
- [[Canvas/Downstream/Recording-Infrastructure]] — what consumes `call-scheduling-updated`
- [[Canvas/Outbound Topics/CALL-SCHEDULING-UPDATED]] — the handoff topic schema
