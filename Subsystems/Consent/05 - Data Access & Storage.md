---
title: Data Access & Storage
tags: [consent, recording-consent, data-access, database, postgres, redis, opensearch, schema]
---

# Data Access & Storage — Consent

> [[_dashboard|← Team Hub]] · [[02 - Data Flow]] · [[Storage & Schema Reference]] · [[Subsystems/Consent/Canvas/Data Stores/DataStore-PostgreSQL|PostgreSQL chip]]

**Source of truth: the `Honeyfy/gong-data-capture` code** (5 modules) plus the schema-owning migrations in the `Honeyfy/honeyfy` monolith (`Schema/src/main/resources/*/db/migration/`). Every claim below is cited to a file. This is the code-grounded companion to the lighter [[Storage & Schema Reference]] inventory.

> The Consent subsystem is **distributed**: the app modules live in `gong-data-capture`, but the `recording_consent` and `data_capture` schemas are **Flyway-managed from the honeyfy monolith**, not from this repo. Only the `event_based_tasks` schema (timed events) is migrated inside `gong-data-capture`.

---

## TL;DR

The subsystem talks to up to **7 PostgreSQL logical datasources**, **OpenSearch** (`AUDITS`), **Redis** (up to 4 clusters/logical DBs), and **Kafka**. It **owns three physical databases' worth of schemas** — `RECORDING_CONSENT`, `DATA_CAPTURE`, and `RECORDING_CONSENT_TIMED_EVENTS` — and does heavy **cross-schema access into the shared `OPERATIONAL` DB** (`public.call`, `appuser`, …).

| Datastore (logical) | Access | Owned here? | Physical DB (local) | Accessor |
|---|---|---|---|---|
| Postgres `RECORDING_CONSENT` | RW | ✅ **Yes** (4 schemas) | `recording_consent_dev` | `RecordingConsentDb` |
| Postgres `DATA_CAPTURE` | RW | ✅ **Yes** (`dcp_change`, `data_capture`) | `data_capture_dev` | `DataCaptureDb` |
| Postgres `RECORDING_CONSENT_TIMED_EVENTS` | RW | ✅ **Yes** (`event_based_tasks`) | `recording_consent_timed_events_dev` | `RecordingConsentTimedEventsDb` |
| Postgres `OPERATIONAL` | RW | ❌ shared | `honeyfy_dev` | `OperationalDb` |
| Postgres `SCHEDULED_TASKS_01` / `_02` | RW | ❌ shared (task framework) | `scheduled_tasks_0{1,2}_dev` | `ScheduledTasks0{1,2}Db` |
| Postgres `USER_AUTH` | RW (ConsentWebApi only) | ❌ shared | `user_auth_dev` | — |
| OpenSearch `AUDITS` | RW | ❌ shared | — | MetaClient beans |
| Redis `CONSENT_REDIS` / `GONG_PROD` / `CIRCUIT_BREAKERS` / `WFE_SESSION` | RW/RO | ❌ shared | — | `RedisAccessor` |

---

## 1. PostgreSQL — logical datasources per module

Datasources are declared per-module in the app descriptors (`*/src/main/resources/descriptors/app/*.gong-app-descriptor.yaml`) and wired as Spring beans in each module's `@Configuration`.

| Module | `dataSources.postgres` (RW unless noted) | moduleType | locks / schedTasks |
|---|---|---|---|
| **RecordingConsentApiServer** | OPERATIONAL, RECORDING_CONSENT, DATA_CAPTURE, SCHEDULED_TASKS_01/02 | api-server | ✅ / ✅ |
| **RecordingConsentTasks** | OPERATIONAL, RECORDING_CONSENT, **RECORDING_CONSENT_TIMED_EVENTS**, DATA_CAPTURE, SCHEDULED_TASKS_01/02 | api-server | ✅ / ✅ |
| **DcpChangeManager** | OPERATIONAL, RECORDING_CONSENT, DATA_CAPTURE, SCHEDULED_TASKS_01/02 | api-server | ✅ / ✅ |
| **MeetingFrontEnd** | OPERATIONAL, RECORDING_CONSENT, DATA_CAPTURE | webapi-server | ✅ / ❌ |
| **ConsentWebApi** | OPERATIONAL, **USER_AUTH** | webapi-server | ❌ / ❌ |

