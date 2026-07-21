---
title: ResetConsentRedisForCompanyEvent
component_type: event
tags: [consent, event, kafka, redis, cache]
---

# 📨 ResetConsentRedisForCompanyEvent

> Topic: **`reset-consent-redis-for-company`** · Cluster: `RECORDING_CONSENT`

Produced by `DcpChangeManager` (via `ChangeRequestLifecycle`) after all users' DCP changes complete. Consumed by `ResetConsentRedisForCompanyConsumer` (RecordingConsentTasks) → evicts company jump-page data from Redis (`DcpJumpPageRedisService`). Next page render picks up fresh DCP settings from DB.
