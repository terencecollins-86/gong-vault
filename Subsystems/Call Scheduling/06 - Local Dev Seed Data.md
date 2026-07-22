---
tags: [call-scheduling, local-dev, seed-data, runbook]
---

# Local Dev Seed Data — Call Scheduler

Getting a successful end-to-end flow locally requires seeding six tables in the right order. This doc covers the minimum seed sequence, a ready-to-fire `CallSchedulingRequest` payload, expected happy-path outcomes, and common failure modes.

> **Flow targeted**: Path E — `NEW_CALL` (no existing call → INSERT into `public.call`). Two payloads are given: an **email** mechanism (`CALENDAR_SYNC_EMAIL`, simplest) and the **largest happy path** (`CALENDAR_INGESTER`, runs the full validator chain + writes `updated_calendar_event`). Use the ingester payload to see all 6 verification rows land.

---

## Why This Matters

The Call Scheduler is a stateful, event-driven service. Almost every meaningful code path — creating a call, rescheduling it, cancelling it — depends on rows existing across **six tables in two databases** before a single Kafka message can be processed successfully. Without that data the service throws, returns silent skip codes, or silently no-ops, giving no indication of what's missing.

This makes local development frustrating: you send an event, nothing happens, and the only feedback is a buried log line like `User not found. userId=501; companyId=9001`.

**This guide solves that by:**
- Giving you the exact six SQL inserts (in dependency order) to bootstrap a working local company and user
- Providing a copy-paste `CallSchedulingRequest` JSON payload that passes every validator on the happy path
- Mapping the 30-second verification checklist so you can confirm the call was created end-to-end (Postgres row + two Kafka events)
- Documenting the five most common failure modes with their root cause and one-line fix

Once seeded, you can iterate on the scheduling logic, test edge-case resolution paths, or reproduce production bugs locally — without needing a live calendar sync event or a real company in the system.

---

## Prerequisites

- `gong-call-schedulers` running in the hybrid env on port **8091** (set via `-Dserver.port=8091` in `.run/CallScheduler-hybrid.run.xml`)
- Postgres accessible at `localhost:5432`
  - Operational DB: `honeyfy_dev`
  - Call-scheduler schema: `call_scheduler_dev`
- Redis accessible (hybrid env routes this automatically)

---

## Seed Sequence

All SQL files exist under:
```
gong-call-schedulers/CallScheduler/src/test/resources/sql/NewFlow/
```

Run in this exact order (FK dependencies):

### Step 1 — Company (`honeyfy_dev`)

```sql
-- addCompany.sql
WITH skip_in_reservation_check_for_tests AS (SELECT null)
INSERT INTO public.company (id, name, emaildomain)
VALUES (9001, 'Acme Corp', 'acme-corp.com');
```

### Step 2 — Company Settings (`honeyfy_dev`)

```sql
-- addCompanySettings.sql
INSERT INTO public.company_settings (company_id, robot_name, max_calls_per_min, max_calls_per_day)
VALUES (9001, 'robot', 5, 5);
```

### Step 3 — Workspace (`honeyfy_dev`)

```sql
-- addWorkSpaceToCompany.sql
INSERT INTO public.workspace (id, company_id, name)
VALUES (1001, 9001, 'general');
```

### Step 4 — Data Capture Profile (`honeyfy_dev`)

```sql
-- addConsentProfileForUse.sql
INSERT INTO data_capture.profile (id, company_id)
VALUES (2001, 9001);
```

### Step 5 — App User (`honeyfy_dev`)

```sql
-- addAppUser.sql
WITH skip_in_reservation_check_for_tests AS (SELECT null)
INSERT INTO public.appuser (id, firstname, lastname, active, emailaddress, companyid, data_capture_profile_id, home_workspace_id, should_record)
VALUES (501, 'Alice', 'Acme', TRUE, 'alice@acme-corp.com', 9001, 2001, 1001, TRUE);
```

