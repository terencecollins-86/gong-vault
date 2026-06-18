---
tags:
- gong
- comms-capture
- hybrid-dev
- module-run
- runbook
created: 2026-06-18
---

# Comms Capture — gong-module-run Runbook

Runbook for backend engineers on the **Comms Capture** team. Maps each bounded context to its subsystem name, individual services, and ready-to-run `gong-module-run` commands.

All commands assume `gong-module-run` is on your PATH. Append `--remote` to deploy to your remote dev namespace instead of running locally.

→ See [[gong-module-run How To]] for general CLI reference and prerequisites.

---

## Bounded Contexts

### 1. Data Capture (`gong-data-capture`)
Recording consent management and DCP change tracking.

| Service | Role |
|---------|------|
| `meetingfrontend` | Meeting join page (browser-facing) |
| `consentwebapi` | Consent WebAPI (browser-facing) |
| `dcpchangemanager` | DCP change event management |
| `recordingconsenttasks` | Async consent processing tasks |
| `recordingconsentapiserver` | Consent API backend |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-data-capture --remote

# Consent services only
gong-module-run up --image-names recordingconsentapiserver,recordingconsenttasks,consentwebapi --remote

# Teardown
gong-module-run down --subsystem-names gong-data-capture --remote
```

---

### 2. Recorders (`gong-recorders`)
Local and dial-in call recording infrastructure.

| Service | Role |
|---------|------|
| `recordingstreamer` | Streams raw audio/video |
| `recordingsupervisor` | Orchestrates recorder lifecycle |
| `recorder` | Core recording process |
| `recorderapiserver` | Internal API for recorder control |
| `globalrecordingsupervisorapiserver` | Global recording supervisor API |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-recorders --remote

# Core recording only
gong-module-run up --image-names recorder,recordingsupervisor,recorderapiserver --remote

# Teardown
gong-module-run down --subsystem-names gong-recorders --remote
```

---

### 3. Cloud Recorders (`gong-cloud-recorders`)
Bot-based cloud recording for Zoom, Webex.

| Service | Role |
|---------|------|
| `cloudrecorder` | Cloud bot recorder |
| `globalzoomwebhooksserver` | Zoom webhook receiver |
| `webexwebhooksserver` | Webex webhook receiver |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-cloud-recorders --remote

# Teardown
gong-module-run down --subsystem-names gong-cloud-recorders --remote
```

---

### 4. Call Scheduling (`gong-call-schedulers`)
Calendar-based call detection and invite handling.

| Service | Role |
|---------|------|
| `callscheduler` | Schedules calls from calendar events |
| `invitehandlerwebhooksserver` | Handles calendar invite webhooks |
| `globalinvitehandlerwebhooksserver` | Global invite webhook handler |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-call-schedulers --remote

# Teardown
gong-module-run down --subsystem-names gong-call-schedulers --remote
```

---

### 5. Telephony Systems (`gong-telephony-systems`)
Dial-in telephony ingestion and troubleshooting.

| Service | Role |
|---------|------|
| `ingestertelephonysystemssupervisor` | Supervises telephony ingestion |
| `telephonysystemstroubleshooters` | Diagnostic tools |
| `textindexer` | Indexes transcribed text |
| `telephonysystemswebapi` | Telephony WebAPI (browser-facing) |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-telephony-systems --remote

# Teardown
gong-module-run down --subsystem-names gong-telephony-systems --remote
```

---

### 6. Ingestion (`gong-ingestion`)
Provider connectivity and calendar/mail ingestion pipeline.

| Service | Role |
|---------|------|
| `providerconnectivity` | Manages OAuth connections to providers |
| `ingestermailsupervisor` | Supervises mail ingestion |
| `ingestermailworker` | Mail ingestion worker |
| `mailingester` | Mail ingest processor |
| `maillistener` | Listens for new mail events |
| `ingestercalendarsupervisor` | Supervises calendar ingestion |
| `googlecalendaringester` | Google Calendar ingester |
| `officecalendaringester` | O365 Calendar ingester |
| `meetingsindexer` | Indexes meeting records |
| `googlemailprocessingserver` | Processes Google mail |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-ingestion --remote

# Provider connectivity only
gong-module-run up --image-names providerconnectivity --remote

# Mail pipeline only
gong-module-run up --image-names ingestermailsupervisor,ingestermailworker,mailingester,maillistener --remote

# Calendar pipeline only
gong-module-run up --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer --remote

# Teardown
gong-module-run down --subsystem-names gong-ingestion --remote
```

---

### 7. Call Orchestration (`gong-orchestration`)
Call processing pipeline coordination.

| Service | Role |
|---------|------|
| `orchestrator` | Central call processing orchestrator |
| `callpipelineexecutor` | Executes call processing pipeline steps |
| `callaiorchestrationserver` | AI processing orchestration |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-orchestration --remote

