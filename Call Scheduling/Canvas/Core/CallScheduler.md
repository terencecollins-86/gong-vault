---
title: CallScheduler (engine)
component_type: service
cluster: CALL_SCHEDULER_V2
tags: [call-scheduling, service, core, hub, oncall]
---

# ⚙️ CallScheduler (core engine)

> [[Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[01 - Services & Modules|Services]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points]] · Owner: **web.conferencing@gong.io**

> [!danger] On-call TL;DR
> **Start here.** The engine consumes scheduling requests, runs the validation chain chosen by
> `CallCreationMechanism`, and **adds / reschedules / cancels / restores** a `Call` in Postgres, then
> publishes the decision on `call-scheduling-updated`. If it's down, **no meetings become scheduled
> recordings.** Private service, **GPE**, `locks: true`, `scheduledTasks: true`.

| | |
|---|---|
| **Service id** | `callscheduler` |
| **Core logic** | `SchedulingCallService`, `CancelCallService`, `RestoreCancelledCallService`, `RecurringEventService`, `CallBuilder`, `EventValidationFactory` |
| **Inbound** | `call-scheduling-requests` (+ low-priority), `call-scheduling-history`, `sync-users-…`, `purge-company` |
| **Outbound** | `call-scheduling-updated`; Postgres `call_scheduler` + `operational`; OpenSearch `CALENDAR_EVENTS_HISTORY` |
