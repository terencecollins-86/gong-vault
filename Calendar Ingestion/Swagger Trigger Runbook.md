---
title: Calendar Ingestion — Swagger Trigger Runbook (local debug)
tags: [calendar-ingestion, runbook, debugging, swagger, breakpoints]
created: 2026-06-25
---

# Swagger Trigger Runbook — hit a breakpoint locally

> [[_dashboard|← Team Hub]] · see also [[Entrypoints Within the Calendar System]] · [[02 - Data Flows]]

Step-by-step for driving the 4 locally-running calendar services from Swagger to a breakpoint.
Every fact below was read from source — file + class + method are cited so you set the breakpoint
on the right line yourself (line numbers drift; method names don't).

**Services running** (from your `up` command):
`officecalendaringester, googlecalendaringester, ingestercalendarsupervisor, meetingsindexer`

```
gong-module-run up --image-names officecalendaringester,googlecalendaringester,ingestercalendarsupervisor,meetingsindexer
```

---

## ⚠️ Read this first — three real gotchas

1. **These are query-param endpoints, not JSON bodies.** Every handler uses `@RequestParam`, so in
   Swagger you fill in form fields and the call goes out as a query string. There is no request body.
2. **All the HTTP surface is on the Supervisor** (`ingestercalendarsupervisor`). The two provider
   ingesters and MeetingsIndexer expose only a Swagger redirect over HTTP — they're **Kafka-driven**.
   You reach their breakpoints by producing a command from the Supervisor (steps 2–4), not by calling them.
3. **Breakpoints in the K8s pod ≠ your local JVM.** If you're on the hybrid runner, a Swagger call
   only stops in your debugger when the intercept routes the request to your local process. Confirm your
   `gong-module-run --debug`/intercept is active for the service you're breaking in. (This is the exact
   trap from the telephony session — Swagger was hitting the pod, not the JVM.)

**Local base URLs** (Embedded-Tomcat ports from `.run/*.run.xml`; `routingPrefix: ""`, no context path):

| Service | Swagger UI |
|---|---|
| IngesterCalendarSupervisor | `http://localhost:8885/swagger-ui/index.html` |
| OfficeCalendarIngester | `http://localhost:8886/swagger-ui/index.html` |
| GoogleCalendarIngester | `http://localhost:8887/swagger-ui/index.html` |
| MeetingsIndexer | `http://localhost:9921/swagger-ui/index.html` |

> Auth: locally there's no app-auth filter, so the `/troubleshooting/**` paths are callable directly.
> In a real env they need VPN + troubleshooter JWT cookie.

---

## The order to trigger (each step feeds the next)

```
[1] Supervisor /troubleshooting//sync/company   ─┐
    or  /troubleshooting/calendar-import/user     ├─► produces google|office-calendar-commands
                                                  ─┘
[2] Google/OfficeIngester  UserCalendarImporter.accept()  ─► fetch + import + persist Mongo
                                                          ─► produces calendar-meeting-upsert-requests
[3] MeetingsIndexer  MeetingUpsertRequestsConsumer.acceptWithResult()  ─► index to OpenSearch
```

Pick **one** entrypoint in step 1. The `/sync/*` pair is the simplest; the `/calendar-import/user`
pair gives you full control over the command payload (scan window, azure user, etc.).

---

## Step 1 — Trigger an import (Supervisor, `:8885`)

You have **four** Swagger operations to choose from. All are `POST`, all query-param.

### 1a. Sync a whole company — simplest

| | |
|---|---|
| **Method / Path** | `POST /troubleshooting//sync/company` |
| **Swagger tag** | `troubleshooting-calendar-events-api` |
| **Params** | `companyId` (long), `mailboxProviderCode` (`GOOGLE_APPS` \| `OFFICE365`) |
| **File** | `IngesterCalendarSupervisor/.../rest/TroubleshootingCalendarEventsApiController.java` |
| **Breakpoint** | `TroubleshootingCalendarEventsApiController.syncCompanyCalendarEvents(...)` |

> The double slash in the path is real — `Troubleshooting.CONTROLLER` is `"/troubleshooting/"` and the
> sub-path re-prepends it (`IngesterCalendarUrls.java`). Use exactly what Swagger shows.

Example call:
```
POST http://localhost:8885/troubleshooting//sync/company?companyId=<COMPANY_ID>&mailboxProviderCode=GOOGLE_APPS
```

### 1b. Sync a single user — note the param name differs

| | |
|---|---|
| **Method / Path** | `POST /troubleshooting//sync/user` |
| **Params** | `companyId` (long), `email` (string), `providerCode` (`GOOGLE_APPS` \| `OFFICE365`) |
| **Breakpoint** | `TroubleshootingCalendarEventsApiController.syncUserCalendarEvents(...)` |

