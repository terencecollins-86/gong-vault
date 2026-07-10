---
title: Outreach
component_type: external-provider
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, provider, dialer, pull-sync, oauth, oncall]
---

# 📞 Outreach

> [[Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> External provider polled on a schedule via `OutreachDialerService` (OAuth2, JSON:API). If this breaks, **Outreach calls stop importing** for the company.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Calls from other vendors are silently dropped.** `filterCall` ignores calls whose `externalVendor` is `dialpad`/`ring_central`/`VoiceExtension:Zoom`, tagged `orum`, or whose recording URL contains `orum.com`/`cloudtalk`/`connectandsell.com` (`:579-586`, reason `CALL_FROM_EXTERNAL_SOURCE`). "Missing call" is often this filter — Gong ingests those via their own provider, not Outreach.
> 2. **Must use the JSON:API Accept header.** `Accept: application/vnd.api+json` (`ACCEPT_HEADER_VALUE :92`, CASE-9756) on every call — a plain JSON accept gets rejected by Outreach.
> 3. **callPurpose / callDisposition perms are optional and swallowed.** If the customer didn't grant those scopes, the error is logged and ignored, not thrown (`getCallPurposes :420-427`, `getCallDispositions :447-454`) — calls still import, just without purpose/disposition.
> 4. **Rate limit (429) → retries spread over 20 minutes** (`RATE_LIMIT_RETRY_SPEC :87`, `handleDownloadRecordingException :618-621`).

---

## What it is

| | |
|---|---|
| **Role** | External dialer provider; Supervisor **pulls** calls via REST (SYNC origin) |
| **Local class** | `OutreachDialerService extends AbstractOAuthDialerService` |
| **IntegrationFlavor** | `OUTREACH_API_OAUTH` (`:264`, enum `IntegrationFlavor.java:46`) |
| **Provider API** | `https://api.outreach.io/api/v2/...` — `calls`, `users`, `callPurposes`, `callDispositions`, `prospects` (`:75-82`) |
| **Auth** | OAuth2 Bearer — `addAuthorizationBearerToken(accessToken, request)`; refresh `refreshAndUpdateAccessToken :298-319`. Gong app-id/secret from secret `outreach.api` (`load :100-104`) |
| **Recording** | `attributes.recordingUrl`; secured recordings (`outreach.io` host) get a Bearer token added (`getAccessTokenForSecureRecordings :628-639`) |
| **REST (our side)** | `OutreachSignerController` (`IngesterTelephonySystemsSupervisor/.../rest/OutreachSignerController.java`) — OAuth callback signing helper, **not** call ingestion |
| **SMS** | None — Outreach integration is calls-only |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — list calls + the external-vendor filter for this provider:
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Listing calls using cursor') || $d.body.contains('Filtered an external vendor call')
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
| **List calls (REST)** | `Dialers/.../services/OutreachDialerService.java:351` | `Retry.untilSuccessWithException(() -> request.getForObject(ListCallsResponse.class)...)` — the provider call |
| **Sync one call (REST)** | `Dialers/.../services/OutreachDialerService.java:777` | `getForObject(SingleCallsResponse.class)` — single-call fetch |
| **External-vendor filter** | `Dialers/.../services/OutreachDialerService.java:587` | Where dialpad/orum/etc. calls are dropped (`CALL_FROM_EXTERNAL_SOURCE`) |
| **Secured-recording auth** | `Dialers/.../services/OutreachDialerService.java:629` | Adds Bearer token only when URL is `outreach.io` |
| **REST signer (our side)** | `IngesterTelephonySystemsSupervisor/.../rest/OutreachSignerController.java:22` | `signSalesforceOrganizationId(...)` — the OAuth-callback signing endpoint |

Step into `syncOneCall` @765 (or `listRecordingsData` @333) to follow the fetch + filter.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `OutreachDialerService.java` in IntelliJ; ensure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 351** (list) or **line 587** (vendor filter). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a sync for that company (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action to inject `outreachCompanyCache.lastProviderCallMade` (the exact URL) without snapshot overhead.

---

## ▶️ Trigger the flow

Pull one Outreach call through the full provider-fetch path with the **Sync one call** troubleshooter — flavor is derived from `company-id` + `integration-id`. Details + payloads: [[Entrypoints Within the Telephony System]] §3.

```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_OUTREACH_CALL_ID'
```
- Controller: `IngesterTelephonySystemsTroubleshooter.syncOneCall()` (`IngesterTelephonySystemsShared/.../troubleshooters/IngesterTelephonySystemsTroubleshooter.java:489`).
- `integration-id` must point to an **OUTREACH_API_OAUTH** integration, else `getIntegrationFlavor` (`:479`) returns the helper response.
- Postman: `HTTP — PCI-Compliant Troubleshooter → Sync one call`.

Alternative (Outreach is pull-only): drive the periodic SyncJob chain (§5).

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsTroubleshooter.syncOneCall` | Re-pull + re-ingest one Outreach call |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the periodic Outreach sync |
| `IntegrationsTroubleshooter` | Verify OAuth creds / flavor / scopes |
| `ProviderDataAccessTroubleshooter` | Raw provider-data access for the company |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[04 - Providers & Dialers]] and [[Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| All Outreach calls stopped | (1) OAuth refresh failing? `refreshAndUpdateAccessToken :309` — 400/401 → re-auth. (2) 429 — retries over 20 min (`:87`). (3) SyncJob ran? `TroubleshootingScheduledTaskController`. |
| Specific calls missing | Likely external-vendor filter (`:587`) — check "Filtered an external vendor call" debug log; those import via their own provider. |
| Calls import but no purpose/disposition | Customer didn't grant those scopes — errors swallowed (`:420`,`:447`); no action needed unless customer wants them. |
| Recording download 403 | Secured `outreach.io` recording needs a valid token (`:629`); a redirect/401 means token expired. |
| 406 / unexpected provider error | Missing `application/vnd.api+json` Accept header (`:92`). |
