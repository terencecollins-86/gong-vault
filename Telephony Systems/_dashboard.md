---
cssclasses: arch
tags: [telephony-systems, team, dashboard]
created: 2026-06-19
---

# ☎️ Telephony Systems — Team Hub

> [[Home|← Home]] · One-stop onboarding for the Telephony Systems team and the `gong-telephony-systems` repo.

A new engineer should be able to read these notes top-to-bottom and understand **what we own, how calls flow through our services, and where to look when something breaks.**

---

## 🚦 Start here (read in order)

1. [[00 - Overview]] — what the team owns, the mental model
2. [[01 - Architecture & Modules]] — the 9 modules, deployable vs. library
3. [[02 - Data Flows]] — diagrams of every flow + **all system entry points**
4. [[03 - Services Reference]] — per-service deep dive (infra, topics, controllers)
5. [[04 - Providers & Dialers]] — the dialers/providers we integrate
6. [[05 - Observability]] — logs, metrics, alerts, Swagger
7. [[06 - Runbook & Troubleshooting]] — troubleshooter endpoints, common ops
8. [[07 - Onboarding Checklist]] — day-1 → week-1 ramp
9. [[gong-entrypoints App — Usage]] — one-button triggers for each entry point

---

## 🗺️ At a glance

| | |
|---|---|
| **Repo** | `Honeyfy/gong-telephony-systems` (`main`) |
| **Group** | `com.honeyfy.telephony` |
| **Deployable services** | TelephonySystemsWebApi · IngesterTelephonySystemsSupervisor · TelephonySystemsTroubleshooters · TextIndexer |
| **Shared libraries** | Dialers · CallEventCommon · IngesterTelephonySystemsShared · TelephonySystemsUtils · TelephonySystemsRecordingsImporter |
| **Deploy env** | GPE (AWS, Crossplane-managed, rolling) |
| **Sentry team** | `telephony-systems` |

---

## 📋 Open team engineering work

```dataview
TABLE jira AS "Jira", status AS "Status", file.mtime AS "Updated"
FROM "Engineering"
WHERE contains(tags, "telephony-systems") OR contains(string(file.name), "Telephony")
SORT file.mtime DESC
LIMIT 10
```

## 🗂️ Notes in this section

```dataview
LIST
FROM "Telephony Systems"
WHERE file.name != "_dashboard"
SORT file.name ASC
```
