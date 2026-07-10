---
title: sync-users-from-web-conferencing-provider
component_type: inbound-kafka-topic
cluster: DATA_CAPTURE
tags: [call-scheduling, kafka, inbound, webex]
---

# 📥 sync-users-from-web-conferencing-provider

> [[Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §3]]

WebEx user-token synchronization. `SyncUsersFromProviderEvent` → `CallSchedulerWebexSyncUsersConsumer`
(`configureSingle:61`), concurrency 4. Cluster **`DATA_CAPTURE`** (not `CALL_SCHEDULER_V2`).