> ⚠️ The provider param here is `providerCode`, but in 1a it's `mailboxProviderCode`. Same enum, different
> field name — Swagger will show the correct one per operation.

```
POST http://localhost:8885/troubleshooting//sync/user?companyId=<COMPANY_ID>&email=<USER_EMAIL>&providerCode=GOOGLE_APPS
```

### 1c. Send a per-user import command — full control over the payload

Use this when you want to set the scan window, admin user, or azure user id explicitly.

| | |
|---|---|
| **Method / Path** | `POST /troubleshooting/calendar-import/user` |
| **Swagger tag** | `troubleshooting-calendar-kafka` |
| **File** | `IngesterCalendarSupervisor/.../rest/TroubleshootingCalendarKafkaMessages.java` |
| **Breakpoint** | `TroubleshootingCalendarKafkaMessages.sendCommand(...)` (the 7-arg user overload) — step into `ProviderCompaniesImporter.sendImportCommand(...)` |

Params (all query):

| Param | Type | Required | Notes |
|---|---|---|---|
| `companyId` | long | yes | |
| `userId` | long | yes | resolved via `userService.readAppUserById` |
| `adminUserId` | long | no (default `0`) | |
| `isCompanyConnection` | boolean | yes | |
| `azureUserId` | string | **yes for OFFICE365** | throws "Missing azure user id" if null for Office |
| `calendar provider` | `GOOGLE_APPS` \| `OFFICE365` | yes | param name literally contains a space |
| `scan window hours` | int | yes | param name literally contains spaces |

```
POST http://localhost:8885/troubleshooting/calendar-import/user?companyId=<CID>&userId=<UID>&isCompanyConnection=true&calendar%20provider=GOOGLE_APPS&scan%20window%20hours=24
```

### 1d. Send a company import command

| | |
|---|---|
| **Method / Path** | `POST /troubleshooting/calendar-import/company` |
| **Params** | `companyId` (long), `calendar provider` (`GOOGLE_APPS` \| `OFFICE365`) |
| **Breakpoint** | `TroubleshootingCalendarKafkaMessages.sendCommand(...)` (the 2-arg company overload) |

---

## Step 2 — Provider ingester consumes the command

Whichever provider you chose in step 1, its ingester now consumes the produced command off Kafka.
**Set this breakpoint before step 1 fires** so you catch the message.

| | |
|---|---|
| **Google** | `GoogleCalendarCommandsConsumer` (`:8887`), topic `google-calendar-commands` |
| **Office** | `OfficeCalendarCommandsConsumer` (`:8886`), topic `office-calendar-commands` |
| **Cluster** | `CALENDAR_INGESTER` |
| **Breakpoint** | `UserCalendarImporter.accept(ConsumerRecord<String, CalendarCommand>)` — both consumers extend it |
| **File** | `CalendarCore/.../ingest/UserCalendarImporter.java` |

From `accept()` step into the import logic to follow: provider auth → fetch events → filter/dedup →
persist `CalendarEventDocument` to MongoDB → produce `calendar-meeting-upsert-requests`.

---

## Step 3 — MeetingsIndexer indexes the meeting (the sink)

| | |
|---|---|
| **Service** | MeetingsIndexer (`:9921`) |
| **Consumer** | `MeetingUpsertRequestsConsumer`, topic `calendar-meeting-upsert-requests`, cluster `CALENDAR_INGESTER` |
| **Breakpoint** | `MeetingUpsertRequestsConsumer.acceptWithResult(List<ConsumerRecord<...>>)` → step into `MeetingIndexerService` |
| **File** | `MeetingsIndexer/.../consumer/MeetingUpsertRequestsConsumer.java` |

This consumer is batch-based (`ResultBasedMultipleRecordConsumer`) — you get a `List` of records, not one.

---

## Quick smoke test (no external dependency)

If you just want to prove the local-debug loop works before wiring up a real company:
set a breakpoint on `SimpleHeartbeatTask`'s run/execute method (present in every service) and start the
service — it fires on the scheduled-task cadence. Breakpoint hits ⇒ your debug wiring is live.

---

## What still needs your eyes

- **Line numbers** — set the breakpoint on the named method, then write the line back here the first time.
- **A real `companyId` / `userId` / `email`** that exists in your local Mongo/RDS. The telephony work hit
  an empty local DB; if `readAppUserById`/`getCompanyForCalendarImport` returns nothing, seed data first.
- A companion `IngesterCalendarSupervisor.postman_collection.json` doesn't exist yet (telephony has one).
  Once you've confirmed these 4 ops in Swagger, that's the natural next artifact.
