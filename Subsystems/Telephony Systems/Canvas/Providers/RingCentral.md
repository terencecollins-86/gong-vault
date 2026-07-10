---
title: RingCentral
component_type: external-provider-dialer
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, dialer, external-provider, ringcentral, oncall]
---

# 📞 RingCentral

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External cloud-phone provider. The Supervisor **polls RingCentral's REST API on a schedule** (SYNC/pull only — no push events), fetches the call log + recordings, and ingests them. If this stops, **RingCentral calls stop appearing in Gong** for affected tenants; everything else is unaffected.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Two flavors, one class.** `RingCentralDialerService` (`RINGCENTRAL_API_OAUTH`, `RingCentralDialerService.java:144`) and its subclass `RingCentralBusinessConnectDialerService` (`RINGCENTRAL_BUSINESS_CONNECT`, `RingCentralBusinessConnectDialerService.java:11`). The base `refreshAndUpdateAccessToken(creds, oauthCreds)` **throws** `"Must provide specific integration flavor..."` (`RingCentralDialerService.java:291`) — token refresh MUST go through the flavor-aware overload at `:358`. Confusing a flavor here breaks refresh.
> 2. **Recordings lag ~10 min.** `getPagingDto` caps the page end-time to `now - RECORDING_MIGHT_NOT_BE_FINAL_TIME_AFTER_COMPLETION` (`RingCentralDialerService.java:237`) because RC recordings aren't ready immediately. A "missing recording" right after a call is usually just not-ready-yet → `NOT_READY_RETRY_SPEC` (3-hour retries, `:98`/`:325`).
> 3. **Rate limiting (429) is retried over 20 min** (`RATE_LIMIT_RETRY_SPEC`, `:97`/`:322`); 404 on a recording maps to `SkipCode.MISSING_RECORDING` (`:325`). Per-leg recording explosion is FF-gated by sync property `RINGCENTRAL_IMPORT_ALL_LEG_RECORDINGS` (`:283`).

---

## What it is

| | |
|---|---|
| **Role** | External provider (pull/SYNC) — Supervisor polls RC REST API for call log + recordings |
| **Provider class** | `RingCentralDialerService` extends `AbstractOAuthDialerService` |
| **Sibling class** | `RingCentralBusinessConnectDialerService` extends `RingCentralDialerService` |
| **IntegrationFlavor** | `RINGCENTRAL_API_OAUTH` (`ringcentral_api_oauth`) · `RINGCENTRAL_BUSINESS_CONNECT` (`ringcentral_business_connect`) |
| **Auth** | OAuth 2.0 authorization-code; Basic auth (`Base64(appKey:appSecret)`) on token endpoint |
| **API host (prod)** | `https://api.ringcentral.com` (`RING_CENTRAL_BASE_API_URL`); dev `platform.devtest.ringcentral.com` |
| **Gong app secret** | protected entity `ring-central.api` (`ring_central_application_key` / `..._secret`) |
| **Downstream** | shared `processCallEvent` / sync→ingest path → [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]] hand-off |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — RC sync activity for one company (download + list-calls debug lines, `RingCentralDialerService.java:308`/`:391`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.mdc.cid == '<companyId>'
| filter $d.body.contains('Downloading RC call') || $d.body.contains('Couldn''t find the page')
| limit 200
```
- Errors only: swap the message filter for `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch the SyncJob success rate and outbound `feign.*` / RC HTTP error rate (429s). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **OAuth token exchange** | `Dialers/.../services/RingCentralDialerService.java:185` | `getAccessTokenFromAuthorizationCode` — the `Basic` auth + form POST to `/restapi/oauth/token` |
| **Token refresh (flavor-aware)** | `Dialers/.../services/RingCentralDialerService.java:358` | `refreshAndUpdateAccessToken(...,flavor)` — the only refresh path that works; base `:291` throws |
| **List call log** | `Dialers/.../services/RingCentralDialerService.java:391` | `listRecordingsData` → `httpClient.getAccountCallsLog(...)` — the page fetch |
| **Sync one call** | `Dialers/.../services/RingCentralDialerService.java:762` | `syncOneCall` → `httpClient.getCompanyCallLogRecord(...)` — single-call pull |
| **Recording download** | `Dialers/.../services/RingCentralDialerService.java:309` | `downloadRecording` → `client.downloadFile(folder, call.callURL, token)` |

Step from `syncOneCall` (`:762`) → `convertToCallData` (`:518`) to watch how an RC record becomes a `CallData`. The flavor returned by `getIntegrationFlavor()` is at `:144` (base) / Business Connect at `RingCentralBusinessConnectDialerService.java:11`.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `RingCentralDialerService.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 391** (list call log) or **762** (`syncOneCall`). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action on `:308` (`Downloading RC call; callId={}`) to inject `call.id` / `call.callURL` without snapshot overhead.

---

## ▶️ Trigger the flow

Use the **Sync one call** troubleshooter — pulls one call from RC and runs the full ingest path. The flavor is derived from `company-id` + `integration-id`, so point them at a RingCentral integration. (Payloads: [[Entrypoints Within the Telephony System]] §3.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_RC_CALL_ID'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

RingCentral is **pull-only** (no event-push for the recorded-calls flavor), so the push twin (§2 `process-one-event`) does not apply here — drive the SyncJob chain (§5) for the periodic path.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one RC call |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic RC sync |
| `IngesterTelephonySystemsSyncInfraTroubleshooter` | Run the SyncJob chain now / enqueue a SyncJob (Entrypoints §5) |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | RC integration config / OAuth connection state |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| All RC calls stopped for a tenant | (1) OAuth token expired/refresh failing — Coralogix for `"Failed to refresh token"` (`RingCentralDialerService.java:363`); check the integration is on the flavor-aware refresh path. (2) Did the SyncJob run? `TroubleshootingScheduledTaskController`. |
| Recording missing right after call | Expected — RC lag (~10 min, `:237`); `NOT_READY_RETRY_SPEC` retries over hours (`:325`). Confirm it appears on a later sync. |
| 429 / rate-limited | `RATE_LIMIT_RETRY_SPEC` spreads retries over 20 min (`:322`); throttle, don't re-drive aggressively. |
| Duplicate calls per leg | `RINGCENTRAL_IMPORT_ALL_LEG_RECORDINGS` sync property is on (`:283`) → `generateRecordsPerLeg` (`:461`) splits one call into per-leg records. |
| Business Connect tenant misbehaving | Confirm it's resolving `RINGCENTRAL_BUSINESS_CONNECT` (`RingCentralBusinessConnectDialerService.java:11`), not the base flavor. |

Related: [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Inbound Topics/GONG-CONNECT-DIALER-EVENTS]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Outbound Topics/DIALER-CALLS-UPDATES]] · [[04 - Providers & Dialers]] · [[Entrypoints Within the Telephony System]]
