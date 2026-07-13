---
title: "UC-E1 · Schedule Upcoming Occurrences of a Recurring Meeting"
tags: [call-scheduling, use-case, recurring, schedule]
created: 2026-07-13
group: E - Recurring
mechanism: background task
resolution: NEW_CALL_RECURRING
crud: NEW
---

# UC-E1 · Schedule Upcoming Occurrences of a Recurring Meeting

> [[04 - Use Cases|← Use Cases hub]] · Group **E — Recurring** · next → [[E2 - Cancel Recurring Series]]

Recurring meetings are handled by a background engine, not a single event — Gong walks the series forward and schedules each upcoming occurrence.

> Recurring is its own sub-area because it's keyed **differently** — by `ical_uid` in `calendar_recurring_event`, *not* `enhanced_ical_id` — and it branches on `MailboxProviderCode` (Google vs Office).

---

## What the user wanted

*"I have a weekly team sync as a recurring calendar event. I want every occurrence recorded, automatically, going forward."*

## What the user did

1. Created a **recurring meeting** in Google Calendar / Outlook with a conference link
2. Left it running — no per-occurrence action

---

## What fired it

The **`recurring-events-call-scheduler`** scheduled task (runs every ~2h), not a per-event Kafka message. It scans the recurring window and expands the series.

---

## What the Call Scheduler did

```
recurring-events-call-scheduler (scheduled task)
  → RecurringEventService#processRecurringEventBatches
      → for each RecurringEventSetDto (initialEvent + eventExceptions):
          → expand to individual occurrences
          → schedule each occurrence in the window
  → Resolution = NEW_CALL_RECURRING (per occurrence)
```

- **Model:** `RecurringEventSetDto` = `initialEvent` + `eventExceptions`, expanded to occurrences
- **Change classification:** `RecurringEventChange` (`CancelledMainEvent`, `UpdatedEventOccurrence`, …)

---

## What happens downstream

Each scheduled occurrence produces its own `call-scheduling-updated` and is handed to recording infrastructure like any single call.

## What the user sees

Every instance of their weekly meeting shows up recorded in Gong — they set it up once.

---

## Code map

| | |
|---|---|
| **Trigger** | `recurring-events-call-scheduler` scheduled task (~2h) |
| **Command** | `RecurringEventService#processRecurringEventBatches` |
| **Keyed by** | `ical_uid` in `calendar_recurring_event` |
| **Model** | `RecurringEventSetDto`, `RecurringEventChange` |
| **Resolution** | `NEW_CALL_RECURRING` |

## Related

- [[E2 - Cancel Recurring Series]] — cancelling the whole series
- [[B - Reschedule/B1 - Reschedule On Time Change|UC-B1]] — single-occurrence reschedule
