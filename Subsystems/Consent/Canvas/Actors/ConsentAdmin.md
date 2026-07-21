---
title: Consent Admin (Actor)
component_type: actor
tags: [consent, actor, admin]
---

# 👤 Consent Admin

Company admin who configures the **Data Capture Profile (DCP)** — whether consent is required, which providers are covered, whether enforcement is on, opt-out behaviour, branding, and email settings. Changes propagate to all company users via `DcpChangeManager` (`ChangeRequestLifecycle` state machine).
