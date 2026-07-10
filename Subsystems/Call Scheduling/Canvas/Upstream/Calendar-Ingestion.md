---
title: Calendar Ingestion (gong-ingestion)
component_type: upstream-producer
tags: [call-scheduling, upstream, calendar]
---

# 📅 Calendar Ingestion

> [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion hub]]

Fans out per-user calendar sync (Google / Office 365) and, for meetings needing recording, produces
`CallSchedulingRequest` (`CALENDAR_EVENT`) onto **`call-scheduling-requests`**. Lives in `gong-ingestion`.
