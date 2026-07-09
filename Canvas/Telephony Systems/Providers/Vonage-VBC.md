---
title: Vonage Business Communications
component_type: external-provider-dialer
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, dialer, external-provider, vonage, oncall]
---

# 📞 Vonage Business Communications

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External cloud-phone provider ("VBC"). Supervisor **polls Vonage's REST API on a schedule** (SYNC/pull only — `AbstractOAuthDialerService`, no event push). If this stops, **Vonage calls stop appearing in Gong** for affected tenants.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Account number is decoded from the OAuth id_token JWT.** `extractAccountId` base64-decodes the JWT payload and scans `eClaims` for `accountNumber` (`VonageBusinessCommunicationsDialerService.java:232`). On failure it returns `""` (empty) and logs a warn (`:244`) — an empty `externalAccountId` then breaks every per-account URL (users, call-logs, recordings). Check this first if a freshly-connected VBC tenant returns nothing.
> 2. **Recording URL is a SEPARATE call, made lazily.** List-calls does NOT include the recording URL — `setRecordingUrl` (`:538`) hits `company_call_recordings?call_id=...` only when needed; calls with `recorded=false` are filtered as `MISSING_RECORDING` in `filterCall` (`:517`). "No recordings" with a `"does not have any active CCR account services"` error maps to `PERMANENT_AUTH_ISSUE` (`:630`).
> 3. **De-dupe across legs/pages.** One call id can return several rows (legs); `getUniqueCallList` (`:466`) keeps the first `Answered`/`Voicemail` row with a non-null user. Pages may split legs, so a missing leg on another page can change which row wins.

---

## What it is

| | |
|---|---|
| **Role** | External provider (pull/SYNC only) — Supervisor polls VBC REST API for calls + recordings |
| **Provider class** | `VonageBusinessCommunicationsDialerService` extends `AbstractOAuthDialerService` |
| **IntegrationFlavor** | `VONAGE_BUSINESS_COMMUNICATIONS_API` (`vonagebusinesscommunications_api`) — enum at `IntegrationFlavor.java:61` |
| **Auth** | OAuth 2.0 auth-code (`scope=openid`); account number extracted from `id_token` JWT |
| **API host** | `https://api.vonage.com` (`URL_PREFIX`, `VonageBusinessCommunicationsDialerService.java:91`); tenant `t/vbc.prod/...` |
| **Gong app secret** | protected entity `vonagebusinesscommunications.api` (`client_id` / `client_secret`) |
| **User association** | by EMAIL (`USER_ASSOCIATION_STRATEGY`, `:100`) |
| **Downstream** | shared sync→ingest path → [[DIALER-CALLS-UPDATES]] hand-off |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — VBC list-calls for one company (`VonageBusinessCommunicationsDialerService.java:445`/`:447`):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.mdc.cid == '<companyId>'
| filter $d.body.contains('Listing Calls')
| limit 200
```
- Errors only: swap the message filter for `| filter $m.severity == ERROR`.
- Guided: ask Claude *"use the coralogix-debug-expert"* or run the `observability:coralogix-logs` skill.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch SyncJob success and outbound `feign.*` / VBC HTTP error rate (5xx retried, `:441`). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **OAuth token exchange** | `Dialers/.../services/VonageBusinessCommunicationsDialerService.java:336` | `getAccessTokenFromAuthorizationCode` → form POST to `/token` |
| **Account-id from JWT** | `Dialers/.../services/VonageBusinessCommunicationsDialerService.java:232` | `extractAccountId` — decodes `id_token`; empty result breaks everything downstream |
| **OAuth token refresh** | `Dialers/.../services/VonageBusinessCommunicationsDialerService.java:203` | `refreshAndUpdateAccessToken` → grant_type=refresh_token, re-extracts account id |
| **List call logs** | `Dialers/.../services/VonageBusinessCommunicationsDialerService.java:430` | `listRecordingsData` → `request.getForObject(ListCallLogsResponse.class)` |
| **Resolve recording URL** | `Dialers/.../services/VonageBusinessCommunicationsDialerService.java:547` | `retrieveCompanyCallRecording` → `company_call_recordings?call_id=...` (lazy, per call) |
| **Recording download** | `Dialers/.../services/VonageBusinessCommunicationsDialerService.java:400` | `downloadRecording` → `client.downloadRecording(call.callURL, ..., "mp3", ...)` |

`getIntegrationFlavor()` = `VONAGE_BUSINESS_COMMUNICATIONS_API` at `:273`.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `VonageBusinessCommunicationsDialerService.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 430** (list calls) or **232** (account-id extraction). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action on `:244` (`Failed to extract the account id from token payload`) to catch the empty-account-id failure mode in prod without a snapshot.

---

## ▶️ Trigger the flow

Use the **Sync one call** troubleshooter — pulls one VBC call by id and runs ingest. Flavor is derived from `company-id` + `integration-id`. (Payloads: [[Entrypoints Within the Telephony System]] §3.)

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_VBC_CALL_ID'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Vonage VBC is **pull-only** (no event push — it extends `AbstractOAuthDialerService`, not `EventPushSupportingDialerService`), so the `process-one-event` push twin (§2) does not apply — drive the SyncJob chain (§5) for the periodic path.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one VBC call |
| `TroubleshootingScheduledTaskController` / `IngesterTelephonySystemsSyncInfraTroubleshooter` | Inspect/trigger the periodic VBC sync (Entrypoints §5) |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | VBC integration / OAuth connection + account-id state |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Freshly-connected VBC tenant returns nothing | Empty account id from JWT — Coralogix for `"Failed to extract the account id from token payload"` (`:244`); without `externalAccountId` every per-account URL 404s. Re-connect / re-auth. |
| Calls listed but recordings missing | Recording URL is a separate lazy call (`setRecordingUrl` `:538`); `recorded=false` → filtered `MISSING_RECORDING` (`:517`). Manually-deleted recordings logged `:560`. |
| `"does not have any active CCR account services"` | Maps to `PERMANENT_AUTH_ISSUE` (`:630`) — the VBC account lacks Company Call Recording; not a Gong-side bug. |
| Duplicate / wrong-direction calls | Leg de-dupe across pages (`getUniqueCallList` `:466`); a leg on another page can flip which row is kept. |
| Token refresh failing | Coralogix for `"Exception when trying to refresh an access token"` (`:226`); a `400` on refresh is remapped to `401` (`:223`) = re-auth. |

Related: [[IngesterTelephonySystemsSupervisor]] · [[GONG-CONNECT-DIALER-EVENTS]] · [[DIALER-CALLS-UPDATES]] · [[04 - Providers & Dialers]] · [[Entrypoints Within the Telephony System]]
