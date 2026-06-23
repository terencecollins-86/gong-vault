---
title: DataStore-S3
component_type: data-store
service: IngesterTelephonySystemsSupervisor
cluster: S3
tags: [telephony-systems, s3, cloud-storage, data-store, oncall]
---

# 🗄️ S3 (recording storage)

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[IngesterTelephonySystemsSupervisor]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> S3 is where **call-recording media** lives — pre-redaction audio, mobile-recording imports, and Enable session data. If S3 access breaks, **recordings can't be uploaded, downloaded, or re-imported** and ingestion stalls at the media step.
>
> 🔑 **Three gotchas that will burn you (verified in code):**
> 1. **Customer-owned buckets are reached by assuming the customer's IAM role**, not Gong creds — `CustomerS3AssumedRoleAccessor` assumes `ExternalS3BucketAccessor` (`role` default at `CustomerS3AssumedRoleAccessor.java:39`, ARN built at `:55`). A broken/rotated customer role ⇒ media fetch fails for *that company only*.
> 2. The service declares **`externalCmkAccessNeeded: true`** (descriptor line 9). Customer media may be encrypted with a customer-managed KMS key; Gong's own buckets use Gong's SSE key. A KMS-permission gap on the customer key looks like an S3 403, not a KMS error.
> 3. **`S3EventsTroubleshooter` does not touch S3** — it reads/writes S3-event **metadata rows in Postgres** (`S3EventsDaoImpl`, DIALERS db). "S3 event missing" usually means the DB row, not the object.

---

## What it is

| | |
|---|---|
| **Role** | Object storage for call-recording media + Enable session data |
| **Declared buckets** (descriptor `cloudStorage`, lines 118–130) | `honeyfy` (`/*`), `gong-pre-redaction-media` (`/*`), `gong-transient-data` (`/ImportMobileRecording/`), `gong-enable` (`/sessions/`) |
| **What's stored** | `gong-pre-redaction-media` → raw call audio before redaction · `gong-transient-data/ImportMobileRecording/` → mobile-recording imports · `gong-enable/sessions/` → Enable session data · `honeyfy` → general main bucket |
| **Supervisor accessor (Gong buckets)** | `CloudFileStoreAccessor` via `CloudFileStoreAccessorFactory` (v1 framework, `com.honeyfy.filestorage`) |
| **Customer-bucket accessor** | `CustomerS3AssumedRoleAccessor` (assumed-role) · `S3Accessor` (`com.honeyfy.awsintegration.s3`) for troubleshooter listing |
| **Bucket-name constants** | `ImporterCloudStorage.java:39–44` (`BUCKET_MAIN`/`BUCKET_PRE_REDACTION`/`BUCKET_TRANSIENT_DATA`/`BUCKET_ENABLE` + `sessions/`, `ImportMobileRecording/` prefixes) |
| **Troubleshooters** | `S3Troubleshooter`, `S3EventsTroubleshooter` |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — S3 delete/upload + customer-bucket assume-role lines:
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('audio file') || $d.body.contains('Assuming') || $d.body.contains('s3')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: swap the message filter for `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). For S3, watch the **AWS S3 metric family** (`aws.s3.*` — 4xx/5xx, request latency) and the Supervisor `com.honeyfy.*` import-failure counters. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Gong-bucket write (Supervisor)** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:90` | `accessor.deleteFile(s3OrigMediaBucket, s3ObjectKey)` — real S3 op on the orig-media bucket; the cleanest local S3 hook |
| **Accessor creation** | `IngesterTelephonySystemsSupervisor/.../services/PbxRecordingImportService.java:89` | `cloudFileStoreFactory.createAccessor(companyId)` — tenant-scoped accessor build |
| **Customer-bucket download** | `TelephonySystemsRecordingsImporter/.../service/CustomerS3AssumedRoleAccessor.java:105` | `downloadFile(bucket, key, dest)` — the assumed-role `getObject` |
| **Role assumption** | `TelephonySystemsRecordingsImporter/.../service/CustomerS3AssumedRoleAccessor.java:55` | ARN `arn:aws:iam::{acct}:role/{role}` built before STS assume |
| **S3-event metadata write** | `Dialers/.../importcalls/S3EventsDaoImpl.java:34` | `storeCallDetails(...)` — Postgres row, *not* S3 (see gotcha 3) |

