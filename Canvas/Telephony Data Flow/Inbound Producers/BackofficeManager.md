---
title: BackofficeManager (+ APP_USER writers)
component_type: upstream-producer
service: BackofficeManager
cluster: APP_USER
tags: [telephony-systems, kafka, upstream, producer, oncall, app-user, msteams]
---

# ⬆️ BackofficeManager (+ APP_USER writers)

> [[Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> BackofficeManager and the other APP_USER writers produce **`app-user-changes`** (email / status / settings changes for Gong app users) on the `APP_USER` cluster. Our Supervisor's `MsTeamsAppUserChangesConsumer` consumes it to keep the **MS Teams / Numonix recording allow-list** in sync — adding/removing user emails to record. If this stops, **MS Teams recording coverage drifts**: newly-enabled users aren't recorded, off-boarded users keep being recorded.
>
> 🔑 **Two gotchas that will burn you (verified in code):**
> 1. **Early exit when the company has no Teams integration.** `accept(...)` returns immediately if `getTeamsIntegrationProperties(companyId)` is empty (`MsTeamsAppUserChangesConsumer.java:59`) — non-Teams companies' events are a no-op here even though they're consumed.
> 2. **Events are pre-filtered before delivery.** A tenant batch-filter predicate only passes email changes, status changes, and settings changes **where `shouldImportCalls` actually flipped** (`:183-190`). A settings change that didn't alter `shouldImportCalls` never reaches `accept`.

---

## What it is

| | |
|---|---|
| **Role** | Upstream producers — app-user lifecycle changes (BackofficeManager + others) |
| **Produces topic** | `app-user-changes`, cluster `APP_USER` |
| **Message type** | `AppUserEvent` (grouped: `GroupedGongEvents<AppUserEvent>`); subtypes `AppUserEmailChangeEvent`, `AppUserStatusChangeEvent`, `AppUserSettingsChangeEvent` |
| **Producer code** | In the **BackofficeManager** / other APP_USER-writer repos (not mounted here) |
| **Our consumer** | `MsTeamsAppUserChangesConsumer.accept(...)` |
| **Consumer wiring** | `configureMultipleByTenant(... APP_USER_CHANGES ...)` — batched per tenant (`:161`) |
| **Consumer cluster const** | `KafkaClusterDetails.APP_USER_KAFKA_CLUSTER` |
| **Downstream of consumer** | `MsTeamsNumonixHttpClient.addEmails / deleteEmail` — update recording allow-list (`:104,122`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the consumer logs handling of each change type at DEBUG (`MsTeamsAppUserChangesConsumer.java:86,108`):
```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Handling user email change') || $d.body.contains('Handling user status or settings change')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Signals: **consumer lag on `app-user-changes`** and outbound `feign.*` to the Numonix HTTP client. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue &lt;url&gt;"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

> ⚠️ The **producers** (BackofficeManager + other APP_USER writers) are in **other repos**, **not mounted here**. Breakpoint the produce there.

Local hook on **our** side — the consumer that receives the app-user changes:

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry (our hook)** | `IngesterTelephonySystemsSupervisor/.../consumers/MsTeamsAppUserChangesConsumer.java:55` | `accept(ConsumerRecord<Long, GroupedGongEvents<AppUserEvent>>)` — every `app-user-changes` batch |
| **No-Teams early exit** | `.../consumers/MsTeamsAppUserChangesConsumer.java:59` | `if (integrationPropertiesList.isEmpty()) return;` — the #1 "nothing happened" |
| **Allow-list write** | `.../consumers/MsTeamsAppUserChangesConsumer.java:104` | `msTeamsNumonixHttpClient.addEmails(...)` — the actual recording-coverage change |

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `MsTeamsAppUserChangesConsumer.java` in IntelliJ; file version ~matches prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 55** (or 59 to catch the no-Teams exit). In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger an app-user change for that company, read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `integrationPropertiesList.size()` at line 59 shows whether the company has Teams integrations at all.

---

## ▶️ Trigger the flow

There is no Supervisor HTTP twin for `app-user-changes`. To exercise the consumer, **produce a `GroupedGongEvents<AppUserEvent>`** to `app-user-changes` on the `APP_USER` cluster locally (general pattern: [[Entrypoints Within the Telephony System]] §4), using a company that **has an MS Teams integration** (else the no-Teams exit at `:59` fires) and an event type that passes the batch filter (email change, status change, or a settings change that flips `shouldImportCalls`). Breakpoint `MsTeamsAppUserChangesConsumer.java:55`.

To debug the MS Teams / Numonix side specifically, use `MSTeamsNumonixTroubleshooter`.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `MSTeamsNumonixTroubleshooter` | Inspect/replay MS Teams & Numonix recording settings |
| `IntegrationsTroubleshooter` / `TelephonyIntegrationFrontTroubleshooter` | Confirm the company's Teams integration is configured |
| `TroubleshootingScheduledTaskController` | Inspect scheduled tasks touching user/recording state |

Discover exact live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| New user not being recorded (MS Teams) | (1) Did an `app-user-changes` event arrive? Lag on `app-user-changes`; Coralogix for "Handling user ..." (`:86/:108`). (2) Does the company have a Teams integration? (`:59` early-exit). (3) `MSTeamsNumonixTroubleshooter`. |
| Off-boarded user still recorded | `deleteEmail` not called — check the status/settings change actually flipped `shouldImportCalls` so it passed the batch filter (`:183-190`). |
| Lag climbing | Per-tenant batched consumer (`configureMultipleByTenant`, `:161`); errors persisted + reprocessed every 30 min (`:173-176`). Check Numonix HTTP `feign.*` latency. |

> Related: [[IngesterTelephonySystemsSupervisor]] · [[APP-USER-CHANGES]] · [[Entrypoints Within the Telephony System]]
