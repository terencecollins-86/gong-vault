---
title: Consent — Overview
tags: [consent, recording-consent, overview, onboarding]
created: 2026-07-09
---

# 00 · Overview

> [[_dashboard|← Team Hub]] · next → [[01 - Services & Modules]]

## What the sub-system owns

**Recording Consent** owns *whether and how meeting participants consent to being recorded*, and
everything that supports that: pre-call consent emails, the participant-facing consent page, the
consent settings API, and the consent state store.

It lives primarily in **`gong-data-capture`**, with a set of **shared consent components in the
honeyfy monolith** that other systems (notably [[Call Scheduling/_dashboard|Call Scheduling]]) call
into.

## The mental model (one paragraph)

> Consent settings (per-company / per-user) are managed through the **DCP consent settings API**
> (`RecordingConsentApiServer` → `DcpConsentSettingsController`), reachable from the monolith via the
> **`DcpConsentSettingsClient`** Feign client. Ahead of a call, **`RecordingConsentTasks`** runs
> scheduled work — sending **pre-call consent emails** (`ConsentEmailSender`) and consuming Kafka
> events for consent-page interactions. Participants land on the **consent page** served by
> **`MeetingFrontEnd`** (`ConsentEmailController`, `JumpPageController`); the jump-page URL is built by
> **`JumpPageUrlService`**. All consent state persists in the **`recording_consent`** database.

## Where it plugs into the rest of Gong

- **Call Scheduling** uses `JumpPageUrlService` to build the consent jump-page URL, and consent
  **resolution changes** trigger cancellation of a scheduled call
  (`cancelExistingCallDueToResolutionChange`). See [[Call Scheduling/00 - Overview]].
- **Per-user consent settings** are resolved through `DcpAppUserConsentService` (monolith).

## Glossary pointers

- Org-wide acronyms: [[Acronyms]]
- Downstream consumer of consent: [[Call Scheduling/_dashboard|Call Scheduling]]
- Datastore detail: [[Storage & Schema Reference]]

## See also

- [[01 - Services & Modules]]
- [[Storage & Schema Reference]]
