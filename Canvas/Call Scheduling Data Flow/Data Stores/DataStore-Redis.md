---
title: Redis
component_type: datastore
tags: [call-scheduling, datastore, redis]
---

# ⚡ Redis

> [[Call Scheduling - Data Flow.canvas|← Canvas]]

`GONG_PROD` (distributed locks for event dedup via `DistributedLockService`, permissions cache),
`CONSENT_REDIS`, `CIRCUIT_BREAKERS`. IAM auth via ElastiCache in prod.
