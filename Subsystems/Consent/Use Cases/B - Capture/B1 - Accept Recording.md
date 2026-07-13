---
title: "UC-B1 · Accept Recording"
tags: [consent, use-case, capture, accept]
created: 2026-07-13
group: B - Capture
---

# UC-B1 · Accept Recording

> [[04 - Use Cases|← Use Cases hub]] · Group **B — Capture** · next → [[B2 - Skip Or Decline]]

A participant consents; recording is allowed and the decision is audited.

---

## What the user wanted

*"Yes, I'm fine being recorded — let the meeting record."*

## What the user did

1. Clicked Accept on the jump page.

---

## What fired it

`JumpPageController#acceptAnswer`.

---

## What the Consent module did

```
JumpPageController#acceptAnswer captures the decision
  → publishes JumpPageInteractionEvent on audit-meeting-consent (keyed by companyId)
  → calls RecordingSupervisorClient#restrictCallRecording to allow recording
  → consumed by AuditMeetingConsentConsumer
  → resolves toward MeetingStatus.RECORDING
```

---

## What happens downstream / what the user sees

Recording proceeds; the decision is audited (→ [[B3 - Audit The Decision]]); the recorder is gated (→ [[C - Enforce/C1 - Restrict Recording|UC-C1]]).

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Participant |
| **Command / process** | `JumpPageController#acceptAnswer` |
| **Event / topic** | `JumpPageInteractionEvent` / `audit-meeting-consent` |
| **State / audit** | `MeetingStatus.RECORDING` |

## Related

[[B2 - Skip Or Decline]] · [[B3 - Audit The Decision]] · [[C - Enforce/C1 - Restrict Recording|UC-C1]]
