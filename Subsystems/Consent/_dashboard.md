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

1. [[00 - Overview]] — what the sub-system owns, the mental model, and the **five consent mechanisms**
2. [[01 - Services & Modules]] — the DCP services, the consent page, and monolith-shared code
3. [[02 - Data Flow]] — every inbound & outbound point, code-grounded
4. [[03 - Ubiquitous Language]] — the DDD domain vocabulary (source of truth: the code)
5. [[04 - Use Cases]] — the domain use cases in DDD terms (actor → command → outcome → event)
6. [[Storage & Schema Reference]] — the `recording_consent` database and its schemas
7. [[05 - Data Access & Storage]] — code-grounded datasource / DAO / schema map
8. [[06 - Local Dev Seed Data]] — seed the base + drive the flows to populate owned tables
9. [[09 - Schema Reference (columns)]] — column-level DDL for every owned table (columns, types, PKs, indexes)

### Operations & troubleshooting

- [[Troubleshooting Endpoints Catalog]] — all 75 troubleshooter endpoints across 13 controllers, mapped to use cases A–F; gaps noted
- [[06 - Local Dev Seed Data]] — seed sequence and failure modes

### Deep-dives by mechanism

- [[Jump Page & DCP]] — consent page internals, DCP settings, PMI vs dynamic, Redis hot path
- [[Meeting Providers & Multi-Provider DCP]] — provider enum list, multi-provider `DcpJumpPageSettingsProvider`, `?provider=` URL discriminator, user provider default
- [[Audio Prompt]] — bot verbal notice, Zoom native consent, suppression when jump page already used
- [[Confirmation Email (LA)]] — assistant-ingested calls with non-org organiser; active-permission flow
- [[Consent Link Creation]] — four surfaces for creating consent links (Outlook, GCal, API, static copy)
- [[Consent Email — Default Allow & Outcome Matrix]] — what happens when the pre-call email is ignored

🗺️ **10,000-ft view:** [[Subsystems/Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|Consent — Data Flow canvas]]
🧭 **Context map:** [[Subsystems/Call Scheduling/Canvas/Bounded Context Map - Call Scheduling & Consent.canvas|Bounded Context Map — Call Scheduling ⇄ Consent]] (DDD)

**Event Storming canvases (Actor → Command → Event → Policy → Data):**
- [[Subsystems/Consent/Canvas/ES1 - Solicit & Capture.canvas|ES1 — Solicit & Capture]] — jump page + consent email participant flows (UCs A+B)
- [[Subsystems/Consent/Canvas/ES2 - Enforce.canvas|ES2 — Enforce]] — compliance gate + recorder boundary (UCs C + CheckCompliance)
- [[Subsystems/Consent/Canvas/ES3 - Propagate DCP Change.canvas|ES3 — Propagate DCP Change]] — change-request state machine (UCs D+E)
- [[Subsystems/Consent/Canvas/ES4 - React to Upstream Events.canvas|ES4 — React to Upstream Events]] — `call-scheduling-updated`, calendar, purge, feature gates (UCs F)

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
