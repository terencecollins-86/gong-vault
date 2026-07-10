---
title: Scheduled Tasks
component_type: scheduled-tasks
tags: [call-scheduling, scheduled-tasks]
---

# ⏰ Scheduled Tasks

> [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §4]]

Programmatic `ScheduledTask` beans run by a DB-coordinated `DistributedScheduledTaskExecutor` (no
`@Scheduled`). Six tasks: webex import-users / refresh-tokens, zoom import-meetings, delete-updated-calendar-events,
**recurring-events-call-scheduler**, global-invite-handlers-summary-emails.
