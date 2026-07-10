---
title: call-scheduling-updated
component_type: outbound-kafka-topic
cluster: CALL_SCHEDULER_V2
tags: [call-scheduling, kafka, outbound, oncall]
---

# 📤 call-scheduling-updated

> [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §6]]

The **downstream hand-off** — where call scheduling ends and recording infrastructure begins.
Producer `CallSchedulingUpdatedProducer` (`:262`), key = `Long callId`, max request 20MB. Carries three
subtypes: `CallSchedulingUpdated`, `CallSchedulingCalendarEventUpdated`, `ManualCallEventUpdated`, each
stamped with a `CallSchedulingCRUDOperation` (NEW/UPDATE/CANCEL).
