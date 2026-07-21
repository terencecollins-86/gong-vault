---
title: DcpChangeRequestEvent
component_type: event
tags: [consent, event, kafka, dcp, change-request]
---

# 📨 DcpChangeRequestEvent

> Topics: **`change-request-executor`** / **`batch-users-change-executor`** / **`single-user-change-executor`** · Cluster: `DATA_CAPTURE`

Drives the `ChangeRequestLifecycle` state machine in `DcpChangeManager`. Lifecycle: company change fires `change-request-executor` → `BatchUsersChangeExecutorConsumer` fans to `batch-users-change-executor` (all users) → per-user `single-user-change-executor` → completion on `single-user-change-request-done` → Redis eviction via `reset-consent-redis-for-company`.
