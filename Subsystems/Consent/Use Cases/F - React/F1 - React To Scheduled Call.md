---
title: "UC-F1 · React to a Scheduled / Cancelled Call"
tags: [consent, use-case, react, call-scheduling]
created: 2026-07-13
group: F - React
---

# UC-F1 · React to a Scheduled / Cancelled Call

> [[04 - Use Cases|← Use Cases hub]] · Group **F — React** · next → [[F2 - React To Calendar Update]]

When Call Scheduling schedules or cancels a call, Consent schedules or cancels the matching consent email.

---

## What this is for

Keeping consent emails in sync with the actual scheduled calls. There is no direct end-user action here — Consent reacts to another subsystem so that a scheduled call always has its pre-call consent email lined up, and a cancelled call never sends a stray one.

## What triggers it

`CallSchedulingUpdated` on `call-scheduling-updated` (from the Call Scheduling subsystem).

---

## What the Consent module did

```
CallSchedulingUpdated on call-scheduling-updated
  → ConsentCallSchedulingUpdatedConsumer
  → DcpConsentEmailSchedulingService#handleEvent
       → schedules or cancels the consent email
```

---

## What happens downstream / why it matters

A scheduled call gets its pre-call consent email queued (see UC-A2); a cancelled call has that email cancelled. This keeps outbound consent communication aligned with reality and avoids emailing participants about calls that will not happen.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | `CallSchedulingUpdated` / `call-scheduling-updated` |
| **Command / process** | `DcpConsentEmailSchedulingService#handleEvent` |
| **Event / topic** | `call-scheduling-updated` |
| **State / audit** | Schedule / cancel consent email |

## Related

[[Subsystems/Call Scheduling/Use Cases/F - Operational/F4 - Hand Off To Recording|Call Scheduling UC-F4]] (producer side) · [[A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]]
