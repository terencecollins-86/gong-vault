---
title: Ytel
component_type: external-provider
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, provider, dialer, sftp, pull-sync, oncall]
---

# 📞 Ytel

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> **SFTP/file-drop provider**, not a REST API. Ytel drops recording files into an SFTP location that lands in an S3 bucket; `YtelDialerService` (a `DialerService` extending `AbstractSFTPDialerService`) lists those files per day and parses metadata **from the filename**. If this breaks, **Ytel calls stop importing** for the company.
>
> 🔑 **Gotchas (verified in code):**
> 1. **All call metadata comes from the filename**, not an API. Template `$ignored/$year$month$day-$hour$minute$second_$phone_$username.$filetype` (`DEFAULT_FILEPATH_TEMPLATE :59`). A renamed/misformatted file → the call is skipped (parse returns empty, `:130-132`). Per-company template/day-pattern overrides exist (`FILE_PATH_TEMPLATE`/`FILE_PATH_DAY_PATTERN`, `:104-107`).
> 2. **`-all` username suffix is stripped.** A filename username ending in `-all` has the suffix removed before user association (`:133-136`) — watch for it when a user won't match.
> 3. **Listing is day-by-day folders.** `listRecordingsData` lists one S3 day-folder per page and advances the date (`:120-160`); `shouldListCallsContinue` walks until `endDate` (`:166-168`). A missing day-folder = silently zero calls for that day.

---

## What it is

| | |
|---|---|
| **Role** | External dialer provider (SFTP file-drop); Supervisor lists files & imports (SYNC origin) |
| **Local class** | `YtelDialerService extends AbstractSFTPDialerService` |
| **IntegrationFlavor** | `YTEL_FTP` (`:78`, enum `IntegrationFlavor.java:79`) |
| **Provider transport** | SFTP → S3 bucket; files listed via `s3Accessor.listFilesInFolder(origMediaBucket, companyRootFolder, dateStr, ...)` (`:121`) |
| **Auth** | SFTP credentials (managed by `AbstractSFTPDialerService` infra); SSH public-key — see `SftpTroubleshooter`/`SshPublicKeyTroubleshooter` |
| **Recording** | The dropped file itself (`$filetype` from filename, e.g. wav/mp3); download via the SFTP/S3 infra in the base class |
| **User association** | By **name then email** parsed from filename (`USER_ASSOCIATION_STRATEGY :64`; `getAppUser :202-211`) |
| **SMS** | None — Ytel is calls-only |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the per-day file listing + `-all` suffix handling:
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('listFilesForDate done') || $d.body.contains("Removed '-all' suffix")
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch provider-sync error rate, S3 access errors, and `DIALERS_SYNC_*` queue depth. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **List files for day** | `Dialers/.../services/YtelDialerService.java:121` | `s3Accessor.listFilesInFolder(...)` — the actual "fetch" (S3 listing) |
| **Parse filename → call** | `Dialers/.../services/YtelDialerService.java:130` | `configurableFilepath.createCallData(...)` — where filename metadata is parsed; empty = skipped |
| **`-all` suffix strip** | `Dialers/.../services/YtelDialerService.java:135` | Username suffix removal before user match |
| **User association** | `Dialers/.../services/YtelDialerService.java:205` | `lookUpAppUserByFullName(...)` — name-first match |

Step from `:121` (list) → per-file `createCallData` @130 → `getAppUser` @202.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `YtelDialerService.java` in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 121** (file listing) or **line 130** (filename parse). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject `filenames.size()` / `currFilename` without snapshot overhead.

---

## ▶️ Trigger the flow

Re-import one Ytel call with the **Sync one call** troubleshooter — flavor (`YTEL_FTP`) is derived from `company-id` + `integration-id`. For SFTP, `providerCallId` is the file/call identifier parsed from the filename. Details + payloads: [[Entrypoints Within the Telephony System]] §3.

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_YTEL_CALL_ID'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- `integration-id` must point to a **YTEL_FTP** integration, else `getIntegrationFlavor` (`:479`) returns the helper response.
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Alternative (Ytel is pull/file-based, no push path): drive the periodic SyncJob chain (§5) to re-scan day-folders.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-import one Ytel file/call |
| `SftpTroubleshooter` / `SshPublicKeyTroubleshooter` | FTP-dialer connectivity & SSH keys |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic day-folder scan |
| `ProviderDataAccessTroubleshooter` | Raw provider-data / S3 file access for the company |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[04 - Providers & Dialers]] and [[IngesterTelephonySystemsSupervisor]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| All Ytel calls stopped | (1) SFTP/SSH key broken? `SftpTroubleshooter` / `SshPublicKeyTroubleshooter`. (2) Files reaching the S3 bucket? Check `listFilesForDate done` count (`:122`). (3) SyncJob ran? `TroubleshootingScheduledTaskController`. |
| Some calls skipped | Filename doesn't match the template → parse returns empty (`:130`). Verify the company's `FILE_PATH_TEMPLATE` (`:106`) vs the actual filenames. |
| User won't match | Check the `-all` suffix strip (`:135`) and name-vs-email association (`:202`). |
| Whole day missing | Day-folder absent or named off the `FILE_PATH_DAY_PATTERN` (`:104`); listing yields zero silently. |
