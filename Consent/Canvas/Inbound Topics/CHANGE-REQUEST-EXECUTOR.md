---
title: change-request-executor
component_type: inbound-kafka-topic
cluster: DATA_CAPTURE
tags: [consent, kafka, inbound, dcp]
---

# 📥 change-request-executor

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §2]]

Drives **DCP settings-change propagation**. `DcpChangeRequestEvent` → `ChangeRequestExecutorConsumer` (`:24`)
→ `ChangeRequestLifecycle` state machine → batch/single-user change actions. Cluster `DATA_CAPTURE`.
Fans out to `batch-users-change-executor` / `single-user-change-executor`.
