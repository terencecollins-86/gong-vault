---
title: ConsentEmailPageInteractionEvent
component_type: event
tags: [consent, event, kafka, email]
---

# 📨 ConsentEmailPageInteractionEvent

> Topic: **`consent-email-page-interaction`** · Cluster: `RECORDING_CONSENT`

Produced by `UiConsentEmailService` (MeetingFrontEnd) when a participant responds to the consent-email landing page. Consumed by `ConsentEmailPageInteractionConsumer` → `ConsentEmailInteractionService#handleInteraction`. If `DENIED`: calls `callSchedulerClient.cancelScheduledCallByConsentEmail` — the **only path from email denial to call cancellation**.
