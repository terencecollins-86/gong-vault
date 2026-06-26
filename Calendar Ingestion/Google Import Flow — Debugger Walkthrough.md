---
title: Google Import Flow — Debugger Walkthrough
tags:
  - calendar-ingestion
  - google
  - debugger
  - breakpoints
  - data-flow
created: 2026-06-26
aliases:
  - google import debugger
  - ImportGoogleCalendarEventsTask walkthrough
---

# Google Import Flow — Debugger Walkthrough

> [[_dashboard|← Team Hub]] · [[02 - Data Flows]] · [[Entrypoints Within the Calendar System]] · [[Swagger Trigger Runbook]]

Step-by-step call chain for `ImportGoogleCalendarEventsTask` — from scheduled trigger to MongoDB write + Kafka hand-off to the indexer. Each numbered step is a recommended breakpoint location.

---

## The three-phase mental model

```
Phase 1 — Fan-out (Supervisor)
  Scheduled task → enumerate companies/users → produce one Kafka command per user
  
Phase 2 — Fetch & persist (GoogleCalendarIngester)
  Consume command → call Google Calendar API → dedup → save CalendarEventDocument to MongoDB
  → produce calendar-meeting-upsert-requests

Phase 3 — Index (MeetingsIndexer)
  Consume upsert → enrich with CRM → write to OpenSearch MEETINGS index
  → produce meetings-indexed
```

> **Tip:** for your first debugging session, set breakpoints at steps **1, 4, 7, 9, 12** — you'll see the handoff across all three phases without drowning in detail.

---

## Phase 1 — Fan-out (runs in IngesterCalendarSupervisor)

### Step 1 · Scheduled task fires

|                 |                                                                                                                             |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **File**        | `IngesterCalendarSupervisor/…/scheduledTasks/ImportCalendarTasks.java`                                                      |
| **Breakpoint**  | `ImportGoogleCalendarEventsTask` bean method — the lambda `() -> importer.importAllCompaniesForProvider(GOOGLE_APPS)`       |
| **Dev cadence** | Every **4 hours** (EVERY_15_MINUTES_1 in prod). If you don't want to wait, use the [[Swagger Trigger Runbook]] to force it. |

```java
// Line 52 — the task definition
return ScheduledTask.create("ImportGoogleCalendarEventsTask",
    () -> importer.importAllCompaniesForProvider(GOOGLE_APPS),
    new CronTrigger(CronSchedules.EVERY_4_HOURS),
    Duration.ofMinutes(15));
```

**What happens next:** calls `ProviderCompaniesImporter.importAllCompaniesForProvider(GOOGLE_APPS)`.

---

### Step 2 · Retrieve companies enabled for Google Calendar import

|                |                                                                  |
| -------------- | ---------------------------------------------------------------- |
| **File**       | `CalendarCore/…/producer/ProviderCompaniesImporter.java`         |
| **Breakpoint** | `importAllCompaniesForProvider(MailboxProviderCode)` — line ~190 |

Key DB calls before the Kafka fan-out:
- `googleAppsCalendarImportDao.listCompaniesForCalendarImport()` → all companies with Google enabled
- `getCompaniesWithCrmIntegration(companyIds)` → used to set `CompanyContext.isCrmIntegrationEnabled`
- `§(companyIds)`
- `getUsersThatRequireSync(...)` → per-user sync eligibility (optionally parallelised via `PARALLEL_CALENDAR_DB_QUERIES_FF`, 25 threads)

**Note:** this can be expensive for large companies. The full user context map is built here before any Kafka messages go out.

---

### Step 3 · Per-company dispatch (10 threads)

| | |
|---|---|
| **File** | `ProviderCompaniesImporter.java` |
| **Breakpoint** | `importSingleCompany(...)` — line ~494 |

10 parallel threads process companies. For each company:
1. Calls `calendarProvider.updateCompanySyncStart(companyId)` — marks start in DB
2. Processes any pending **deletion requests** first (sends `DELETE_MEETINGS_COMMAND`)
3. Calls `sendImportCommand(IMPORT_COMMAND, companyId, ...)` for each eligible user

