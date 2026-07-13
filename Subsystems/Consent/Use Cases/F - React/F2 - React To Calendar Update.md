---
title: "UC-F2 · React to a Calendar Update"
tags: [consent, use-case, react, calendar]
created: 2026-07-13
group: F - React
---

# UC-F2 · React to a Calendar Update

> [[04 - Use Cases|← Use Cases hub]] · Group **F — React** · prev → [[F1 - React To Scheduled Call]] · next → [[F3 - Reset Consent Cache]]

Calendar changes are mirrored into the consent calendar store.

---

## What this is for

Keeping the consent-side calendar mirror current. No end-user action triggers this directly — Consent maintains its own copy of relevant calendar events so downstream consent logic can read meeting details without calling back into the calendar subsystem.

## What triggers it

`CalendarUpdateEvent` on `calendar-updates-for-consent`.

---

## What the Consent module did

```
CalendarUpdateEvent on calendar-updates-for-consent
  → CalendarUpdatesForConsentConsumer
  → ConsentMeetingUpdatesService#handleUpdate
       → upsert consent calendar mirror
       → recording_consent_settings.calendar_event (ConsentMeetingUpdatesDao)
```

---

## What happens downstream / why it matters

The upserted mirror in `recording_consent_settings.calendar_event` is the local source of truth for meeting details used by consent flows. Keeping it fresh means consent decisions reflect the latest calendar state without a synchronous cross-subsystem dependency.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | `CalendarUpdateEvent` / `calendar-updates-for-consent` |
| **Command / process** | `ConsentMeetingUpdatesService#handleUpdate` |
| **Event / topic** | `calendar-updates-for-consent` |
| **State / audit** | `recording_consent_settings.calendar_event` |

## Related

[[F1 - React To Scheduled Call]]
