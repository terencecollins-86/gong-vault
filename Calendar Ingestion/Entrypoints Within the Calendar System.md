# Entrypoints Within the Calendar System

Walkthrough for triggering each calendar-ingestion entrypoint locally and hitting a breakpoint,
one at a time. Run the subsystem locally first:
`gong-module-run --debug up --subsystem-names gong-ingestion`

> ⚠️ **Honesty note:** breakpoints below are keyed to **class + method** (verified from the code
> map), not line numbers — open the class and set the breakpoint on the named method, then write
> the line number back into this doc the first time you do it. The local ports are from the
> `.run/*.run.xml` Embedded-Tomcat configs.

## Local services & ports

| Service | Local base URL | Context path |
|---|---|---|
| IngesterCalendarSupervisor | `http://localhost:8885` | none (`routingPrefix: ""`) |
| OfficeCalendarIngester | `http://localhost:8886` | none |
| GoogleCalendarIngester | `http://localhost:8887` | none |
| MeetingsIndexer | `http://localhost:9921` | none |

- **Auth:** none locally — internal-only services, no app-level auth filter on localhost.
- **Where the HTTP surface is:** almost everything is on the **Supervisor** (`:8885`). The two
  provider ingesters and MeetingsIndexer only expose `HomeController` (Swagger redirect) over
  HTTP — they're driven by Kafka, so you trigger them by producing to their command topics.

## The two ways work enters the system

- **Scheduled fan-out (primary)** — the Supervisor's `ImportGoogle/OfficeCalendarEventsTask`
  run every ~15 min, enumerate enabled companies/users, and **produce import commands** to
  `google-calendar-commands` / `office-calendar-commands`. Entrypoints #1 and #4 below.
- **Per-user import (Kafka)** — the provider ingesters consume those commands and call the
  provider API. Entrypoint #5.

Then meetings flow on to MeetingsIndexer via `calendar-meeting-upsert-requests` (#6).

---

## 1. Heartbeat — zero-arg smoke test

First entrypoint on purpose: proves the local-debug loop (scheduled-task executor → your
breakpoint) is working without any external dependency.

| | |
|---|---|
| **Type** | Distributed scheduled task (no HTTP) |
| **Class** | `SimpleHeartbeatTask` (present in every service) |
| **Breakpoint** | the task's `run()` / execute method — logs "Hello!" |
| **How to trigger** | Just start the service; it fires every ~1 min (prod cadence; longer in dev). |

If the breakpoint hits, your scheduled-task wiring is alive. Then move to a real entrypoint.

---

## 2. Trigger a manual import for a company — the most useful entrypoint

The on-demand twin of the scheduled fan-out. Drives the same import path for a single company
without waiting for the 15-minute timer.

| | |
|---|---|
| **Service** | Supervisor (`:8885`) |
| **Controller** | `TroubleshootingCalendarEventsApiController` |
| **Breakpoint** | the import-trigger handler method (the one that enqueues an import for the given company) |
| **File** | `IngesterCalendarSupervisor/src/main/java/com/honeyfy/ingester/calendar/supervisor/rest/TroubleshootingCalendarEventsApiController.java` |

Find the exact path + params from Swagger (`http://localhost:8885/swagger-ui/index.html`), set a
company id you have locally, and watch the command get produced. Step into the producer
(`ProviderCompaniesImporter` in `CalendarCore`) to follow the fan-out.

---

## 3. Send an import/backfill Kafka command by hand

Bypasses the scheduler entirely and lets you craft the exact command the provider ingester will
consume.

| | |
|---|---|
| **Service** | Supervisor (`:8885`) |
| **Controller** | `TroubleshootingCalendarKafkaMessages` |
| **Breakpoint** | the send-command handler |
| **Produces to** | `google-calendar-commands` / `office-calendar-commands` (an `ImportCommand` / `BackfillMeetingsCommand` from `CalendarIngesterCommon`) |

Use this to drive entrypoint #5 (the provider consumer) with a known payload.

---

## 4. Scheduled import fan-out (the real periodic path)

The production trigger that #2/#3 shadow.

| | |
|---|---|
| **Service** | Supervisor (`:8885`) |
| **Class** | `ImportCalendarTasks` → `ImportGoogleCalendarEventsTask` / `ImportOfficeCalendarEventsTask` |
| **Breakpoint** | the task execute method, then step into `ProviderCompaniesImporter` |
| **How to trigger** | Wait for the timer, or use #2 to force one company through the same code on demand. |

---

## 5. Provider import command consumer (Google / Office) — the real fetch path

Where a command becomes an actual provider API call.

| | |
|---|---|
| **Type** | Kafka consumer (no HTTP) |
| **Google** | `GoogleCalendarCommandsConsumer` (`:8887`), topic `google-calendar-commands`, cluster `CALENDAR_INGESTER` |
| **Office** | `OfficeCalendarCommandsConsumer` (`:8886`), topic `office-calendar-commands`, cluster `CALENDAR_INGESTER` |
| **Breakpoint** | the consumer's `accept(...)` / import method (both extend `UserCalendarImporter`) → then step into `UserCalendarImporterLogic` in `CalendarCore/.../ingest/` |
| **How to trigger** | Produce a command via #3, or let #2/#4 produce it. Set the breakpoint first. |

This is the single-user fetch+import path: provider auth → fetch events → filter/dedup → persist
`CalendarEventDocument` to MongoDB → produce `calendar-meeting-upsert-requests`.

---

## 6. Meeting upsert → index (the sink)

Where a meeting lands in OpenSearch.

| | |
|---|---|
| **Service** | MeetingsIndexer (`:9921`) |
| **Type** | Kafka consumer (no HTTP) |
| **Consumer** | `MeetingUpsertRequestsConsumer`, topic `calendar-meeting-upsert-requests`, cluster `CALENDAR_INGESTER` |
| **Breakpoint** | the consumer handler → `MeetingIndexerService.indexMeetingsByOrder()` |
| **How to trigger** | Let #5 produce the upsert, or produce a `calendar-meeting-upsert-requests` message directly. |

Companion consumers on the same service (set breakpoint on each `accept`, produce to its topic):

| Consumer | Topic | Cluster |
|---|---|---|
| `meetings-crm-association-updated-consumer` | `association-updated` | ACTIVITY_CRM_ASSOCIATIONS |
| `meetings-call-scheduler-updated-consumer` | `call-scheduling-updated` | CALL_SCHEDULER_V2 |

---

## Companion Postman collection (to create)

Telephony has a `IngesterTelephonySystemsSupervisor.postman_collection.json`. The calendar
equivalent doesn't exist yet — once the Supervisor's troubleshooter paths are confirmed from
Swagger, build a `IngesterCalendarSupervisor.postman_collection.json` with the request folders
matching the entrypoints above, and drop it under `Calendar Ingestion/Postman Collections/`
(mirroring the Telephony layout).