---

### Step 4 · Produce per-user Kafka command

| | |
|---|---|
| **File** | `ProviderCompaniesImporter.java` |
| **Breakpoint** | `sendCommand(CalendarCommand, long, long)` — line ~745 |

```java
// For Google (lines 746-754)
googleCalendarCommandsKafkaTemplate.send(
    "google-calendar-commands",   // topic
    String.valueOf(userId),        // partition key — guarantees single-thread per user
    importCommand)
```

The `ImportCommand` payload contains:
- `companyId`, `userId`, `userEmail`
- `userContext` — `shouldRecord`, `shouldImportNonRecordedMeetings`, `shouldScanCalendarForInterviews`
- `companyContext` — `calendarEventsImport` (RECORDED_ONLY vs ALL_EVENTS), `isCrmIntegrationEnabled`
- `scanWindowHours` (default 15 h) — how far forward to fetch events
- `cycleId` — a UUID tying all commands in this fan-out cycle together (useful for log correlation)

> Partition key = `userId` → all commands for the same user land on the same partition → no concurrent processing of the same user.

---

## Phase 2 — Fetch & persist (runs in GoogleCalendarIngester)

### Step 5 · Kafka consumer receives the command

| | |
|---|---|
| **File** | `GoogleCalendarIngester/…/consumer/GoogleCalendarCommandsConsumer.java` |
| **Breakpoint** | the class-level `@KafkaListener` consumer method (delegates immediately to parent) |
| **Concurrency** | 80 threads (`com.honeyfy.ingester.calendar.google.consumer.concurrency`) |

`GoogleCalendarCommandsConsumer extends UserCalendarImporter`. All real logic is in the parent.

---

### Step 6 · Route by command type

| | |
|---|---|
| **File** | `CalendarCore/…/ingest/UserCalendarImporter.java` |
| **Breakpoint** | `accept(ConsumerRecord<String, CalendarCommand>)` — line 92 |

```java
// Line 126 — IMPORT_COMMAND branch
ImportCommand importCommand = (ImportCommand) calendarCommand;
userCalendarImporterLogic.importSingleUserCalendarEvents(
    providerCode, importCommand.commandType, importCommand.companyId,
    importCommand.userId, importCommand.userEmail, importCommand.userContext,
    importCommand.companyContext, importCommand.isImportSecondaryCalendars,
    importCommand.scanWindowHours, importCommand.dataCaptureOwnerEmails, cycleId)
```

Other command types: `BACKFILL_MEETINGS_COMMAND` routes to `calendarMeetingsBackfillService.backfillMeetingsForUser(...)` instead.

---

### Step 7 · The core import decision — which path?

| | |
|---|---|
| **File** | `CalendarCore/…/ingest/UserCalendarImporterLogic.java` |
| **Breakpoint** | `importSingleUserCalendarEvents(...)` — line 74 |

**Time window set here:**
- `from = now - 15 minutes` (look-back to catch changes just before the cycle)
- `to = now + scanWindowHours` (default: `now + 15h`)

**Branch logic (lines 106–122):**

```java
if (userContext.shouldRecord || userContext.shouldScanCalendarForInterviews) {
    callsEventsImportLogic.importEvents(...)   // ← RECORDED path (meetings that become calls)
}
if (companyContext.calendarEventsImport == ALL_EVENTS && userContext.shouldImportNonRecordedMeetings) {
    allEventsImportLogic.importEvents(...)     // ← ALL_EVENTS path (non-recorded meetings too)
}
```

Both paths can run for the same user. They share the same `providerEvents` list but write to different MongoDB collections and use different downstream handling.

> **Important:** If `userContext` is `null` (legacy path), `callsEventsImportLogic` always runs.

The `DELETE_MEETINGS_COMMAND` path (line 124) calls `allEventsImportLogic.importEvents(session, false, emptyList())` — the empty list triggers deletion of all the user's meetings.

