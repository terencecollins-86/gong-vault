---
title: APP-USER-CHANGES
component_type: inbound-kafka-topic
service: IngesterTelephonySystemsSupervisor
cluster: APP_USER
tags: [telephony-systems, kafka, inbound, oncall, ms-teams]
---

# 📥 APP-USER-CHANGES

> [[Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> App-user change events (email / status / settings) consumed for the **MS Teams (Numonix) recording integration**. The consumer keeps the Numonix bot's recorded-email list in sync: when a user's email changes or their `shouldImportCalls`/active state flips, it adds/removes that email on the relevant MS tenant(s). If it stalls, **MS Teams recording enrolment drifts** — newly-enabled users aren't recorded, off-boarded users keep being recorded.
>
> 🔑 **Gotchas (verified in code):**
> 1. **Pre-filtered at the Kafka layer.** A `tenantBatchFilter` predicate only lets through `AppUserEmailChangeEvent`, `AppUserStatusChangeEvent`, and `AppUserSettingsChangeEvent` *where `shouldImportCalls` actually changed* (`MsTeamsAppUserChangesConsumer.java:182-191`). Other app-user events never reach `accept()`.
> 2. **No-op when no Teams integration.** `accept()` returns immediately if the company has no MS Teams integration properties (`:58-61`) — most companies short-circuit here.
> 3. **Per-tenant batched consumer**, not `@KafkaListener` — `configureMultipleByTenant(... APP_USER_CHANGES ...)` (`:161-178`) with error-reprocessing every 30 min. Calls out to `MsTeamsNumonixHttpClient` (external HTTP) to add/delete emails.

---

## What it is

| | |
|---|---|
| **Role** | Inbound app-user changes → sync MS Teams (Numonix) recorded-email list |
| **Topic** | `app-user-changes` (`KafkaTopics.APP_USER_CHANGES`) |
| **Cluster** | `APP_USER` (`APP_USER_KAFKA_CLUSTER`) |
| **Access (app-descriptor)** | `READ` · consumer `ms-teams-app-user-changes-consumer` |
| **Message type** | `GroupedGongEvents<AppUserEvent>` (`com.honeyfy.kafka.events.appuser.AppUserEvent`) |
| **Consumer** | `MsTeamsAppUserChangesConsumer` |
| **Side effects** | `MsTeamsNumonixHttpClient.addEmails(...)` / `.deleteEmail(...)` per MS tenant |
| **Upstream producer** | App-user / Users service — external to this module |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — the handler's per-type debug lines (`MsTeamsAppUserChangesConsumer.java:86` email, `:108` status/settings):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Handling user email change') || $d.body.contains('Handling user status or settings change')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: `| filter $m.severity == ERROR`. Numonix HTTP failures surface as `feign`/HTTP-client errors from `MsTeamsNumonixHttpClient`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). Lag on `app-user-changes` + `feign.*` to the Numonix endpoint (add/delete email latency & errors). Filter `service:ingestertelephonysystemssupervisor` + `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate via *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Consumer entry** | `IngesterTelephonySystemsSupervisor/.../consumers/MsTeamsAppUserChangesConsumer.java:55` | `accept(ConsumerRecord<Long, GroupedGongEvents<AppUserEvent>>)` — every batch |
| **No-Teams guard** | `.../consumers/MsTeamsAppUserChangesConsumer.java:59` | `integrationPropertiesList.isEmpty()` ⇒ return (most companies stop here) |
| **Email-change branch** | `.../consumers/MsTeamsAppUserChangesConsumer.java:81` | `handleEmailChange(...)` — add/remove emails on Numonix |
| **Status/settings branch** | `.../consumers/MsTeamsAppUserChangesConsumer.java:107` | `handleUserStatusOrSettingsChange(...)` |
| **Batch filter** | `.../consumers/MsTeamsAppUserChangesConsumer.java:183` | The predicate that gates which events even arrive |
| **Wiring** | `.../consumers/MsTeamsAppUserChangesConsumer.java:161` | `configureMultipleByTenant(... APP_USER_CHANGES ...)` |

Step from `:55` → `:58` (guard) → into the per-type branch (`:81` / `:107`) → watch `msTeamsNumonixHttpClient` add/delete calls.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against prod. Full setup: [[Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `MsTeamsAppUserChangesConsumer.java` in IntelliJ (match the prod build — Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 55**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company (one that *has* a Teams integration) so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Trigger a user change, read the snapshot, then **delete the breakpoint.**

> A **Log** action injecting `integrationPropertiesList.size()` at `:58` instantly tells you whether the company is short-circuiting at the no-Teams guard.

---

## ▶️ Trigger the flow

There is **no Supervisor HTTP twin** that produces an `AppUserEvent` — these originate in the App-User/Users service (another module) and land on the `APP_USER` cluster. On our side the local hook is the consumer above.

**To exercise this consumer:** produce a `GroupedGongEvents<AppUserEvent>` (e.g. an `AppUserEmailChangeEvent`, or an `AppUserSettingsChangeEvent` that flips `shouldImportCalls`) for a company with a Teams integration to topic `app-user-changes` on the `APP_USER` cluster — see [[Entrypoints Within the Telephony System]] §4 for the produce-to-topic pattern. The event must pass the batch filter (`:183`) or it's dropped. Breakpoint `:55` first.

**For MS Teams recording-config debugging:** use the `MSTeamsNumonixTroubleshooter` (below), which inspects/sets the Numonix bot configuration directly.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `MSTeamsNumonixTroubleshooter.getTenantBotConfiguration` | Read the current Numonix bot config for a company (`GET .../ms-teams-numonix/tenant/get-bot-configuration`) |
| `MSTeamsNumonixTroubleshooter.setTenantBotConfiguration` | Set/repair the bot config (`POST .../tenant/set-bot-configuration`) |
| `MSTeamsNumonixTroubleshooter.runReport` | Run the Numonix recording-setting report (`POST .../run-numonix-recording-setting-report`) |

Base path `/troubleshooting/ms-teams-numonix` (`MSTeamsNumonixTroubleshooter.java:59`). Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| MS Teams recording enrolment drifting | (1) Lag on `app-user-changes`. (2) Coralogix for "Handling user …" lines (`:86`/`:108`) — events arriving & passing the filter? (3) Numonix HTTP errors from `MsTeamsNumonixHttpClient`. |
| Changes never reach the consumer | The batch filter (`:183`) only passes email/status/settings-with-shouldImportCalls-change events — confirm the event type. |
| Company seemingly ignored | No Teams integration ⇒ early return (`:59`). Verify via `MSTeamsNumonixTroubleshooter.getTenantBotConfiguration`. |