> The cloud-storage framework (`CloudFileStoreAccessor`, `S3Accessor`, KMS) lives in external Gong libs (`com.honeyfy.filestorage`, `com.honeyfy.awsintegration.s3`) — **not mounted here**. The local hooks above are on our side of that boundary.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `PbxRecordingImportService.java` in IntelliJ; match the file version to prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 90**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Inspect locally (below), read the snapshot vars (`s3OrigMediaBucket`, `s3ObjectKey`), then **delete the breakpoint.**

> Use a **Log** action instead of a Snapshot to inject `s3ObjectKey` on-demand without snapshot overhead.

---

## 🔍 Inspect locally

S3 is read/written, not "triggered". To observe a real object operation, drive an import or use the S3 troubleshooter to list a customer bucket.

**List a customer bucket (verifies access + lists keys)** — via `S3Troubleshooter` (`/troubleshooting/s3`):
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/s3/generic/s3/executeListS3OnCustomerBucket?company-id=0&integration-id=0&region=US_EAST_1&bucket=REPLACE_CUSTOMER_BUCKET&folderPath=/'
```
- Controller: `S3Troubleshooter.executeS3ListFilesForCompany()` (`IngesterTelephonySystemsSupervisor/.../rest/S3Troubleshooter.java:104`; route `:103`). Gong buckets (`gong-*`/`honeyfy-*`) are **rejected** here — access is via AWS+Okta (`:118`/`:126`).
- Folders variant: `executeS3ListFoldersForCompany()` (`S3Troubleshooter.java:73`, route `:72`).

**Inspect S3-event metadata rows (Postgres)** — via `S3EventsTroubleshooter` (`/troubleshooting/s3-events`):
```bash
curl 'http://localhost:8097/troubleshooting/s3-events/listEventsForCompanyAndIntegration?company-id=0&integration-id=0'
```
- Controller: `S3EventsTroubleshooter.listEventsForCompanyAndIntegration()` (`IngesterTelephonySystemsSupervisor/.../rest/S3EventsTroubleshooter.java:61`). Default bucket on upsert/delete is `gong-pre-redaction-media` (`:99`, `:118`).

To drive a real media write, run a recording import (see [[Entrypoints Within the Telephony System]] §3 Sync one call / §5 SyncJob).

---

## 🧰 Troubleshooters

| Troubleshooter | Endpoint(s) | Use for |
|---|---|---|
| `S3Troubleshooter` | `executeListS3OnCustomerBucket` (`:104`), `executeListS3FoldersOnCustomerBucket` (`:73`) | List files/folders on a **customer** bucket using their import credentials |
| `S3EventsTroubleshooter` | `listEventsForCompanyAndIntegration` (`:61`), `upsertEvent` (`:114`), `deleteSpecificEvent` (`:95`), `processDLQ` (`:145`) | Inspect/re-drive S3-drop **event metadata** (Postgres rows), reprocess DLQ |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Recordings not uploaded/downloaded for one company | (1) Customer role assume failing? Coralogix for "Assuming ... role" + S3 403. (2) Their bucket/region/credentials in DB (`S3Troubleshooter.executeListS3OnCustomerBucket`). (3) `externalCmkAccessNeeded` — customer KMS key permission. |
| "S3 event missing" | It's a **Postgres** row, not the object — `S3EventsTroubleshooter.listEventsForCompanyAndIntegration` (`:61`); re-add with `upsertEvent` (`:114`). |
| Gong-bucket access denied | Listing `gong-*` via troubleshooter is **blocked by design** (`S3Troubleshooter.java:118`) — use AWS console via Okta. |
| S3 event stuck in DLQ | `S3EventsTroubleshooter.processDLQ` (`:145`) reprocesses; failures are logged per-message, not thrown (`:154`). |
