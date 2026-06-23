---
title: Dialpad Webhook Controller
component_type: inbound-rest-controller
service: IngesterTelephonySystemsSupervisor
tags: [telephony-systems, rest, inbound, dialpad, oncall]
---

# 🌐 Dialpad Webhook Controller

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Inbound REST surface for **Dialpad provisioning** — listing/creating Dialpad users, call-event subscriptions, and websockets, plus initiating outbound calls. It is a thin Feign-fronted controller over `DialpadDialerClientCommonService`; if it breaks, **Dialpad call-event subscriptions can't be (re)provisioned** but already-flowing call ingestion is unaffected.
>
> 🔑 **Gotchas (verified in code):**
> 1. Every method runs inside `Tenant.evaluateForCompany(companyId, …)` (`DialpadController.java:111`) and resolves an OAuth bearer per call via `getBearerToken(…)` (`:124`) — a **stale/missing Dialpad OAuth token** surfaces here as `UNAUTHORIZED`/`FORBIDDEN`, not as a 500.
> 2. `DialpadDialerException` is **caught and remapped**, never thrown raw — `DialpadRestControllerAdvice.java:20` translates HTTP status → `DialpadError` enum (`:29`). A Dialpad `429` comes back as `DialpadError.TOO_MANY_REQUESTS`, not a generic error.
> 3. The controller's own `@RequestMapping` paths live in the `DialpadApi` interface (`com.honeyfy.ingester.telephony.systems.supervisor.api.DialpadApi`), which is **not source-mounted here** — use the `DialpadTroubleshooter` paths below to drive it locally.

---

## What it is

| | |
|---|---|
| **Role** | Inbound REST: Dialpad user / call-event / websocket provisioning + call initiation |
| **Controller class** | `DialpadController implements DialpadApi` (`@RestController`, `rest/DialpadController.java:32`) |
| **Backing service** | `DialpadDialerClientCommonService` (+ `DialpadOAuthDialerService` for tokens) |
| **Error advice** | `DialpadRestControllerAdvice` (`@RestControllerAdvice(assignableTypes = DialpadController.class)`) |
| **Troubleshooter front** | `DialpadTroubleshooter` — base path `troubleshooting/dialpad` |
| **Flavor** | `IntegrationFlavor.DIAL_PAD_API` |
| **Callers** | Internal Feign / `DialpadTroubleshooter`; see [[Dialpad]] |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

**Controller operations** (method → `DialpadController` line; HTTP path is in the un-mounted `DialpadApi`):

| Operation | `DialpadController.java` | Troubleshooter path (verified) |
|---|---|---|
| `listUser(companyId, filterEmail)` | `:41` | `GET troubleshooting/dialpad/list/users` |
| `getUser(companyId, dialpadUserId)` | `:49` | `GET troubleshooting/dialpad/get/user` |
| `listCallEvents(companyId, dialpadUserId)` | `:57` | `GET troubleshooting/dialpad/list/call-events` |
| `createCallEvent(companyId, userId, websocketId)` | `:65` | `POST troubleshooting/dialpad/create/call-event` |
| `deleteCallEvent(companyId, callEventId)` | `:73` | `DELETE troubleshooting/dialpad/delete/call-event` |
| `listWebsocket(companyId)` | `:81` | `GET troubleshooting/dialpad/list/websockets` |
| `getWebsocket(companyId, dialpadWebsocketId)` | `:89` | `GET troubleshooting/dialpad/get/websocket` |
| `createWebsocket(companyId)` | `:97` | `POST troubleshooting/dialpad/create/websocket` |
| `callInitiate(companyId, …)` | `:105` | `POST troubleshooting/dialpad/call/initiate` |

---

## 👀 See it working

