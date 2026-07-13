---
title: "UC-B3 · Audit the Decision"
tags: [consent, use-case, capture, audit]
created: 2026-07-13
group: B - Capture
---

# UC-B3 · Audit the Decision

> [[04 - Use Cases|← Use Cases hub]] · Group **B — Capture** · prev → [[B2 - Skip Or Decline]]

Every accept/skip is written to the compliance audit trail. System-driven (consumer).

---

## What this is for

A defensible compliance record of who was asked and what they answered.

## What triggers it

`AuditMeetingConsentConsumer` consumes the `JumpPageInteractionEvent`.

---

## What fired it

`AuditMeetingConsentConsumer`, consuming from `audit-meeting-consent`.

---

## What the Consent module did

```
AuditMeetingConsentConsumer
  → AuditService#addJumpPageSession / #addJumpPageInteraction
  → writes recording_compliance.jump_page_session + jump_page_interaction
     (mirrored in data-capture by RecordingComplianceDao)
  → AuditService#countAnswers aggregates interaction counts
```

> Terminology: "compliance" (audit trail) = `recording_compliance`; "consent" (policy/decision) = `recording_consent_settings`.

---

## What happens downstream / what the user sees

The decision is durably recorded for compliance reporting and answer aggregation.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | `AuditMeetingConsentConsumer` |
| **Command / process** | `AuditService#addJumpPageSession` / `#addJumpPageInteraction` |
| **Event / topic** | consumed from `audit-meeting-consent` |
| **State / audit** | `recording_compliance.jump_page_session` / `jump_page_interaction` |

## Related

[[B1 - Accept Recording]] · [[B2 - Skip Or Decline]]
