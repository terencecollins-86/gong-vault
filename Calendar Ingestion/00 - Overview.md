---
title: Calendar Ingestion — Overview
tags: [calendar-ingestion, overview, onboarding]
created: 2026-06-25
---

# 00 · Overview

> [[_dashboard|← Team Hub]]

## What the sub-system owns

The **Calendar Ingestion** sub-system lives in `gong-ingestion` under `Calendar/`. It
**brings meetings in from customers' calendars**. Customers connect their **Google
Workspace** or **Microsoft Office 365 / Outlook** calendars; our job is to:

1. **Sync** calendar events from those providers (on a schedule and on demand),
2. **Convert** raw calendar events into Gong's internal **meeting** model,
3. **Associate** meetings with the right CRM records and users,
4. **Index** meetings into OpenSearch so the rest of Gong can search and analyse them,
5. **Schedule recordings** for upcoming meetings (hand-off to the call scheduler), and
6. **Operate & troubleshoot** all of the above in production.

Like Telephony Systems, this is an **ingestion edge** sub-system: most of our work is
upstream of core Gong processing. Once a meeting is indexed (the `meetings-indexed` topic)
and a recording is scheduled (`call-scheduling-requests`), downstream teams take over.

## The mental model (one paragraph)

> The **IngesterCalendarSupervisor** decides *who* to sync (scheduled tasks fan companies
> and users out as commands) → it produces per-user **import commands** to Kafka
> (`google-calendar-commands` / `office-calendar-commands`) → the provider ingesters
> (**GoogleCalendarIngester**, **OfficeCalendarIngester**) consume those commands, call the
> provider API (Google Calendar / MS Graph) via **CalendarCore** import logic, persist raw
> events to **MongoDB**, and emit **meeting-upsert requests** (`calendar-meeting-upsert-requests`)
> → **MeetingsIndexer** consumes those, enriches with CRM, and writes the meeting into the
> **OpenSearch MEETINGS index**, also emitting `meetings-indexed`. In parallel, meetings that
> need recording produce **call-scheduling requests**.

See [[02 - Data Flows]] for the diagrams and the full list of entry points.

## Why it's structured the way it is

- **`CalendarCore` is a library, not a service.** All the functional import/meeting logic
  (provider abstraction, event import, meeting upsert, CRM association, purge/backfill) lives
  there so the Supervisor and both provider ingesters share the same code without duplication.
- **The Supervisor is split from the provider ingesters.** `IngesterCalendarSupervisor` owns
  *orchestration* (scheduled fan-out, REST/troubleshooter API, deletion & backfill); the two
  provider ingesters own *fetching* — they consume per-user commands and talk to the provider.
- **Google and Office are separate deployables.** They scale and fail independently and have
  very different provider SDKs/auth (Google service-account vs Azure AD / MS Graph), so each
  gets its own service consuming its own command topic.
- **MeetingsIndexer is the sink.** A dedicated service owns the OpenSearch `MEETINGS` index so
  indexing, CRM re-association, and call-id updates are decoupled from fetching.

## Key external dependencies

Calendar Ingestion is a heavy *consumer* of other Gong platform services:

- **ProviderIntegrationManager** — source of truth for calendar integration config/credentials
- **AuroraController** — Postgres access plumbing
- **CrmMappings / CrmAssociator** — CRM account/contact association for meetings
- **FeatureFlagsBroker** — feature-flag gating
- **CallScheduler v2** — downstream recording-scheduling (we produce `call-scheduling-requests`)
- **CloudStorageController** — storage access (Supervisor)
- **Users / GlobalDirectory** — email → app-user resolution

## Glossary pointers

- Org-wide acronyms: [[Acronyms]]
- Provider catalog: [[04 - Providers & Sources]]
- Sibling sub-system (same template, same repo): [[Telephony Systems/_dashboard|Telephony Systems]]
