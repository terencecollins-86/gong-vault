---
title: Dialpad
component_type: external-provider-dialer
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, dialer, external-provider, dialpad, oncall]
---

# 📞 Dialpad

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External cloud-phone provider with **two implementations sharing one flavor** (`DIAL_PAD_API`). The Supervisor both **polls Dialpad's REST API** (sync) and **receives pushed events** (real-time). If this stops, **Dialpad calls stop appearing in Gong** for affected tenants. The **webhook/REST management side** (subscriptions, callbacks) is a separate concern — see [[Dialpad-Webhook-Controller]].
>
> 🔑 **Gotchas (verified in code):**
> 1. **Two classes, same flavor `DIAL_PAD_API`.** `DialpadOAuthDialerService` (OAuth 2.0 + Dialpad REST/Feign client, push-supporting, `DialpadOAuthDialerService.java:135`) is the modern path; `DialPadDialerService` (legacy **CSV stats-report** download, token in settings, `DialPadDialerService.java:154`) is the old one. Both return `IntegrationFlavor.DIAL_PAD_API` — the connection method (`DIALPAD_OAUTH` vs `DIALPAD`) decides which is used. The OAuth path is FF-gated by `DIALPAD_OAUTH_DIALER_FF_NAME` (`DialpadOAuthDialerService.java:159`).
> 2. **Legacy CSV is async & eventually-consistent.** `DialPadDialerService.listRecordingsData` requests a stats report, polls for its URL, then downloads a CSV (`:252`/`:256`/`:260`). A 404 on the report deletes the cached `ASYNC_REQUEST_ID` and restarts (`:334`). Null CSV durations are coerced to **0 → filtered as TOO_SHORT** and retried next sync (`:563`).
> 3. **OAuth user resolution chases operator calls.** Calls with `entryPointCallId` are dropped as duplicates; user is resolved from the call's own target or, for queue/coaching calls, the **operator call** — fetched via an extra `getCall` on a cache miss (`DialpadOAuthDialerService.java:336`).

---

## What it is

