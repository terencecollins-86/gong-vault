---
title: ScheduledCallsActionsController (+ Troubleshooters)
component_type: rest-controller
tags: [call-scheduling, rest, api]
---

# 🔌 REST API + Troubleshooters

> [[Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §1]]

`ScheduledCallsActionsController` (`:25`, implements `CallSchedulerApi`) — manual schedule, cancel,
restore, change-privacy. `CancelBlacklistedCallsController` (`:9`). Plus **74 troubleshooting endpoints**
(19 files) for ops/replay — 3 re-inject events into the request topics.
