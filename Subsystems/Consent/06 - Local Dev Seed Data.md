---
tags: [consent, recording-consent, local-dev, seed-data, runbook]
title: Local Dev Seed Data
---

# Local Dev Seed Data — Consent

> [[_dashboard|← Team Hub]] · [[05 - Data Access & Storage]] · [[02 - Data Flow]] · [[Subsystems/Call Scheduling/06 - Local Dev Seed Data|Call Scheduling — Seed Data]]

Unlike Call Scheduling — which has a fixed six-script bootstrap — **Consent has no pre-baked seed scripts**. There is no `NewFlow/`-style directory in `gong-data-capture`; the owned tables are populated by **running the flows**, not by inserting rows directly. This doc explains what to seed (the shared operational base) and how to make each owned table fill up.

> **Bottom line**: seed the *same six operational rows* as Call Scheduling (`honeyfy_dev`), then drive the Consent flows. The `recording_consent_*`, `dcp_change`, and `event_based_tasks` tables have **no seed SQL** — they are written at runtime.

---

## Why This Matters

Consent is a **reactive, event-driven** subsystem. It has no "create a company" entry point of its own — it inherits the operational base (`company`, `appuser`, `data_capture.profile`) that Call Scheduling seeds, then reacts to:
- the **`call-scheduling-updated`** hand-off from Call Scheduling ([[02 - Data Flow]] §2, `ConsentCallSchedulingUpdatedConsumer`),
- participant interactions on the **jump page** (`MeetingFrontEnd`),
- **DCP settings changes** (`change-request-executor` → `DcpChangeManager`).

So there is nothing to "seed" into the owned schemas up front — you seed the *base*, start the services, and trigger a flow. Each flow writes its own rows.

---

## Prerequisites

