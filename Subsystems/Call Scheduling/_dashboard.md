---
cssclasses: arch
tags: [call-scheduling, team, dashboard]
created: 2026-07-09
---

# 📞 Call Scheduling — Team Hub

> [[Home|← Home]] · One-stop map for **call scheduling** — the `gong-call-schedulers` repo plus the calendar feed that drives it.

A new engineer should be able to read these notes top-to-bottom and understand **what call scheduling owns, how scheduling requests flow in, and where a scheduled recording actually gets written.**

---

## 🚦 Start here (read in order)

1. [[00 - Overview]] — what the sub-system owns, the mental model, the flow
2. [[01 - Services & Modules]] — CallScheduler, the webhook servers, and the calendar producer
3. [[02 - Entry Points (Inbound & Outbound)]] — every inbound & outbound point, code-grounded
4. [[03 - Ubiquitous Language]] — the DDD domain vocabulary (source of truth: the code)
5. [[04 - Onboarding Checklist]] — day-1 / week-1 ramp + local dev

🗺️ **10,000-ft view:** [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|Call Scheduling — Data Flow canvas]]

---

## 🗺️ At a glance

| | |
|---|---|
| **Primary repo** | `Honeyfy/gong-call-schedulers` |
| **Feeder repo** | `Honeyfy/gong-ingestion` (`Calendar/` sub-tree) |
| **Core engine** | `CallScheduler` module |
| **Kafka in** | `CALL-SCHEDULING-REQUESTS` |
| **Postgres out** | `scheduled_calls` table |
| **Related hubs** | [[Subsystems/Calendar Ingestion/_dashboard\|Calendar Ingestion]] · [[Subsystems/Consent/_dashboard\|Consent]] · [[Subsystems/Telephony Systems/_dashboard\|Telephony Systems]] |

---

## 📁 Folders in this section

```dataview
TABLE length(rows) AS "Pages", max(rows.file.mtime) AS "Last updated"
FROM "Subsystems/Call Scheduling"
GROUP BY file.folder AS "Folder"
SORT length(rows) DESC
```

## 🗂️ Notes in this section

```dataview
TABLE file.folder AS "Folder", file.mtime AS "Updated"
FROM "Subsystems/Call Scheduling"
WHERE file.name != "_dashboard"
SORT file.folder ASC, file.name ASC
```

## 🏷️ Tags in this subsystem

```dataview
TABLE length(rows) AS "Pages"
FROM "Subsystems/Call Scheduling"
FLATTEN file.tags AS tag
WHERE tag
GROUP BY tag
SORT length(rows) DESC
```

## See also

- [[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion]] — produces `CALL-SCHEDULING-REQUESTS`
- [[Subsystems/Consent/_dashboard|Consent]] — recording consent gates what gets scheduled/recorded
- [[Acronyms]]
