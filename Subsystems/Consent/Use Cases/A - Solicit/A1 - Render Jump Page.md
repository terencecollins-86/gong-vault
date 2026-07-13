---
title: "UC-A1 · Render the Jump Page to a Participant"
tags: [consent, use-case, solicit, jump-page]
created: 2026-07-13
group: A - Solicit
---

# UC-A1 · Render the Jump Page to a Participant

> [[04 - Use Cases|← Use Cases hub]] · Group **A — Solicit** · next → [[A2 - Send Pre-Call Consent Email]]

A meeting participant sees whether/how the meeting is being recorded and is asked to consent.

---

## What the user wanted

*"I just joined a meeting — is this being recorded? Do I consent?"*

## What the user did

1. Joined a meeting.
2. The conferencing join flow routed them to Gong's jump page (a.k.a. consent page).

---

## What fired it

`MeetingFrontEnd` serves `JumpPageController#viewJumpPage` against the company's `DcpJumpPageSettings`, resolved from the `profileKey/userKey[/meetingKey]` URL.

---

## What the Consent module did

```
JumpPageUrlService builds the URL (profileKey/userKey[/meetingKey])
  → 2 segments = PMI / static page, 3 = dynamic / one-time meeting
  → in-flight state modelled by ConsentPageRequestData
      (aggregating ConsentPageRequestResult)
```

---

## What happens downstream / what the user sees

The participant sees the consent page and can accept (→ [[B - Capture/B1 - Accept Recording|UC-B1]]) or skip (→ [[B - Capture/B2 - Skip Or Decline|UC-B2]]).

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Meeting participant |
| **Command / process** | `JumpPageController#viewJumpPage` |
| **Event / topic** | — (HTTP) |
| **State / audit** | serves `DcpJumpPageSettings` |

Failure vocab: `AuthorizationFailureType` (`CALENDAR_EMAIL_UNDEFINED`, `EMPTY_TOKEN`, `INVALID_TOKEN`).

## Related

[[A2 - Send Pre-Call Consent Email]] · [[B - Capture/B1 - Accept Recording|UC-B1]] · [[B - Capture/B2 - Skip Or Decline|UC-B2]]
