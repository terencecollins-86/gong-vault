---
title: "UC-D2 · Schedule / Manage a One-Time (Dynamic) Jump-Page Meeting"
tags: [consent, use-case, configure, jump-page, meeting]
created: 2026-07-13
group: D - Configure
---

# UC-D2 · Schedule / Manage a One-Time (Dynamic) Jump-Page Meeting

> [[04 - Use Cases|← Use Cases hub]] · Group **D — Configure** · prev → [[D1 - Read Write DCP Settings|UC-D1]]

An admin flow creates a per-meeting (dynamic, 3-segment) jump page.

---

## What this is for

A per-meeting jump page — as opposed to the static PMI (personal meeting ID) page. This
lets a specific meeting get its own consent jump page, with its own provider and optionally
a custom URL key.

## What triggers it

An admin flow (scheduling / editing / deleting a one-time meeting).

---

## What the Consent module did

```
admin flow
        │
        ▼
JumpPageAdminService#scheduleMeeting
        #updateOnetimeMeeting
        #deleteOnetimeMeeting
        │
        ├─▶ OneTimeMeetingStatus lifecycle:  CREATED → SCHEDULED → DELETED
        ├─▶ #chooseMeetingProvider           (picks provider)
        └─▶ #validateUserUrlKey → URL_KEY_VALIDATION
                { OK | INVALID_CHARACTERS | LENGTH_ISSUE | EXIST }
```

---

## What happens downstream / why it matters

A dynamic, 3-segment jump page exists for that specific meeting, ready to be rendered when
a participant arrives (see [[A - Solicit/A1 - Render Jump Page|UC-A1]]). Custom URL-key
validation keeps the per-meeting URL well-formed and unique.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | admin flow |
| **Command / process** | `JumpPageAdminService#scheduleMeeting` / `#updateOnetimeMeeting` / `#deleteOnetimeMeeting` |
| **Event / topic** | — |
| **State / audit** | `OneTimeMeetingStatus` |

## Related

[[D1 - Read Write DCP Settings|UC-D1]] · [[A - Solicit/A1 - Render Jump Page|UC-A1]] (this creates the dynamic page A1 renders)
