---
title: "UC-A2 · Send a Pre-Call Consent Email"
tags: [consent, use-case, solicit, email]
created: 2026-07-13
group: A - Solicit
---

# UC-A2 · Send a Pre-Call Consent Email

> [[04 - Use Cases|← Use Cases hub]] · Group **A — Solicit** · prev → [[A1 - Render Jump Page]] · next → [[A3 - Render Consent Email Landing Page]]

Ahead of a call, Gong emails participants asking them to consent before the meeting.

---

## What this is for

Give participants a chance to consent before the call rather than at join time. System-driven (a scheduled task), but the beneficiary is the participant.

## What triggers it

`RecordingConsentTasks` — the `ConsentEmailsTasks#consentEmailScheduledTask` (every 1m).

---

## What fired it

`ConsentEmailsTasks#consentEmailScheduledTask`, polling every minute.

---

## What the Consent module did

```
PreCallEmailService#sendEmail (real Mailgun send)
  or enqueue via ConsentEmailSender#sendConsentEmail
  → produces ConsentEmailPageData keyed by emailId
  → email carries isEmailIdObsolete (obsoletion is its lifecycle)
  → answering later emits ConsentEmailAuditEvent on consent-email-audit
```

---

## What happens downstream / what the user sees

The recipient can open and answer the email → [[A3 - Render Consent Email Landing Page]].

---

## Code map

| | |
|---|---|
| **Actor / trigger** | `ConsentEmailsTasks#consentEmailScheduledTask` (1m) |
| **Command / process** | `PreCallEmailService#sendEmail` / `ConsentEmailSender#sendConsentEmail` |
| **Event / topic** | `ConsentEmailAuditEvent` / `consent-email-audit` |
| **State / audit** | `ConsentEmailPageData` (`emailId`) |

## Related

[[A3 - Render Consent Email Landing Page]] · [[A1 - Render Jump Page]]
