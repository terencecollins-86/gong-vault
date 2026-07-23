---
title: Local Dev - Prod Data Import Fix
fileClass: runbook
type: runbook
tags: [local-dev, gong-module-run, prod-data, installercli, data-loading, telephony-systems]
created: 2026-06-23
---

# 🛠️ Local Dev — Fixing `gong-module-run prod-data`

> Notes from getting `gong-module-run prod-data --import-prod-data` to populate the local DBs after two separate failures. Both fixes are **local edits** to checked-in `@Honeyfy/gong-devops` tooling in `gong-build-commons` — not committed.

## TL;DR

`gong-module-run prod-data --import-prod-data` failed twice in a row:

1. **InstallerCli image `not found`** — the tag was built with the wrong format (dashes vs dots).
2. **`Cannot find any export data folder is S3`** — the importer pointed at an empty export path; only the *synthetic* export bucket is populated for this account.

Two one-line edits in `gong-build-commons/dev/prod-data/` fixed both. Run command at the bottom.

---

## Symptom 1 — InstallerCli image not found

```
Error response from daemon: failed to resolve reference
"…/installercli:17-master-1-11680": not found
```

### Root cause

`gong-build-commons/dev/prod-data/gong-import-prod-data:63` resolves the image tag from a DNS TXT record, then runs `tr "." "-"`:

```bash
tag_name=$(nslookup -type=txt "$subsystem_name".builds.dev.gongio.net \
  | grep "v=" | awk '{print $NF}' | tr -d "\"v=\"" | tr "." "-")
```

- DNS advertises: `v=17.master.1.11680`
- After `tr "." "-"`: `17-master-1-11680` ← **not in ECR**
- ECR actually publishes `installercli` with **dots**: `17.master.1.11680` ✅

The `.`→`-` transform was likely copied from the *migrator* image convention (`…-db-migrator`, which does use dashes), but `installercli` publishes with dots. The `--tag-name` override flag was also dead — line 63 reassigned `tag_name` unconditionally.

### Fix — `gong-import-prod-data:63`

```bash
# Before
tag_name=$(nslookup -type=txt "$subsystem_name".builds.dev.gongio.net | grep "v=" | awk '{print $NF}' | tr -d "\"v=\"" | tr "." "-")

# After — drop the .→- transform; only resolve from DNS when no --tag-name was passed
if [[ -z "$tag_name" ]]; then
    tag_name=$(nslookup -type=txt "$subsystem_name".builds.dev.gongio.net | grep "v=" | awk '{print $NF}' | tr -d "\"v=\"")
fi
```

This also makes `--tag-name <tag>` work (e.g. `--tag-name 17.master.1.11679`), which was silently ignored before.

---

## Symptom 2 — Cannot find any export data folder in S3

```
java.lang.IllegalStateException: Cannot find any export data folder is S3
    at com.honeyfy.installer.cli.UnifiedExportImport.lambda$downloadFromS3IfRequired$6(UnifiedExportImport.java:344)
```

### Root cause

`db-snapshot-import` (run by `import-prod-data-entrypoint.sh`) defaults to the **real prod export** path. The importer looks for an `export.json.gz` manifest under a root path in bucket `gong-internal-export`:

| Path constant (`UnifiedExportImport.java`) | S3 path | Status for this account |
|---|---|---|
| `EXPORTED_ARCHIVES_ROOT_PATH` (default) | `jenkins-export/archives` | **empty** |
| `ANONYMIZED_EXPORTED_ARCHIVES_ROOT_PATH` | `jenkins-export/anonymized_archives` | **empty** |
| `SYNTHETIC_EXPORTED_ARCHIVES_ROOT_PATH` | `synthetic-export/archives` | **populated** — daily snapshots, manifest present |

Verified via:
```bash
aws --profile prod s3 ls s3://gong-internal-export/jenkins-export/archives/        # empty
aws --profile prod s3 ls s3://gong-internal-export/synthetic-export/archives/      # PRE 2026_06_22_02_06/ …
aws --profile prod s3 ls s3://gong-internal-export/synthetic-export/archives/2026_06_22_02_06/export.json.gz  # exists
```

So the default path has no data for this account; the only usable snapshot is the synthetic export. The `--synthetic` flag (`DbSnapshotImportCommand`, `InstallerCli.java`) switches the source to `synthetic-export/archives`.

### Fix — `import-prod-data-entrypoint.sh`

```diff
 -m WebAppSample \
 db-snapshot-import \
+--synthetic \
 --postgres "postgres:5432" \
```

---

## Run it

```bash
gong-module-run prod-data --import-prod-data

# watch progress (background container)
docker logs -f installercli-17.master.1.11680
```

Success looks like:
```
Found source data folder; s3Path=…/synthetic-export/archives/2026_06_22_02_06
```

If a previous attempt left a stopped container (name-collision guard at `gong-import-prod-data:94`):
```bash
docker rm -f installercli-<tag>
```

---

## ⚠️ Caveats

- **This loads synthetic prod-shaped data, not real prod data.** `jenkins-export/archives` is empty for this account — only `synthetic-export/archives` is populated. Real-prod export would need separate export-job/permission setup (infra side).
- **The import overwrites all local DBs** — including any manual seed data (e.g. `dialers_dev` from `seed-dialers-local.sql`). It's a multi-GB import across postgres/mongo/opensearch and runs in the background.
- **Both edits are local + uncommitted, in shared `@Honeyfy/gong-devops` tooling.** The `--synthetic` edit changes the *default* behavior of `prod-data`. Teammates with real-prod export access should NOT hardcode `--synthetic` — confirm with gong-devops before any PR. The tag-format fix (Symptom 1) is a genuine bug worth proposing upstream; the `--synthetic` switch (Symptom 2) is account-specific and should stay local unless the team decides otherwise.

## Files touched

| File | Change |
|---|---|
| `gong-build-commons/dev/prod-data/gong-import-prod-data` (line 63) | Remove `.`→`-` tag transform; respect `--tag-name` |
| `gong-build-commons/dev/prod-data/import-prod-data-entrypoint.sh` | Add `--synthetic` to `db-snapshot-import` |

## Related

- [[Telephony Systems]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]]
- Original goal: seed local DBs to test `process-one-event` (company 9001 / appuser 501) — see `gong-telephony-systems/dev/seed-dialers-local.sql`.
