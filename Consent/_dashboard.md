---
cssclasses: arch
tags: [consent, recording-consent, team, dashboard]
created: 2026-07-09
---

# ✅ Consent — Team Hub

> [[Home|← Home]] · One-stop map for **recording consent** — the `gong-data-capture` repo plus the shared consent code in the honeyfy monolith.

A new engineer should be able to read these notes top-to-bottom and understand **what recording consent owns, how the consent page reaches participants, and which datastore holds consent state.**

---

## 🚦 Start here (read in order)

1. [[00 - Overview]] — what the sub-system owns, the mental model
2. [[01 - Services & Modules]] — the DCP services, the consent page, and monolith-shared code
3. [[02 - Data Flow]] — every inbound & outbound point, code-grounded
4. [[03 - Ubiquitous Language]] — the DDD domain vocabulary (source of truth: the code)
5. [[Storage & Schema Reference]] — the `recording_consent` database and its schemas

🗺️ **10,000-ft view:** [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|Consent — Data Flow canvas]]

---

## 🗺️ At a glance

| | |
|---|---|
| **Primary repo** | `Honeyfy/gong-data-capture` |
| **Shared code** | honeyfy monolith (`com.honeyfy.consentemail.*`, `com.honeyfy.consentsettings.*`, `com.honeyfy.appcommon.compliance.*`, `com.honeyfy.datacapture.client.*`) |
| **Database** | `recording_consent` (Postgres) |
| **Schemas** | `recording_consent_email` · `recording_consent_settings` · `recording_compliance` |
| **Related hubs** | [[Call Scheduling/_dashboard\|Call Scheduling]] · [[Calendar Ingestion/_dashboard\|Calendar Ingestion]] |

---

## 🗂️ Notes in this section

```dataview
LIST
FROM "Consent"
WHERE file.name != "_dashboard"
SORT file.name ASC
```

## See also

- [[Call Scheduling/_dashboard|Call Scheduling]] — consent gates what gets scheduled/recorded
- [[Acronyms]]
