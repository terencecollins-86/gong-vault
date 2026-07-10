---
title: Calendar Ingestion — Storage & Schema Reference
tags: [calendar-ingestion, storage, database, postgres, mongodb, opensearch, redis, schema]
created: 2026-06-25
---

# Storage & Schema Reference

> [[_dashboard|← Team Hub]] · [[System Diagram]] · [[02 - Data Flows]] · [[01 - Architecture & Modules]]

Every datastore the four calendar services touch, the **logical databases** they connect to, and the
**tables / collections / indexes** by schema. Sourced from the `*.gong-app-descriptor.yaml` datasource
blocks (connections + access level) and the SQL/DAO code (actual table & collection names).

> ⚠️ **Ownership caveat (important):** the calendar services *connect to* several Postgres logical DBs
> but **own only the `calendar` schema**. Tables under `public`, `googleapps_integration`,
> `office365_integration`, and `connectivity` are owned by other services — calendar reads (and a few
> it updates) them but does **not** define their DDL. There are **no `CREATE TABLE` statements in this
> repo**. The system's *own* calendar data lives in **MongoDB + OpenSearch**, not Postgres.

---

## 1. Datastore connections (from app-descriptors)

All four services declare the same four backends. Access differs slightly per service.

| Datastore | Logical DB / cluster | Supervisor | Google | Office | MeetingsIndexer |
|---|---|---|---|---|---|
| **Postgres (Aurora)** | `OPERATIONAL` | RW | RW | RW | RW |
| | `INGESTER` | RW | RW | RW | RW |
| | `RECRUITING` | RO | RO | RO | — |
| | `RECORDING_CONSENT` | RW | RW | RW | RW |
| **MongoDB (DocumentDB)** | `CALENDAR_EVENTS` | RW | RW | RW | RW |
| **OpenSearch (ES)** | `CALENDAR_EVENTS_HISTORY` | RW | RW | RW | RW |
| | `MEETINGS` | RW | — *(commented out)* | — *(commented out)* | RW |
| **Redis** | `INGESTER_REDIS` | RW | RW | RW | — |
| | `GONG_PROD` | RW | RW | RW | RW |
| | `CIRCUIT_BREAKERS` | RO | RO | RO | RO |

> The provider ingesters have `MEETINGS` **commented out** in their descriptors — they hand meetings to
> MeetingsIndexer via Kafka (`calendar-meeting-upsert-requests`) rather than writing the index directly.
> `GONG_PROD` Redis carries a `#todo: remove` note — it "belongs to call scheduling".

---

## 2. PostgreSQL — tables by schema

Tables grouped by the schema they live under (extracted from every `.sql` file in the repo).

### 🟢 `calendar` — **owned by calendar services** (read + write)
| Table | Used for |
|---|---|
| `calendar.calendar_deletion_requests` | Delayed (24h) company/user meeting-deletion requests — created, polled, marked done |
| `calendar.meeting_backfill_tasks` | Backfill-task state machine (upsert / state transitions / delete / retry) |

### 🔵 `googleapps_integration` — owned by Google integration (calendar reads)
| Table | Used for |
|---|---|
| `googleapps_integration.appuser_settings` | Per-user Google calendar import settings |
| `googleapps_integration.googleapps_preferences` | Company Google import preferences |

### 🔵 `office365_integration` — owned by Office integration (calendar reads + some writes)
| Table | Used for |
|---|---|
| `office365_integration.azure_user` | Azure AD user records (sync, delete-redundant) |
| `office365_integration.company_settings` | Office company import settings |
| `office365_integration.company_application_settings` | Office app-level connection settings |

### 🔵 `connectivity` — owned by provider-connectivity (calendar reads/writes status)
| Table | Used for |
|---|---|
| `connectivity.appuser_sync_status` | Per-user mailbox/calendar sync status (admin-fallback queries fill/delete rows) |

### 🔵 `public` — shared core schema (calendar reads)
| Table | Used for |
|---|---|
| `public.appuser` | App users (email → user resolution) |
| `public.company` | Company records |
| `public.company_settings` | Company-level settings |
| `public.workspace_settings` | Workspace retention / meeting settings |
| `public.call` | Calls (call-id association to meetings) |
| `public.invitee` | Meeting invitees |
| `public.collaborator` | Meeting collaborators |
| `public.workspace` | Workspaces |

> Logical-DB → schema mapping is by Aurora connection, not 1:1 by name. The `calendar` schema sits in
> the `INGESTER` logical DB; `public` / `*_integration` / `connectivity` are reached via `OPERATIONAL`.
> Confirm the exact DB for a given schema with `kb_table(action=schema)` before a migration.

---

## 3. MongoDB — `CALENDAR_EVENTS` database (the real event store)

Tenant-isolated collections (DAO constants in `CalendarCore/.../mongo/`):

| Collection | DAO | Holds |
|---|---|---|
| `calendar_events` | `CalendarEventsDao` | Per-user imported `CalendarEventDocument`s — the primary raw store |
| `all_calendar_events` | `AllEventsMirrorDao` | All-events mirror cache (cross-user view) |
| `calendar_meetings` | `CalendarMeetingsDao` | Derived meetings |
| `all_calendar_meetings` | `AllMeetingsMirrorDao` | All-meetings mirror cache |
| `deleted_meetings` | `DeletedMeetingsDao` | Tombstones for deleted meetings |

> The mirror collections (`all_*`) are the ones the `/troubleshooting/calendar-mirror/**` and
> `…/calendar-all-events-mirror/**` endpoints manage. See [[Troubleshooting Endpoints Catalog]].

---

## 4. OpenSearch — indexes

| Index (logical) | Schema class | Holds | Writers |
|---|---|---|---|
| `MEETINGS` | `EsMeetingSchema` | Queryable indexed meetings (the system sink) | MeetingsIndexer, Supervisor |
| `CALENDAR_EVENTS_HISTORY` | — | Event-history audit trail | all four services |

> `MEETINGS` is written via `MeetingIndexerService` / `MeetingsIndexMetaClient`. The provider ingesters
> do **not** write it directly (commented out in their descriptors).

---

## 5. Redis — logical databases

| Logical DB | Access | Used for |
|---|---|---|
| `INGESTER_REDIS` | RW (not MeetingsIndexer) | Ingester working state / coordination |
| `GONG_PROD` | RW | Legacy call-scheduling state (`#todo: remove`) |
| `CIRCUIT_BREAKERS` | RO | Circuit-breaker state for provider calls |

---

## What I did not verify

- **Column-level schemas / PKs / FKs** — not extracted here (this is a table inventory). For columns,
  run `kb_table(table="calendar.meeting_backfill_tasks", action="schema")` (and similar) — that's the
  authoritative source and resolves the logical-DB → physical-schema mapping.
- **Exact Aurora logical-DB for each non-`calendar` schema** — inferred from access patterns; confirm
  via KB before relying on it for a migration or a cross-service change.
- Whether every `public.*` table is read-only to calendar — most are reads, but confirm per table.
