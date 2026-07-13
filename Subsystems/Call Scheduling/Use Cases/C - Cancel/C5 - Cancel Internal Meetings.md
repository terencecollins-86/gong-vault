---
title: "UC-CX · Cancel Internal Meetings"
tags: [call-scheduling, use-case, cancel, internal-meetings]
created: 2026-07-13
group: C - Cancel
resolution: INTERNAL_MEETING_RECORDING_DISABLED
crud: CANCEL
---

# UC-CX · Cancel Internal Meetings

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Cancel** · prev → [[C - Cancel/C4 - Cancel By Company And Provider|UC-C4]] · next → [[C - Cancel/C6 - Cancel Blacklisted Calls|UC-C6]]

An admin turns off internal-meeting recording, cancelling scheduled recordings of internal meetings.

---

## What the user wanted

*"Stop recording our internal meetings — only keep recording external calls."*

## What the user did

This is triggered by an admin toggling the internal-meeting recording setting (also reachable via a troubleshooting entry point), not by an individual call owner.

---

## What fired it

An admin setting disables internal-meeting recording, invoking a cancel over scheduled internal-meeting calls.

---

## What the Call Scheduler did

```
CancelCallService#cancelScheduledInternalMeetingsCallsRecordings
  → UPDATE public.call SET SkipCode + Resolution = INTERNAL_MEETING_RECORDING_DISABLED
       (for scheduled internal-meeting calls)
  → produce call-scheduling-updated  (CRUD = CANCEL) per call
```

Note: there is NO CallStatus enum — cancel state is set via **SkipCode + Resolution**.

---

## What happens downstream

Recording infrastructure consumes the `CANCEL` events and stops the scheduled captures.

## What the user sees

Internal meetings are no longer recorded; external calls are unaffected.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Admin disables internal-meeting recording (setting / troubleshooting entry point) |
| **Command** | `CancelCallService#cancelScheduledInternalMeetingsCallsRecordings` |
| **Resolution** | `INTERNAL_MEETING_RECORDING_DISABLED` |
| **Event / CRUD** | `CallSchedulingUpdated` / `CANCEL` |

## Related

- [[C - Cancel/C4 - Cancel By Company And Provider|UC-C4]]
- [[C - Cancel/C6 - Cancel Blacklisted Calls|UC-C6]]
