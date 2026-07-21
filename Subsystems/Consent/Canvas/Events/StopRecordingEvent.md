---
title: StopRecordingEvent
component_type: event
tags: [consent, event, kafka, recording]
---

# 📨 StopRecordingEvent

> Topic: **`audit-stop-recording`** · Cluster: `RECORDING_CONSENT`

Produced by the recording infrastructure when recording is halted (participant declined after joining, or compliance rule triggered). Consumed by `AuditStopRecordingConsumer` (RecordingConsentTasks) → writes `recording_compliance.stop_recording_audit`. Consent does **not** produce this — it only consumes and audits it.
