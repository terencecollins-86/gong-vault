---
title: CallSchedulingUpdated (Event)
component_type: event
tags: [call-scheduling, event, kafka, outbound]
---

# 📨 CallSchedulingUpdated

> Topic: **`call-scheduling-updated`** · Cluster: `CALL_SCHEDULER_V2` · Key: `callId (Long)`

The downstream hand-off. Three subtypes: `CallSchedulingUpdated`, `CallSchedulingCalendarEventUpdated`, `ManualCallEventUpdated`. Stamped with `CallSchedulingCRUDOperation` (`NEW`/`UPDATE`/`CANCEL`). Recording infrastructure and Consent both consume this. Max request size 20MB.
