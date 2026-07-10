---
title: DcpChangeManager
component_type: service
cluster: DATA_CAPTURE
tags: [consent, service, dcp, orchestration]
---

# 🔀 DcpChangeManager

> [[Subsystems/Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[01 - Services & Modules|Services]] · Owner: **tomer.priel@gong.io**

Orchestrates **DCP settings changes** across users (GPE, private). `ChangeRequestLifecycle` state machine
+ orchestrators (`DcpBatchUserChangeActionOrchestrator`, `DcpSingleUserChangeActionOrchestrator`) run
change actions: `CancelNonCompliantCallsAction`, `ConsentEmailSettingsChangeAction`, `SyncMeetingPmiAction`,
`ConsentEmailBackFillAction`. Consumes/produces the `*-change-executor` topics on `DATA_CAPTURE`.
