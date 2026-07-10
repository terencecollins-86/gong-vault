---
title: Mailgun (email invites)
component_type: upstream-producer
tags: [call-scheduling, upstream, email, mailgun]
---

# ✉️ Mailgun email invites

> [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]]

Calendar invites arriving **out-of-band** as email (not via calendar sync) are POSTed by Mailgun to the
webhook receiver. Signature-validated by `MailGunSignatureValidator`; MIME body persisted to S3.
Flows: calendar-sync / opt-in / coordinator (+ tenant + EU variants).
