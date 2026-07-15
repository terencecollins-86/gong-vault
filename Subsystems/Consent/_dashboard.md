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
5. [[04 - Use Cases]] — the domain use cases in DDD terms (actor → command → outcome → event)
6. [[Storage & Schema Reference]] — the `recording_consent` database and its schemas
7. [[05 - Data Access & Storage]] — code-grounded datasource / DAO / schema map
8. [[06 - Local Dev Seed Data]] — seed the base + drive the flows to populate owned tables

🗺️ **10,000-ft view:** [[Subsystems/Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|Consent — Data Flow canvas]]
🧭 **Context map:** [[Subsystems/Call Scheduling/Canvas/Bounded Context Map - Call Scheduling & Consent.canvas|Bounded Context Map — Call Scheduling ⇄ Consent]] (DDD)

---

## 🗺️ At a glance

| | |
|---|---|
| **Primary repo** | `Honeyfy/gong-data-capture` |
| **Shared code** | honeyfy monolith (`com.honeyfy.consentemail.*`, `com.honeyfy.consentsettings.*`, `com.honeyfy.appcommon.compliance.*`, `com.honeyfy.datacapture.client.*`) |
| **Database** | `recording_consent` (Postgres) |
| **Schemas** | `recording_consent_email` · `recording_consent_settings` · `recording_compliance` |
| **Related hubs** | [[Subsystems/Call Scheduling/_dashboard\|Call Scheduling]] · [[Subsystems/Calendar Ingestion/_dashboard\|Calendar Ingestion]] |

---

## 📁 Folders in this section

```dataview
TABLE length(rows) AS "Pages", max(rows.file.mtime) AS "Last updated"
FROM "Subsystems/Consent"
WHERE file.folder != this.file.folder
FLATTEN regexreplace(replace(file.folder, this.file.folder + "/", ""), "/.*", "") AS Subfolder
GROUP BY Subfolder
SORT length(rows) DESC
```

## 🗂️ Notes in this section

```dataview
TABLE file.folder AS "Folder", file.mtime AS "Updated"
FROM "Subsystems/Consent"
WHERE file.name != "_dashboard"
SORT file.folder ASC, file.name ASC
```

## 🏷️ Tags in this subsystem

```dataview
TABLE length(rows) AS "Pages"
FROM "Subsystems/Consent"
FLATTEN file.tags AS tag
WHERE tag
GROUP BY tag
SORT length(rows) DESC
```

## See also

- [[Subsystems/Call Scheduling/_dashboard|Call Scheduling]] — consent gates what gets scheduled/recorded
- [[Acronyms]]
