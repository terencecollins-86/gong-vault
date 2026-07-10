---
title: Calendar Ingestion — Onboarding Checklist
tags: [calendar-ingestion, onboarding, checklist]
created: 2026-06-25
---

# 07 · Onboarding Checklist

> [[_dashboard|← Team Hub]] · [[06 - Runbook & Troubleshooting]]

A concrete ramp for a new engineer joining calendar ingestion.

## Day 1 — orient

- [ ] Read [[00 - Overview]] and [[01 - Architecture & Modules]].
- [ ] Skim [[02 - Data Flows]] — internalise the **3 entry-point classes** (scheduled tasks
      are the primary one — different from Telephony, where Kafka is primary).
- [ ] Clone & build the repo:
	```bash
	git clone https://github.com/Honeyfy/gong-ingestion.git
	cd gong-ingestion
	./mvnw -T1C clean install -DskipTests
	```
- [ ] Get access: GitHub `Honeyfy`, VPN, Datadog, Coralogix, Sentry (team `mail-cal-ingestion`),
      Jira `GONG`.
- [ ] Open the project in IntelliJ; note the `.run/` configs for the 4 services (each has a
      normal and an "Embedded Tomcat" variant).

## Week 1 — go deep

- [ ] Read [[03 - Services Reference]] and pick the **Supervisor** as your home base.
- [ ] Trace **Flow A (scheduled import fan-out)** end-to-end: scheduled task → command topic →
      provider consumer → CalendarCore import → `calendar-meeting-upsert-requests`.
- [ ] Read [[04 - Providers & Sources]] and open both `GoogleCalendarProvider` and
      `OfficeCalendarProvider` in `CalendarCore/.../provider/`.
- [ ] Do an [[05 - Observability]] tour: run a Coralogix query, find the service in Datadog,
      open the Sentry team view. **Fill in the TODO placeholders** as you find real URLs.
- [ ] Run the subsystem locally and hit an entrypoint — follow [[Entrypoints Within the Calendar System]].
- [ ] Open the Supervisor Troubleshooter Swagger UI (see [[06 - Runbook & Troubleshooting]]).

## First contribution

- [ ] Pick a starter ticket. Branch as `GONG-####-short-description` (UPPERCASE key, lowercase
      hyphenated desc).
- [ ] Remember **wiring tests**: new Feign deps must be declared in the module's
      `*.gong-app-descriptor.yaml` `applications:` block.
- [ ] Run pre-commit hooks (never `--no-verify`); conventional commit messages.
- [ ] For cross-service changes, check
      [Technical Ownership](https://gongio.atlassian.net/wiki/spaces/EN/pages/4209180678/) first.

## People & ownership

| Area | Owner |
|---|---|
| All 4 calendar services | ariel.bloch@gong.io |
| Sentry team | `mail-cal-ingestion` (shared with the Mail sub-system) |

## Mental checkpoints (can you answer these?)

1. What are the **3 ways** work enters Calendar Ingestion, and which is primary? (→ [[02 - Data Flows]])
2. Why is `CalendarCore` a library and not a service? (→ [[00 - Overview]])
3. Why are Google and Office **separate deployables** but share `CalendarCore`? (→ [[00 - Overview]])
4. Which service writes the OpenSearch `MEETINGS` index? (→ MeetingsIndexer, [[03 - Services Reference]])
5. Where do I look first when "meetings aren't showing up"? (→ [[06 - Runbook & Troubleshooting]])
