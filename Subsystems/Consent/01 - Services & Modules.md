---
title: Consent — Services & Modules
tags: [consent, recording-consent, services, modules, reference]
created: 2026-07-09
---

# 01 · Services & Modules

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · next → [[Storage & Schema Reference]]

Per-module reference for recording consent. The consent services live in **`gong-data-capture`**;
several shared consent components live in the **honeyfy monolith**.

---

## `gong-data-capture` (primary repo)

### RecordingConsentTasks  ⏰ scheduled tasks + consumer

Scheduled tasks that drive consent ahead of a call. Sends **pre-call emails** and runs the **Kafka
consumer** for consent-page interactions.

### RecordingConsentApiServer  🔌 DCP consent settings API

Serves the **DCP consent settings API** via `DcpConsentSettingsController`.

### MeetingFrontEnd  🖥️ participant consent page

Serves the **consent page** to participants.

| Controller | Role |
|---|---|
| **`ConsentEmailController`** | Serves consent-email-driven page views. |
| **`JumpPageController`** | Serves the consent jump page. |

### ConsentWebApi  🌐 web API for consent flows

Web API backing the consent flows.

### ConsentCommon  📦 shared consent models

Shared consent domain models used across the consent services.

---

## honeyfy monolith — shared consent components

| Class | Role |
|---|---|
| **`com.honeyfy.consentemail.service.ConsentEmailSender`** | Sends consent emails. |
| **`com.honeyfy.consentsettings.service.DcpAppUserConsentService`** | Per-user consent settings. |
| **`com.honeyfy.appcommon.compliance.JumpPageUrlService`** | Builds the consent jump-page URL (**used by [[Subsystems/Call Scheduling/_dashboard\|Call Scheduling]]**). |
| **`com.honeyfy.datacapture.client.DcpConsentSettingsClient`** | Feign client for consent settings (calls `RecordingConsentApiServer`). |

---

## Quick "which module do I touch?" guide

| I want to… | Module / class |
|---|---|
| Change pre-call consent emails or the consent-interaction consumer | `RecordingConsentTasks` |
| Change the consent settings API | `RecordingConsentApiServer` → `DcpConsentSettingsController` |
| Change the participant-facing consent page | `MeetingFrontEnd` (`ConsentEmailController`, `JumpPageController`) |
| Change how the jump-page URL is built | `JumpPageUrlService` (monolith) |
| Change per-user consent resolution | `DcpAppUserConsentService` (monolith) |
| Call consent settings from another service | `DcpConsentSettingsClient` (Feign, monolith) |

## See also

- [[00 - Overview]]
- [[Storage & Schema Reference]]
- [[Subsystems/Call Scheduling/_dashboard|Call Scheduling]]
