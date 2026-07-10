---
title: RecordingConsentTasks (engine)
component_type: service
cluster: RECORDING_CONSENT
tags: [consent, service, core, hub, oncall]
---

# ⚙️ RecordingConsentTasks (core engine)

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[01 - Services & Modules|Services]] · [[02 - Data Flow|Data Flow]] · Owner: **tomer.priel@gong.io**

> [!danger] On-call TL;DR
> The **consent engine** (GPE, private): runs the Kafka consumers (audit, calendar, consent-email,
> reset-redis) and ~20 scheduled tasks — including **sending pre-call consent emails** and warming the
> consent/jump-page Redis caches. If it stalls, consent emails stop and audit lags.

| | |
|---|---|
| **Consumers** | `audit-meeting-consent`, `audit-stop-recording`, `calendar-updates-for-consent`, `consent-email-page-interaction`, `reset-consent-redis-for-company`, `call-scheduling-updated` |
| **Key tasks** | `ConsentEmailsTasks` (send), `JumpPageSettingsChangeTask`, `Populate*RedisTask`, `DeletePastMeetings…` |
| **Writes** | `recording_consent` DB (compliance audit, settings), Redis, Mailgun email |
