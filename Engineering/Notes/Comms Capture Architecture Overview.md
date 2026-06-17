---
tags:
- gong
- comms-capture
- architecture
- onboarding
created: 2026-06-17
---

# Comms Capture — Architecture Overview

High-level map of how Gong captures communications. Companion to [[Comms Capture Maven Modules]].

---

## Confluence Docs (search links)

Confluence MCP was unavailable when this was generated — use these pre-built CQL search links to find the actual architecture pages:

| Topic | Confluence Search |
|-------|-------------------|
| Comms capture overview | [search "comms capture"](https://gongio.atlassian.net/wiki/search?text=comms+capture&spaces=EN) |
| Email ingestion architecture | [search "email ingestion architecture"](https://gongio.atlassian.net/wiki/search?text=email+ingestion+architecture&spaces=EN) |
| Mail digestion pipeline | [search "mail digestion"](https://gongio.atlassian.net/wiki/search?text=mail+digestion&spaces=EN) |
| Cloud recorder / Zoom capture | [search "cloud recorder architecture"](https://gongio.atlassian.net/wiki/search?text=cloud+recorder+architecture&spaces=EN) |
| Bot recorder (Meet / Teams) | [search "gong-recorders"](https://gongio.atlassian.net/wiki/search?text=gong-recorders&spaces=EN) |
| Telephony / dialer capture | [search "telephony capture"](https://gongio.atlassian.net/wiki/search?text=telephony+capture&spaces=EN) |
| SMS capture | [search "SMS capture"](https://gongio.atlassian.net/wiki/search?text=SMS+capture&spaces=EN) |
| Gong Connect (native dialer) | [search "gong connect architecture"](https://gongio.atlassian.net/wiki/search?text=gong+connect+architecture&spaces=EN) |
| Data Capture Profile / consent | [search "DataCaptureProfile DCP"](https://gongio.atlassian.net/wiki/search?text=DataCaptureProfile+DCP&spaces=EN) |
| Activity store | [search "activity store architecture"](https://gongio.atlassian.net/wiki/search?text=activity+store+architecture&spaces=EN) |
| Engage LinkedIn capture | [search "LinkedIn activity capture"](https://gongio.atlassian.net/wiki/search?text=LinkedIn+activity+capture&spaces=EN) |
| Calendar sync | [search "calendar ingestion"](https://gongio.atlassian.net/wiki/search?text=calendar+ingestion&spaces=EN) |
| Adjustable logging (troubleshooter) | [Confluence page](https://gongio.atlassian.net/wiki/spaces/EN/pages/3103196742/Adjustable+Logging) |
| Technical ownership | [Ownership map](https://gongio.atlassian.net/wiki/spaces/EN/pages/4209180678/) |

> **Tip**: Swap `&spaces=EN` for `&spaces=COMMS` or `&spaces=ENGAGE` if the Engineering space returns nothing.

---

## Capture Domains

### 1. Bot-Based Call Recording — `gong-recorders`

Records live meetings by joining as a bot participant.

- **Providers**: Google Meet, Microsoft Teams
- **Core abstraction**: `Connector` interface
- **Key flow**: Call Scheduler deploys bot → bot joins → streams audio → uploads to S3 → triggers call-processing workflow
- **Repos**: `gong-recorders`, `gong-call-schedulers`

### 2. Cloud Recording Retrieval — `gong-cloud-recorders`

Retrieves recordings from cloud provider storage after the meeting ends.

- **Providers**: Zoom, Webex
- **Trigger**: Provider webhook → `GlobalZoomWebhooksServer` / `WebexWebhooksServer`
- **Status tracking**: `CaptureStatusReporter` writes to `call_workflow_tracking` table
- **Downstream**: `AsyncCallWorkflowClient#submit` triggers call-processing pipeline
- **Repos**: `gong-cloud-recorders`

### 3. Telephony / Dialer Capture — `gong-telephony-systems`

Captures calls made through third-party dialers and direct API uploads.

| Adapter | Class |
|---------|-------|
| Gong Connect (native) | `GongConnectDialerService` |
| Amazon Connect | `AmazonConnectDialerService` |
| Salesloft | `SalesloftDialerService` |
| Outreach | `OutreachDialerService` |

- **Base class**: `AbstractDialerService`
- **Kafka producers**: `GdmCallEventSender`, `DialerCallsUpdatesProducer`
- **Repos**: `gong-telephony-systems`

### 4. Gong Connect (Native VoIP Dialer) — `gong-connect`

Gong's own dialer built on Twilio.

- **Inbound webhooks**: `GongConnectWebhooksServer` (call status), `GongConnectMessagingWebhooksServer` (SMS/WhatsApp)
- **Messaging abstraction**: `MessagingProvider` interface over Twilio
- **Repos**: `gong-connect`

### 5. Email Capture — `gong-ingestion` → `gong-email-digestion`

Two-stage pipeline:

```
Gmail / O365 mailbox
    → GoogleMailProcessingServer / OfficeMailProcessingServer  (gong-ingestion)
    → MailIngestionPipeline: analyse → CRM-associate → S3 upload → Kafka(EmailIngested)
    → EmailsIndexer  (gong-email-digestion)
    → OpenSearch index: gong-emails
    → TrackersDigester  (gong-activity-digesters)
    → Activity store
```

- **Owner / Sentry team**: `mail-cal-ingestion` (eyal.miller@gong.io)
- **Repos**: `gong-ingestion`, `gong-email-digestion`, `gong-activity-digesters`

### 6. Calendar Capture — `gong-ingestion`

- **Providers**: Google Calendar, O365 Calendar
- **Pattern**: Polling/cursor (not webhooks)
- **Supervisors**: `IngesterCalendarSupervisor`, `GoogleCalendarIngester`, `OfficeCalendarIngester`
- **Output**: `MeetingsIndexer` → meetings DB records used by `gong-call-schedulers`

### 7. SMS Capture

- **Dialpad**: `DialpadSmsService` in `gong-telephony-systems` — polls Dialpad API, stores via `SmsSyncService`
- **Twilio (Gong Connect)**: `GongConnectMessagingServer` handles inbound/outbound SMS and WhatsApp
- **Repos**: `gong-telephony-systems`, `gong-connect`

### 8. LinkedIn / Social Capture — `gong-crm-enrichment`

Engage sequence steps (LinkedIn messages, connection requests) are captured as activities:

```
Engage sequence executes LinkedIn step
    → FlowLinkedinStepCompletedEvent (Kafka, produced by gong-engage)
    → LinkedinActivityConsumer  (gong-crm-enrichment)
    → LinkedinActivityService → LinkedinActivityCommand → CRM enrichment
```

- **Repos**: `gong-engage`, `gong-crm-enrichment`

---

## Cross-Cutting Concerns

### Consent & Data Capture Profile (DCP) — `gong-data-capture`

Controls what is allowed to be captured per company and user.

- **API**: `DcpConsentSettingsController` — jump-page, audio prompt, pre-call email, consent email settings
- **Change detection**: `JumpPageSettingsChangeDetector`, `ProviderChangeDetector`
- **DB**: `data_capture` schema
- **Repos**: `gong-data-capture`

### Activity Store — `gong-activity-store`

Unified sink for all captured communication activities (calls, emails, LinkedIn, SMS).

- **Gateways**: `ActivityStoreGateway`, `CallActivityStoreGateway`, `MessagingActivityStoreGateway`
- **Repos**: `gong-activity-store`, `gong-communications-publisher`

### Call Scheduling — `gong-call-schedulers`

Bridges calendar events to bot deployment decisions.

- Matches calendar invites to upcoming calls
- Decides which capture method to use (bot vs cloud recording)
- **Repos**: `gong-call-schedulers`

---

## Convergence Point

All capture paths ultimately write to the **`honeyfy.public.call`** table (RDS). This is the single source of truth for a captured call/communication.

---

## Key Kafka Events

| Event | Producer | Consumers |
|-------|----------|-----------|
| `EmailIngested` | `gong-ingestion` | `gong-activity-digesters`, `gong-email-digestion` |
| `FlowLinkedinStepCompletedEvent` | `gong-engage` | `gong-crm-enrichment` |
| `DialerCallsUpdates` | `gong-telephony-systems` | `gong-communications-publisher` |
| Call workflow trigger | `gong-cloud-recorders` | Call processing pipeline |

---

## Key Enums / Shared Models (in `honeyfy` monorepo)

| Class | Package | Purpose |
|-------|---------|---------|
| `ActivityType` | `com.honeyfy.activity.associations.api.model` | Email, call, LinkedIn, SMS |
| `CallToCapture` | `com.honeyfy.appcommon.capture` | Scheduled call: provider code, URL, owner |
| `CaptureStatus` | `com.honeyfy.appcommon.status` | Capture lifecycle status |
| `DataCaptureSettingType` | `com.honeyfy.users.common` | DCP setting types |
| `IntegrationType` | `com.honeyfy.appcommon.integration` | Telephony provider enum |

---

## Related Notes

- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Software Defined Modules - R&D]] — YAML descriptor system
- [[gong-java-cheat-sheet]]
