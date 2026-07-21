---
title: Calendar Ingestion (Actor / Upstream)
component_type: actor
tags: [call-scheduling, actor, upstream, calendar-ingestion]
---

# 📅 Calendar Ingestion (Upstream)

`gong-ingestion` — continuously syncs Google/Outlook calendars. Detects recordable meetings (conference URL + owner `should_record=true`) and produces `CallSchedulingRequest` onto `call-scheduling-requests`. The highest-volume upstream trigger for scheduling. → [[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion hub]]
