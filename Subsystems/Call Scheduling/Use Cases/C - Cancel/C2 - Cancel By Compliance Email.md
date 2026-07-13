---
title: "UC-CX · Cancel By Compliance Email"
tags: [call-scheduling, use-case, cancel, compliance]
created: 2026-07-13
group: C - Cancel
resolution: CANCEL_BY_COMPLIANCE_EMAIL
crud: CANCEL
---

# UC-CX · Cancel By Compliance Email

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Cancel** · prev → [[C - Cancel/C1 - Cancel By Owner|UC-C1]] · next → [[C - Cancel/C3 - Cancel On Resolution Change|UC-C3]]

A participant withdraws recording consent by replying to a compliance/consent email, cancelling the scheduled recording.

---

## What the user wanted

*"I'm replying to this consent email to say I do not want this call recorded."*

## What the user did

1. Receives a compliance/consent email about an upcoming recorded call.
2. Replies to withdraw consent for the recording.

---

## What fired it

The compliance/consent email reply is processed and invokes the compliance-email cancel path.

---

## What the Call Scheduler did

```
CancelCallService#cancelByComplianceEmailScheduledCall
  → UPDATE public.call SET SkipCode + Resolution = CANCEL_BY_COMPLIANCE_EMAIL
  → produce call-scheduling-updated  (CRUD = CANCEL)
```

Note: there is NO CallStatus enum — cancel state is set via **SkipCode + Resolution**.

---

## What happens downstream

Recording infrastructure consumes the `CANCEL` event and stops the scheduled capture.

## What the user sees

The call is no longer recorded, honoring the withdrawn consent.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Participant / compliance actor via consent email reply |
| **Command** | `CancelCallService#cancelByComplianceEmailScheduledCall` |
| **Resolution** | `CANCEL_BY_COMPLIANCE_EMAIL` |
| **Event / CRUD** | `CallSchedulingUpdated` / `CANCEL` |

## Related

- [[C - Cancel/C1 - Cancel By Owner|UC-C1]]
- [[C - Cancel/C3 - Cancel On Resolution Change|UC-C3]]
