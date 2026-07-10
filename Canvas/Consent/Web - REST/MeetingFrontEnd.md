---
title: MeetingFrontEnd (jump page)
component_type: webapi-server
tags: [consent, web, rest, public, oncall]
---

# 🖥️ MeetingFrontEnd

> [[Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §1]] · Sentry: **consent**

**Public** consent-page web server (**GPE**, `/`). `JumpPageController` (`:85`) renders/answers the jump
page (`viewJumpPage:286`, `acceptAnswer:614`, `skipAnswer:653`); `ConsentEmailController` (`:30`) serves
the consent-email landing page. Publishes `audit-meeting-consent`; calls `RecordingSupervisorClient` to
restrict/stop recording.
