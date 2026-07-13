---
title: "UC-C4 · Cancel By Company And Provider"
tags: [call-scheduling, use-case, cancel, provider]
created: 2026-07-13
group: C - Cancel
resolution: CALL_PROVIDER_DISABLED_FOR_COMPANY
crud: CANCEL
---

# UC-C4 · Cancel By Company And Provider

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Cancel** · prev → [[C - Cancel/C3 - Cancel On Resolution Change|UC-C3]] · next → [[C - Cancel/C5 - Cancel Internal Meetings|UC-C5]]

An admin disables a conferencing provider for the whole tenant, cancelling every scheduled call on that provider.

---

## What the user wanted

*"We're no longer recording calls on this conferencing provider — cancel all of them."*

## What the user did

This is triggered by an admin changing a company-level provider setting, not by an individual call owner.

---

## What fired it

An admin setting disables a call provider for the company, invoking a bulk cancel over that provider's scheduled calls.

---

## What the Call Scheduler did

```
CancelCallService#cancelScheduledCalls
  → CallDataDao#cancelScheduledCallsByCallProvider
  → UPDATE public.call SET SkipCode + Resolution = CALL_PROVIDER_DISABLED_FOR_COMPANY
       (for all scheduled calls on the disabled provider)
  → produce call-scheduling-updated  (CRUD = CANCEL) per call
```

Note: there is NO CallStatus enum — cancel state is set via **SkipCode + Resolution**.

---

## What happens downstream

Recording infrastructure consumes the `CANCEL` events and stops the scheduled captures.

## What the user sees

Calls on the disabled provider are no longer recorded across the tenant.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Admin disables provider (company setting) |
| **Command** | `CancelCallService#cancelScheduledCalls` → `CallDataDao#cancelScheduledCallsByCallProvider` |
| **Resolution** | `CALL_PROVIDER_DISABLED_FOR_COMPANY` |
| **Event / CRUD** | `CallSchedulingUpdated` / `CANCEL` |

## Related

- [[C - Cancel/C3 - Cancel On Resolution Change|UC-C3]]
- [[C - Cancel/C5 - Cancel Internal Meetings|UC-C5]]
