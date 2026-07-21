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
honeyfy monolith** that other systems (notably [[Subsystems/Call Scheduling/_dashboard|Call Scheduling]]) call
into.

## The five consent mechanisms

Gong captures and enforces consent through five mechanisms — a company's DCP controls which ones apply.

| Mechanism | When | How |
|---|---|---|
| **Consent page (jump page)** | Before joining — participant clicks the meeting link | Gong-hosted page intercepts the join link; participant accepts or declines before being redirected to Zoom/Teams/Webex |
| **Audio prompt** | At call start — bot speaks into the meeting | Recording bot plays a verbal recording notice; can be suppressed if consent was already captured via the consent page |
| **Pre-call consent email** | 10–20 min before the meeting | Sent to external invitees; acts as notice + recording disclosure; participant can still accept/deny via the email landing page |
| **Confirmation email (LA)** | 24/48/72h before the meeting | Sent for calls ingested via the Gong assistant where the organizer is not a Gong org member; requests permission to record; landing page lets participant cancel recording |
| **Native Zoom consent** | At recording start / participant join | Zoom shows its own built-in disclaimer; Gong's audio prompt settings do not apply, but all other DCP settings do |

Detailed docs: [[Audio Prompt]] · [[Confirmation Email (LA)]] · [[Jump Page & DCP]] · [[Use Cases/A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]]

---

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
  (`cancelExistingCallDueToResolutionChange`). See [[Subsystems/Call Scheduling/00 - Overview]].
- **Per-user consent settings** are resolved through `DcpAppUserConsentService` (monolith).

## Glossary pointers

- Org-wide acronyms: [[Acronyms]]
- Downstream consumer of consent: [[Subsystems/Call Scheduling/_dashboard|Call Scheduling]]
- Datastore detail: [[Storage & Schema Reference]]

## See also

- [[01 - Services & Modules]]
- [[Storage & Schema Reference]]
