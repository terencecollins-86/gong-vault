---
title: "UC-A2 · Schedule from an Opt-In Email Invite"
tags: [call-scheduling, use-case, schedule, opt-in, email]
created: 2026-07-13
group: A - Schedule
mechanism: OPT_IN_EMAIL
resolution: NEW_CALL
crud: NEW
---

# UC-A2 · Schedule from an Opt-In Email Invite

> [[04 - Use Cases|← Use Cases hub]] · Group **A — Schedule** · prev → [[A1 - Calendar Sync Schedule]] · next → [[A3 - Coordinator Invite-Handler]]

The consent-first flow: someone (often **not** a Gong user) explicitly asks Gong to record a meeting by email.

---

## What the user wanted

*"I'm not a Gong customer, but I want this specific meeting recorded — I'll forward the invite to Gong's recording address to opt in."*

## What the user did

1. Received (or created) a meeting invite with a conference link
2. **Forwarded / replied** to the Gong opt-in recording address
3. Waited for Gong's confirmation email

> This is the only creational flow driven by a human emailing Gong directly, rather than a calendar sync.

---

## What fired the event

The email lands at **InviteHandlerWebhooksServer** via a Mailgun webhook:
1. `IncomingMailgunController` receives `POST /incoming-email/opt-in-invite/mime`
2. `MailGunSignatureValidator` verifies the webhook, MIME body persisted to S3
3. Produces a `CallSchedulingRequest` (`EMAIL_EVENT`, mechanism `OPT_IN_EMAIL`) onto **`call-scheduling-requests`**

Upstream detail: [[Subsystems/Call Scheduling/Canvas/Upstream/Mailgun-Email|Mailgun Email]].

---

## What the Call Scheduler did

```
CallSchedulingRequestsConsumer  (EMAIL_EVENT branch)
  → optInEventValidation chain  (its own validators, wrapped by ConditionalValidation)
  → addCallFromCalendarAndReport
      → INSERT public.call (status=SCHEDULED)
      → INSERT call_scheduler.scheduled_calls
  → Resolution = NEW_CALL
  → OptInEmailResponseSender sends the opt-in reply
      (Onetime_Successful, or Request_To_Record_By_Non_Gong_User)
  → produce call-scheduling-updated (CallSchedulingUpdated, NEW)
```

**Why it's a distinct flow:** opt-in has its own validation chain *and* a reply-email side effect that calendar-sync does not.

---

## What happens downstream

- **Confirmation email** back to the requester (opt-in reply)
- **Recording infrastructure** consumes `call-scheduling-updated` and arranges capture
- After the meeting: transcription + AI analysis, same as any recorded call

## What the user sees

| When | What |
|------|------|
| Shortly after emailing | Opt-in confirmation reply from Gong |
| After the meeting | Recording available (in the Gong workspace of the recording org) |

---

## Code map

| | |
|---|---|
| **Mechanism** | `OPT_IN_EMAIL` (`CallCreationMechanism.isOptIn()`) |
| **Ingress** | `IncomingMailgunController` `/incoming-email/opt-in-invite/mime` |
| **Validation** | `optInEventValidation` |
| **Resolution** | `NEW_CALL` |
| **Event / CRUD** | `CallSchedulingUpdated` / `NEW` |
| **Reply variants** | `Onetime_Successful`, `Request_To_Record_By_Non_Gong_User` |

## Related

- [[A1 - Calendar Sync Schedule]] — the non-consent counterpart
- [[03 - Ubiquitous Language]] · [[02 - Entry Points (Inbound & Outbound)]]