`ConsentCommon` is a shared library (holds `sql/ConsentEmail/*`); its DB choice is set by the consuming module. `MeetingFrontEndUI` is the front-end asset module — no DB.

> ⚠️ **`DATA_CAPTURE` is a real Postgres DB here** (unlike in Call Scheduling, where it's Kafka-only). `DcpChangeManagerDao` is wired to `DataCaptureDb` and writes the `dcp_change.*` tables. `DATA_CAPTURE` is *also* used as a Kafka cluster in the same descriptors — both are true.

---

## 2. Owned schemas

### 2a. `RECORDING_CONSENT` DB → 4 schemas (monolith-migrated)

Flyway-managed from `honeyfy/Schema/src/main/resources/recording_consent/db/migration/`. Accessed via `RecordingConsentDb` beans (`honeyfy/AppCommon/.../db/RecordingConsentDb.java`, maps to `Database.RECORDING_CONSENT`).

| Schema | Tables | Created by |
|---|---|---|
| `recording_consent_email` | `consent_email`, `audit`, `company_obfuscation`, `consent_email_settings_history` | `V20220714_1030__create_consent_email_schema.sql` |
| `recording_consent_settings` | `user_settings`, `appuser_consent_settings`, `appuser_static_link`, `calendar_event`, `consent_feature`, `protected_pmi_feature_displayed` | `V20220901_1130__create_consent_settings_schema.sql` |
| `recording_compliance` | jump-page / stop-recording tables (`jump_page_session`, `jump_page_interaction`, `stop_recording_audit`, `stop_recording_session_audit`) | `V20250915_1230__create_recording_compliance_schema.sql` |
| `recording_user_consent` | `settings`, `settings_language`, `audit`, `external_attendee_consent_decision` | recording_consent migrations |

> 🪤 **`recording_compliance` name collision**: a **legacy** `recording_compliance` schema also exists in the **`OPERATIONAL`** DB (`honeyfy/Schema/.../operational/db/migration/2019/V20190205_1152__create_compliance_audit_schema.sql`, and it's in `operational/dev.properties`'s `flyway.schemas`). The **live** jump-page / stop-recording tables that `RecordingComplianceDao` writes are in the **`RECORDING_CONSENT`** DB (the DAO uses `RecordingConsentDb.SingleTenant.WRITER`). Don't confuse the two when browsing schemas.

### 2b. `DATA_CAPTURE` DB → `dcp_change` + `data_capture`

Flyway-managed from `honeyfy/Schema/src/main/resources/data_capture/db/migration/`. Accessed via `DataCaptureDb`.

| Schema | Tables | Notes |
|---|---|---|
| `dcp_change` | `change_request_queue`, `change_request_user`, `change_request_action`, `settings_change`, `user_assignment_change`, `dcp_settings_revision`, `latest_completed_dcp_revision` | DCP change-orchestration state (created by `V20221110_1300__create_dcp_changes_schema.sql`) |
| `data_capture` | `profile`, `pre_call_email_settings`, `jump_page_settings`, `consent_email_settings` | DCP/consent settings backing store |
| `webex_integration` | (also created here) `preferences`, `user_lookup`, `user_by_user_credentials`, … | Provider integration — not consent-owned logic |

### 2c. `RECORDING_CONSENT_TIMED_EVENTS` DB → `event_based_tasks` (owned in THIS repo)

The **only** schema migrated inside `gong-data-capture`:
`RecordingConsentTasks/src/main/resources/schema/recording_consent_timed_events/db/migration/`.

| Table | PK | Purpose | Migration |
|---|---|---|---|
| `event_based_tasks.events` | `id TEXT` | Deferred/time-based event queue (`when_to_run`, `out_topic`, `retry_count`) | `V20220615_1200__create_events_table.sql` |

RLS added in `V20231121_1006` (single-/cross-tenant policies keyed on `company_id`); `public.audit_changes()` trigger function from `V20220615_1000`.

> Note: the migration creates schema **`event_based_tasks`**, though the Flyway config `recording_consent_timed_events/dev.properties` lists `flyway.schemas=public,recording_consent_timed_events`. The **table lives in `event_based_tasks`** in the `recording_consent_timed_events_dev` physical DB.

---

## 3. Cross-schema access — `OPERATIONAL` DB (`public`)

Every module declares `OPERATIONAL: GENERIC_READ_WRITE` and reads/writes the shared `public` schema owned by other services.

**Tables touched** (from the module SQL and inline queries):

| Table (`public.`) | Access | Used by |
|---|---|---|
| `call` | R/W | compliance counts, MS Teams attendance, consent-email eligibility |
| `appuser` | R | user resolution |
| `company` | R | company lookup |
| `collaborator` | R | call participants |
| `invitee` | R | call invitees |
| `sent_email` | R | consent-email dedup / audit |
| `onetime_meeting_jump_page`, `onetime_meeting_jump_page_to_call`, `appuser_jump_page` | R/W | one-time-meeting jump-page linkage |
| `callrecording` | R | recording linkage |

---

## 4. DAOs → DB access → schema

| DAO | DB access bean(s) | Schema / tables | File |
|---|---|---|---|
| `RecordingComplianceDao` | `RecordingConsentDb.SingleTenant.WRITER` + `OperationalDb.{SingleTenant.WRITER, CrossTenant_UNSAFE.READER}` | `recording_compliance.jump_page_*`, `stop_recording_*`; `public.call` | `RecordingConsentTasks/.../dao/RecordingComplianceDao.java` |
| `UserSettingsDao` | `RecordingConsentDb.SingleTenant.{WRITER,READER}` | `recording_consent_settings.user_settings` | `RecordingConsentTasks/.../service/UserSettingsDao.java` |
| `DcpChangeManagerDao` | `DataCaptureDb.{SingleTenant, CrossTenant_UNSAFE}.{WRITER,READER}` | `dcp_change.*` | `DcpChangeManager/.../service/DcpChangeManagerDao.java` |
| `MicrosoftTeamsAttendanceReportDao` | `OperationalDb.SingleTenant.WRITER` | `public.call` (MS Teams details) | `ConsentWebApi/.../service/MicrosoftTeamsAttendanceReportDao.java` |

Purge SQL (`RecordingConsentApiServer/.../sql/PurgeCompany/`) spans all owned schemas — the file names encode the target (`recording_consent_email-consent_email`, `recording_compliance-jump_page_session`, `recording_consent_settings-*`).

---

## 5. Tenancy & access model

Same three-flavour model as Call Scheduling (from `com.honeyfy.appcommon.db`):

| Bean type | Method | RLS effect |
|---|---|---|
| `SingleTenantDbAccess` | `.company(companyId)` | sets `gong.tenant.company_id`; RLS restricts rows to that tenant |
| `CrossTenantDbAccess` | `.crossTenant_UNSAFE()` | `*_cross_tenant_*` role; RLS `USING (true)` → all tenants |
| `Db` (autowired) | `db.sql.statement(...)` | plain access + `...UsingSfm` mappers |

`event_based_tasks.events` and the `recording_consent_settings` / `dcp_change` tables all carry the standard `single_tenant_access_policy` / `cross_tenant_access_policy` RLS pair keyed on `company_id`.

---

## 6. Redis, OpenSearch, task framework

- **Redis** (`dataSources.redis`): `CONSENT_REDIS` (write-through cache for jump-page / DCP compliance + consent-email accessors — see [[Subsystems/Consent/Canvas/Data Stores/DataStore-Redis|Redis chip]]), `GONG_PROD` (locks/permissions), `CIRCUIT_BREAKERS` (RO, required when `scheduledTasks: true`), and `WFE_SESSION` (ConsentWebApi web sessions).
- **OpenSearch**: `AUDITS` (RW) across the api-server / task modules.
- **`SCHEDULED_TASKS_01` / `_02`**: shared distributed-task framework DBs (`ScheduledTasks0{1,2}Db`), enabled by `scheduledTasks: true`. Physical: `scheduled_tasks_0{1,2}_dev`, `public` schema.

---

## 7. Logical → physical DB names (finding these in IntelliJ)

> 🪤 **Gotcha** (same as Call Scheduling): `RECORDING_CONSENT`, `DATA_CAPTURE`, `OPERATIONAL`, … are **logical** names — constants in the `Database` enum (`gong-infra-core/SharedEntities/.../softwaredefinedtopology/db/Database.java`). They **never** appear literally in IntelliJ's database list. IntelliJ shows **physical** database names; map through the Flyway configs first.

Local-dev mapping (`honeyfy/DbConfig/src/main/resources/DbConfig/flyway/<name>/dev.properties`, all on `localhost:5432`, creds `postgres`/`postgres`):

| Logical DS | Physical DB (IntelliJ) | Schema(s) to expand |
|---|---|---|
| `RECORDING_CONSENT` | **`recording_consent_dev`** | `recording_consent_email`, `recording_consent_settings`, `recording_compliance`, `recording_user_consent` |
| `DATA_CAPTURE` | **`data_capture_dev`** | `dcp_change`, `data_capture`, `webex_integration` |
| `RECORDING_CONSENT_TIMED_EVENTS` | **`recording_consent_timed_events_dev`** | `event_based_tasks` |
| `OPERATIONAL` | **`honeyfy_dev`** | `public` (+ legacy `recording_compliance`) |
| `SCHEDULED_TASKS_01` / `_02` | **`scheduled_tasks_0{1,2}_dev`** | `public` |
| `USER_AUTH` | **`user_auth_dev`** | `user_auth` |

**Traps:**
- ❌ Don't look for the operational tables in `operational_dev` — the app targets **`honeyfy_dev`** (legacy `CreateOperationalDevDb` migration creates the misleading `operational_dev` name). Same trap documented in [[Subsystems/Call Scheduling/08 - Data Access & Storage#1a. Logical → physical DB names (finding these in IntelliJ)|Call Scheduling §1a]].
- ❌ `recording_compliance` exists in **two** physical DBs (`honeyfy_dev` legacy + `recording_consent_dev` live) — the DAO writes the `recording_consent_dev` one.
- ❌ Consent spans **6+ separate physical databases** locally; enable **"show all databases"** on a single `localhost:5432` connection or add a data source per DB.

---

## 8. Where to look in code

- **Datasource declaration**: `gong-data-capture/*/src/main/resources/descriptors/app/*.gong-app-descriptor.yaml`
- **Owned schema (this repo)**: `gong-data-capture/RecordingConsentTasks/src/main/resources/schema/recording_consent_timed_events/db/migration/`
- **Owned schemas (monolith)**: `honeyfy/Schema/src/main/resources/{recording_consent,data_capture}/db/migration/`
- **DB beans**: `honeyfy/AppCommon/.../db/{RecordingConsentDb,OperationalDb}.java`, `Database` enum in `gong-infra-core/SharedEntities/.../softwaredefinedtopology/db/Database.java`
- **DAOs**: `gong-data-capture/{RecordingConsentTasks,DcpChangeManager,ConsentWebApi}/.../` (see §4)
- **SQL statements**: `gong-data-capture/*/src/main/resources/sql/**/*.sql`

> Related: [[Storage & Schema Reference]] · [[Subsystems/Consent/Canvas/Data Stores/DataStore-PostgreSQL|PostgreSQL chip]] · [[Subsystems/Consent/Canvas/Data Stores/DataStore-Redis|Redis chip]] · [[Subsystems/Call Scheduling/08 - Data Access & Storage|Call Scheduling — Data Access]]