- **Schemas migrated** — all Consent DBs must exist and be Flyway-migrated. If `recording_consent_timed_events_dev`, `scheduled_tasks_01/02_dev`, or `user_auth_dev` are empty, run the Flyway commands in [[05 - Data Access & Storage#7. Logical → physical DB names (finding these in IntelliJ)|§7 migration runbook]] first.
- **Operational base seeded** — company 9001, user 501, `data_capture.profile` 2001 in `honeyfy_dev`. This is the **Call Scheduling six-script seed** ([[Subsystems/Call Scheduling/06 - Local Dev Seed Data|Call Scheduling §Seed Sequence]]) — Consent reuses it, doesn't duplicate it.
- Postgres at `localhost:5432` (IntelliJ/Mac) or `host.docker.internal:5432` (inside a container) — see [[05 - Data Access & Storage#7. Logical → physical DB names (finding these in IntelliJ)|§7]].
- Redis reachable (hybrid env routes automatically).

### Module ports (from `*.gong-app-descriptor.yaml`)

| Module                        | Port   | Public                 | Role                                                                |
| ----------------------------- | ------ | ---------------------- | ------------------------------------------------------------------- |
| **MeetingFrontEnd**           | `8098` | yes (`/`)              | Jump page + consent-email landing page                              |
| **RecordingConsentApiServer** | `7254` | no                     | DCP settings API, purge, static links                               |
| **RecordingConsentTasks**     | `9095` | no                     | Kafka consumers, scheduled tasks, `call-scheduling-updated` handler |
| **DcpChangeManager**          | `8121` | no                     | DCP change-request orchestration                                    |
| **ConsentWebApi**             | —      | yes (`/consentwebapi`) | MS Teams attendance reports                                         |

---

## What Populates Each Owned Table

Rather than "run these inserts," the map below is **"fire this to fill that table"** — the honest Consent equivalent of a seed sequence.

| Owned table (schema.table) | Physical DB | Filled by | Trigger |
|---|---|---|---|
| `recording_consent_settings.calendar_event` | `recording_consent_dev` | `ConsentMeetingUpdatesDao.upsertEventData` | **`call-scheduling-updated`** Kafka event (the Call Scheduling hand-off) or `calendar-updates-for-consent` |
| `recording_consent_settings.appuser_consent_settings` | `recording_consent_dev` | `DcpConsentSettingsDao.upsertAppUserConsentSettings` | `POST :7254/…/DcpConsentSettingsApi` (saveUserProviderDefault) |
| `recording_consent_settings.user_settings` | `recording_consent_dev` | `UserSettingsDao.upsert` | `POST :9095/…UserSettingsController.saveUserSettings` |
| `recording_consent_email.consent_email` (+ `audit`, `company_obfuscation`) | `recording_consent_dev` | `DcpConsentEmailRecordingConsentDao.*` | Consent-email flow: `ConsentEmailsTasks` scheduled task (every 1m) after a call is eligible, or the email landing page POST on `:8098` |
| `recording_compliance.jump_page_session` / `jump_page_interaction` | `recording_consent_dev` | `RecordingComplianceDao.insert*` | Participant hits the **jump page** GET/POST on `:8098` (`JumpPageController`) → `audit-meeting-consent` → `AuditMeetingConsentConsumer` |
| `recording_compliance.stop_recording_audit` | `recording_consent_dev` | `RecordingComplianceDao.auditCallStoppingStatus` | `audit-stop-recording` Kafka event |
| `dcp_change.change_request_*` | `data_capture_dev` | `DcpChangeManagerDao.*` | `change-request-executor` Kafka event → `DcpChangeManager`, or the `DcpChangeManagerTroubleshooter` endpoints on `:8121` |
| `data_capture.profile` / settings tables | `data_capture_dev`* | DCP settings API | *the seed's `profile` row is in `honeyfy_dev.data_capture`; the `data_capture_dev` copies fill via DCP settings flow |
| `event_based_tasks.events` | `recording_consent_timed_events_dev` | `TimeBasedEventsScheduler` | `recording-consent-time-based-events` produced by `ConsentEmailBackFillAction` (DCP change) |

> ⚠️ Note the **two `data_capture` locations** ([[05 - Data Access & Storage#2b. `DATA_CAPTURE` DB → `dcp_change` + `data_capture`|§2b]]): the *seed* `profile` row lives in `honeyfy_dev.data_capture` (operational), while the DCP settings backing store is `data_capture_dev.data_capture`. Don't expect the seeded profile to appear in `data_capture_dev`.

---

## The Simplest End-to-End: reuse the Call Scheduling flow

The cleanest way to see Consent write real rows is to **let Call Scheduling hand off to it**:

1. Seed the operational base + fire the `CallSchedulingRequest` exactly as in [[Subsystems/Call Scheduling/06 - Local Dev Seed Data|Call Scheduling §Fire the Flow]] (company 9001, user 501).
2. Call Scheduling produces **`call-scheduling-updated`** on success ([[Subsystems/Call Scheduling/08 - Data Access & Storage|CS §Kafka]]).
3. With `RecordingConsentTasks` (`:9095`) running, `ConsentCallSchedulingUpdatedConsumer` consumes it and upserts `recording_consent_settings.calendar_event`.

**Verify:**
```sql
-- recording_consent_dev
SELECT * FROM recording_consent_settings.calendar_event WHERE company_id = 9001;
```

If the row appears, the Call Scheduling → Consent hand-off is working end-to-end locally.

---

## Direct Injection (skip Kafka)

To exercise a specific Consent path without producing a real Kafka message, use the **13 troubleshooting controllers** (75 endpoints total). The full catalog — grouped by use case, with exact paths, params, and gaps — lives in [[Troubleshooting Endpoints Catalog]].

Quick reference for the most common local-dev tasks:

| Goal | Endpoint | Module:port |
|---|---|---|
| Warm Redis for a company | `POST /troubleshooting/consent_redis/populate-company-in-redis?company-id=9001&force=true` | RCT `:9095` |
| Read/inspect a company DCP profile | `POST /troubleshooting/data-capture-profile/read-default-data-capture-profile?company-id=9001` | RCAS `:7254` |
| Assign a DCP profile to a user | `POST /troubleshooting/data-capture-profile/set-data-capture-profile-to-appuser?company-id=9001&dcp-id=2001&appuser-id=501` | RCAS `:7254` |
| Drive a DCP change-request through its states | `POST /troubleshooting/dcp-change-manager/set-change-request-state?company-id=9001&change-request-id=…&change-request-state=DONE` | DCM `:8121` |
| Execute a running change request | `POST /troubleshooting/dcp-change-manager/execute-running-change-request?company-id=9001&change-request-id=…&ignore-exception-and-run-next-request=false` | DCM `:8121` |
| Seed consent-email Redis for a specific call | `POST /troubleshooting/consent_email/redis/set-consent-email-page-data-by-email-id?company-id=9001&email-id=…` | RCT `:9095` |
| Replay a consent-email denial (bypasses Kafka) | `POST /troubleshooting/consent_email/send-event-to-consent-email-page-interaction-service?company-id=9001&…` | RCT `:9095` |

---

## Common Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| `calendar_event` never populates | `call-scheduling-updated` not consumed | Confirm `RecordingConsentTasks` (`:9095`) is up and on cluster `CALL_SCHEDULER_V2`; check the CS flow actually produced the event |
| DCP profile lookups return empty | operational base not seeded | Seed company 9001 / profile 2001 per [[Subsystems/Call Scheduling/06 - Local Dev Seed Data|CS seed]] |
| `event_based_tasks.events` empty | `recording_consent_timed_events_dev` not migrated | Flyway it per [[05 - Data Access & Storage#7. Logical → physical DB names (finding these in IntelliJ)|§7]] |
| Scheduled tasks never run | `scheduled_tasks_01/02_dev` empty | Flyway them per [[05 - Data Access & Storage#7. Logical → physical DB names (finding these in IntelliJ)|§7]] — the `DistributedScheduledTaskExecutor` is lock-backed by these |
| Jump-page rows missing | `MeetingFrontEnd` (`:8098`) not running, or profile/user keys wrong | Bring up MeetingFrontEnd; jump-page URL is `/{profileKey}/{userKey}/{meetingKey}` |

---

## Code References

| Path | Role |
|---|---|
| `RecordingConsentTasks/.../rest/Troubleshooting*.java` | Direct-injection endpoints (`:9095`) |
| `DcpChangeManager/.../troubleshooting/DcpChangeManagerTroubleshooter.java` | Change-request state manipulation (`:8121`) |
| `RecordingConsentApiServer/.../rest/TroubleshootingDataCaptureProfile.java` | DCP profile read/assign (`:7254`) |
| `HF/ConsentProfile/.../callschedulingupdated/ConsentCallSchedulingUpdatedConsumer.java` | The Call Scheduling → Consent hand-off consumer |
| `RecordingConsentTasks/.../dao/`, `service/` | The DAOs that write the owned tables (see [[05 - Data Access & Storage#4. DAOs → DB access → schema|§4]]) |

> Related: [[05 - Data Access & Storage]] · [[02 - Data Flow]] · [[Subsystems/Call Scheduling/06 - Local Dev Seed Data|Call Scheduling — Seed Data]]
