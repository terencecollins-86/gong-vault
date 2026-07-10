---
tags:
- gong
- installer
- import
- prod-data
- onboarding
created: 2026-06-17
---

# Import Prod Data — Calls

Guide to running the **"Import Prod Data - Calls"** run configuration successfully end-to-end.

---

## What the Config Does

Run configuration: `honeyfy/.run/Import Prod Data - Calls.run.xml`

```
Main class:  com.honeyfy.installer.cli.InstallerCli
Module:      Installer (honeyfy/Installer)
Command:     db-snapshot-import
Arguments:   -m WebAppSample
             --reset-password "Sababa"
             --exclude "public.appuser_login_history"
             --component OPERATIONAL_DB
             --component DWH_DB
             --component TRANSCRIPTS_MONGO
             --component CONVERSATION_SUMMARY_MONGO
             --component CALLS
```

It downloads a prod snapshot from S3 and imports exactly these components into your local databases:

| Component | Type | What it contains |
|-----------|------|-----------------|
| `OPERATIONAL_DB` | PostgreSQL | Core operational database (calls, users, companies, etc.) |
| `DWH_DB` | PostgreSQL | Data warehouse DB |
| `TRANSCRIPTS_MONGO` | MongoDB | Call transcripts |
| `CONVERSATION_SUMMARY_MONGO` | MongoDB | Conversation summaries / AI call briefs |
| `CALLS` | OpenSearch (Elasticsearch) | Call search index |

The `--reset-password "Sababa"` flag resets all user passwords in the imported data to `Sababa` so you can log in locally.

---

## Prerequisites

### 1. AWS Account Access

The importer downloads from S3 bucket **`gong-internal-export`** (prod) using the **`internal`** AWS profile.

You need:
- **AWS `internal` profile** configured in `~/.aws/config` and `~/.aws/credentials`
- This profile must have read access to the `gong-internal-export` S3 bucket
- The bucket is in the **devtest** AWS account / `us-east-1` region

**How to get it**: Ask your team lead or DevOps for access to the `internal` AWS profile. It's typically set up during onboarding via OKTA → AWS SSO.

> If you pass `-aws:pr devtest` instead, it uses the `devtest` AWS profile instead of `internal`. The default (no `-aws:pr` flag) falls through to `internal`.

### 2. VPN

**Yes — VPN is required.** The exported data is pulled from S3 (`gong-internal-export`), which is inside the Gong AWS VPC. You must be on **Gong VPN** for the import to reach the bucket and for MongoDB/OpenSearch targets (if using remote endpoints rather than localhost).

### 3. Local Services Running

The importer writes to **your local dev databases**. Before running, make sure these are up:

| Service | Default local target | Start command |
|---------|---------------------|---------------|
| PostgreSQL | `localhost:5432` | Docker / local Postgres |
| MongoDB | `localhost:27017` | Docker / local MongoDB |
| OpenSearch | `localhost:9200` | Docker / local OpenSearch |

> The importer defaults to `jdbc:postgresql://localhost:5432/<db>` for non-prod. You can override via `--postgres`, `--mongodb`, `--elastic` flags if needed.

### 4. Built Installer Module

The run config has `<option name="Make" enabled="true" />` — IntelliJ will build the `Installer` module first. Make sure the project compiles cleanly before running.

---

## Component-by-Component Requirements

### `OPERATIONAL_DB` (PostgreSQL)
- Needs local PostgreSQL running
- Importer will create/replace the `operational` database schema
- Credentials loaded from devtest creds (`DbStaticCreds.loadDevTestCreds(GongAppRole.Installer)`) — no manual credential setup needed for local runs

### `DWH_DB` (PostgreSQL)
- Same as above, targets local `dwh` database

### `TRANSCRIPTS_MONGO` (MongoDB)
- Needs local MongoDB running
- Uses `MongoFactory.createProdMongoClient` path — for local it connects to `localhost:27017`

### `CONVERSATION_SUMMARY_MONGO` (MongoDB)
- Same MongoDB instance as transcripts

### `CALLS` (OpenSearch / Elasticsearch)
- Needs local OpenSearch running on `localhost:9200`
- Imports the call search index (`IndexClass.CALLS` → `EsCallSchema`)

---

## Step-by-Step Runbook

1. **Connect to VPN**

2. **Verify AWS `internal` profile is working**:
   ```bash
   aws s3 ls s3://gong-internal-export/jenkins-export/archives/ --profile internal
   ```
   If this returns a listing, you have access. If denied, contact DevOps.

3. **Start local databases** (Docker is the standard):
   ```bash
   # Postgres, MongoDB, OpenSearch — ask your team for the docker-compose file
   # typically in honeyfy/docker or a local dev setup guide
   ```

4. **Open IntelliJ** in the `honeyfy` project

5. **Run the config** → `Import Prod Data - Calls` from the run configurations dropdown

6. **Monitor the logs** — the import runs components in parallel (default `maxConcurrentDbImportTasks=4`). Each component logs its progress. Expected runtime: 15–45 min depending on snapshot size and machine.

7. **Verify** by connecting to local Postgres and checking `public.call` has rows.

---

## Common Failure Modes

| Error | Cause | Fix |
|-------|-------|-----|
| `Access Denied` on S3 | No `internal` AWS profile or not on VPN | Set up `internal` profile, connect VPN |
| `Connection refused localhost:5432` | Local Postgres not running | Start Docker / local Postgres |
| `Connection refused localhost:27017` | Local MongoDB not running | Start Docker / local MongoDB |
| `Connection refused localhost:9200` | Local OpenSearch not running | Start OpenSearch container |
| `export.json.gz not found` | Snapshot not yet published / S3 path stale | Check if Jenkins export ran recently; re-run or wait |
| Build fails before launch | Installer module not compiling | Fix compile errors first |
| Hangs after downloading | Memory pressure with 4 parallel tasks | Reduce via `-mc:di 1` in program args |

---

## Related Run Configs

| Config | Components |
|--------|-----------|
| `Import Prod Data - Full` | Everything (no Snowflake) |
| `Import Prod Data - Only MONGO` | MongoDB only |
| `Import Prod Data - Emails` | Email/calendar components |
| `Import Prod Data - Deals` | Deals DB + OpenSearch |
| `Import Prod Data - GDM` | Gong Data Mesh DB |
| `Import_Prod_Data___Cleanup` | Cleans up import artifacts |
| `Import_Prod_Data___Postgres_only` | Postgres DBs only |

---

## S3 Bucket Reference

| Bucket | Used for | Profile required |
|--------|----------|-----------------|
| `gong-internal-export` | Prod snapshots (what Calls import uses) | `internal` |
| `gong-internal-export-dev` | Dev/devtest snapshots | `devtest` |

The prefix path in the bucket is `jenkins-export/archives/` (set by `EXPORTED_ARCHIVES_ROOT_PATH`).

---

## Related Notes

- [[Comms Capture Maven Modules]]
- [[Comms Capture Architecture Overview]]
