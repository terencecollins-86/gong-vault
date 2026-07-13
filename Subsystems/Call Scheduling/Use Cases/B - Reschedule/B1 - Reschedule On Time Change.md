---
title: "UC-B1 · Reschedule When the Meeting Time Changes"
tags: [call-scheduling, use-case, reschedule, calendar-sync]
created: 2026-07-13
group: B - Reschedule
mechanism: CALENDAR_INGESTER
resolution: RESCHEDULED
crud: UPDATE
---

# UC-B1 · Reschedule When the Meeting Time Changes

> [[04 - Use Cases|← Use Cases hub]] · Group **B — Reschedule**

The user moves an already-scheduled meeting, and Gong keeps the recording aligned to the new time.

---

## What the user wanted

*"I pushed my customer call back an hour. I don't want to re-set anything in Gong — the recording should just follow the meeting."*

## What the user did

1. Opened the existing meeting in **Google Calendar / Outlook**
2. Changed the **start/end time** (or the conference URL)
3. Saved

> The call already exists in Gong (from [[A1 - Calendar Sync Schedule|UC-A1]]); this flow *moves* it, it doesn't create a new one.

---

## What fired the event

Calendar Ingestion detects the change and produces another `CallSchedulingRequest` (`CALENDAR_EVENT`) for the same `enhanced_ical_id`.

---

## What the Call Scheduler did

```
CallSchedulingRequestsConsumer
  → dedup guard: updated_calendar_event  (last-seen create/modified timestamps)
      · unchanged re-delivery → no-op (TOO_OLD_REQUEST)
  → existing scheduled call found for enhanced_ical_id
  → SchedulingCallService#rescheduleCallUpdateAndReport
      → UPDATE public.call (new start/end/url)
  → Resolution = RESCHEDULED   (or TOO_LATE_TO_RESCHEDULE if original start effectively passed)
  → produce call-scheduling-updated (CallSchedulingCalendarEventUpdated, UPDATE)
```

**Dedup:** `updated_calendar_event` (keyed by `enhanced_ical_id`) tracks last-seen timestamps so an unchanged re-delivery is a no-op.

---

## What happens downstream

Recording infrastructure consumes the `UPDATE` event and re-aligns the scheduled capture (bot re-scheduled / cloud recording window adjusted) to the new time.

## What the user sees

Nothing changes on their side — the recording simply happens at the new time. If it was moved too late (past the original start), recording may not re-arm (`TOO_LATE_TO_RESCHEDULE`).

---

## Code map

| | |
|---|---|
| **Mechanism** | `CALENDAR_INGESTER` |
| **Command** | `SchedulingCallService#rescheduleCallUpdateAndReport` |
| **Resolution** | `RESCHEDULED` / `TOO_LATE_TO_RESCHEDULE` |
| **Event / CRUD** | `CallSchedulingCalendarEventUpdated` / `UPDATE` |
| **Dedup** | `updated_calendar_event` (keyed by `enhanced_ical_id`) |

## Related

- [[A1 - Calendar Sync Schedule]] — created the call this flow moves
- [[E - Recurring/E1 - Schedule Recurring Occurrences|UC-E1]] — recurring occurrences reschedule differently