> **Important**: The email domain must be a real registered TLD (e.g. `.com`, `.io`). The service uses Apache Commons `EmailValidator` which rejects synthetic TLDs like `.test` or `.local`, causing the user lookup to silently return empty without hitting the database.

### Step 6 — Provider Enabled (`honeyfy_dev`)

```sql
-- addProviderToCompanySettings.sql
INSERT INTO public.company_recorder_properties (company_id, call_provider_code, enabled)
VALUES (9001, 'zoom', TRUE);
```

---

## Fire the Flow

Use the existing troubleshooting endpoint to inject a `CallSchedulingRequest` directly onto the Kafka topic:

```
POST http://localhost:8091/troubleshooting/call-scheduling-requests-consumer/sendEventJson
Content-Type: application/json
```

```json
{
  "companyId": 9001,
  "callSchedulingEventType": "CALENDAR_EVENT",
  "callCreationMechanism": "CALENDAR_SYNC_EMAIL",
  "calendarPayload": {
    "userId": 501,
    "emailAddress": "alice@acme-corp.com",
    "provider": "Google",
    "providerEventId": "my-event-id-001",
    "iCalUID": "my-event-id-001@google.com",
    "recurringEventId": null,
    "etag": "etag-001",
    "organizer": {
      "name": "Alice Acme",
      "emailAddress": "alice@acme-corp.com",
      "responseStatus": "ACCEPTED",
      "role": "ORGANIZER"
    },
    "creator": {
      "name": "Alice Acme",
      "emailAddress": "alice@acme-corp.com",
      "responseStatus": "ACCEPTED",
      "role": "ORGANIZER"
    },
    "invitees": [
      {
        "name": "Alice Acme",
        "emailAddress": "alice@acme-corp.com",
        "responseStatus": "ACCEPTED",
        "role": "ORGANIZER"
      },
      {
        "name": "Bob External",
        "emailAddress": "bob@external.com",
        "responseStatus": "NOT_RESPONDED",
        "role": "PARTICIPANT"
      }
    ],
    "startTime": "2026-08-01T14:00:00Z",
    "endTime": "2026-08-01T15:00:00Z",
    "createTime": "2026-07-13T10:00:00Z",
    "lastModifiedTime": "2026-07-13T10:00:00Z",
    "originalStartTime": "2026-08-01T14:00:00Z",
    "summary": "Acme Sync",
    "description": "Join Zoom: https://zoom.us/j/123456789",
    "location": "",
    "additionalMeetingUrls": [],
    "isPrivateOrConfidential": false,
    "isAllDay": false,
    "isCancelled": false,
    "isRecurrent": false,
    "isCrmIntegrationEnabled": false,
    "isMeetingIndexed": false
  }
}
```

> **Key payload requirements** (learned from live debugging):
> - `provider` must be `"Google"` or `"Office"` — the `shortName` from `MailboxProviderCode`, NOT `"GoogleApps"`
> - Invitee fields are `name` + `emailAddress` (Jackson field names), NOT `displayName` + `email`
> - `responseStatus` and `role` are required on every invitee — omitting them causes a NPE in `InviteesContext`
> - The Zoom URL in `description` is required — `CheckUrlValidity` returns `NO_CALL_IN_DETAILS` without it
> - Change `providerEventId` and `iCalUID` for each new test send to avoid `TOO_OLD_REQUEST`

---

## Expected Happy-Path Outcome

After a successful Path E flow, verify:

| #   | What to check                              | Where                                                          | Mechanism |
| --- | ------------------------------------------ | -------------------------------------------------------------- | --------- |
| 1   | Redis lock acquired and released           | Logs: `CallScheduler.9001.<enhancedId>`                        | both      |
| 2   | New row with `status = 'SCHEDULED'`        | `honeyfy_dev` → `public.call`                                  | both      |
| 3   | New row inserted                           | `call_scheduler_dev` → `call_scheduler.scheduled_calls`        | both      |
| 4   | New upsert row                             | `call_scheduler_dev` → `call_scheduler.updated_calendar_event` | **`CALENDAR_INGESTER` only** |
| 5   | `CallSchedulingCalendarEventUpdated` event | Kafka topic `call-scheduling-updated`                          | both      |
| 6   | History event                              | Kafka topic `call-scheduling-history`                          | both      |

