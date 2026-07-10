---
title: call-scheduling-updated
component_type: inbound-kafka-topic
cluster: CALL_SCHEDULER_V2
tags: [consent, kafka, inbound, oncall]
---

# 📥 call-scheduling-updated

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §2]]

The hand-off **from Call Scheduling**. `CallSchedulingUpdated` → `ConsentCallSchedulingUpdatedConsumer`
(`HF/ConsentProfile/.../ConsentCallSchedulingUpdatedConsumer.java:26`, maxPoll 60m) →
`DcpConsentEmailSchedulingService.handleEvent` (`:69`) schedules/cancels the pre-call consent email.
Cluster `CALL_SCHEDULER_V2`.