| | |
|---|---|
| **Role** | External provider (pull/SYNC + push) — Supervisor polls REST and/or receives events |
| **Modern class** | `DialpadOAuthDialerService` extends `EventPushSupportingDialerService` |
| **Legacy class** | `DialPadDialerService` extends `AbstractDialerService` (CSV stats-report) |
| **IntegrationFlavor** | `DIAL_PAD_API` (`dialpad_api`) — shared by both; OAuth flavor in enum at `IntegrationFlavor.java:27` |
| **Auth (modern)** | OAuth 2.0 auth-code via `DialpadDialerClient` (gong-clients Feign); scopes `calls:list recordings_export offline_access` (`:214`) |
| **Auth (legacy)** | static API token in integration settings, sent as `Bearer` (`DialPadDialerService.java:192`) |
| **Gong app secret (OAuth)** | protected entity `dialpad.oauth.api` (`..._client_id` / `..._client_secret`) |
| **Downstream** | shared `processCallEvent` (push) / sync→ingest path → [[DIALER-CALLS-UPDATES]] |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — Dialpad list-calls for one company (OAuth `DialpadOAuthDialerService.java:290`; legacy `DialPadDialerService.java:282`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.mdc.cid == '<companyId>'
| filter $d.body.contains('Listing calls')
| limit 200
```
- Errors only: swap the message filter for `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch the `gong-connect-dialer-events` consumer lag (push path), SyncJob success, and outbound Dialpad `feign.*` error rate. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **OAuth token exchange** | `Dialers/.../services/DialpadOAuthDialerService.java:220` | `getAccessTokenFromAuthorizationCode` → `dialpadDialerClient.getOrRefreshAccessToken(...)` |
| **OAuth token refresh** | `Dialers/.../services/DialpadOAuthDialerService.java:248` | `refreshAccessToken` — grant_type=refresh_token |
| **OAuth list calls** | `Dialers/.../services/DialpadOAuthDialerService.java:298` | `listCallsInternal` → `dialpadDialerClientCommonService.listCalls(...)` (with 401-refresh retry) |
| **Push download URL** | `Dialers/.../services/DialpadOAuthDialerService.java:509` | `getTelephonyCallEventDownloadUrl` → `dialpadDialerClient.getCall(...)` (resolves recording for a pushed event) |
| **OAuth recording download** | `Dialers/.../services/DialpadOAuthDialerService.java:458` | `downloadRecording` → `client.downloadRecording(call.callURL, ...)` |
| **Legacy CSV request** | `Dialers/.../services/DialPadDialerService.java:252` | `requestAsyncRecordingsStatReport` — kicks off the async CSV report |
| **Legacy CSV parse** | `Dialers/.../services/DialPadDialerService.java:367` | `fetchCallRecords` → `new CallData(csvRecord)` per row |

> Note: the OAuth REST/Feign client (`DialpadDialerClient`, `dialpadDialerClientCommonService`) lives in **gong-clients** (`com.honeyfy.clients.telephonysystems.client.Dialpad`), **not** in this repo. The local hooks above (`:220`, `:298`, `:509`) are on **our** side of that boundary — set them to watch what we send/receive. `getIntegrationFlavor()` = `DIAL_PAD_API` at `DialpadOAuthDialerService.java:135` / `DialPadDialerService.java:154`.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialpadOAuthDialerService.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 298** (list calls) or **509** (push download-URL resolve). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync or push for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action on `:359` (`Could not find provider user for call; callId={}`) to catch user-association misses without a snapshot.

---

## ▶️ Trigger the flow

**Push (real-time, OAuth path)** — fire the **Process one telephony call event** twin with the Dialpad flavor; it runs the same `processCallEvent` as the live consumer (Origin `TROUBLESHOOTER`). (Payloads: [[Entrypoints Within the Telephony System]] §2.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=DIAL_PAD_API' \
  -H 'Content-Type: application/json' \
  -d '{
    "companyId": 0,
    "providerIdentifier": "REPLACE_DIALPAD_CALL_ID",
    "providerIdentifierType": "DIAL_PAD",
    "providerName": "dialpad",
    "direction": "OUTBOUND"
  }'
```
- Controller: `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent()` (`IngesterTelephonySystemsSupervisor/.../rest/TelephonyCallEventsTroubleshooter.java:45`; the `processCallEvent` call is at `:50`).

**Pull (single call)** — **Sync one call** (§3) drives the sync→ingest path; flavor derived from `company-id` + `integration-id`:
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_DIALPAD_CALL_ID'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`). Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `TelephonyCallEventsTroubleshooter.process-one-event` | Replay one pushed Dialpad event (`integration-flavor=DIAL_PAD_API`) |
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one Dialpad call |
| `TroubleshootingScheduledTaskController` / `IngesterTelephonySystemsSyncInfraTroubleshooter` | Inspect/trigger the periodic sync (Entrypoints §5) |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | Dialpad integration / OAuth connection state |

Webhook subscription/management endpoints are documented separately — [[Dialpad-Webhook-Controller]]. Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Dialpad calls stopped (OAuth tenant) | Token refresh failing — Coralogix for `"Exception when trying to refresh an access token"` (`DialpadOAuthDialerService.java:259`); confirm `DIALPAD_OAUTH_DIALER_FF_NAME` is on and the connection method is `DIALPAD_OAUTH`. |
| Dialpad calls stopped (legacy tenant) | CSV report stuck — Coralogix for `"csv report from DialPad is not ready"` / 404 (`DialPadDialerService.java:328`/`:336`); the cached `ASYNC_REQUEST_ID` is auto-deleted on 404 and retried. |
| Calls show but recordings missing | Legacy: null/0 duration → filtered TOO_SHORT, re-imported later (`:563`). OAuth push: download URL resolved via `getCall` (`:509`); 404 there = recording not ready. |
| Wrong/no user on a queue call | OAuth operator-call resolution (`resolveProviderUser` `:336`); a missing operator call leaves the user null (logged `:359`). |
| Webhook events not arriving | Not this page — check the subscription/callback side: [[Dialpad-Webhook-Controller]]. |

Related: [[IngesterTelephonySystemsSupervisor]] · [[Dialpad-Webhook-Controller]] · [[GONG-CONNECT-DIALER-EVENTS]] · [[DIALER-CALLS-UPDATES]] · [[04 - Providers & Dialers]] · [[Entrypoints Within the Telephony System]]
