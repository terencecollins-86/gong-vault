---
title: JumpPageInteractionEvent
component_type: event
tags: [consent, event, kafka, jump-page]
---

# 📨 JumpPageInteractionEvent

> Topic: **`audit-meeting-consent`** · Cluster: `RECORDING_CONSENT` · Key: `companyId`

Produced by `JumpPageController#publishInteractionEvent` (MeetingFrontEnd) when a participant accepts or skips the consent page. Carries `denied_recording`, `got_access`, `per_meeting_consent`, `skipped_consent_page`, `skipped_consent_reason`. Consumed by `AuditMeetingConsentConsumer` → writes `recording_compliance.jump_page_session` + `jump_page_interaction`.
