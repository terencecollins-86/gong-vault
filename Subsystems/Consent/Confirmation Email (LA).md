---
title: Consent — Confirmation Email (LA)
tags: [consent, recording-consent, confirmation-email, la, reference]
created: 2026-07-21
aliases:
  - confirmation email
  - LA email
  - consent confirmation email
  - assistant consent
---

# Confirmation Email (LA)

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · [[Use Cases/A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]] · [[Consent Email — Default Allow & Outcome Matrix]]

> [!note] TL;DR
> The **confirmation email** is a consent mechanism for calls ingested through the **Gong assistant** where the **call organiser is not a Gong org member** (the "LA" / Local Assistant case). Sent 24/48/72 hours before the call, it asks participants to permit recording. The landing page includes an option to **cancel the recording** — unlike the pre-call consent email where silence = no objection, the confirmation email is a more active-permission flow.

---

## What makes this different from the pre-call consent email

| | Pre-call consent email | Confirmation email (LA) |
|---|---|---|
| **When sent** | 10–20 minutes before the meeting | 24/48/72 hours before the meeting |
| **Trigger** | DCP settings enabled + call scheduled via Gong | Call ingested via the Gong assistant; organiser is NOT a Gong org member |
| **Purpose** | Recording notice (advance notice jurisdictions) | Permission request to record |
| **Landing page action** | Accept / Deny recording | Option to **cancel** the recording |
| **Silence = ?** | No action taken; call records normally | See DCP settings; more of an active-permission model |
| **Sender** | Gong on behalf of the company | Gong on behalf of the company |

---

## When it fires

The confirmation email is sent when **all** of these are true:

1. The call was **ingested via the Gong assistant** (not via a standard integration).
2. The **call organiser is not a member of the Gong org** (i.e. the meeting was organised by an external participant or a non-Gong-licensed user).
3. The timing window (24/48/72 hours before the call) is met.

---

## What the participant receives

The email:
- Informs the participant that the call will be recorded by Gong on behalf of the company.
- Contains a **landing page link** with an option to cancel the recording.

Unlike the standard pre-call consent email (where the recording notice is required and non-removable), this email is specifically a **permission request** — the participant is being asked, not just notified.

---

## Landing page outcome

| Participant action | Effect |
|---|---|
| **Does nothing / ignores** | Depends on DCP `isEnforced` setting — see [[Consent Email — Default Allow & Outcome Matrix]] for the full matrix |
| **Clicks to cancel the recording** | Recording is cancelled for this call |

---

## Admin configuration

The confirmation email shares admin controls with other consent email settings in the DCP consent profile:
- Subject, sender name, body, signature, legal footer, logo, and privacy-policy link are configurable.
- The **recording-notice section is required** and cannot be removed or edited.

---

## Relationship to other consent mechanisms

```
Call ingested via assistant (organiser not in Gong org)
    │
    ├─ 24/48/72h before: Confirmation email sent
    │       participant can cancel recording via landing page
    │
    └─ At call start: Audio prompt plays (if enabled)
            (consent page link may not be in the invite for LA calls)
```

For calls where the organiser IS a Gong org member, the standard pre-call consent email and/or consent page apply instead. See [[Jump Page & DCP]] and [[Use Cases/A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]].

---

## See also

- [[00 - Overview]] — the five consent mechanisms and where this fits
- [[Consent Email — Default Allow & Outcome Matrix]] — full outcome matrix for email non-response and denial
- [[Use Cases/A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]] — the standard pre-call consent email use case
- [[Use Cases/A - Solicit/A3 - Render Consent Email Landing Page|UC-A3]] — landing-page flow (shared with pre-call email)
- [[Jump Page & DCP]] — the DCP settings that govern `isEnforced` / `isEnabled`
- [[03 - Ubiquitous Language]] — domain vocabulary (`ConsentEmailResponse`, `MeetingStatus`)
