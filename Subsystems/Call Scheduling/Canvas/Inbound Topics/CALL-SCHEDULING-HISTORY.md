---
title: call-scheduling-history
component_type: inbound-kafka-topic
cluster: CALL_SCHEDULER_V2
tags: [call-scheduling, kafka, inbound]
---

# 📥 call-scheduling-history

> [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §3]]

Calendar-event history for OpenSearch indexing. Consumed by `CallSchedulingHistoryConsumer`
(`configureMultipleByTenant:94`), **batch 100 / 30s**, → bulk-index `CalendarEventHistoryItem` into
`CALENDAR_EVENTS_HISTORY`. Cluster `CALL_SCHEDULER_V2`.
