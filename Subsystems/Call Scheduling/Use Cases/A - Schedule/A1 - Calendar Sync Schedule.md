---
title: "UC-A1 · Schedule a Call from Calendar Sync"
tags: [call-scheduling, use-case, schedule, calendar-sync]
created: 2026-07-13
group: A - Schedule
mechanism: CALENDAR_INGESTER
resolution: NEW_CALL
crud: NEW
---

# UC-A1 · Schedule a Call from Calendar Sync

> [[04 - Use Cases|← Use Cases hub]] · Group **A — Schedule** · next → [[A2 - Opt-In Email Invite]]

The default, highest-volume flow: a user schedules a normal meeting in their calendar and Gong records it automatically.

---

## What the user wanted

*"I have a customer call on my calendar with a Zoom link — I want Gong to record it so I get the transcript and AI insights afterward, without doing anything extra."*

## What the user did

1. Opened **Google Calendar** (or Outlook) and created a meeting
2. Pasted a **Zoom URL** into the description
3. Invited guests and hit **Save**

> No Gong UI involved. The user never opens Gong for this to work.

---

## What fired the event

**gong-ingestion** (Calendar Ingestion) continuously syncs the user's calendar. On the save it:
1. Fetches the changed event
2. Sees a recordable conference URL
3. Confirms the owner is a Gong user with `should_record=true`
4. Produces a `CallSchedulingRequest` (`CALENDAR_EVENT`) onto **`call-scheduling-requests`**

Upstream detail: [[Subsystems/Call Scheduling/Canvas/Upstream/Calendar-Ingestion|Calendar Ingestion]].

---

## What the Call Scheduler did

```
CallSchedulingRequestsConsumer
  → Redis lock on (companyId, enhancedCalendarEventId)  — dedup
  → load owner AppUser
  → generalEventValidation chain:
      ✓ provider enabled  ✓ URL valid  ✓ should_record
      ✓ not blacklisted / internal / do-not-record
  → SchedulingCallService#addCallFromCalendarAndReport
      → INSERT public.call (status=SCHEDULED)
      → INSERT call_scheduler.scheduled_calls (keyed by enhanced_ical_id)
      → flag external_meeting_update_required=TRUE
      → queue pre-call email
  → produce call-scheduling-updated (CallSchedulingCalendarEventUpdated, NEW)
```

**Idempotency**: the `scheduled_calls` row keyed by `enhanced_ical_id` means re-delivery does not double-schedule.

---

## What happens downstream

- **Recording infrastructure** consumes `call-scheduling-updated` and enables cloud recording (Zoom API) or schedules a bot for `startTime` → [[Subsystems/Call Scheduling/Canvas/Downstream/Recording-Infrastructure|Recording Infrastructure]]
- **Pre-call email** (`FirstRecordedCallEmailType`) notifies the owner the call will be recorded
- **At meeting time** the recording is captured; afterward it flows to transcription + AI analysis

## What the user sees

| When | What |
|------|------|
| Before the meeting | "This call will be recorded" email |
| After the meeting | Recording, transcript, and AI analysis appear automatically in their Gong feed |

---

## Code map

| | |
|---|---|
| **Mechanism** | `CALENDAR_INGESTER` |
| **Command** | `SchedulingCallService#addCallFromCalendarAndReport` |
| **Resolution** | `NEW_CALL` |
| **Event / CRUD** | `CallSchedulingCalendarEventUpdated` / `NEW` |
| **Failure vocab (sample)** | `USER_NOT_MARKED_FOR_RECORDING`, `CALL_PROVIDER_DISABLED_FOR_COMPANY`, `INTERNAL_MEETING_RECORDING_DISABLED`, `CALL_BLACKLISTED`, `COMPLIANCE_ENFORCING` |

## Related

- [[07 - End-to-End User Flow]] — this exact flow, fully walked through
- [[06 - Local Dev Seed Data]] — seed the DB and fire this locally
- [[03 - Ubiquitous Language]] · [[02 - Entry Points (Inbound & Outbound)]]
