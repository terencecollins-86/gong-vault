---
title: CallSchedulingRequest (Event)
component_type: event
tags: [call-scheduling, event, kafka, inbound]
---

# 📨 CallSchedulingRequest

> Topics: **`call-scheduling-requests`** (high-priority) · **`call-scheduling-low-priority-requests`** · Cluster: `CALL_SCHEDULER_V2`

The inbound scheduling request. Produced by `gong-ingestion` (calendar sync), `InviteHandlerWebhooksServer` (email invite), or troubleshooter replay. Consumed by `CallSchedulingRequestsConsumer` — Redis-locked on `(companyId, enhancedCalendarEventId)` for dedup. Dispatches to the validation chain via `CallCreationMechanism`.
