---
title: "UC-E2 · Cancel a Recurring Series"
tags: [call-scheduling, use-case, recurring, cancel]
created: 2026-07-13
group: E - Recurring
mechanism: email / calendar-ingester (+ MailboxProviderCode)
resolution: (cancel + CancellationReason)
crud: CANCEL
---

# UC-E2 · Cancel a Recurring Series

> [[04 - Use Cases|← Use Cases hub]] · Group **E — Recurring** · prev → [[E1 - Schedule Recurring Occurrences]]

Cancelling a recurring meeting stops recording every future occurrence — and the mechanics differ between Google and Office because they encode series cancellation differently.

---

## What the user wanted

*"I ended our weekly sync. I don't want Gong recording any of the future occurrences anymore."*

## What the user did

1. Deleted / cancelled the **recurring series** in Google Calendar or Outlook

---

## What fired it

The cancellation arrives via calendar ingestion or email, and the engine branches on:
- `callCreationMechanism.isEmail()` vs `isFromCalendarIngester()`
- `MailboxProviderCode` — **Google vs Office** (they encode recurrence cancellation differently)

---

## What the Call Scheduler did

```
CancelCallService#cancelScheduledRecurringCall
  → branch by mechanism (email vs calendar-ingester)
  → branch by MailboxProviderCode:
      · Google → mark calendar_recurring_event.should_cancel_recurring_event
      · Office → CalendarRecurringEventsService#shouldCancelRecurringOfficeEvent
                 (owns the iCal↔recurringId map + "should cancel" cache)
  → persist a CancellationReason (CANCELLED_MAIN_EVENT, USER_NOT_ACTIVE, …)
  → produce call-scheduling-updated (CANCEL)
```

**Office quirk:** the Office path needs `CalendarRecurringEventsService` because Office does not carry the same recurrence-cancellation signal Google does — it maps iCal UID ↔ recurrence ID and caches the "should cancel" decision.

---

## What happens downstream

Recording infrastructure consumes the `CANCEL` events and stops all future captures for the series.

## What the user sees

Future occurrences of the meeting are no longer recorded.

---

## Code map

| | |
|---|---|
| **Command** | `CancelCallService#cancelScheduledRecurringCall` |
| **Google state** | `calendar_recurring_event.should_cancel_recurring_event` |
| **Office state** | `CalendarRecurringEventsService#shouldCancelRecurringOfficeEvent` + `calendar_cancel_office_events` |
| **Reason** | `CancellationReason` (`CANCELLED_MAIN_EVENT`, `USER_NOT_ACTIVE`, …) |
| **Event / CRUD** | `CallSchedulingUpdated` / `CANCEL` |

## Related

- [[E1 - Schedule Recurring Occurrences]] — the scheduling counterpart
- [[C - Cancel/C1 - Cancel By Owner|Group C]] — single-call cancels
