---
cssclasses: arch
tags: [calendar-ingestion, team, dashboard]
created: 2026-06-25
---

# 📅 Calendar Ingestion — Team Hub

> [[Home|← Home]] · One-stop onboarding for calendar ingestion in the `gong-ingestion` repo (`Calendar/` sub-system).

A new engineer should be able to read these notes top-to-bottom and understand **what the calendar sub-system owns, how meetings flow through our services, and where to look when something breaks.**

---

## 🚦 Start here (read in order)

1. [[00 - Overview]] — what the sub-system owns, the mental model
2. [[01 - Architecture & Modules]] — the 6 modules, deployable vs. library
3. [[02 - Data Flows]] — diagrams of every flow + **all system entry points**
4. [[03 - Services Reference]] — per-service deep dive (infra, topics, consumers)
5. [[04 - Providers & Sources]] — the calendar providers we integrate (Google, Office 365)
6. [[05 - Observability]] — logs, metrics, alerts, Swagger
7. [[06 - Runbook & Troubleshooting]] — troubleshooter endpoints, common ops
8. [[07 - Onboarding Checklist]] — day-1 → week-1 ramp
9. [[Entrypoints Within the Calendar System]] — local-debug walkthrough per entrypoint

---

## 🗺️ At a glance

| | |
|---|---|
| **Repo** | `Honeyfy/gong-ingestion` (`main`) — `Calendar/` sub-tree |
| **Group** | `com.honeyfy.ingestion` → `CalendarIngesterSystem` aggregator |
| **Package** | `com.honeyfy.ingester.calendar.*` |
| **Deployable services** | IngesterCalendarSupervisor · GoogleCalendarIngester · OfficeCalendarIngester · MeetingsIndexer |
| **Shared libraries** | CalendarCore · CalendarIngesterCommon |
| **Deploy env** | GPE (AWS, Crossplane-managed, rolling) |
| **Owner** | ariel.bloch@gong.io |
| **Sentry team** | `mail-cal-ingestion` |

---

## 📋 Open team engineering work

```dataview
TABLE jira AS "Jira", status AS "Status", file.mtime AS "Updated"
FROM "Engineering"
WHERE contains(tags, "calendar-ingestion") OR contains(string(file.name), "Calendar")
SORT file.mtime DESC
LIMIT 10
```

## 🗂️ Notes in this section

```dataview
LIST
FROM "Calendar Ingestion"
WHERE file.name != "_dashboard"
SORT file.name ASC
```
