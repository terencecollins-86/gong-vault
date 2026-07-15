---
title: Data Access & Storage
tags: [call-scheduling, data-access, database, postgres, redis, opensearch, schema]
---

# Data Access & Storage — Call Scheduling

> [[_dashboard|← Team Hub]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points]] · [[Subsystems/Call Scheduling/Canvas/Data Stores/DataStore-PostgreSQL|PostgreSQL chip]]

**Source of truth: the `Honeyfy/gong-call-schedulers` code** — app descriptors (`*.gong-app-descriptor.yaml`), Flyway migrations (`schema/call_scheduler/db/migration/`), the `@Configuration` DB beans, and the DAO classes. Every claim below is cited to a file.

---

## TL;DR

The subsystem talks to **5 PostgreSQL logical datasources**, **OpenSearch** (3 indices), **Redis** (3 clusters / 2 logical DBs), and **Kafka**. It **owns exactly one Postgres schema — `call_scheduler`** (5 tables, Flyway-managed here). Everything else is **cross-schema access into databases owned by other services** (chiefly the `operational` DB's `public` schema).

| Datastore                    | Access                                  | Owned here?                         | Primary accessor                                   |
| ---------------------------- | --------------------------------------- | ----------------------------------- | -------------------------------------------------- |
| Postgres `CALL_SCHEDULER`    | RW                                      | ✅ **Yes** (schema `call_scheduler`) | `CallSchedulerDb`                                  |
| Postgres `OPERATIONAL`       | RW                                      | ❌ shared                            | `OperationalDb` / `Db`                             |
| Postgres `RECORDING_CONSENT` | RW                                      | ❌ shared                            | via imported library beans                         |
| Postgres `RECRUITING`        | RW (CallScheduler) / RO (InviteHandler) | ❌ shared                            | via `recruiting` library                           |
| Postgres `DATA_CAPTURE`      | RW (declared)                           | ❌ shared                            | declared in descriptor; no direct DAO in this repo |
| OpenSearch                   | RW                                      | ❌ shared                            | MetaClient beans                                   |
| Redis                        | RW/RO                                   | ❌ shared                            | `RedisAccessor` / `JedisAccessor`                  |

---

## 1. PostgreSQL — logical datasources

Datasources are declared per-module in the app descriptors and wired as Spring beans in each module's `@Configuration`.

**Declared datasources** (`CallScheduler.gong-app-descriptor.yaml` → `dataSources.postgres`):

```yaml
postgres:
  OPERATIONAL:        GENERIC_READ_WRITE
  CALL_SCHEDULER:     GENERIC_READ_WRITE
  RECORDING_CONSENT:  GENERIC_READ_WRITE
  RECRUITING:         GENERIC_READ_WRITE
  DATA_CAPTURE:       GENERIC_READ_WRITE
```

`InviteHandlerWebhooksServer.gong-app-descriptor.yaml` declares the same set, except **`RECRUITING: GENERIC_READ_ONLY`**.
`GlobalInviteHandlerWebhooksServer.gong-app-descriptor.yaml` declares **no `dataSources`** — it is a GGE-region forwarder with no database access.

**Bean wiring** (`CallScheduler/.../config/CallSchedulerConfig.java`):
- `OperationalDb.Beans.class` + `CallSchedulerDb.Beans.class` imported (the two DBs with real DAOs).
- An **operational read replica** is tuned: `@Bean(OperationalDbReplica.SETTINGS)` with pool sizing from
  `com.honeyfy.callscheduler.conf.operational.reader.db.settings.{max.total,min.idle}.connections` (default 16 / 8).
- `RecordingConsentDb.DB_RECORDING_CONSENT_SETTINGS_RW` and `RecruitingDb.DB_RECRUITING_SETTINGS_{RW,RO}` beans
  are declared **`@Profile(PROD)` as `DbSettings` only** — there are **no DAOs or `.sql` files** for these in this repo. They exist so imported shared libraries (recording-consent, recruiting) can open connections.

> ⚠️ **`DATA_CAPTURE` nuance**: it appears under `dataSources.postgres` in the descriptors, but no `DataCaptureDb` accessor or SQL is used in this repo. `DATA_CAPTURE` **is** used as a **Kafka cluster** (`KafkaClusterDetails.DATA_CAPTURE_KAFKA_CLUSTER`, `CallSchedulerWebexSyncUsersConsumer.java:62`). Treat the Postgres declaration as provisioned-but-not-directly-accessed from this codebase.

### 1a. Logical → physical DB names (finding these in IntelliJ)

> 🪤 **Gotcha**: the datasource names above (`OPERATIONAL`, `CALL_SCHEDULER`, …) are **logical** names — constants in the `Database` enum (`gong-infra-core/SharedEntities/.../softwaredefinedtopology/db/Database.java`). They are **never** the physical Postgres database names. Searching IntelliJ's active/inactive schema list for "OPERATIONAL" will always come up empty. IntelliJ shows **physical database names**; you have to map through the code first.

The logical→physical mapping for **local dev** is defined by the Flyway configs in `honeyfy/DbConfig/src/main/resources/DbConfig/flyway/<name>/dev.properties`:

| Logical DS (enum) | Physical DB (IntelliJ) | Host | Schema(s) | Tables you'll find | Source (`.../flyway/*/dev.properties`) |
|---|---|---|---|---|---|
| `OPERATIONAL` | **`honeyfy_dev`** | `localhost:5432` | `public` (+ `webex_integration`, `zoom_integration`, `gotomeeting_integration`, `data_capture`, …) | `call`, `appuser`, `company`, `invitee`, `collaborator`, `recurring_event*`, `workspace`, provider `meeting`/`meeting_lookup` | `operational/dev.properties` |
| `CALL_SCHEDULER` | **`call_scheduler_dev`** | `localhost:5432` | `call_scheduler` (+ `public`) | the 5 owned tables (§2) | `call_scheduler/dev.properties` |

**In IntelliJ's Database tool window:**
1. Add / open a data source pointing at `localhost:5432/**honeyfy_dev**` (local creds `postgres` / `postgres`) — this is the `OPERATIONAL` DB. Expand its **`public`** schema for the cross-schema tables in §3.
2. `call_scheduler`'s owned tables live in a **separate physical DB, `call_scheduler_dev`** — add a data source for `localhost:5432/call_scheduler_dev` (or enable **"show all databases"** on a single `localhost:5432` connection so both appear).

> 🐳 **Host differs inside a container**: `localhost:5432` is correct for IntelliJ / psql running **on your Mac**. When you connect **from inside a GCR / Docker container** (e.g. running Flyway or `psql` from an agent shell), Postgres is reached at **`host.docker.internal:5432`** instead — `localhost` resolves to the container itself. Same creds (`postgres`/`postgres`), same DB names.

**Two traps:**
- ❌ **`operational_dev` is the wrong DB.** A legacy migration (`honeyfy/Schema/.../V20170101_0059__CreateOperationalDevDb.java`) creates a database literally named `operational_dev`, but the app + Flyway actually target **`honeyfy_dev`**. Connecting IntelliJ to `operational_dev` shows an empty/stale DB.
- ❌ Don't expect one DB to hold everything — `OPERATIONAL` and `CALL_SCHEDULER` are **two different physical databases** locally, even though both are on `localhost:5432`.

---

## 2. Owned schema — `call_scheduler`

Flyway-managed in `schema/call_scheduler/db/migration/`. Created by `V20220830_0941__new_schema_call_scheduler.sql`, which grants the standard Gong app roles (`gong_app_ro_role` / `gong_app_rw_role`) and default privileges.

**All 5 owned tables have Row-Level Security enabled.** Accessed via the `CallSchedulerDb` beans.

| Table | Primary key | Purpose | Migration |
|---|---|---|---|
| `scheduled_calls` | `(enhanced_ical_id, company_id)` | Idempotency marker — "this event has been scheduled" | `V20230304_0810` |
| `calendar_recurring_event` | `(company_id, ical_uid)` | Recurring-series cancellation state; `should_cancel_recurring_event`, `is_office` flags | `V20220830_0942` (+ `V20231204_0900` adds `is_office`) |
| `updated_calendar_event` | unique `(enhanced_ical_id, company_id)` | Dedup / last-modified tracking for updated events | `V20230301_0942` |
| `calendar_office_recurring_ical_event` | `(company_id, ical_uid, recurrence_id)` | Office365 ical ↔ recurrence-id map | `V20231101_0942` |
| `calendar_cancel_office_events` | `(company_id, recurrence_id)` | Office365 per-instance cancellation state | `V20231101_0943` |

**Common column pattern**: `company_id BIGINT NOT NULL`, `create_date_time` / `update_date_time TIMESTAMPTZ DEFAULT now()`.

**Audit trigger**: `public.audit_changes()` (`V20220824_1317`) auto-sets `update_date_time = now()` on `UPDATE`, unless the session GUC `gong.silent.update = 'true'`. Attached to `calendar_recurring_event` and `calendar_cancel_office_events`.

**RLS policies** (identical shape on every owned table):
```sql
single_tenant_access_policy → USING (company_id = current_setting('gong.tenant.company_id')::bigint)
cross_tenant_access_policy  → USING (true)   -- for *_cross_tenant_* roles
```

### DAOs writing to `call_scheduler`

| DAO | DB access bean | Tables | File |
|---|---|---|---|
| `ScheduledCallsDao` | `CallSchedulerDb.SingleTenant.WRITER`, `CrossTenant_UNSAFE.READER` | `scheduled_calls` | `CallScheduler/.../dao/ScheduledCallsDao.java` |
| `CalendarRecurringEventsDao` | `CallSchedulerDb.SingleTenant.WRITER`, `CrossTenant_UNSAFE.READER` | `calendar_recurring_event`, `calendar_office_recurring_ical_event`, `calendar_cancel_office_events` | `CallScheduler/.../dao/CalendarRecurringEventsDao.java` |
| `UpdatedCalendarEventDao` | `CallSchedulerDb.SingleTenant.WRITER`, `CrossTenant_UNSAFE.WRITER` | `updated_calendar_event` | `CallSchedulingCommon/.../common/UpdatedCalendarEventDao.java` |

---

## 3. Cross-schema access — `operational` DB (`public` schema)

The bulk of read/write traffic goes to the **`operational` database, `public` schema**, which is **owned by other services** (calls, users, companies). This subsystem accesses it via `OperationalDb` beans and the autowired `Db` helper.

> 🔑 **Correction worth flagging**: the `recurring_event*` tables live in **`public` (operational)**, **not** in the `call_scheduler` schema. `RecurringEventsDao` is wired to `OperationalDb`, not `CallSchedulerDb`.

**Tables touched** (extracted from the `.sql` files under `CallSchedulingCommon/.../sql/{CallData,recurringevents,CallBuilder}` and `CallScheduler/.../sql/{UpdateCalls,...}`):

| Table (`public.`) | Access | Notes |
|---|---|---|
| `call` | R/W | The central entity — 300+ references across the SQL files |
| `appuser` | R | Owner/invitee user resolution |
| `company` | R | Company lookup |
| `invitee` | R/W | Call invitees |
| `collaborator` | R | Call collaborators |
| `callrecording` | R | Recording linkage |
| `workspace` | R/W | Workspace assignment (`updateCallWorkspace.sql`) |
| `recurring_event` | R/W | Recurring rule storage |
| `recurring_event_exception` | R/W | Per-instance exceptions |
| `recurring_event_history` | W | Recurring audit trail |
| `company_recorder_properties` | R | Recorder config |
| `provider_reported_call_info` | R | Provider-reported metadata |
| `provider_reported_attendee` | R | Provider-reported attendees |

### DAOs against `operational`

| DAO | DB access bean(s) | File |
|---|---|---|
| `CallDataDao` | autowired `Db` (`OperationalDb.Beans`) | `CallSchedulingCommon/.../common/CallDataDao.java` |
| `RecurringEventsDao` | `OperationalDb.SingleTenant.{WRITER,READER}`, `CrossTenant_UNSAFE.WRITER`, `Db` | `CallSchedulingCommon/.../recurring/RecurringEventsDao.java` |
| `UpdateCallDao` | `OperationalDb.SingleTenant.WRITER` | `CallScheduler/.../dao/UpdateCallDao.java` |
| `CallSchedulingUpdatedProducerDao` | `OperationalDb.SingleTenant.READER` | `CallScheduler/.../dao/CallSchedulingUpdatedProducerDao.java` |

Service-layer direct access also exists: `CancelBlacklistedCallsService`, `InviteHandlerNameWithReservationService`, `TroubleshootingWebEx` (all `@Qualifier(OperationalDb...)`).

### Read-only integration schemas (troubleshooting only)

`CallScheduler/.../sql/TroubleshootingCallProviderServices/SelectCallsWithoutProviderUpcomingMeeting.sql` reads
across three provider-integration schemas to find scheduled calls missing a provider meeting:
- `gotomeeting_integration.meeting`
- `webex_integration.meeting_lookup`
- `zoom_integration.meeting`

These are **read-only, troubleshooting-endpoint** queries — not part of the core scheduling write path.

---

## 4. Tenancy & access model

Three access flavours are used across the DAOs (all from `com.honeyfy.appcommon.db`):

| Bean type | Method | RLS effect |
|---|---|---|
| `SingleTenantDbAccess` | `.company(companyId)` | Sets `gong.tenant.company_id`; RLS restricts rows to that tenant |
| `CrossTenantDbAccess` | `.crossTenant_UNSAFE()` | Uses `*_cross_tenant_*` role; RLS `USING (true)` → **all tenants** |
| `Db` (autowired) | `db.sql.statement(...)` | Plain access + Spring Fixed Mapper (`...UsingSfm`) |

- **Single-tenant is the default** for writes (`company(companyId)` is threaded through nearly every mutation).
- **`crossTenant_UNSAFE`** is used only for cross-company sweeps: `DeleteUpdatedCalendarEvents.sql` (retention cleanup) and `getCalendarRecurringEventsToCancel.sql` (global cancellation scan).
- SQL statements are **externalised files** loaded by relative path (e.g. `db.sql.statement("sql/CallData/SelectCallByID.sql")`), not inline strings.

---

## 5. Redis

Declared in descriptors (`dataSources.redis`) and wired in both configs:

| Cluster / logical DB | Access | Use |
|---|---|---|
| `GONG_PROD` cluster | RW | Distributed locks (event-dedup, `DistributedLocks`), permissions cache (`RedisLogicalDatabase.PERMISSIONS_MODULE_CACHING`), internal access control (`INTERNAL_ACCESS_CONTROL`) |
| `CONSENT_REDIS` | RW | Consent state |
| `CIRCUIT_BREAKERS` | RO | Circuit-breaker state |

Prod uses **IAM auth via ElastiCache** (`ElasticCacheIAMCredentialsProviderFactory`, `RedisDynamicCredsSupplierFactory`); dev/test use `ServerMode.SINGLE`. `locks: true` in the descriptor enables DB-/Redis-backed distributed locking.

---

## 6. OpenSearch / Elasticsearch

Declared in descriptors (`dataSources.elasticsearch`), accessed via MetaClient beans:

| Index | Access | Accessor |
|---|---|---|
| `CALENDAR_EVENTS_HISTORY` | R/W | `CalendarEventsHistoryWriter` / `CalendarEventsHistoryIndexMetaClient` — bulk-indexed from the `call-scheduling-history` topic |
| `MEETINGS` | R/W | `MeetingsIndexMetaClient` |
| `AUDITS` | R/W | audit index |

Tenant isolation is via the MetaClient index-per-tenant pattern.

---

## 7. Per-module summary

| Module | Postgres | Redis | OpenSearch | Notes |
|---|---|---|---|---|
| **CallScheduler** | OPERATIONAL, CALL_SCHEDULER, RECORDING_CONSENT, RECRUITING (all RW), DATA_CAPTURE | GONG_PROD, CONSENT_REDIS, CIRCUIT_BREAKERS | CALENDAR_EVENTS_HISTORY, MEETINGS, AUDITS | Core engine; owns the DAOs + Flyway migrations |
| **InviteHandlerWebhooksServer** | OPERATIONAL RW, CALL_SCHEDULER RW, RECORDING_CONSENT RW, **RECRUITING RO**, DATA_CAPTURE | GONG_PROD, CONSENT_REDIS, CIRCUIT_BREAKERS | CALENDAR_EVENTS_HISTORY, AUDITS | Mailgun webhook → produces requests; no owned SQL |
| **GlobalInviteHandlerWebhooksServer** | **none** | none | none | GGE forwarder — no DB access |
| **CallSchedulerMonitor** | none | none | none | No direct DB access |
| **CallSchedulingCommon** | (library) | — | — | Holds `CallDataDao`, `UpdatedCalendarEventDao`, `RecurringEventsDao` — DB choice set by consumer module |

---

## 8. Where to look in code

- **Schema (owned)**: `schema/call_scheduler/db/migration/*.sql`
- **Datasource declaration**: `*/src/main/resources/descriptors/app/*.gong-app-descriptor.yaml`
- **Bean wiring**: `CallScheduler/.../config/CallSchedulerConfig.java`, `InviteHandlerWebhooksServer/.../config/InviteHandlerWebhooksConfig.java`
- **DAOs**: `CallScheduler/.../dao/`, `CallSchedulingCommon/.../common/`, `CallSchedulingCommon/.../recurring/`
- **SQL statements**: `*/src/main/resources/sql/**/*.sql`

> Related: [[Subsystems/Call Scheduling/Canvas/Data Stores/DataStore-PostgreSQL|PostgreSQL chip]] · [[Subsystems/Call Scheduling/Canvas/Data Stores/DataStore-Redis|Redis chip]] · [[Subsystems/Call Scheduling/Canvas/Data Stores/DataStore-OpenSearch|OpenSearch chip]] · [[06 - Local Dev Seed Data|Seed Data (six-table bootstrap)]]
