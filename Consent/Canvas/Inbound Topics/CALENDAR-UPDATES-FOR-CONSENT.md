---
title: calendar-updates-for-consent
component_type: inbound-kafka-topic
cluster: RECORDING_CONSENT
tags: [consent, kafka, inbound, calendar]
---

# 📥 calendar-updates-for-consent

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §2]]

`CalendarUpdateEvent` → `CalendarUpdatesForConsentConsumer` (`:24`) → `ConsentMeetingUpdatesService.handleUpdate`
(`:44`), keeping the consent calendar-event mirror current. Cluster `RECORDING_CONSENT`.