> ⚠️ **Row 4 requires a non-email mechanism.** `updated_calendar_event` is written by `updateEventIfNotTooOld()`, gated at `IncomingEventHandler.java:179` by `if (!context.creationMechanism.isEmail())`. `CallCreationMechanism.isEmail()` (in `AppCommon`) returns **true** for `CALENDAR_SYNC_EMAIL`, `OPT_IN_EMAIL`, and `COORDINATOR_EMAIL` — so the email payload above **can never populate row 4**. To exercise it, use the `CALENDAR_INGESTER` payload in the next section.

---

## Largest Happy Path — `CALENDAR_INGESTER` (calendar sync)

The email payload above skips **two whole stages** — the `updated_calendar_event` upsert *and* the 13-validator chain (`IncomingEventHandler.java:179,188`). To drive the **fullest** happy path — the one a real calendar-sync from the ingester takes — send with `callCreationMechanism: "CALENDAR_INGESTER"`. This is the payload to use when you want to see the whole system exercised end-to-end, including all 6 verification rows above.

**What the ingester path adds over the email path** (`EventValidationFactory.java:66` → `generalEventValidation`, 13 validators):

| Validator | Gate in local dev | Satisfied by |
|---|---|---|
| `CheckEventRelevance` | Rejects `MISC_EVENT` / `PRIVATE_OR_CONFIDENTIAL_EVENT` | `isPrivateOrConfidential: false` + a real `summary` (already in payload) |
| `CheckOrganizer` | `CANNOT_IDENTIFY_CALL_OWNER` if organizer ≠ a known appuser | user 501 = organizer (seed step 5) |
| `CheckProviderEnabled` | `CALL_PROVIDER_DISABLED_FOR_COMPANY` | `company_recorder_properties` zoom=TRUE (seed step 6) |
| `CheckUrlValidity` | `NO_CALL_IN_DETAILS` | Zoom URL in `description` |
| `CheckConsentPageEnabled`, `CheckCompliance`, `CheckDoNotRecordUsers`, `CheckDoNotRecordInterviewUsers`, `CheckInternalMeetingAllowed`, `CheckInterviewValidity`, `CheckBlockTitle`, `CheckBlockParticipnat`, `CheckRecordingOnlyFromOrganizerCalendar` | Feature-flag-gated or default-pass — **no-ops** with the standard seed | nothing extra to seed |

> ✅ **The standard 6-row seed already satisfies the full ingester path.** The only "extra" work vs. the email flow is using a fresh `iCalUID`/`providerEventId` (row 4 enforces `TOO_OLD_REQUEST` dedup).

**Payload** — identical to the email one except the mechanism and fresh IDs:

```json
{
  "companyId": 9001,
  "callSchedulingEventType": "CALENDAR_EVENT",
  "callCreationMechanism": "CALENDAR_INGESTER",
  "calendarPayload": {
    "userId": 501,
    "emailAddress": "alice@acme-corp.com",
    "provider": "Google",
    "providerEventId": "ingester-001",
    "iCalUID": "ingester-001@google.com",
    "recurringEventId": null,
    "etag": "etag-ing-001",
    "organizer": {
      "name": "Alice Acme", "emailAddress": "alice@acme-corp.com",
      "responseStatus": "ACCEPTED", "role": "ORGANIZER"
    },
    "creator": {
      "name": "Alice Acme", "emailAddress": "alice@acme-corp.com",
      "responseStatus": "ACCEPTED", "role": "ORGANIZER"
    },
    "invitees": [
      { "name": "Alice Acme", "emailAddress": "alice@acme-corp.com",
        "responseStatus": "ACCEPTED", "role": "ORGANIZER" },
      { "name": "Bob External", "emailAddress": "bob@external.com",
        "responseStatus": "NOT_RESPONDED", "role": "PARTICIPANT" }
    ],
    "startTime": "2026-08-01T14:00:00Z",
    "endTime": "2026-08-01T15:00:00Z",
    "createTime": "2026-07-13T10:00:00Z",
    "lastModifiedTime": "2026-07-13T10:00:00Z",
    "originalStartTime": "2026-08-01T14:00:00Z",
    "summary": "Acme Sync",
    "description": "Join Zoom: https://zoom.us/j/123456789",
    "location": "",
    "additionalMeetingUrls": [],
    "isPrivateOrConfidential": false,
    "isAllDay": false,
    "isCancelled": false,
    "isRecurrent": false,
    "isCrmIntegrationEnabled": false,
    "isMeetingIndexed": false
  }
}
```

