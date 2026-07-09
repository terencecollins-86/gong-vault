---
title: Zoom Phone
component_type: external-provider-dialer
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, dialer, external-provider, zoom-phone, oncall]
---

# 📞 Zoom Phone

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External cloud-phone provider. Supervisor both **polls Zoom's REST API** (sync) and **receives pushed events** (real-time — `EventPushSupportingDialerService`). If this stops, **Zoom Phone calls stop appearing in Gong** for affected tenants.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Two parallel call APIs behind a feature flag.** `ZOOM_PHONE_USE_CALL_HISTORY_API` (`ZoomPhoneDialerService.java:1211`) switches between the **legacy `call_logs`** API and the **new `call_history`** API (GONG-121700). `listRecordingsData` (`:832`) and `syncOneCall` (`:1139`) both branch on `useCallHistoryApi`. When debugging, first confirm which branch the tenant is on — the URLs, pagination (page-number vs cursor token), and DTOs differ.
> 2. **401 self-heals mid-request.** `retryRequestsForTooManyRequests` (`:485`) retries ALL Zoom HTTP errors (Zoom is flaky) and force-refreshes the token in-place on a 401 (`:500`), writing fresh creds back to the cache. One "wasted" request per refresh is expected, not a bug.
> 3. **Recording-skip & reference-preservation are FF-gated.** `ZOOM_PHONE_IGNORE_RECORDING_SKIP_REASON_IN_PUSH` (`:130`/`:310`) changes whether a pushed event is treated as a recorded call; `ZOOM_PHONE_REFERENCE_PRESERVATION_ON_UPSERT` (`:131`) re-injects a prior `childCallId` so a follow-up push doesn't drop the `PROVIDER_CALL_IDENTIFIER` reference. A "missing reference after a 2nd event" is usually this flag being off.

---

## What it is