---

### Step 8 · Fetch events from Google Calendar API

Called from inside `getProviderEvents(...)` — line 101 of `UserCalendarImporterLogic`.

The Google provider:
1. Gets OAuth access token for the user
2. Calls `Google Calendar API events.list(...)` with the `from`/`to` time window
3. Paginates through results
4. Returns `List<CalendarEvent>` — the raw provider objects

---

### Step 9 · Dedup, resolve transitions, persist to MongoDB

| | |
|---|---|
| **File** | `CalendarCore/…/ingest/EventsImportLogicBase.java` |
| **Breakpoint** | `importEvents(UserImportSession, boolean, List<CalendarEvent>)` — line 129 |

Key steps:
1. **Convert** `CalendarEvent` → `CalendarEventDocument` (MongoDB document shape)
2. **Compare** against existing MongoDB state → `EventTransitionResolver` determines if each event is NEW / UPDATED / UNCHANGED / DELETED
3. **For each event** → `handleEvent(session, eventTransitionResolver)` → routes to subclass (`CallsEventsImportLogic` or `AllEventsImportLogic`)
4. **Persist** the event to MongoDB `calendar_events` collection via `CalendarEventsDao`
5. **Update mirror** — `all_calendar_events` collection
6. **Log history** — `CALENDAR_EVENTS_HISTORY` OpenSearch index

---

### Step 10 · Meeting processing & call scheduling

|                |                                                                                  |
| -------------- | -------------------------------------------------------------------------------- |
| **File**       | `CalendarCore/…/meetings/CalendarMeetingsProcessor.java`                         |
| **Breakpoint** | `processMeeting(UserImportSession, IngesterResult, CalendarEventFlow)` — line 63 |

What happens here:
1. **Block list check** — skip indexing if company blocked
2. **Convert** `CalendarEventDocument` → `MeetingIndexDto` (the OpenSearch shape)
3. **CRM association lookup** — annotate with CRM data if available
4. **Determine delete flag** — no CRM match → `toDelete = true`
5. **Guard rail** — skip if `meetingId.length() > 512` (OpenSearch limit)

For `CallsEventsImportLogic`: also sends `call-scheduling-requests` to Call Scheduler v2 here.

---

### Step 11 · Produce `calendar-meeting-upsert-requests`

| | |
|---|---|
| **File** | `CalendarMeetingsProcessor.java` |
| **Breakpoint** | the `kafkaTemplateUpsertMeetings.send(...)` call — line ~188 |

```java
kafkaTemplateUpsertMeetings.send(
    "calendar-meeting-upsert-requests",  // topic
    calendarEventDocument.meetingId,      // partition key
    upsertMsg)                            // MeetingUpsertFromCalendarIngest payload
```

The `MeetingUpsertFromCalendarIngest` contains a `MeetingIndexDto` — the complete meeting record ready to index, including CRM associations, invitees, workspace IDs, and the `toDelete` flag.

---

## Phase 3 — Index (runs in MeetingsIndexer)

### Step 12 · Consume upsert request

| | |
|---|---|
| **File** | `MeetingsIndexer/…/consumer/MeetingUpsertRequestsConsumer.java` |
| **Breakpoint** | `acceptWithResult(ConsumerRecord<String, MeetingUpsertFromCalendarIngest>)` |

---

### Step 13 · Write to OpenSearch MEETINGS index

| | |
|---|---|
| **File** | `MeetingsIndexer/…/MeetingIndexerService.java` |
| **Breakpoint** | `indexMeetingsByOrder(...)` |

- If `toDelete == true` → delete from index
- Otherwise → upsert into `MEETINGS` index
- Produces `meetings-indexed` event for downstream consumers (search, CRM, forecasting)

---

## Full call chain summary

