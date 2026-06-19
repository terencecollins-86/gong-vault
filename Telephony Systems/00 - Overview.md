---
title: Telephony Systems — Overview
tags: [telephony-systems, overview, onboarding]
created: 2026-06-19
---

# 00 · Overview

> [[_dashboard|← Team Hub]]

## What the team owns

The **Telephony Systems** team owns `gong-telephony-systems` — the part of Gong that
**brings calls in from the outside world**. Customers use third-party dialers and
telephony platforms (Salesforce-based dialers, Five9, RingCentral, Truly, MS Teams,
Dialpad, FTP drops, etc.). Our job is to:

1. **Ingest** call metadata and recordings from those providers,
2. **Convert** them into Gong's internal *activity* / *call* model,
3. **Associate** them with the right CRM records and users,
4. **Index** their text so the rest of Gong can search and analyse them, and
5. **Operate & troubleshoot** all of the above in production.

We are an **ingestion edge** team: most of our work is upstream of the core Gong
processing pipeline. Once we hand a call off (via the `call-processing-inbound` Kafka
topic and the Activity Store), downstream teams take over transcription, analysis, etc.

## The mental model (one paragraph)

> A provider produces call data → it arrives at one of our **entry points** (Kafka event,
> REST upload, S3 drop, or scheduled sync) → the **IngesterTelephonySystemsSupervisor**
> orchestrates fetching the recording + metadata → **Dialers** library code talks to the
> specific provider → the **RecordingsImporter** pulls the media and converts the call to
> an activity → the call is pushed downstream for processing, while **TextIndexer**
> indexes any associated text → **Troubleshooters** lets us inspect and re-drive any of it.

See [[02 - Data Flows]] for the diagrams and the full list of entry points.

## Why it's structured the way it is

- **`Dialers` is a library, not a service.** Every provider integration lives there as
  reusable code so multiple services (the supervisor, the recordings importer, the
  troubleshooters) can drive the same provider logic without duplicating it.
- **Ingestion is split from the web/BFF.** `IngesterTelephonySystemsSupervisor` does the
  heavy async ingestion work; `TelephonySystemsWebApi` is the thin public-facing API for
  configuring integrations.
- **Troubleshooting is a first-class service.** Because provider integrations fail in
  customer-specific ways, `TelephonySystemsTroubleshooters` exists purely so support and
  engineering can inspect/replay production state. (See the vault's
  [[Architecture/Troubleshoot Endpoints|Troubleshoot Endpoints]] note for the auth model.)

## Key external dependencies

Telephony Systems is a heavy *consumer* of other Gong platform services:

- **ProviderIntegrationManager** — source of truth for integration config/credentials
- **FileUpload / CloudStorageController** — where recordings land
- **CallActivityStoreGateway** — the downstream activity store
- **Orchestrator / PurgeOrchestrator** — processing & data-lifecycle coordination
- **GlobalDirectory, Permissions, FeatureFlags, AuroraController** — platform plumbing
- **GongConnect** — Gong's own calling product (events flow back to us)

## Glossary pointers

- Org-wide acronyms: [[Acronyms]]
- Provider catalog: [[04 - Providers & Dialers]]