| | |
|---|---|
| **Role** | External provider (pull/SYNC + push) — Supervisor polls REST and/or receives events |
| **Provider class** | `ZoomPhoneDialerService` extends `EventPushSupportingDialerService` |
| **IntegrationFlavor** | `ZOOM_PHONE_API_OAUTH` (`zoomphone_api_oauth`) — enum at `IntegrationFlavor.java:64` (SMS variant `ZOOM_PHONE_SMS`) |
| **Auth** | OAuth 2.0 auth-code; `Basic clientId:clientSecret` on token endpoint, `Bearer` on API |
| **API host** | `https://api.zoom.us/v2` (`API_BASE_URL`, `ZoomPhoneDialerService.java:102`); OAuth at `zoom.us/oauth/*` |
| **Gong app secret** | protected entity `zoom-phone.api` (`client-id` / `client-secret`) |
| **Call API** | legacy `call_logs` **or** new `call_history` (FF `ZOOM_PHONE_USE_CALL_HISTORY_API`) |
| **Downstream** | shared `processCallEvent` (push) / sync→ingest path → [[DIALER-CALLS-UPDATES]] |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — Zoom list-calls for one company (legacy `"Listing calls"` `:541` / new `"Listing call history"` `:717`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.mdc.cid == '<companyId>'
| filter $d.body.contains('Listing calls') || $d.body.contains('Listing call history')
| limit 200
```
- Errors only: swap the message filter for `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch `gong-connect-dialer-events` consumer lag (push), SyncJob success, and Zoom HTTP error/429 rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

##  🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **OAuth token exchange** | `Dialers/.../services/ZoomPhoneDialerService.java:352` | `getAccessTokenFromAuthorizationCode` → form POST + Basic auth |
| **OAuth token refresh** | `Dialers/.../services/ZoomPhoneDialerService.java:407` | `refreshAndUpdateAccessToken` → `refreshAccessToken(...)` (`:413`) |
| **List calls (API branch)** | `Dialers/.../services/ZoomPhoneDialerService.java:832` | `listRecordingsData` — branches on `useCallHistoryApi` (`:848`) |
| **The HTTP retry/refresh core** | `Dialers/.../services/ZoomPhoneDialerService.java:485` | `retryRequestsForTooManyRequests` — every Zoom GET, plus the 401 in-place refresh (`:500`) |
| **Sync one call** | `Dialers/.../services/ZoomPhoneDialerService.java:1139` | `syncOneCall` — also branches legacy vs call_history |
| **Recording download** | `Dialers/.../services/ZoomPhoneDialerService.java:1061` | `downloadRecording` → `client.downloadRecording(call.callURL, ..., "mp3", ...)` |
| **Push download-URL resolve** | `Dialers/.../services/ZoomPhoneDialerService.java:217` | `getTelephonyCallEventDownloadUrl` — 3-candidate fallback (childCallId → callLogId → call element) |

`getIntegrationFlavor()` = `ZOOM_PHONE_API_OAUTH` at `:176`.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `ZoomPhoneDialerService.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 832** (list calls) or **485** (HTTP core). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync or push for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action on `:499` (`Attempting to refresh token while executing request; url={}`) to confirm whether 401-refresh is firing in prod, without a snapshot.

---

## ▶️ Trigger the flow

**Push (real-time)** — fire the **Process one telephony call event** twin with the Zoom flavor; runs the same `processCallEvent` as the live consumer. (Payloads: [[Entrypoints Within the Telephony System]] §2.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=ZOOM_PHONE_API_OAUTH' \
  -H 'Content-Type: application/json' \
  -d '{
    "companyId": 0,
    "providerIdentifier": "REPLACE_ZOOM_CALL_LOG_ID",
    "providerIdentifierType": "ZOOM_PHONE",
    "providerName": "zoom-phone",
    "direction": "OUTBOUND"
  }'
```
- Controller: `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent()` (`IngesterTelephonySystemsSupervisor/.../rest/TelephonyCallEventsTroubleshooter.java:45`; the `processCallEvent` call is at `:50`).

**Pull (single call)** — **Sync one call** (§3); flavor derived from `company-id` + `integration-id`:
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_ZOOM_CALL_LOG_ID'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`). Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.process-one-event` | Replay one pushed Zoom event (`integration-flavor=ZOOM_PHONE_API_OAUTH`) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one Zoom call |
| `TroubleshootingScheduledTaskController` / `IngesterTelephonySystemsSyncInfraTroubleshooter` | Inspect/trigger periodic sync (Entrypoints §5) |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | Zoom integration / OAuth connection state |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Zoom calls stopped for a tenant | Token refresh failing — Coralogix for `"Exception when trying to refresh an access token"` (`:429`); a `400` on refresh is remapped to `401` (`:426`) = re-auth needed. |
| Wrong/missing calls after enabling a flag | Confirm which API the tenant is on: `ZOOM_PHONE_USE_CALL_HISTORY_API` (`:1211`). Legacy and call_history differ in pagination + queue-call user resolution (`:802`/`:1015`). |
| Pushed call not recorded | `ZOOM_PHONE_IGNORE_RECORDING_SKIP_REASON_IN_PUSH` (`:310`) gates recorded-vs-skip; download URL resolved via 3-candidate fallback (`:217`), 404 = recording not ready (`MISSING_RECORDING`, `:303`). |
| `PROVIDER_CALL_IDENTIFIER` reference dropped on 2nd event | `ZOOM_PHONE_REFERENCE_PRESERVATION_ON_UPSERT` off (`:131`); turn on to re-inject the prior `childCallId` (`:1484`). |
| Intermittent Zoom 5xx/429 | Expected flakiness — `retryRequestsForTooManyRequests` retries (`:485`); throttle re-drives. |

Related: [[IngesterTelephonySystemsSupervisor]] · [[GONG-CONNECT-DIALER-EVENTS]] · [[DIALER-CALLS-UPDATES]] · [[04 - Providers & Dialers]] · [[Entrypoints Within the Telephony System]]
