---
title: "UC-E2 · Run a Concrete Change Action"
tags: [consent, use-case, propagate, actions]
created: 2026-07-13
group: E - Propagate
---

# UC-E2 · Run a Concrete Change Action

> [[04 - Use Cases|← Use Cases hub]] · Group **E — Propagate** · prev → [[E1 - Orchestrate Change Request]]

Each change request executes concrete actions against affected calls/users.

---

## What this is for

Applying the actual side effects of a DCP change per user. UC-E1 decides *who* is affected; this use case does the real work — cancelling calls, changing email settings, syncing meetings, and backfilling consent emails.

## What triggers it

The change-request lifecycle (UC-E1) dispatches each action.

---

## What the Consent module did

```
ChangeRequestLifecycle dispatches an action:
  ├─ CancelNonCompliantCallsAction
  ├─ ConsentEmailSettingsChangeAction
  ├─ SyncMeetingPmiAction
  └─ ConsentEmailBackFillAction
        → produces ScheduleEventDTO
        → recording-consent-time-based-events
        → TimeBasedEventsScheduler (RecordingConsentTasks)   [backfill bridge]
```

---

## What happens downstream / why it matters

The backfill bridge is the notable path: `ConsentEmailBackFillAction` does not send emails directly — it publishes time-based events that the `TimeBasedEventsScheduler` framework in `RecordingConsentTasks` picks up, so backfilled emails flow through the same scheduling machinery as normal pre-call emails.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Change-request lifecycle (UC-E1) |
| **Command / process** | `CancelNonCompliantCallsAction` / `ConsentEmailSettingsChangeAction` / `SyncMeetingPmiAction` / `ConsentEmailBackFillAction` |
| **Event / topic** | `ScheduleEventDTO` / `recording-consent-time-based-events` |
| **State / audit** | Per-action |

## Related

[[E1 - Orchestrate Change Request]]
