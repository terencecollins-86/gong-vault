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
5. [[04 - Use Cases]] — the domain use cases in DDD terms (actor → command → Resolution → event)
6. [[05 - Onboarding Checklist]] — day-1 / week-1 ramp + local dev

🗺️ **10,000-ft view:** [[Subsystems/Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|Call Scheduling — Data Flow canvas]]
🧭 **Context map:** [[Subsystems/Call Scheduling/Canvas/Bounded Context Map - Call Scheduling & Consent.canvas|Bounded Context Map — Call Scheduling ⇄ Consent]] (DDD)

**Event Storming canvases (Actor → Command → Event → Policy → Data):**
- [[Subsystems/Call Scheduling/Canvas/ES1 - Schedule.canvas|ES1 — Schedule]] — all scheduling paths A1–A4 (calendar sync, email invite, manual, coordinator)
- [[Subsystems/Call Scheduling/Canvas/ES2 - Cancel & Reschedule.canvas|ES2 — Cancel & Reschedule]] — B1 (reschedule) + C1–C6 (all cancel paths + compliance gate)
- [[Subsystems/Call Scheduling/Canvas/ES3 - Restore & Recurring.canvas|ES3 — Restore & Recurring]] — D1 (restore) + E1–E2 (recurring series expansion + cancel)
- [[Subsystems/Call Scheduling/Canvas/ES4 - Operational.canvas|ES4 — Operational]] — F1–F4 (GDPR purge, token sync, history audit, recording hand-off)

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
WHERE file.folder != this.file.folder
FLATTEN regexreplace(replace(file.folder, this.file.folder + "/", ""), "/.*", "") AS Subfolder
GROUP BY Subfolder
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
