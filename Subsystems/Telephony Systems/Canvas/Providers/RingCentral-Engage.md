---
title: RingCentral Engage
component_type: external-provider-dialer
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, dialer, external-provider, ringcentral-engage, oncall]
---

# 📞 RingCentral Engage

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External **contact-center / dialer** provider (separate product from RingCentral cloud-phone — different class, different API host `engage.ringcentral.com`). Supervisor **polls Engage's REST reporting API on a schedule** (SYNC/pull only). If this stops, **Engage calls stop appearing in Gong** for affected tenants.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Deprecated flavor.** `RINGCENTRAL_ENGAGE_API` lives in the *deprecated* block of the enum (`IntegrationFlavor.java:77`) with `sqsInfraSupported=false` — it does **not** run on the SQS SyncJob infra; it uses the legacy time-based sync. Don't expect it on the SyncInfra troubleshooter queue.
> 2. **Tokens never refresh.** `refreshAndUpdateAccessToken` just returns the existing creds (`RingCentralEngageDialerService.java:219`). Auth is a **two-step login**: username/password/platformId → short-lived access token → a **permanent API token** (`getAccessToken` `:173` → `getPermanentApiToken` `:187`), stored once. If auth breaks, the permanent token is bad — re-validate credentials, don't wait for a refresh.
> 3. **Calls fetched as an Excel-style report.** `listRecordingsData` POSTs a `GLOBAL_CALL_TYPE_EXCEL` report query (`:282`/`LIST_CALLS_REPORT_TYPE` `:57`), paged one **day** at a time (`getPagingDto` `:266`). User email is resolved by walking agent-groups → agents → per-agent detail calls (`listUsers` `:223`).

---

## What it is

| | |
|---|---|
| **Role** | External provider (pull/SYNC) — Supervisor polls Engage reporting API for calls + recordings |
| **Provider class** | `RingCentralEngageDialerService` extends `AbstractTokenSupportedDialerService` |
| **IntegrationFlavor** | `RINGCENTRAL_ENGAGE_API` (`ringcentralengage_api`) — **deprecated block**, `sqsInfraSupported=false` |
| **Auth** | username + password + platformId → access token → **permanent API token** (`X-Auth-Token` header) |
| **API host** | `https://engage.ringcentral.com` (`API_ROOT`, `RingCentralEngageDialerService.java:53`) |
| **User association** | by EMAIL (`USER_ASSOCIATION_STRATEGY`, `:62`) |
| **Downstream** | shared sync→ingest path → [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]] hand-off |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — Engage list-calls + list-users debug lines for one company (`RingCentralEngageDialerService.java:300`/`:258`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.mdc.cid == '<companyId>'
| filter $d.body.contains('Listing calls') || $d.body.contains('Listing users')
| limit 200
```
- Errors only: swap the message filter for `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch periodic-sync success and outbound HTTP error rate to `engage.ringcentral.com`. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Get access token** | `Dialers/.../services/RingCentralEngageDialerService.java:173` | `getAccessToken` — username/password/platformId login |
| **Get permanent API token** | `Dialers/.../services/RingCentralEngageDialerService.java:187` | `getPermanentApiToken` — the token actually stored & used |
| **Validate credentials** | `Dialers/.../services/RingCentralEngageDialerService.java:160` | `validateCredentials` — full auth chain on connect; first place auth breaks |
| **List calls (report)** | `Dialers/.../services/RingCentralEngageDialerService.java:292` | `listRecordingsData` → `request.postForObject(queryJson, ...)` — the Excel-report POST |
| **Recording download** | `Dialers/.../services/RingCentralEngageDialerService.java:336` | `downloadRecording` → `client.downloadRecording(call.callURL, folder)` |

`getIntegrationFlavor()` returns `RINGCENTRAL_ENGAGE_API` at `:100`. Step from `:292` → the `CallDataDto` ctor (`:472`) to see ANI/DNIS → from/to mapping.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `RingCentralEngageDialerService.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 292** (list calls) or **187** (permanent token). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action on `:300` (`Listing calls; fromDate={}; toDate={}; total={}`) to confirm a sync window returned rows without a snapshot.

---

## ▶️ Trigger the flow

Use the **Sync one call** troubleshooter — pulls one Engage call by id and runs ingest. Flavor is derived from `company-id` + `integration-id`. (Payloads: [[Entrypoints Within the Telephony System]] §3.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_ENGAGE_UII'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Engage is **pull-only** (no event push), and `sqsInfraSupported=false`, so it runs on the **legacy time-based sync**, not the SQS SyncJob queue — the `process-one-event` push twin (§2) does not apply.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one Engage call |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic Engage sync (legacy time-based) |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | Engage integration config + credential state |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| All Engage calls stopped for a tenant | Permanent API token invalid (no auto-refresh — `:219`). Coralogix for the warn `"Error when trying to get an access token or a permanent API token"` (`:165`); re-validate creds via `IntegrationsTroubleshooter`. |
| Calls missing for specific days | Report is paged 1 day at a time (`:266`); a single failed day-page can leave a gap. Re-run the sync window. |
| User not associated | `listUsers` walks agent-groups→agents→detail (`:223`); a user missing from any group, or email vs username mismatch (`:315`), drops the association. |
| Nothing on the SyncInfra queue | Expected — `sqsInfraSupported=false` (`IntegrationFlavor.java:77`); Engage uses the legacy time-based sync, not the SQS SyncJob. |

Related: [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Inbound Topics/GONG-CONNECT-DIALER-EVENTS]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]] · [[04 - Providers & Dialers]] · [[Entrypoints Within the Telephony System]]
