---
title: Calendar Feed
component_type: upstream-producer
tags: [consent, upstream, calendar]
---

# 📅 Calendar Feed

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]]

Produces **`calendar-updates-for-consent`** (`CalendarUpdateEvent`). Consumed by
`CalendarUpdatesForConsentConsumer` → `ConsentMeetingUpdatesService.handleUpdate` to keep the consent
calendar-event mirror (`recording_consent_settings.calendar_event`) current.
