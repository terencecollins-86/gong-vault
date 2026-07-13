---
title: "UC-A3 · Render the Consent-Email Landing Page"
tags: [consent, use-case, solicit, email]
created: 2026-07-13
group: A - Solicit
---

# UC-A3 · Render the Consent-Email Landing Page

> [[04 - Use Cases|← Use Cases hub]] · Group **A — Solicit** · prev → [[A2 - Send Pre-Call Consent Email]]

A recipient who opened the consent email lands on a page to accept or decline.

---

## What the user wanted

*"I got Gong's email about an upcoming call — I want to answer whether I consent."*

## What the user did

1. Opened the consent email.
2. Clicked through to the landing page.
3. Answered.

---

## What fired it

`MeetingFrontEnd` serves `ConsentEmailController#getConsentEmailPage` (`{CONSENT_EMAIL_URL}/{obfuscatedCompanyId}/{emailId}`).

---

## What the Consent module did

```
per-call subject = ConsentEmailCall / ConsentEmailCallDetails
  → derives a MeetingStatus
POST answer body = UiConsentEmailResponse (answerConsentEmailPage)
  → produces ConsentEmailPageInteractionEvent
  → consumed by ConsentEmailPageInteractionConsumer
     (email-channel equivalent of a jump-page answer — rejoins Group B)
```

---

## What happens downstream / what the user sees

The answer is captured and audited on the email channel, mirroring a jump-page decision (→ [[B - Capture/B3 - Audit The Decision|UC-B3]]).

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Email recipient |
| **Command / process** | `ConsentEmailController#getConsentEmailPage` / `#answerConsentEmailPage` |
| **Event / topic** | `ConsentEmailPageInteractionEvent` / `consent-email-page-interaction` |
| **State / audit** | `ConsentEmailCallDetails` → `MeetingStatus` |

## Related

[[A2 - Send Pre-Call Consent Email]] · [[B - Capture/B3 - Audit The Decision|UC-B3]]
