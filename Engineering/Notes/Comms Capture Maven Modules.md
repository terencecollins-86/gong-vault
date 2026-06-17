---
tags:
- gong
- comms-capture
- maven
- architecture
created: 2026-06-12
---

# Comms Capture — Maven Modules

Overview of all Maven modules (`groupId: com.honeyfy`) across the
communications capture services.

## Services

### [[gong-recorders]]
Bot-based recording (Google Meet, Microsoft Teams). Core abstraction:
`Connector` interface.

| Module | Role |
|---|---|
| `Recorder` | Core recorder process |
| `RecorderApiServer` | REST API for recorder operations |
| `RecordingSupervisor` | Supervises recorder lifecycle |
| `RecordingStreamer` | Streams recording data |
| `GlobalRecordingSupervisorApiServer` | Global supervisor API |

### [[gong-cloud-recorders]]
Cloud recording retrieval via provider webhooks (Zoom, Webex).

| Module | Role |
|---|---|
| `CloudRecorder` | Core cloud recording retrieval |
| `GlobalZoomWebhooksServer` | Receives Zoom recording webhooks |
| `WebexWebhooksServer` | Receives Webex recording webhooks |

### [[gong-ingestion]]
Email (Gmail / O365) and calendar (Google / O365) ingestion.

| Module                                          | Role                                  |
| ----------------------------------------------- | ------------------------------------- |
| `GoogleMailProcessingServer`                    | Gmail ingestion                       |
| `GoogleCalendarIngester`                        | Google Calendar sync                  |
| `OfficeCalendarIngester`                        | O365 Calendar sync                    |
| `IngesterCalendarSupervisor`                    | Supervises calendar ingestion workers |
| `MeetingsIndexer`                               | Indexes meeting records               |
| *(4 additional modules — check root `pom.xml`)* |                                       |

### [[gong-email-digestion]]
Downstream email processing pipeline (indexing, classification, privacy).

| Module                    | Role                                           |
| ------------------------- | ---------------------------------------------- |
| `EmailsIndexer`           | Indexes emails into OpenSearch (`gong-emails`) |
| `DigesterEmailSupervisor` | Supervises digestion workers                   |
| `EmailPrivacyClassifier`  | Applies privacy rules                          |

### [[gong-connect]]

Gong's built-in VoIP dialer (Twilio-backed).

| Module | Role |
|---|---|
| `GongConnectWebApi` | REST API |
| `GongConnectWebhooksServer` | Receives Twilio call-status webhooks |
| `GongConnectTasks` | Async/scheduled tasks |
| `GongConnectMessagingServer` | SMS/messaging |

### [[gong-telephony-systems]]
Third-party telephony integrations (RingCentral, Groove, ConnectAndSell, etc.) and direct API uploads.

| Module                               | Role                                   |
| ------------------------------------ | -------------------------------------- |
| `IngesterTelephonySystemsSupervisor` | Supervises telephony ingestion         |
|                                      |                                        |
| `TelephonySystemsWebApi`             | REST API                               |
| `TelephonySystemsTroubleshooters`    | Troubleshooter endpoints               |
| `TextIndexer`                        | Indexes telephony text/transcript data |

### [[gong-call-schedulers]]
Matches calendar events to upcoming call recordings; schedules bot deployment.

| Module                              | Role                             |
| ----------------------------------- | -------------------------------- |
| `CallScheduler`                     | Core scheduling logic            |
| `InviteHandlerWebhooksServer`       | Handles calendar invite webhooks |
| `GlobalInviteHandlerWebhooksServer` | Global invite webhook handler    |

  ---

## Full Module List
  
GlobalRecordingSupervisorApiServer
Recorder
RecorderApiServer
RecordingStreamer
RecordingSupervisor
CloudRecorder
GlobalZoomWebhooksServer
WebexWebhooksServer
GoogleCalendarIngester
IngesterCalendarSupervisor
MeetingsIndexer
OfficeCalendarIngester
GoogleMailProcessingServer
DigesterEmailSupervisor
EmailPrivacyClassifier
EmailsIndexer
GongConnectMessagingServer
GongConnectTasks
GongConnectWebApi
GongConnectWebhooksServer
IngesterTelephonySystemsSupervisor
TelephonySystemsTroubleshooters
TelephonySystemsWebApi
TextIndexer
CallScheduler
GlobalInviteHandlerWebhooksServer
InviteHandlerWebhooksServer

  ---

## Key Architecture Notes

- **`honeyfy.public.call`** is the convergence table — all ingestion
  paths write a row here
- **Webhook-first** for cloud providers (Zoom, Webex, Twilio, HubSpot)
- **Polling/cursor** for calendar and CRM (Google, O365, Salesforce)
- **`Connector` interface** in `gong-recorders` is the abstraction for
  all bot-based capture
- **Two-stage email pipeline**: `gong-ingestion` → Kafka →  `gong-email-digestion` → OpenSearch

## Related Notes

- [[comms-capture-service-map]]
- [[gong-architecture-overview]]
- [[Software Defined Modules - R&D]] — YAML descriptor system that governs module resource declarations
