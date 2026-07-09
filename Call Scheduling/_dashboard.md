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

---

## 🗺️ At a glance

| | |
|---|---|
| **Primary repo** | `Honeyfy/gong-call-schedulers` |
| **Feeder repo** | `Honeyfy/gong-ingestion` (`Calendar/` sub-tree) |
| **Core engine** | `CallScheduler` module |
| **Kafka in** | `CALL-SCHEDULING-REQUESTS` |
| **Postgres out** | `scheduled_calls` table |
| **Related hubs** | [[Calendar Ingestion/_dashboard\|Calendar Ingestion]] · [[Consent/_dashboard\|Consent]] · [[Telephony Systems/_dashboard\|Telephony Systems]] |

---

## 🗂️ Notes in this section

```dataview
LIST
FROM "Call Scheduling"
WHERE file.name != "_dashboard"
SORT file.name ASC
```

## See also

- [[Calendar Ingestion/_dashboard|Calendar Ingestion]] — produces `CALL-SCHEDULING-REQUESTS`
- [[Consent/_dashboard|Consent]] — recording consent gates what gets scheduled/recorded
- [[Acronyms]]
