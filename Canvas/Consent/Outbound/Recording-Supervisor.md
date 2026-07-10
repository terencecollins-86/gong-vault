---
title: RecordingSupervisor (downstream)
component_type: downstream-consumer
tags: [consent, downstream, recorder]
---

# 🎙️ RecordingSupervisor

> [[Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §6]]

The recorder. `RecordingSupervisorClient.restrictCallRecording` (`:11`) / `markRecordingStop` (`:13`) tell
it whether to record based on the consent decision — the consent→recorder boundary. Wiring is partly
event-mediated (`StopRecordingEvent` / `audit-stop-recording`).
