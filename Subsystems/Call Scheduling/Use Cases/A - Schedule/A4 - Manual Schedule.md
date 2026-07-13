---
title: "UC-A4 · Schedule a Call Manually (UI / API)"
tags: [call-scheduling, use-case, schedule, manual, api]
created: 2026-07-13
group: A - Schedule
mechanism: MANUAL
resolution: NEW_CALL
crud: NEW
---

# UC-A4 · Schedule a Call Manually (UI / API)

> [[04 - Use Cases|← Use Cases hub]] · Group **A — Schedule** · prev → [[A3 - Coordinator Invite-Handler]]

The direct path: a Gong user or internal service schedules a recording explicitly, bypassing calendar and email ingestion entirely.

---

## What the user wanted

*"I want to tell Gong directly to record this meeting — I have the details, just schedule it."*

## What the user did

1. Used a **Gong UI action** (or an internal service called the API) to schedule a call
2. Provided the meeting details directly (URL, time, owner)

---

## What fired it

A synchronous REST call — no Kafka ingress:
- `ScheduledCallsActionsController#scheduleNewCallManually` (implements `CallSchedulerApi`, contract in `gong-clients`)
- Request body: `ManualSchedulingCallDetails`

---

## What the Call Scheduler did

```
ScheduledCallsActionsController#scheduleNewCallManually
  → ManualSchedulingCallService#scheduleNewCallManually  (mechanism = MANUAL)
      → INSERT public.call (status=SCHEDULED)
      → createOrUpdateMeetingProviderUpcomingMeeting
      → flag external_meeting_update_required=TRUE
  → Resolution = NEW_CALL
  → produce call-scheduling-updated (ManualCallEventUpdated, NEW)
```

**Distinct event subtype:** manual scheduling emits `ManualCallEventUpdated` (not the calendar/opt-in subtypes), so downstream can tell it apart.

---

## What happens downstream

Same handoff as every creational flow: `call-scheduling-updated` → recording infrastructure → capture → transcription + AI.

## What the user sees

Immediate confirmation from the API/UI action, then the recording appears in their feed after the meeting.

---

## Code map

| | |
|---|---|
| **Mechanism** | `MANUAL` (bypasses calendar/email ingress) |
| **Ingress** | `ScheduledCallsActionsController#scheduleNewCallManually` (REST) |
| **Command** | `ManualSchedulingCallService#scheduleNewCallManually` |
| **Contract** | `ManualSchedulingCallDetails` (`gong-clients`) |
| **Resolution** | `NEW_CALL` |
| **Event / CRUD** | `ManualCallEventUpdated` / `NEW` |

## Related

- [[A1 - Calendar Sync Schedule]] · [[06 - Local Dev Seed Data]] (clean synchronous REST path — good to run locally)
- [[02 - Entry Points (Inbound & Outbound)]]
