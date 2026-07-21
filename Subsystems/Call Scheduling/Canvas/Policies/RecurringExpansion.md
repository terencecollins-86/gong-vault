---
title: Recurring Expansion (Policy)
component_type: policy
tags: [call-scheduling, policy, recurring]
---

# 📋 Recurring Expansion (Policy)

> `RecurringEventService#processRecurringEventBatches` · `recurring-events-call-scheduler` task (~2h)

**"Walk the recurring series forward; schedule each occurrence in the lookahead window."**

Keyed by `ical_uid` in `calendar_recurring_event` (not `enhanced_ical_id`). Model: `RecurringEventSetDto` = `initialEvent` + `eventExceptions`. Change types: `RecurringEventChange` (`CancelledMainEvent`, `UpdatedEventOccurrence`, …). Branches on `MailboxProviderCode` (Google vs Office). Each occurrence is individually scheduled → `Resolution.NEW_CALL_RECURRING`.
