---
title: "UC-CX · Cancel By Owner"
tags: [call-scheduling, use-case, cancel, owner]
created: 2026-07-13
group: C - Cancel
resolution: CANCEL_BY_OWNER
crud: CANCEL
---

# UC-CX · Cancel By Owner

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Cancel** · next → [[C - Cancel/C2 - Cancel By Compliance Email|UC-C2]]

The owner of a scheduled call cancels its recording directly from the Gong UI.

---

## What the user wanted

*"I don't want Gong to record this particular call that I own — cancel it."*

## What the user did

1. Opens the scheduled call in the Gong UI.
2. Clicks the option to stop/cancel Gong recording for that call.

---

## What fired it

A REST request from the Gong UI, invoking the owner-driven cancel path.

---

## What the Call Scheduler did

```
CancelCallService#cancelByOwnerScheduledCall
  → UPDATE public.call SET SkipCode = CANCELED_BY_OWNER,
                            Resolution = CANCEL_BY_OWNER
  → produce call-scheduling-updated  (CRUD = CANCEL)
```

Note: there is NO CallStatus enum — cancel state is set via **SkipCode + Resolution**.

---

## What happens downstream

Recording infrastructure consumes the `CANCEL` event and stops the scheduled capture.

## What the user sees

The call is no longer scheduled to be recorded; Gong will not join or capture it.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Call owner via Gong UI (REST) |
| **Command** | `CancelCallService#cancelByOwnerScheduledCall` |
| **Resolution** | `CANCEL_BY_OWNER` (+ `SkipCode.CANCELED_BY_OWNER`) |
| **Event / CRUD** | `CallSchedulingUpdated` / `CANCEL` |

## Related

- [[D - Restore/D1 - Restore Cancelled Call By Owner|UC-D1]] — the inverse (owner restores a cancelled call)
- [[C - Cancel/C2 - Cancel By Compliance Email|UC-C2]]
