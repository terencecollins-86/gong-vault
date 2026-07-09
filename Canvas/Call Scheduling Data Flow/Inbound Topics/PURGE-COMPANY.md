---
title: purge-company
component_type: inbound-kafka-topic
cluster: OPERATIONAL_V1
tags: [call-scheduling, kafka, inbound, gdpr]
---

# 📥 purge-company

> [[Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §3]]

Company data purge (GDPR). `PurgeCompany` → `CallSchedulerPurgeCompanyConsumer` (`configureSingle:62`),
concurrency 1, retries 2, `persistErrorsWithReprocessing`. Cluster **`OPERATIONAL_V1`**.
