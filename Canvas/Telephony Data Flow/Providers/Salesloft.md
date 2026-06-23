---
title: Salesloft
component_type: external-provider
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, provider, dialer, pull-sync, oauth, oncall]
---

# 📞 Salesloft

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External provider polled on a schedule via `SalesloftDialerService` (OAuth2). If this breaks, **Salesloft calls stop importing** for the company. Two flavors share this code — the standard OAuth one and a username/password variant for locked recordings.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Two recording-download APIs, switched by a date cache.** `isSafeRecordingNewApiCache` returns *new-API* only if the integration was enabled **after `2023-09-01`** (`NEW_API_CREATION_DTAE`, `:126`,`:181`). Old API 302 → auto-falls-back to new API (`handleOldApiDownloadException :505-514`). Download failures often trace here.
> 2. **Two-endpoint join.** A call = `call_data_records` **+** `activities/calls` merged (`listRecordingsData :651-722`, comment @659). Missing call data can mean only one endpoint returned.
> 3. **Connect requires an ADMIN user.** `validateCredentials` calls `/v2/me.json` and rejects non-admins (`testIfAdmin :290-338`). A non-admin token fails at connect, not at sync.
> 4. **`SALESLOFT_API_OAUTH_USERNAME_PASSWORD` scrapes the Salesloft web UI** (no API for the "must-be-logged-in-to-listen" recording feature, CASE-12004). It caches each recording to **BYOK S3** then re-downloads (`SalesloftUsernamePasswordDialerService.java:275-309`).

---

## What it is

| | |
|---|---|
| **Role** | External dialer provider; Supervisor **pulls** calls via REST (SYNC origin) |
| **Local class** | `SalesloftDialerService extends AbstractOAuthDialerService` (+ `SalesloftUsernamePasswordDialerService extends SalesloftDialerService`) |
| **IntegrationFlavor** | `SALESLOFT_API_OAUTH` (`:200`, enum `IntegrationFlavor.java:54`); username/pass variant `SALESLOFT_API_OAUTH_USERNAME_PASSWORD` (`SalesloftUsernamePasswordDialerService.java:86`, enum `:55`) |
| **Provider API** | `https://api.salesloft.com` — `/v2/call_data_records.json`, `/v2/activities/calls.json`, `/v2/users.json`, `/v2/me.json` (`:98-109`) |
| **Auth** | OAuth2 Bearer — `addAuthorizationBearerToken(accessToken, request)`; refresh in `refreshAndUpdateAccessToken :611-637`. Gong client-id/secret from secret `salesloft.api` (`load :190-196`) |
| **Recording** | `recording.url` (old) or `dialer_recording.uuid` → `/v2/streamable_dialer_recordings/{uuid}` (new) (`CALL_DOWNLOAD_BY_UUID_URL :109`) |
| **SMS** | None — Salesloft integration is calls-only |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the two list calls + the call/user joins for this provider:
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Listing call data records') || $d.body.contains('Get Call Data Record object')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch `feign.*` / provider-sync error rate, OAuth-refresh failures, and `DIALERS_SYNC_*` queue depth. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **List call data records** | `Dialers/.../services/SalesloftDialerService.java:744` | `request.getForObject(...)` — the primary provider call |
| **Sync one call (REST)** | `Dialers/.../services/SalesloftDialerService.java:999` | `getForObject(GetOneCallDataRecordResponse.class)` — single-call fetch |
| **Old→new API fallback** | `Dialers/.../services/SalesloftDialerService.java:507` | 302 on old API → switch to new UUID download (`handleOldApiDownloadException`) |
| **Admin check (connect)** | `Dialers/.../services/SalesloftDialerService.java:304` | `/v2/me.json` admin validation — why a token is rejected at connect |
| **User/pass: cache recording** | `Dialers/.../services/SalesloftUsernamePasswordDialerService.java:280` | FE-scraped recording → BYOK S3 upload (username/pass flavor only) |

Step into `syncOneCall` @987 (or `listRecordingsData` @651) to follow the provider fetch + join.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `SalesloftDialerService.java` in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 744** (list) or **line 507** (download fallback). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject `salesloftCompanyCache.lastProviderCallMade` (the exact URL) without snapshot overhead.

---

## ▶️ Trigger the flow

Pull one Salesloft call through the full provider-fetch + join path with the **Sync one call** troubleshooter — flavor is derived from `company-id` + `integration-id`. Details + payloads: [[Entrypoints Within the Telephony System]] §3.

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_SALESLOFT_CALL_DATA_RECORD_ID'
```
- `providerCallId` is the **Call Data Record** id (the service then resolves the linked `activities/calls` id, `syncOneCall :999-1016`).
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- `integration-id` must point to a **SALESLOFT_API_OAUTH** (or username/pass) integration, else `getIntegrationFlavor` (`:479`) returns the helper response.
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Alternative (Salesloft is pull-only): drive the periodic SyncJob chain (§5).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one Salesloft call |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic Salesloft sync |
| `IntegrationsTroubleshooter` | Verify OAuth creds / admin status / flavor |
| `ProviderDataAccessTroubleshooter` | Raw provider-data access for the company |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[04 - Providers & Dialers]] and [[IngesterTelephonySystemsSupervisor]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| All Salesloft calls stopped | (1) OAuth refresh failing? `refreshAndUpdateAccessToken :611` — 400/401 → re-auth needed. (2) 429 → 5-min back-off (`listUsers :422`). (3) SyncJob ran? `TroubleshootingScheduledTaskController`. |
| Recording download fails | Old/new-API mismatch — check the @507 fallback ran; verify enabled-date vs `2023-09-01` (`:181`). |
| Connect rejected at setup | Token user isn't a Salesloft **admin** (`testIfAdmin :306`) — `/v2/me.json` returned `team_admin=false`. |
| Username/pass flavor: empty audio | FE scrape failed or recording not cached to S3 (`cacheCallRecordingAndFinalize :275`); check "Error when trying to cache Salesloft call" debug log. |
| Call has data but no CRM link | `crmSync :960` only fills SFDC ids when company has an SFDC CRM + connector present. |
