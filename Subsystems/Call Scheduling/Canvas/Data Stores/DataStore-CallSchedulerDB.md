---
title: call_scheduler DB
component_type: datastore
tags: [call-scheduling, datastore, postgres]
---

# 🗄️ call_scheduler (PostgreSQL)

Schema `call_scheduler`. Key tables:

| Table | Purpose |
|---|---|
| `scheduled_calls` | Keyed by `enhanced_ical_id` — idempotency guard; deduplicates re-delivered scheduling requests |
| `calendar_recurring_event` | Recurring series state, keyed by `ical_uid`; audit triggers |
| `updated_calendar_event` | Calendar event update tracking (non-email mechanisms) |

Cross-schema writes: `public.call` (operational DB) via `CallDataDao` — `SkipCode`, `Resolution`, call status. See [[Subsystems/Call Scheduling/08 - Data Access & Storage]].
