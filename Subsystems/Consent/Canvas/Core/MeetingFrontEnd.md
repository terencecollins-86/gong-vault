---
title: MeetingFrontEnd
component_type: service
tags: [consent, service, jump-page, public]
---

# 🖥️ MeetingFrontEnd

> [[_dashboard|← Consent Hub]] · [[01 - Services & Modules|Services]] · Port **8098** · Public

Serves the **jump page** and **consent-email landing page** to participants. `JumpPageController` (GET renders, POST captures accept/skip). `ConsentEmailController` handles email-linked landings. Reads `DcpJumpPageUrlSettings` from Redis — no DB hit on the critical path. Produces `audit-meeting-consent` on accept/skip. Calls `RecordingSupervisorClient#restrictCallRecording` synchronously.
