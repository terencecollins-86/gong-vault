---
title: Recording Infrastructure
component_type: downstream-consumer
tags: [call-scheduling, downstream]
---

# 🎙️ Recording Infrastructure

> [[Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]]

Consumes `call-scheduling-updated` to actually record/skip the scheduled call. Downstream of this
domain — the recorder acts on the `CallSchedulingUpdated` decision keyed by `callId`.
