---
title: "UC-C1 · Restrict Recording on Decision"
tags: [consent, use-case, enforce, recorder]
created: 2026-07-13
group: C - Enforce
---

# UC-C1 · Restrict Recording on Decision

> [[04 - Use Cases|← Use Cases hub]] · Group **C — Enforce** · next → [[C2 - Stop Recording|UC-C2]]

The participant's accept/skip decision is enforced on the actual recorder.

---

## What this is for

This is the boundary where consent ends and recording begins. It makes the recorder
obey the consent decision a participant made — so that "accept" lets the recorder run
and "skip / decline" holds it back.

## What triggers it

A participant accepts or skips recording (see [[B - Capture/B1 - Accept Recording|UC-B1]] /
[[B - Capture/B2 - Skip Or Decline|UC-B2]]). That decision is what drives the recorder call.

---

## What the Consent module did

```
participant decision (UC-B1 / UC-B2)
        │
        ▼
RecordingSupervisorClient#restrictCallRecording
        │
        ▼
recorder starts  ──or──  recorder is restricted (per consent)
```

---

## What happens downstream / why it matters

The recorder either begins capturing the call or is held back, in line with the
recorded consent decision. This is the enforcement seam — if it is wrong, a call is
recorded without consent (or a consented call is not captured).

> [!warning] Honest wiring caveat
> The consent → recorder link had **no direct caller** inside the four consent packages.
> The wiring is event-mediated (via `StopRecordingEvent` / `audit-stop-recording`, see
> [[C2 - Stop Recording|UC-C2]]) or lives outside those roots. Treat
> `RecordingSupervisorClient` as the **seam**, not a tight coupling.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | participant decision ([[B - Capture/B1 - Accept Recording|UC-B1]] / [[B - Capture/B2 - Skip Or Decline|UC-B2]]) |
| **Command / process** | `RecordingSupervisorClient#restrictCallRecording` |
| **Event / topic** | (direct client call) |
| **State / audit** | recorder starts / restricts |

## Related

[[B - Capture/B1 - Accept Recording|UC-B1]] · [[B - Capture/B2 - Skip Or Decline|UC-B2]] · [[C2 - Stop Recording|UC-C2]]
