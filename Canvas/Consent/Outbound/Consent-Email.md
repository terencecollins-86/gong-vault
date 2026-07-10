---
title: Pre-call Consent Email (Mailgun)
component_type: outbound-email
tags: [consent, email, mailgun, outbound]
---

# ✉️ Pre-call Consent Email

> [[Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §9]]

Outbound consent email via Mailgun. Real send: `PreCallEmailService.sendEmail` (`:481`); enqueue:
`ConsentEmailSender.sendConsentEmail` (`HF/ConsentProfile/.../ConsentEmailSender.java:55`). Recipients land
on `ConsentEmailController`.
