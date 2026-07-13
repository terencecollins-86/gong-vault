---
title: "UC-C3 · Cancel On Resolution Change"
tags: [call-scheduling, use-case, cancel, resolution]
created: 2026-07-13
group: C - Cancel
resolution: COMPLIANCE_ENFORCING / USER_NOT_MARKED_FOR_RECORDING
crud: CANCEL
---

# UC-C3 · Cancel On Resolution Change

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Cancel** · prev → [[C - Cancel/C2 - Cancel By Compliance Email|UC-C2]] · next → [[C - Cancel/C4 - Cancel By Company And Provider|UC-C4]]

The calendar/consent decision flips against recording, so an already-scheduled call is cancelled automatically.

---

## What the user wanted

*"Something about this call changed and it should no longer be recorded — Gong should catch that."*

## What the user did

This is triggered by a system re-evaluation of the recording resolution, not a direct end-user click.

---

## What fired it

A background re-computation of the call's recording resolution detects the decision now goes against recording (e.g. compliance now enforcing, or the user is no longer marked for recording).

---

## What the Call Scheduler did

```
SchedulingCallService#cancelExistingCallDueToResolutionChange
  → UPDATE public.call SET SkipCode + Resolution
        = COMPLIANCE_ENFORCING | USER_NOT_MARKED_FOR_RECORDING
  → produce call-scheduling-updated  (CRUD = CANCEL)
```

Note: there is NO CallStatus enum — cancel state is set via **SkipCode + Resolution**.

---

## What happens downstream

Recording infrastructure consumes the `CANCEL` event and stops the scheduled capture.

## What the user sees

The call quietly drops off the recording schedule to reflect the new compliance/recording decision.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | System resolution re-evaluation (background) |
| **Command** | `SchedulingCallService#cancelExistingCallDueToResolutionChange` |
| **Resolution** | `COMPLIANCE_ENFORCING` / `USER_NOT_MARKED_FOR_RECORDING` |
| **Event / CRUD** | `CallSchedulingUpdated` / `CANCEL` |

## Related

- [[C - Cancel/C2 - Cancel By Compliance Email|UC-C2]]
- [[C - Cancel/C4 - Cancel By Company And Provider|UC-C4]]
