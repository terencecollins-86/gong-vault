---
title: Telephony Systems — Onboarding Checklist
tags: [telephony-systems, onboarding, checklist]
created: 2026-06-19
---

# 07 · Onboarding Checklist

> [[_dashboard|← Team Hub]] · [[06 - Runbook & Troubleshooting]]

A concrete ramp for a new engineer joining Telephony Systems.

## Day 1 — orient

- [x] Read [[00 - Overview]] and [[01 - Architecture & Modules]].
- [x] Skim [[02 - Data Flows]] — internalise the **4 entry-point classes**.
- [x] Clone & build the repo (see the repo `README.md`):
	```bash
	git clone https://github.com/Honeyfy/gong-telephony-systems.git
	cd gong-telephony-systems
	./mvnw -T1C clean install -DskipTests
	```
- [ ] Get access: GitHub `Honeyfy`, VPN, Datadog, Coralogix, Sentry (team `telephony-systems`), Jira `GONG`.
- [ ] Open the project in IntelliJ; note the `.run/` configs for the 3 initializers.

## Week 1 — go deep

- [ ] Read [[03 - Services Reference]] and pick the **Supervisor** as your home base.
- [ ] Trace **Flow A (recording ingestion)** end-to-end in the code, consumer → activity.
- [ ] Read [[04 - Providers & Dialers]] and open one provider in `Dialers/importcalls/`.
- [ ] Do an [[05 - Observability]] tour: run a Coralogix query, find the service in Datadog,
      open the Sentry team view. **Fill in the TODO placeholders** as you find real URLs.
- [ ] Open a Troubleshooter Swagger UI over VPN (see [[06 - Runbook & Troubleshooting]]).
- [ ] Pair on an on-call/incident if one comes up; otherwise read the runbook playbooks.

## First contribution

- [ ] Pick a starter ticket (use the `create-telephony-ticket` skill if creating one).
- [ ] Branch as `GONG-####-short-description` (UPPERCASE key, lowercase hyphenated desc).
- [ ] Remember **wiring tests**: new Feign deps must be declared in the module's
      `*.gong-app-descriptor.yaml` `applications:` block.
- [ ] Run pre-commit hooks (never `--no-verify`); conventional commit messages.
- [ ] For cross-service changes, check
      [Technical Ownership](https://gongio.atlassian.net/wiki/spaces/EN/pages/4209180678/) first.

## People & ownership

| Area | Owner |
|---|---|
| WebApi | adi.magen@gong.io |
| Supervisor / Troubleshooters | yossi.rizgan@gong.io |
| TextIndexer | dor.shemer@gong.io (deal-intelligence) |

## Mental checkpoints (can you answer these?)

1. What are the **4 ways** data enters Telephony Systems? (→ [[02 - Data Flows]])
2. Why is `Dialers` a library and not a service? (→ [[00 - Overview]])
3. Which service do I change to add a provider? To replay a stuck import? (→ [[03 - Services Reference]])
4. Where do I look first when "calls aren't showing up"? (→ [[06 - Runbook & Troubleshooting]])
5. Which service in this repo is *not* owned by our team? (TextIndexer → deal-intelligence)
