---
title: call-scheduling-requests
component_type: inbound-kafka-topic
cluster: CALL_SCHEDULER_V2
tags: [call-scheduling, kafka, inbound, oncall]
---

# 📥 call-scheduling-requests

> [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §3]]

The **main inbound path**. `CallSchedulingRequest` (`CALENDAR_EVENT` or `EMAIL_EVENT`) → consumed by
`CallSchedulingRequestsConsumer` (bean `:262`, `configureSingle:286`), concurrency 50, key = iCal id,
distributed Redis locks for dedup. Cluster `CALL_SCHEDULER_V2`. **If this consumer stalls, calls stop
getting scheduled.** Low-priority twin: `call-scheduling-low-priority-requests` (concurrency 10).
