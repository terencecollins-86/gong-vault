---
title: Load Prod Data Locally (and the honeyfy_dev truth)
tags: [telephony-systems, local-dev, seeding, installer, onboarding]
created: 2026-07-08
---

# 🗄️ Load Prod Data Locally — and where user/company data actually lives

> [[_dashboard|← Team Hub]] · [[gong-entrypoints App — Usage]] · [[06 - Runbook & Troubleshooting]]

> [!tip] TL;DR — you probably don't need the import
> The `appuser` / `company` tables the telephony flow reads live in **`honeyfy_dev`**, and on a
> normally set-up machine that DB is **already populated** (thousands of rows). Check before you
> import anything:
> ```bash
> PGPASSWORD=postgres psql -U postgres -h localhost -d honeyfy_dev -c "select count(*) from public.appuser;"
> ```
> If that returns a large count, skip the whole prod-import saga below and jump to
> [§ Seed the telephony shim users](#seed-the-telephony-shim-users).

---

## Which DB holds what (the thing that wasted hours)

| Logical datasource | Local Postgres DB | Holds | Notes |
|---|---|---|---|
| OPERATIONAL | **`honeyfy_dev`** | `public.appuser`, `public.company`, `public.call` | The Schema `operational` Flyway block migrates **honeyfy_dev** (`Schema/pom.xml`, `url=.../honeyfy_dev`). The Supervisor's `OPERATIONAL` datasource maps here locally. |
| — | `operational_dev` | *(empty)* | Created by `V20170101_0059__CreateOperationalDevDb.java` but **never populated** — a red herring. Do **not** target it. |
| Dialers | `dialers_dev` | `dialers.company_sync`, etc. | Seeded by `gong-telephony-systems/dev/seed-dialers-local.sql` (shim companies 9001/9002/9003). |

`userService.readAppUserById` → `SelectAppUsersByIDs.sql` → `public.appuser JOIN public.company` on
the **OPERATIONAL** datasource = **honeyfy_dev**.

---

## Seed the telephony shim users

`honeyfy_dev` has real users, but **none belong to the dialers shim companies (9001/9002)**, so an
`APPUSER_ID` for those never resolves and every `COMPLETED` process-call-event falls to a 200-failed
path instead of the handled path. Seed the missing rows:

```bash
PGPASSWORD=postgres psql -U postgres -h localhost -d honeyfy_dev \
  -f "gong-entrypoints/src/main/java/io/gong/gongentrypoints/telephonysystems/processcallevent/seed-appuser-local.sql"
```

Creates companies 9001/9003 + appusers 700501 (→ path H, handled), 700601 (→ path G, 500),
700502 (inactive → E), 700503 (no-import → F). Idempotent. Columns match the **live** honeyfy_dev
schema (verified via `information_schema`, not the stale 2015 baseline DDL). See
[[gong-entrypoints App — Usage]] and the entrypoint `processcallevent/README.md` for the full 8-path
table.

> [!warning] Don't trust old baseline DDL
> The 2015 `V0__main-schema.sql` is heavily drifted (`company.create_date_time`→`createdatetime`,
> `appuser.status` removed, `active` is NOT NULL no-default). Always confirm columns with:
> ```bash
> PGPASSWORD=postgres psql -U postgres -h localhost -d honeyfy_dev -c \
> "select column_name, is_nullable, column_default from information_schema.columns where table_schema='public' and table_name='appuser' and is_nullable='NO' order by ordinal_position;"
> ```

---

## Prod / synthetic import (`Import Prod Data - Calls`) — only if you need broad prod data

Needed only for use-cases beyond the telephony shim (realistic calls, many companies, etc.). It was a
**rabbit hole** on 2026-07-08 — capture below so the next person skips the dead ends.

### Command (pure CLI, no IntelliJ — avoids IDE cache)

```bash
export HONEYFY=/path/to/honeyfy
export AWS_PROFILE=internal            # profile resolved by InstallerCli when no -aws:pr flag

# 1. Build the fat jar, skipping the local Flyway migrator (see gotcha #2)
mvn -f "$HONEYFY/pom.xml" -pl Installer -am clean package -Dskip.db.migrator=true -DskipTests -T1C

# 2. Run the import (args mirror the .run config; --synthetic is the key flag, see gotcha #1)
INSTALLER_JAR=$(ls -t "$HONEYFY/Installer/target/InstallerCli##"*.jar | head -1)
java -ea -Dlog.appName=DbImport -jar "$INSTALLER_JAR" \
  -m WebAppSample db-snapshot-import --reset-password "Sababa" \
  --exclude "public.appuser_login_history" \
  --component OPERATIONAL_DB --component DWH_DB \
  --component TRANSCRIPTS_MONGO --component CONVERSATION_SUMMARY_MONGO --component CALLS \
  --synthetic 2>&1 | tee /tmp/import.log
```

### Gotchas (all hit in order)

1. **Wrong S3 prefix.** Default reads `jenkins-export/archives`, but the `gong-internal-export`
   bucket (us-east-1 — `GetBucketLocation` returns `null`, which *means* us-east-1) only has
   `synthetic-export/archives/<dated>`. The **`--synthetic`** flag points the importer there
   (`UnifiedExportImport.java`, `SYNTHETIC_EXPORTED_ARCHIVES_ROOT_PATH`). Find the latest folder:
   ```bash
   aws s3 ls s3://gong-internal-export/ --recursive --profile internal --region us-east-1 | grep export.json.gz
   ```
   The synthetic manifest **does** include OPERATIONAL + person.zip.
2. **Flyway build gate.** `mvn -pl Installer -am package` triggers Schema Flyway `migrate` against
   every `*_dev` DB. Seen failures: checksum mismatch (`deals_dev`), then a failed migration
   (`assisted_communication`: "column subject does not exist"). `-Dskip.db.migrator=true` skips all
   57 executions — safe, since the import restores its own schema.
3. **Empty restore (unresolved).** Even with `--synthetic` + skip flag, the CLI run produced an
   **empty** operational DB (no `interim_*` DB, `~/UnifiedExportImport/` empty, jar named
   `InstallerCli##000000-2016.xx.xx.xxxx` = placeholder version → possibly stale). The importer builds
   `interim_<db>` then `ALTER DATABASE ... RENAME` over the real one (`PostgresDbImporter.java`); the
   restore never completed. **Root cause not found — this is an Installer/DevEx tooling issue.**

### Escalation asks for Installer/DevEx

- Why does `db-snapshot-import --synthetic` complete without populating `operational` (empty
  `~/UnifiedExportImport/`, no interim DB)?
- Is the placeholder-version jar (`InstallerCli##000000-2016.xx.xx.xxxx.jar`) expected from a CLI
  `package`, or a sign the build didn't repackage?
- Is the CLI path supported, or is the IntelliJ `Import Prod Data - Calls` run config the only
  sanctioned entry point?

---

## References

- Seed: `gong-entrypoints/.../telephonysystems/processcallevent/seed-appuser-local.sql`
- Entrypoint paths + Postman: `gong-entrypoints/.../processcallevent/README.md`, `telephonysystems.postman_collection.json`
- Import internals: `honeyfy/Installer/src/main/java/com/honeyfy/installer/cli/UnifiedExportImport.java`, `InstallerCli.java`
- Prior guide: [[Engineering/Notes/Import Prod Data - Calls]]