**Verify row 4 lands** (the whole point):
```sql
-- call_scheduler_dev
SELECT company_id, enhanced_ical_id FROM call_scheduler.updated_calendar_event WHERE company_id = 9001;
```

> If validation returns an unexpected resolution the email path bypassed, check which validator fired — the resolution enum name maps 1:1 to the table above (e.g. `CANNOT_IDENTIFY_CALL_OWNER` → `CheckOrganizer`).

---

## Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `RuntimeException: User not found. userId=501; companyId=9001` | Step 5 missing | Run `addAppUser.sql` |
| `Resolution: CALL_PROVIDER_DISABLED_FOR_COMPANY` | Step 6 missing | Run `addProviderToCompanySettings.sql` |
| `Resolution: NO_CALL_IN_DETAILS` | No Zoom/Teams/Meet URL in `description` | Add `https://zoom.us/j/123456789` to `description` |
| `Resolution: TOO_OLD_REQUEST` | `updated_calendar_event` row already newer | Use a new `iCalUID` / `providerEventId`, or `DELETE FROM call_scheduler.updated_calendar_event WHERE company_id = 9001` |
| `IllegalArgumentException: Unknown provider shortName: GoogleApps` | Wrong `provider` value | Use `"Google"` or `"Office"` — the `shortName`, not the provider code |
| `Owner is not the event owner: event-owner=Optional.empty` (silent) | Email domain uses `.test` or `.local` TLD | Apache Commons `EmailValidator` rejects synthetic TLDs — use `.com` or `.io` |
| `NullPointerException` in `InviteesContext` | Missing `responseStatus` on invitees | Add `"responseStatus": "ACCEPTED"` and `"role": "ORGANIZER"` to every invitee object |
| `AssertionError: Tried to pull cache entry with null key` | Invitee using `email` field instead of `emailAddress` | Rename to `emailAddress` — `CalendarInvitee` uses Jackson field names, not bean property names |
| Lock stuck | Redis lock TTL 15 min, previous crash | `DEL CallScheduler.9001.<enhancedId>` in Redis CLI |
| INSERT fails with `POSTGRES_LOG_TO_GONG_LOG - DELETE/UPDATE without reservation` | Reservation trigger on `public.company` / `public.appuser` | Wrap DELETE/UPDATE with `WITH skip_in_reservation_check_for_tests AS (SELECT null)` |

---

## Code References

| File | Role |
|------|------|
| `CallScheduler/src/test/resources/sql/NewFlow/` | Source SQL for all 6 seed scripts |
| `…/kafka/consumer/CallSchedulingRequestsConsumer.java` | Kafka entry point — acquires Redis lock, dispatches to handler |
| `…/handler/IncomingEventHandler.java` | Core decision tree (50+ resolution paths) |
| `…/rest/toubleshooting/TroubleshootingCallSchedulingRequestsConsumer.java` | REST shim to inject events without a real Kafka producer |
| `honeyfy/CallScheduling/…/kafka/events/CallSchedulingRequest.java` | Full payload schema |
