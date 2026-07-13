---
title: "UC-C6 · Cancel Blacklisted Calls"
tags: [call-scheduling, use-case, cancel, blacklist]
created: 2026-07-13
group: C - Cancel
resolution: CALL_BLACKLISTED
crud: CANCEL
---

# UC-C6 · Cancel Blacklisted Calls

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Cancel** · prev → [[C - Cancel/C5 - Cancel Internal Meetings|UC-C5]]

A call matches the company blacklist (title / email / domain phrase) and is aborted before recording.

---

## What the user wanted

*"Never record calls that match our blacklist — abort them automatically."*

## What the user did

This is triggered by admin blacklist configuration plus a cancel run, not by an individual call owner.

---

## What fired it

A call matches a company blacklist phrase (title, email, or domain), and a cancel run over blacklisted calls is invoked.

---

## What the Call Scheduler did

```
CancelBlacklistedCallsController#cancelBlacklistedCalls
  → UPDATE public.call SET status = 'ABORTED',
                            capture_status = 'SKIPPED',
                            capture_skip_code = 'CALL_BLACKLISTED',
                            Resolution = CALL_BLACKLISTED
       (for calls matching the blacklist)
  → produce call-scheduling-updated  (CRUD = CANCEL) per call
```

Note: there is NO CallStatus enum for the general cancel path — cancel state is set via **SkipCode + Resolution**. This blacklist path additionally stamps `status='ABORTED'` and `capture_status='SKIPPED'` on the row.

---

## What happens downstream

Recording infrastructure consumes the `CANCEL` events and stops the scheduled captures.

## What the user sees

Blacklisted calls are never recorded; they show as aborted / skipped.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Admin blacklist config + cancel run |
| **Command** | `CancelBlacklistedCallsController#cancelBlacklistedCalls` |
| **Resolution** | `CALL_BLACKLISTED` (`status='ABORTED'`, `capture_status='SKIPPED'`, `capture_skip_code='CALL_BLACKLISTED'`) |
| **Event / CRUD** | `CallSchedulingUpdated` / `CANCEL` |

## Related

- [[C - Cancel/C5 - Cancel Internal Meetings|UC-C5]]
