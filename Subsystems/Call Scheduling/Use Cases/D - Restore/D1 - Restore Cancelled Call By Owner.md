---
title: "UC-D1 · Restore a Cancelled Call by Owner"
tags: [call-scheduling, use-case, restore, owner]
created: 2026-07-13
group: D - Restore
mechanism: MANUAL
resolution: RESTORED_BY_OWNER
crud: UPDATE
---

# UC-D1 · Restore a Cancelled Call by Owner

> [[04 - Use Cases|← Use Cases hub]] · Group **D — Restore**

The undo path: a user who cancelled a recording changes their mind and brings it back. The exact inverse of [[C - Cancel/C1 - Cancel By Owner|UC-C1]].

---

## What the user wanted

*"I cancelled the recording on this call by mistake — I want it recorded after all."*

## What the user did

1. Found the cancelled call in the **Gong UI**
2. Clicked **restore recording**

---

## What fired it

A synchronous REST call:
- `ScheduledCallsActionsController#restoreCancelledCallByOwner`
- Recurring variant: `#restoreCancelledRecurringCallByOwner` (restores the whole series)

---

## What the Call Scheduler did

```
ScheduledCallsActionsController#restoreCancelledCallByOwner
  → RestoreCancelledCallService#restoreCancelledCallByOwner
      → reactivate the Call aggregate (clear cancel state)
      → flag external_meeting_update_required=TRUE
  → Resolution = RESTORED_BY_OWNER
  → produce call-scheduling-updated (UPDATE)
```

Reuses the same `Call` aggregate that UC-C1 deactivated — restore is C1 in reverse.

---

## What happens downstream

Recording infrastructure consumes the `UPDATE` event and re-arms the capture that the earlier cancel had stopped.

## What the user sees

The call flips back to "will be recorded"; after the meeting the recording appears as normal.

---

## Code map

| | |
|---|---|
| **Ingress** | `ScheduledCallsActionsController#restoreCancelledCallByOwner` (REST) |
| **Command** | `RestoreCancelledCallService#restoreCancelledCallByOwner` |
| **Recurring variant** | `#restoreCancelledRecurringCallByOwner` |
| **Resolution** | `RESTORED_BY_OWNER` |
| **Event / CRUD** | `CallSchedulingUpdated` / `UPDATE` |

## Related

- [[C - Cancel/C1 - Cancel By Owner|UC-C1]] — the cancel this reverses