# Teardown
gong-module-run down --subsystem-names gong-orchestration --remote
```

---

### 8. Processors (`gong-processors`)
Call processing jobs and workflow execution.

| Service | Role |
|---------|------|
| `processorjobsupervisor` | Supervises processing jobs |
| `processor` | Core call processor |
| `kubernetesjoblauncherapiserver` | Launches K8s processing jobs |
| `callprocessingworkflowrunner` | Runs call processing Temporal workflows |
| `callprocessingworkflowcoordinator` | Coordinates workflow execution |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-processors --remote

# Workflow runner only
gong-module-run up --image-names callprocessingworkflowrunner,callprocessingworkflowcoordinator --remote

# Teardown
gong-module-run down --subsystem-names gong-processors --remote
```

---

### 9. In-Meeting Experience (`gong-inmeeting-experience`)
Live in-call features and real-time transcription.

| Service | Role |
|---------|------|
| `zoomappwebapi` | Zoom app integration WebAPI |
| `liveawstranscription` | Live real-time transcription via AWS |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-inmeeting-experience --remote

# Teardown
gong-module-run down --subsystem-names gong-inmeeting-experience --remote
```

---

### 10. Conversations (`gong-conversations`)
Post-call conversation data, summaries, and translation.

| Service | Role |
|---------|------|
| `conversationresearcherapiserver` | API for conversation research queries |
| `omnisearchdigester` | Digests data for omni-search |
| `conversationsummary` | Generates call summaries |
| `translationapiserver` | Transcript translation |
| `calldataapiserver` | API for call data retrieval |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-conversations --remote

# Teardown
gong-module-run down --subsystem-names gong-conversations --remote
```

---

### 11. Webconf Streaming (`gong-webconf-streaming`)
Streaming webhook infrastructure for web conferencing providers.

| Service | Role |
|---------|------|
| `streamingwebhookapiserver` | Receives streaming webhooks |
| `streamingaccountmanagementapiserver` | Manages streaming account config |
| `streamingapiserver` | Core streaming API |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-webconf-streaming --remote

# Teardown
gong-module-run down --subsystem-names gong-webconf-streaming --remote
```

---

### 12. Communications Publisher (`gong-communications-publisher`)
Publishes communication events downstream.

| Service | Role |
|---------|------|
| `communicationssyncserver` | Syncs communication data |
| `entityidproviderserver` | Provides stable entity IDs |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-communications-publisher --remote

# Teardown
gong-module-run down --subsystem-names gong-communications-publisher --remote
```

---

### 13. Communication Compliance (`gong-communication-compliance`)
Compliance enforcement over captured communications.

| Service | Role |
|---------|------|
| `communicationcomplianceapiserver` | Compliance API backend |
| `communicationcompliancewebapi` | Compliance WebAPI (browser-facing) |
| `communicationcomplianceserver` | Core compliance processing |

```bash
# Full subsystem
gong-module-run up --subsystem-names gong-communication-compliance --remote

# Teardown
gong-module-run down --subsystem-names gong-communication-compliance --remote
```

---

## Common Multi-Context Combos

### End-to-end capture pipeline (scheduling → ingestion → recording → processing)
```bash
gong-module-run up \
  --subsystem-names gong-call-schedulers,gong-ingestion,gong-recorders,gong-cloud-recorders,gong-orchestration,gong-processors \
  --remote
```

### Capture + post-call (add conversations and summaries)
```bash
gong-module-run up \
  --subsystem-names gong-call-schedulers,gong-ingestion,gong-recorders,gong-cloud-recorders,gong-orchestration,gong-processors,gong-conversations \
  --remote
```

### Streaming capture path (webconf providers → cloud recorder → processor)
```bash
gong-module-run up \
  --subsystem-names gong-webconf-streaming,gong-cloud-recorders,gong-orchestration,gong-processors \
  --remote
```

### Consent + recording only (data capture team focus)
```bash
gong-module-run up \
  --subsystem-names gong-data-capture,gong-recorders \
  --remote
```

### Tear down everything above
```bash
gong-module-run down \
  --subsystem-names gong-call-schedulers,gong-ingestion,gong-recorders,gong-cloud-recorders,gong-orchestration,gong-processors,gong-conversations,gong-webconf-streaming,gong-data-capture,gong-communications-publisher,gong-communication-compliance,gong-inmeeting-experience \
  --remote
```

---

## Related Notes

- [[gong-module-run How To]] — CLI reference, prerequisites, and deployment scope guide
- [[Comms Capture Architecture Overview]] — which services own which capture domain
- [[Comms Capture Maven Modules]] — per-service module breakdown
