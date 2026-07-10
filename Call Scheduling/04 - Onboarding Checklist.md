---
title: Call Scheduling — Onboarding Checklist
tags: [call-scheduling, onboarding, checklist]
created: 2026-07-09
---

# 04 · Onboarding Checklist

> [[_dashboard|← Team Hub]] · [[03 - Ubiquitous Language]]

A concrete ramp for a new engineer joining **Call Scheduling**. Everything a newcomer needs to get
started on `gong-call-schedulers`.

## Day 1 — orient

- [ ] Read [[00 - Overview]] and [[01 - Services & Modules]] — know the **4 modules** (2 deployables).
- [ ] Skim [[02 - Entry Points (Inbound & Outbound)]] — internalise the **two ways a call gets scheduled** (calendar-sync feed vs email invite).
- [ ] Open the [[Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|data-flow canvas]] for the 10,000-ft view.
- [ ] Clone & build the repo:
	```bash
	git clone https://github.com/Honeyfy/gong-call-schedulers.git
	cd gong-call-schedulers
	./mvnw -T1C clean install -DskipTests
	```
- [ ] Get access: GitHub `Honeyfy`, VPN, Datadog, Coralogix, Sentry (team `call-scheduling`), Jira `GONG`.
- [ ] Open the project in IntelliJ; note the `.run/` configs (`CallScheduler.run.xml`, `InviteHandlerWebhooksServer.run.xml`).

## Week 1 — go deep

- [ ] Read [[03 - Ubiquitous Language]] — learn to say **creation mechanism**, **Resolution**, **flow**, **enhanced iCal id vs iCal UID** correctly.
- [ ] Trace the **email-invite path** end-to-end: `IncomingMailgunController` → `EmailHandlerService.handle` → produce `call-scheduling-requests` → `CallSchedulingRequestsConsumer` → `SchedulingCallService`.
- [ ] Trace the **calendar-sync path**: `CallSchedulingRequest` (`CALENDAR_EVENT`) → `IncomingEventHandler` → validation chain → `ScheduledCallsDao` UPSERT.
- [ ] Read the **validation framework** (`EventValidationFactory:30` and the ~12 validators in `validation/`).
- [ ] Set up local dev (below) and hit a troubleshooting endpoint via Swagger to drive the engine by hand.
- [ ] Do an observability tour: run a Coralogix query on `subsystemname == 'callscheduler'`, find the service in Datadog (Kafka consumer lag on `call-scheduling-requests` is the #1 health signal), open the Sentry `call-scheduling` team view.

## Local development

**Prerequisites:** LEAPP connected to Gong AWS Dev/Test · Docker running (embedded Kafka/Redis) · local PostgreSQL on `localhost:5432`.

### Hybrid health check (port 8091)

The hybrid run config binds the service to `localhost:8091` (`-Dserver.port=8091`).

```bash
# Is it up?
curl -s http://localhost:8091/actuator/health | jq .

# Is it ready to serve traffic?
curl -s http://localhost:8091/actuator/health/readiness | jq .

# Build info / version
curl -s http://localhost:8091/actuator/info | jq .

# All exposed actuator endpoints
curl -s http://localhost:8091/actuator | jq .
```

Expected: `{"status":"UP"}` from the health endpoint.

```bash
# Database
createdb call_scheduler_dev
mvn flyway:migrate -P dev

# Run the engine
mvn spring-boot:run -pl CallScheduler
# Run the webhook receiver (optional)
mvn spring-boot:run -pl InviteHandlerWebhooksServer

# Tests (TestNG, not JUnit)
mvn test
mvn test -Dgroups=basic
```

**Drive the engine without Kafka** — re-inject a scheduling request over HTTP via the troubleshooting
consumer (`TroubleshootingCallSchedulingRequestsConsumer.sendEventJson`, `@RequestBody CallSchedulingRequest`).
This is the fastest way to hit a breakpoint in `CallSchedulingRequestsConsumer` / `SchedulingCallService`
without producing to Kafka yourself.

## First contribution

- [ ] Pick a starter ticket in Jira `GONG`.
- [ ] Branch as `GONG-####-short-description` (UPPERCASE key, lowercase hyphenated desc).
- [ ] New service-to-service deps must be declared in the module's `*.gong-app-descriptor.yaml` (`applications:` / `dataSources:` / `kafka:` blocks).
- [ ] Run pre-commit hooks (never `--no-verify`); conventional commit messages.
- [ ] For cross-service changes, check [Technical Ownership](https://gongio.atlassian.net/wiki/spaces/EN/pages/4209180678/) first.

## People & ownership

| Area | Owner |
|---|---|
| CallScheduler / InviteHandlerWebhooksServer | web.conferencing@gong.io (Sentry team `call-scheduling`) |
| GlobalInviteHandlerWebhooksServer | moshe.hatav@gong.io |

## Mental checkpoints (can you answer these?)

1. What are the **two ways** a call gets scheduled, and which `CallCreationMechanism` values map to each? (→ [[02 - Entry Points (Inbound & Outbound)]] §2–3, [[03 - Ubiquitous Language]] §5)
2. Why are there **no** `@KafkaListener` / `@Scheduled` / Feign clients? Where's the wiring instead? (→ [[02 - Entry Points (Inbound & Outbound)]] §3–4, §9)
3. Which **three Kafka clusters** does the engine consume from, and why isn't it just one? (→ [[02 - Entry Points (Inbound & Outbound)]])
4. What's the difference between **`enhanced_ical_id`** and **`ical_uid`**, and which table uses which? (→ [[03 - Ubiquitous Language]] §1, §6)
5. Where does a scheduled call **leave** this system, and what's on that topic? (→ `call-scheduling-updated`, [[02 - Entry Points (Inbound & Outbound)]] §6)
6. What does the `GlobalInviteHandlerWebhooksServer` actually do (hint: it doesn't schedule anything)? (→ [[01 - Services & Modules]], [[02 - Entry Points (Inbound & Outbound)]] §2)
