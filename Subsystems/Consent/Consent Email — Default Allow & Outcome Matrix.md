---
title: Consent Email — Default Allow & Outcome Matrix
tags: [consent, recording-consent, email, dcp, policy, reference]
created: 2026-07-20
aliases:
  - consent email ignored
  - no response consent
  - default allow recording
  - consent email outcomes
---

# Consent Email — Default Allow & Outcome Matrix

> [[_dashboard|← Team Hub]] · [[Use Cases/A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]] · [[Jump Page & DCP]]

> [!note] TL;DR
> **If a participant ignores a consent email and never clicks the link, the call records normally.** The consent email is a notification, not a gate. Recording is only stopped when a participant actively clicks **Deny**. Silence = no objection. The real gate is the jump page (`isEnforced = true`), not the email.

---

## What happens when the email is ignored

When a participant never opens or clicks the consent email:

- Their `ConsentEmailResponse` stays `NO_RESPONSE` in the database indefinitely.
- **No deadline check runs at call start time.** There is no job that fires when the call begins to inspect email responses and block recording.
- `ConsentEmailInteractionService.handleInteraction()` only reacts to `ConsentEmailResponse.DENIED`. All other values — including `NO_RESPONSE` — cause an immediate return with no action.
- `ConsentEmailCallDetails.calculateMeetingStatus()` defaults to `MeetingStatus.RECORDING`. There is no "pending consent" or "consent unknown" status.

The call records.

---

## Why the system is designed this way

The consent email's job is to **inform** participants ahead of time — it satisfies legal notice requirements in jurisdictions where advance notice (not active consent) is sufficient. The active gate is the **jump page**: participants cannot join the meeting URL without going through it. The email is an alternative channel for companies that prefer to notify participants days before a call.

Only an explicit denial signals a clear objection. Silence is treated as no objection.

---

## Full outcome matrix

| What the participant does | `ConsentEmailResponse` | What happens to recording |
|---|---|---|
| **Never opens / ignores email** | `NO_RESPONSE` | **Records normally** — no action taken |
| **Opens email, clicks Accept** | `ACCEPTED` | Records normally |
| **Opens email, clicks Deny** | `DENIED` | `cancelScheduledCallByConsentEmail()` fires → `SkipCode.CANCEL_BY_COMPLIANCE_EMAIL` → not recorded |
| **Joins via jump page, clicks Accept** | n/a | Records normally → `MeetingStatus.RECORDING` |
| **Joins via jump page, clicks Decline** | n/a | `JumpPageController#skipAnswer` → Zoom API stop → `MeetingStatus.RECORDING_CANCELLED` |
| **Jump page `isEnforced = true`, meeting not using Gong URL** | n/a | Blocked at scheduling → `Resolution.COMPLIANCE_ENFORCING` / `SkipCode.COMPLIANCE_ENFORCING` — call never scheduled |
| **`ConsentEmailSettings.isEnabled = false`** | n/a | No email sent; recording proceeds on jump page settings alone |

---

## The `isEnforced` vs `isEnabled` distinction

Both fields live on `DcpJumpPageSettings` (not on `ConsentEmailSettings`). They control **jump page** behaviour, not email behaviour.

| Setting | Effect |
|---|---|
| `isEnabled = false` | Jump page feature entirely off. Jump page URL throws `JumpPageNotConfiguredException`. Emails are also typically not useful without a jump page. |
| `isEnabled = true`, `isEnforced = false` | Jump page shown. If a participant bypasses it (joins the raw Zoom link), recording still proceeds. A non-compliant-call warning email can be sent. |
| `isEnabled = true`, `isEnforced = true` | **Scheduling-level block.** `CheckCompliance.validate()` (in `gong-call-schedulers`) returns `Resolution.COMPLIANCE_ENFORCING` for meetings not using the Gong jump page URL. The call is never scheduled for recording. |

`isEnforced` is not triggered by email non-response — it fires at calendar-event processing time, not at call start time.

`ConsentEmailSettings` has only `isEnabled` (no `isEnforced`). Consent emails are optional notifications, not enforcement.

---

## What `DENIED` actually triggers

When a participant clicks Deny on the consent email landing page:

```
ConsentEmailController#answerConsentEmailPage (MeetingFrontEnd :8098)
  → produces ConsentEmailPageInteractionEvent on consent-email-page-interaction
    → ConsentEmailPageInteractionConsumer (RecordingConsentTasks)
      → ConsentEmailInteractionService.handleInteraction()
          response == DENIED?
            → callSchedulerClient.cancelScheduledCallByConsentEmail()
                → gong-call-schedulers cancels the scheduled call
                   SkipCode = CANCEL_BY_COMPLIANCE_EMAIL
```

This is the **only** code path from the consent email system that stops a recording.

---

## `SkippedReason` — what it covers (and doesn't)

`SkippedReason` is a **jump page** concept, not a consent email concept:

| Value | Meaning |
|---|---|
| `RECORDING_DENIED` | Participant clicked Deny on the jump page |
| `PAGE_NOT_CONFIGURED` | Jump page URL hit but `isEnabled = false` or meeting URL missing |
| `MEETING_TOO_OLD` | One-time meeting link older than 45 minutes with no call IDs |
| `FAILED_TO_CANCEL_RECORDING` | Audit value when blocking failed |

**"No email response" is not a `SkippedReason` value.** `ConsentEmailResponse.NO_RESPONSE` is stored silently in the DB and never acted upon.

---

## `JumpPageRecordingOptOut` — what it controls

Stored on `DcpJumpPageSettings.recordingOptOut`. Jump-page only, not email:

| Value | Effect |
|---|---|
| `EXPLICIT` | Jump page shows a "Deny" button. Participant can actively opt out. `blockMeetingInRecorder()` fires on deny. |
| `IMPLICIT` | No deny button. Participant implicitly consents by joining. Posting a deny answer returns HTTP 400. |

Not relevant to consent email non-response.

---

## See also

- [[Use Cases/A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]] — how the email is scheduled and sent
- [[Use Cases/A - Solicit/A3 - Render Consent Email Landing Page|UC-A3]] — what the participant sees when they do click
- [[Use Cases/B - Capture/B2 - Skip Or Decline|UC-B2]] — jump page decline flow (distinct from email decline)
- [[Jump Page & DCP]] — `isEnforced`, `isEnabled`, `JumpPageRecordingOptOut` in context
- [[03 - Ubiquitous Language]] — `MeetingStatus`, `SkippedReason`, `ConsentEmailResponse` definitions
- [[02 - Data Flow]] — `consent-email-page-interaction` consumer and `ConsentEmailInteractionService`
- [[Work/Architecture/Recording Architecture — How Gong Records Meetings]] — how recording is actually stopped when denial is received