```
[Supervisor] ImportCalendarTasks.ImportGoogleCalendarEventsTask (lambda)
    └─ ProviderCompaniesImporter.importAllCompaniesForProvider(GOOGLE_APPS)
        └─ importSingleCompany(...)                        [×10 threads, one per company]
            └─ sendImportCommand(IMPORT_COMMAND, ...)
                └─ sendCommand() → Kafka: "google-calendar-commands" [key=userId]

[GoogleCalendarIngester] GoogleCalendarCommandsConsumer (×80 threads)
    └─ UserCalendarImporter.accept(kafkaRecord)
        └─ userCalendarImporterLogic.importSingleUserCalendarEvents(...)
            ├─ getProviderEvents() → Google Calendar API (OAuth + paginate)
            ├─ [if shouldRecord] callsEventsImportLogic.importEvents(...)
            │     └─ EventsImportLogicBase.importEvents(...)
            │           ├─ CalendarEventDocument dedup + transition resolution
            │           ├─ CalendarMeetingsProcessor.processMeeting(..., CALL)
            │           │     ├─ Kafka: "call-scheduling-requests"
            │           │     └─ Kafka: "calendar-meeting-upsert-requests" [key=meetingId]
            │           └─ MongoDB: upsert calendar_events + meeting + mirror
            └─ [if ALL_EVENTS + shouldImportNonRecordedMeetings] allEventsImportLogic.importEvents(...)
                  └─ (same shape as above, writes to all_calendar_meetings)

[MeetingsIndexer] MeetingUpsertRequestsConsumer
    └─ MeetingIndexerService.indexMeetingsByOrder(...)
        ├─ OpenSearch: upsert/delete MEETINGS index
        └─ Kafka: "meetings-indexed"
```

---

## Key data structures at each hop

| Hop | Structure | What it contains |
|-----|-----------|-----------------|
| Supervisor → Google ingester | `ImportCommand` | `companyId`, `userId`, `userEmail`, `userContext` (shouldRecord, shouldImportNonRecorded), `companyContext` (ALL_EVENTS vs RECORDED_ONLY), `scanWindowHours`, `cycleId` |
| Google API → code | `CalendarEvent` | Raw provider event (UID, title, times, organizer, attendees, etag) |
| In-memory dedup | `CalendarEventDocument` | Parsed + normalised MongoDB document |
| Google ingester → MeetingsIndexer | `MeetingUpsertFromCalendarIngest` → `MeetingIndexDto` | Full meeting record: invitees, workspace IDs, CRM associations, `toDelete` flag |
| MeetingsIndexer → downstream | `meetings-indexed` event | Meeting ID + indexed state |

---

## Gotchas to watch

| Situation | What you'll see | Why |
|-----------|----------------|-----|
| Breakpoint at step 7 never routes to `callsEventsImportLogic` | Both `shouldRecord` and `shouldScanCalendarForInterviews` are false | User's company has recording disabled; try with a company/user that has recording enabled |
| Meeting is fetched but never produces to `calendar-meeting-upsert-requests` | `processMeeting` returns early | Block list check or `meetingId.length() > 512` |
| `calendar-meeting-upsert-requests` produced but MeetingsIndexer doesn't index | `toDelete == true` in the payload | Meeting has no CRM match — check `isCrmIntegrationEnabled` on `CompanyContext` |
| Commands produced but GoogleCalendarIngester never fires | Consumer group lag | 80-thread consumer pool, but if events pile up the consumer may be behind |
| `DELETE_MEETINGS_COMMAND` in step 6 instead of `IMPORT_COMMAND` | Company has a pending deletion request | Normal — deletion requests are processed before imports in each cycle |

---

## See also

- [[Entrypoints Within the Calendar System]] — how to trigger each step manually
- [[Swagger Trigger Runbook]] — force a single-company import without waiting for the timer
- [[02 - Data Flows]] — Kafka topic map (who reads/writes what)
- [[Storage & Schema Reference]] — MongoDB collections and PostgreSQL tables touched by this flow
- [[Meeting Ingestion Architecture]] — canvas diagram of the full system
