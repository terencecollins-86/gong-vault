---
title: Recording Architecture — How Gong Records Meetings
tags: [architecture, recording, cloud-recorders, recorders, zoom, consent, recording-supervisor]
created: 2026-07-20
aliases:
  - recording architecture
  - how gong records
  - gong recorder
  - cloud recorder
  - RecordingSupervisor
---

# Recording Architecture — How Gong Records Meetings

> [!note] TL;DR
> Gong has two recording modes: **cloud recording** (Zoom/Teams own the recorder; Gong controls it via API) and **bot recording** (Gong's own recorder bot dials in). `RecordingSupervisor` (`gong-recorders`) coordinates both. When a participant declines consent, Gong issues API calls to Zoom to stop the cloud recording and disable auto-record — it does not just suppress on Gong's side.

---

## The two recording modes

| Mode | Where recording happens | Gong's role | Repo |
|---|---|---|---|
| **Cloud recording** | Zoom / Webex infrastructure | Controls via provider REST API; imports completed recording from Zoom S3 → Gong S3 | `gong-cloud-recorders` |
| **Bot / machine recording** | Gong's own recorder process | Bot dials into meeting, streams audio/video, uploads to S3 | `gong-recorders` |

Both modes are coordinated by **`RecordingSupervisor`** — the central lifecycle orchestrator. The two paths converge at S3 and the call-processing pipeline downstream.

---

## Architecture overview

```
                        ┌────────────────────────────────────────────┐
                        │            RecordingSupervisor             │
                        │           (gong-recorders)                 │
                        │  - Polls scheduled calls                   │
                        │  - Manages recording state machine         │
                        │  - Coordinates stop / restrict requests    │
                        └──────────┬─────────────────┬──────────────┘
                                   │                 │
              ┌────────────────────▼───┐   ┌─────────▼─────────────────┐
              │   Bot Recording Path   │   │  Cloud Recording Path      │
              │   (gong-recorders)     │   │  (gong-cloud-recorders)    │
              │                        │   │                            │
              │  recorder bot joins    │   │  ZoomApiV2Client           │
              │  meeting, streams      │   │  → setCloudRecording()     │
              │  audio/video           │   │  → sendLiveMeetingEvent()  │
              └────────┬───────────────┘   └─────────┬──────────────────┘
                       │                             │
                       │  S3 upload                  │  Zoom webhook
                       │                             │  (recording.completed)
                       └──────────────┬──────────────┘
                                      │
                              ┌───────▼────────┐
                              │  Call-processing│
                              │  pipeline       │
                              └────────────────┘
```

---

## Cloud recording in detail (Zoom)

Gong does **not** send a bot into Zoom meetings in cloud-recording mode. Instead:

1. **Before the meeting** — `RecordingSupervisor` calls `ZoomApiV2Client.setCloudRecording()` / `updateMeetingDetails()` to enable Zoom's own cloud recording for that meeting.
2. **During the meeting** — Zoom records on its own infrastructure.
3. **After the meeting** — Zoom fires a `recording.completed` webhook to `ZoomCloudRecorderController.events()` (in `gong-cloud-recorders`). `ZoomWebhookService` handles it and `ZoomCloudProcessorInitializerWorker.processMeeting()` imports the recording from Zoom S3 into Gong's S3 bucket and kicks off the call-processing pipeline.

---

## How consent decline stops a Zoom recording

When a participant clicks **Decline** on the Gong jump page, the recording stop flows synchronously before the Kafka audit event:

```
JumpPageController#skipAnswer  (gong-data-capture / MeetingFrontEnd)
  │
  ▼ sync HTTP
RecordingSupervisorClient.restrictCallRecording()
  │
  ▼ (gong-recorders)
ComplianceRecorderService.restrictAllRecordings()
  ├─ marks meeting room as restricted  (RecordersRestrictionsService → DB)
  ├─ for BOT recordings:
  │    produces OptOutRecorderEvent → tells bot to leave
  └─ for CLOUD recordings:
       produces RequestStopRecordingEvent on Kafka
         │
         ▼ (gong-cloud-recorders)
       RequestStopRecordingConsumer
         → StopRecordingMutualService.tryStopRecording()
             ├─ ZoomApi.sendLiveMeetingEvent()       → Zoom REST API (stops recording)
             └─ AutoRecordingToggler
                  → ZoomApi.enforceDisableAutoRecording()  → Zoom API (prevents restart)
  │
  ▼ (after outcome known)
StopRecordingEvent produced on audit-stop-recording (Kafka, RECORDING_CONSENT cluster)
  │
  ▼ (gong-data-capture / RecordingConsentTasks)
AuditStopRecordingConsumer
  → RecordingComplianceDao.auditCallStoppingStatus()
  → recording_compliance.stop_recording_audit (Postgres)
```

**Key points:**
- The recording is stopped on **Zoom's actual infrastructure** — not just suppressed on Gong's side.
- Zoom's auto-recording is also disabled so it can't restart automatically.
- The `RecordingSupervisorClient.restrictCallRecording()` call is **synchronous** (direct HTTP) — the consent decision is enforced inline, not via Kafka.
- The Kafka event (`audit-stop-recording`) is the **audit trail** published after the outcome is known.

---

## `StopRecordingEvent` — what's in the audit record

Both `gong-recorders` and `gong-cloud-recorders` produce `StopRecordingEvent` to the `audit-stop-recording` topic. Key fields:

| Field | Meaning |
|---|---|
| `wasRecordingStopped` | Did Gong's API call to Zoom succeed? |
| `wasAutoRecordingDisabled` | Was Zoom's auto-recording feature also turned off? |
| `wasCallCancelledIfNeeded` | Was the entire call cancelled (not just recording)? |
| `participantRequestTime` | When the participant declined |
| `meetingId` / `callId` | Identifiers for correlation |

---

## Gong-initiated stop vs Zoom-host-initiated stop

| Scenario | How Gong learns about it | `RequestStopRecordingEvent` on Kafka? |
|---|---|---|
| Participant declines consent | `restrictCallRecording()` → Zoom API → `recording.completed` webhook | **Yes** |
| Gong user clicks "Stop Recording" in Gong UI | `markRecordingStop()` → Kafka → Zoom API → webhook | **Yes** |
| Zoom host presses Stop Recording in Zoom UI | `recording.completed` webhook only | **No** |
| Meeting ends naturally | `recording.completed` webhook only | **No** |

The presence of a `RequestStopRecordingEvent` for a given `callId` distinguishes Gong-driven stops from host/natural stops. The `wasRecordingStopped` flag on the audit event captures whether Gong's stop command was acknowledged by Zoom's API.

---

## `RecordingSupervisor` — key responsibilities

Service: `recordingsupervisor` in `gong-recorders`. Two critical methods on `RecordingControlApi` (gong-clients interface):

| Method | Path | Used by | What it does |
|---|---|---|---|
| `restrictCallRecording(...)` | Compliance-decline path | `JumpPageController` (via `RecordingSupervisorClient`) | Restricts the meeting room, stops recording (cloud or bot), optionally cancels the call |
| `markRecordingStop(...)` | Manual stop path | Gong UI / admin flows | Persists a stop intent, then produces `RequestStopRecordingEvent` for cloud calls or marks DB directly for bot calls |

---

## Key classes at a glance

| Class | Repo | Role |
|---|---|---|
| `RecordingSupervisorOrchestrator` | `gong-recorders` | Polls scheduled calls, manages recording state, holds `KafkaTemplate<Long, StopRecordingEvent>` |
| `ComplianceRecorderService` | `gong-recorders` | Consent-decline handler: restricts rooms, fires OptOut events for bots, produces `RequestStopRecordingEvent` for cloud |
| `StopRequestRecordingService` | `gong-recorders` | Manual stop: produces `RequestStopRecordingEvent` (cloud) or marks DB (bot) |
| `RecordersRestrictionsService` | `honeyfy` | DB-backed restriction table: marks meetings restricted, checks `wasCallAlreadyStopped` |
| `RecordingControlApi` | `gong-clients` | Interface defining `restrictCallRecording` + `markRecordingStop` |
| `RequestStopRecordingConsumer` | `gong-cloud-recorders` | Kafka consumer; delegates to `RequestStopRecordingService` |
| `StopRecordingMutualService` | `gong-cloud-recorders` | Core stop logic: distributed lock + `ZoomApi.sendLiveMeetingEvent()` + `AutoRecordingToggler` |
| `AutoRecordingToggler` | `gong-cloud-recorders` | Disables Zoom auto-recording via `ZoomApi.enforceDisableAutoRecording()` |
| `ZoomApi` | `gong-cloud-recorders` | Thin service wrapping `ZoomApiV2Client`; `sendLiveMeetingEvent()` = the actual "stop recording" Zoom API call |
| `ZoomApiV2Client` | `honeyfy` | HTTP client to Zoom REST API v2 |
| `ZoomCloudRecorderController` | `gong-cloud-recorders` | Zoom webhook receiver (`/events`) |
| `ZoomWebhookService` | `gong-cloud-recorders` | Handles `recording.completed` → triggers recording import |
| `AuditStopRecordingConsumer` | `gong-data-capture` | Consumes `audit-stop-recording`; writes `stop_recording_audit` to Postgres |

---

## See also

- [[Subsystems/Consent/Jump Page & DCP]] — full consent decline flow including `restrictCallRecording` call
- [[Subsystems/Consent/02 - Data Flow]] — `audit-stop-recording` consumer in the Consent Kafka table
- [[Subsystems/Consent/Use Cases/C - Enforce/C1 - Restrict Recording]] — use-case card
- [[Subsystems/Consent/Use Cases/C - Enforce/C2 - Stop Recording]] — use-case card
- [[Work/Engineering/Runbooks/Comms Capture/Cloud Recorders]] — operational runbook (run/debug `gong-cloud-recorders`)
- [[Work/Engineering/Runbooks/Comms Capture/Recorders]] — operational runbook (run/debug `gong-recorders`)
