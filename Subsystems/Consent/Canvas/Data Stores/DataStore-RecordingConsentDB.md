---
title: recording_consent DB
component_type: datastore
tags: [consent, datastore, postgres]
---

# 🗄️ recording_consent (PostgreSQL)

Three schemas:

| Schema | Key tables |
|---|---|
| `recording_compliance` | `jump_page_session`, `jump_page_interaction`, `stop_recording_audit` |
| `recording_consent_settings` | `appuser_consent_settings`, `user_settings`, `calendar_event`, `consent_feature` |
| `recording_consent_email` | `consent_email`, `audit`, `company_obfuscation`, `history` |

Redis logical DB: **`RECORDING_COMPLIANCE`** (descriptor: `CONSENT_REDIS`). See [[Subsystems/Consent/Storage & Schema Reference]].
