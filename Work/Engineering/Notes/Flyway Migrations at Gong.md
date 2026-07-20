---
title: Flyway Migrations at Gong
tags:
  - flyway
  - database
  - postgres
  - migrations
  - local-dev
  - cheatsheet
created: 2026-07-20
aliases:
  - flyway
  - db migrations
  - schema migrations
---

# Flyway Migrations at Gong

> [!note] Purpose
> Gong uses Flyway to version-control and apply PostgreSQL schema changes. This note covers the conventions, how migrations are applied per environment, and the local dev workflow from inside a GCR container.

---

## Key Conventions

| Convention | Value |
|---|---|
| Plugin | `org.flywaydb:flyway-maven-plugin` |
| History table | `schema_version` (not Flyway's default `flyway_schema_history`) |
| Long-running history table | `schema_version_long_running` |
| Migration file prefix | `V{version}__{description}.sql` |
| Out-of-order | `true` (enabled across all environments) |
| Properties location | `honeyfy/DbConfig/src/main/resources/DbConfig/flyway/<dbname>/{dev,prod,test}.properties` |

---

## How Migrations Are Applied — By Environment

### Production & Staging: `InstallerCli` / `db-migrator` container

The `Schema/pom.xml` flyway-maven-plugin is **only for local dev**. In all containerised environments (prod, staging, gcells), migrations run via a dedicated **`<servicename>-db-migrator`** Docker image built alongside each service.

#### The flow

```
1. CI (Jenkins / Docker Bake) builds two images per service:
     <servicename>:<version>                  ← the service itself
     <servicename>:<version>-db-migrator      ← InstallerCli JAR + SQL scripts

2. At deploy time the migrator container runs FIRST:
     java -jar /service/InstallerCli.jar \
       -m <ModuleName> db-migrate \
       -o jdbc:postgresql://${POSTGRESQL_OPERATIONAL_ENDPOINT}/honeyfy \
       -d jdbc:postgresql://${POSTGRESQL_DWH_ENDPOINT}/dwh \
       ...  (one flag per owned database)

3. Container exits 0  →  the service container starts
```

`InstallerCli` reads the module's `gong-app-descriptor.yaml` to know which databases it owns, then uses the `DbConfig/flyway/<dbname>/prod.properties` (baked into the image) to drive Flyway.

#### Key behaviours of `DbMigrator`

- **Distributed lock** — acquires a PostgreSQL advisory lock (`PgDistributedLockService`) to prevent concurrent migrators racing on the same DB.
- **Parallel execution** — migrates up to 5 databases in parallel.
- **Role migrations first** — runs `ProdDbRolesMigrator` (creates/updates DB roles) before any schema migration.
- **Aurora switchover guard** — refuses to run if an Aurora maintenance/switchover is in progress.
- **Short vs long migrations** — long-running migrations use a separate `schema_version_long_running` table and run independently.
- **Squashing** — some gcells (`gcell-nam-04`, `gcell-nam-02`) use a squashing mode to collapse old migrations.

#### Auth in prod

No static password. The `prod.properties` omits `flyway.password` — credentials are **RDS IAM tokens** generated at runtime by `RdsInstanceIamRoleTokenGeneratorFactory`. DB URLs come from GPE environment variables:

```properties
# prod.properties (example: operational DB)
flyway.table=schema_version
flyway.outOfOrder=true
flyway.url=jdbc:postgresql://${POSTGRESQL_OPERATIONAL_ENDPOINT}/honeyfy?ssl=true
flyway.user=postgres
flyway.locations=db/migration,operational/db/migration,...
flyway.schemas=public,webex_integration,insights,...
```

---

### CI: `ci` Maven profile in `Schema/pom.xml`

The `ci` profile runs a single execution (`dbRolesMigratorForTest`) that applies only role migrations, using `${com.honeyfy.db.host.test}` injected by the CI infrastructure. Full schema migrations in CI are handled by a `gong-module-run`-style docker-compose setup (same `InstallerCli` path as local dev, but with CI DB coordinates).

---

### Local Dev: Two Options

#### Option A — `gong-module-run` (recommended)

`gong-module-run` spins up the full docker-compose stack including `docker-compose-migrators.yaml`. Migrator containers run automatically with `depends_on: condition: service_completed_successfully` before the service container. DB URLs point to the local Postgres container. No manual commands needed.

#### Option B — Direct `mvn` invocation (targeted, manual)

Use when you need to migrate a single DB without starting the full stack.

> [!warning] Relative paths don't work outside the reactor
> Running `mvn flyway:migrate@<id>` directly will fail with "No migration found" because the relative `filesystem:../src/main/resources/...` paths don't resolve outside a full reactor build. You **must** override with absolute `-Dflyway.locations`.

```bash
mvn -f honeyfy/Schema/pom.xml \
  org.flywaydb:flyway-maven-plugin:migrate@<execution-id> \
  -Dflyway.url="jdbc:postgresql://host.docker.internal:5432/<db>_dev" \
  -Dflyway.locations="classpath:com/honeyfy/migration/common,filesystem:<ABS_PATH>/db/migration" \
  -Dflyway.schemas="public,<schema>"
```

Replace:
- `<execution-id>` — the `<id>` from the `<execution>` block in `honeyfy/Schema/pom.xml`
- `<db>_dev` — physical database name (e.g. `call_scheduler_01_dev`)
- `<ABS_PATH>` — absolute path to the module's migration SQL folder
- `<schema>` — schema(s) owned by this DB (omit if only `public`)

**Host & credentials inside GCR:**

| Setting | Value |
|---|---|
| Host | `host.docker.internal` (NOT `localhost`) |
| Port | `5432` |
| User | `postgres` |
| Password | `postgres` |

The `dev.properties` and `Schema/pom.xml` default to `localhost` — always override with `-Dflyway.url` when running from inside a GCR container.

---

## `DbConfig` — Environment Properties

Every logical database has three property files under:
```
honeyfy/DbConfig/src/main/resources/DbConfig/flyway/<dbname>/
  dev.properties    ← localhost URLs, static postgres/postgres creds
  prod.properties   ← GPE-var URLs, no password (IAM auth)
  test.properties   ← used by unit tests (in-memory / test container URLs)
```

`DbMigrator.findEnvironmentDbProperties()` selects the file at runtime based on active Spring profiles (`Prod` → `prod`, `Dev` → `dev`, else `test`).

---

## Known Execution IDs (Schema/pom.xml dev profile)

Most commonly needed for manual local migration:

| Execution ID | Physical DB | Schema(s) |
|---|---|---|
| `operational` | `honeyfy_dev` | public + 26 others |
| `scheduled_tasks_01` | `scheduled_tasks_01_dev` | public |
| `scheduled_tasks_02` | `scheduled_tasks_02_dev` | public |
| `user_auth` | `user_auth_dev` | public (no separate `user_auth` schema is created) |
| `call_scheduler` | `call_scheduler_01_dev` | call_scheduler |
| `recorder` | `recorder_dev` | public, recorder |
| `ingester` | `ingester_dev` | public, ingester, mail_import |
| `recording_consent_timed_events` | `recording_consent_timed_events_dev` | public (migrations in `gong-data-capture`) |

> `recording_consent_timed_events` has its migrations in `gong-data-capture`, not `honeyfy/Schema`. Borrow any execution id but override `flyway.url` and `flyway.locations`.

---

## Common Failures

### "No migration found"

**Cause**: relative `filesystem:` path not resolving outside the reactor.

**Fix**: add `-Dflyway.locations` with an absolute path.

```bash
-Dflyway.locations="classpath:com/honeyfy/migration/common,filesystem:/develop/code/<repo>/src/main/resources/db/migration"
```

### "Connection refused" / "Unable to connect"

**Cause**: using `localhost` instead of `host.docker.internal` from inside GCR.

**Fix**: always use `-Dflyway.url="jdbc:postgresql://host.docker.internal:5432/<db>_dev"`.

### "URL override appends database name twice"

**Cause**: using `-Dflywaydb.database.url` (the pom property) instead of `-Dflyway.url`.

**Fix**: use `-Dflyway.url` (the Flyway property) to fully replace the URL. The pom property gets `/<db>_dev` appended, producing `jdbc:postgresql://host.docker.internal:5432/call_scheduler_01_dev/call_scheduler_01_dev`.

### "Checksum mismatch"

**Cause**: a previously applied migration file was edited after it ran.

**Fix**: in dev, delete the row from `schema_version` and re-run. **Never do this in prod.**

```sql
DELETE FROM schema_version WHERE script = 'V1__some_migration.sql';
```

### "Validate failed" after a local DB wipe

**Cause**: `schema_version` has stale rows but the schema is gone.

**Fix**: drop and recreate the database, then re-run migrations.

### "Concurrent migration error" / advisory lock timeout

**Cause**: another `InstallerCli` instance holds the PostgreSQL advisory lock on the same DB.

**Fix**: wait for the other process to finish, or in dev kill the stuck process and release the lock:

```sql
SELECT pg_advisory_unlock_all();
```

---

## Seeding After Migration

Flyway only creates the schema. Seed data must be inserted manually. See [[Import Prod Data - Calls]] and subsystem-specific seed guides.

For `appuser` and `company`, those live in `honeyfy_dev` (already populated in local dev via `gong-module-run --volume-init` or the synthetic image). See [[Subsystems/Call Scheduling/08 - Data Access & Storage]] for the full logical → physical DB mapping.

---

## See also

- [[Subsystems/Call Scheduling/08 - Data Access & Storage]] — logical → physical DB mapping for Call Scheduling
- [[Subsystems/Consent/05 - Data Access & Storage]] — Consent DB layout
- [[Import Prod Data - Calls]] — seeding call data after migration
- [[gong-java-cheat-sheet]] — general Java patterns at Gong
