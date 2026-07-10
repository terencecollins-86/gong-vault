---
title: PostgreSQL (recording_consent)
component_type: datastore
tags: [consent, datastore, postgres]
---

# 🐘 PostgreSQL — `recording_consent`

> [[Subsystems/Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[Storage & Schema Reference]] · [[02 - Data Flow|Data Flow §7]]

Owned DB, three schemas: **`recording_consent_email`** (consent emails, audit, obfuscation),
**`recording_consent_settings`** (appuser/user settings, calendar_event), **`recording_compliance`**
(jump_page_session/interaction, stop_recording audit). Also writes `public.call` (operational).
