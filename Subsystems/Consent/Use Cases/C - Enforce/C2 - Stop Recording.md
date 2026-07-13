---
title: "UC-C2 · Stop Recording"
tags: [consent, use-case, enforce, recorder, audit]
created: 2026-07-13
group: C - Enforce
---

# UC-C2 · Stop Recording

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Enforce** · prev → [[C1 - Restrict Recording|UC-C1]]

An in-progress recording is stopped and the stop is audited.

---

## What this is for

Honoring a mid-call withdrawal / stop signal — and keeping a compliance record that the
stop happened, when, and for which call. This is the "I changed my mind" / "stop now" path.

## What triggers it

The `audit-stop-recording` event fires (carrying a `StopRecordingEvent`). The actor is
another Gong service publishing that event, not a person clicking directly on this module.

---

## What the Consent module did

```
audit-stop-recording event (StopRecordingEvent)
        │
        ▼
AuditStopRecordingConsumer
        │
        ▼
AuditService#auditCallStoppingStatus
        │
        ├─▶ RecordingSupervisorClient#markRecordingStop   (recording stopped)
        │
        └─▶ recording_compliance.stop_recording_audit     (stop audited)
```

---

## What happens downstream / why it matters

The active recording is stopped on the recorder, and a compliance row is written to
`recording_compliance.stop_recording_audit`. That audit trail is what proves, after the
fact, that a stop signal was received and honored — critical for consent compliance.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | `audit-stop-recording` event |
| **Command / process** | `AuditService#auditCallStoppingStatus` → `RecordingSupervisorClient#markRecordingStop` |
| **Event / topic** | `StopRecordingEvent` / `audit-stop-recording` |
| **State / audit** | `recording_compliance.stop_recording_audit` |

## Related

[[C1 - Restrict Recording|UC-C1]]
