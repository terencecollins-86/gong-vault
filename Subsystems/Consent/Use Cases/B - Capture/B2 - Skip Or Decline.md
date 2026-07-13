---
title: "UC-B2 · Skip / Decline Recording"
tags: [consent, use-case, capture, decline]
created: 2026-07-13
group: B - Capture
---

# UC-B2 · Skip / Decline Recording

> [[04 - Use Cases|← Use Cases hub]] · Group **B — Capture** · prev → [[B1 - Accept Recording]] · next → [[B3 - Audit The Decision]]

A participant declines; recording is cancelled and the decision is audited.

---

## What the user wanted

*"No, I don't consent to being recorded."*

## What the user did

1. Clicked Skip/Decline on the jump page.

---

## What fired it

`JumpPageController#skipAnswer` (`.../skip-answer` on both dynamic 3-segment and PMI 2-segment paths).

---

## What the Consent module did

```
JumpPageController#skipAnswer records the skip
  → publishes the same JumpPageInteractionEvent
  → drives recording toward MeetingStatus.RECORDING_CANCELLED via the recorder
```

---

## What happens downstream / what the user sees

Recording is cancelled; the decision is audited (→ [[B3 - Audit The Decision]]) and enforcement stops the recorder (→ [[C - Enforce/C2 - Stop Recording|UC-C2]]).

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Participant |
| **Command / process** | `JumpPageController#skipAnswer` |
| **Event / topic** | `JumpPageInteractionEvent` / `audit-meeting-consent` |
| **State / audit** | `MeetingStatus.RECORDING_CANCELLED` |

## Related

[[B1 - Accept Recording]] · [[C - Enforce/C2 - Stop Recording|UC-C2]]
