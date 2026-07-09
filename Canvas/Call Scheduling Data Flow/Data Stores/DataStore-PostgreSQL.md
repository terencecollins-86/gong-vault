---
title: PostgreSQL
component_type: datastore
tags: [call-scheduling, datastore, postgres]
---

# 🐘 PostgreSQL

> [[Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §7]]

Owned schema **`call_scheduler`**: `scheduled_calls` (key `enhanced_ical_id`), `calendar_recurring_event`
(key `ical_uid`), `updated_calendar_event`. Cross-schema writes to **`operational`** (`call` table via
`UpdateCallDao` / `CallDataDao`). Flyway migrations in `schema/call_scheduler/db/migration/`.