**Coralogix (DataPrime)** — Dialpad controller + advice activity (the advice logs `DialpadDialerException` at warn, `DialpadRestControllerAdvice.java:22`):
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('DialpadDialerException') || $l.subsystemName.contains('Dialpad')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: add `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Watch the Dialpad outbound `feign.*` error rate (the controller calls Dialpad's API through the OAuth service). Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Controller entry** | `IngesterTelephonySystemsSupervisor/.../rest/DialpadController.java:41` | `listUser(...)` — first method; proves the request reached the controller |
| **Tenant + token** | `IngesterTelephonySystemsSupervisor/.../rest/DialpadController.java:111` | `Tenant.evaluateForCompany(...)` then `getBearerToken(...)` — where OAuth resolution happens |
| **Bearer resolve** | `IngesterTelephonySystemsSupervisor/.../rest/DialpadController.java:124` | `getBearerToken(...)` → `safeRefreshAccessTokenIfNeeded(...)` — catches stale-token issues |
| **Error remap** | `IngesterTelephonySystemsSupervisor/.../rest/DialpadRestControllerAdvice.java:29` | `switch` on Dialpad HTTP status → `DialpadError` enum |

> The `@RequestMapping` annotations are on `DialpadApi` (interface not source-mounted) — set the breakpoint on the `DialpadController` method body, which always executes.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialpadController.java` in IntelliJ; make sure the file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 41** (or `:124` for token issues). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger via the troubleshooter (below), read the snapshot, then **delete the breakpoint.**

> Use a **Log** action at `:124` to inject the resolved integration id without snapshot overhead.

---

## ▶️ Trigger the flow

The controller's own paths aren't source-visible, but `DialpadTroubleshooter` (base `troubleshooting/dialpad`) calls the same `DialpadApi` bean. No app-level auth locally. List a company's Dialpad users (hits `DialpadController.listUser` @41):

```bash
curl -X GET \
  'http://localhost:8097/troubleshooting/dialpad/list/users?company-id=0'
```

Create a call-event subscription (hits `createCallEvent` @65):
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/dialpad/create/call-event?company-id=0&dialpad-user-id=0&dialpad-websocket-id=0'
```

- `company-id` must be a company with a configured `DIAL_PAD_API` integration, or token resolution (`:124`) fails.
- Postman: `Other Troubleshooters → Dialpad Troubleshooter`. See [[Dialpad]] and [[Entrypoints Within the Telephony System]].

---

## 🧰 Troubleshooters

| Troubleshooter | Path / use for |
|---|---|
| `DialpadTroubleshooter.listUsers` | `GET troubleshooting/dialpad/list/users` — verify OAuth + user lookup |
| `DialpadTroubleshooter.listCallEvents` / `createCallEvent` / `deleteCallEvent` | Inspect / (re)provision Dialpad call-event subscriptions |
| `DialpadTroubleshooter.listWebsockets` / `createWebsocket` / `getWebsocket` | Inspect / create the Dialpad websocket the call-events attach to |
| `DialpadTroubleshooter.initiateCall` | `POST troubleshooting/dialpad/call/initiate` — drive an outbound Dialpad call |
| `TelephonyCallEventsTroubleshooter` (`process-one-event`) | Push one Dialpad call event into ingestion (see Entrypoints §2) |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Dialpad provisioning returns 401/403 | OAuth token stale/revoked — breakpoint `DialpadController.java:124`; check `oauth2-*` secrets and the `DIAL_PAD_API` integration row. |
| Dialpad calls "429 / too many requests" | Advice maps it to `DialpadError.TOO_MANY_REQUESTS` (`DialpadRestControllerAdvice.java:33`) — back off; not retried here. |
| "No integration for company" | `dialpadOAuthDialerService.getIntegrationIdForCompany(companyId)` (`DialpadController.java:112`) — company has no `DIAL_PAD_API` integration. |
| Dialpad call events not arriving for ingestion | Subscription/websocket missing — `listCallEvents` + `listWebsockets`; (re)create via `createCallEvent`. Then trace ingest via [[Dialpad]] / [[CALL-PROCESSING-INBOUND]]. |
