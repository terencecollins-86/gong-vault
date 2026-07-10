---
title: OpenSearch
component_type: datastore
tags: [call-scheduling, datastore, opensearch]
---

# 🔎 OpenSearch

> [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §8]]

Indices `CALENDAR_EVENTS_HISTORY` (bulk-indexed from `call-scheduling-history` via
`CalendarEventsHistoryWriter`), `MEETINGS`, `AUDITS`.
