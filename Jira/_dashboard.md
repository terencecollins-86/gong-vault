---
cssclasses: eng
tags: [jira, dashboard, purge, Q1FY27]
created: 2026-07-23
---

# 🎫 Jira Tickets — Dashboard

> [[Work/_dashboard|← Work]] · Tracks all Jira sub-tasks assigned to me, with kanban-style workflow status and quick links to PRs.

**Workflow statuses:** `todo` → `doing` → `pr` → `done`

---

## 📋 All tickets — kanban view

```dataview
TABLE WITHOUT ID
  link(file.link, jira) AS "Ticket",
  table AS "Table",
  choice(workflow_status = "todo",   "⬜ Todo",
  choice(workflow_status = "doing",  "🔵 Doing",
  choice(workflow_status = "pr",     "🟡 PR Open",
  choice(workflow_status = "done",   "✅ Done", workflow_status)))) AS "Status",
  choice(pr_url != "" AND pr_url != null, link(pr_url, "PR ↗"), "—") AS "PR",
  parent_epic AS "Epic"
FROM "Jira"
WHERE jira != null
SORT choice(workflow_status = "doing", 0, choice(workflow_status = "pr", 1, choice(workflow_status = "todo", 2, 3))) ASC
```

---

## ⬜ Todo

```dataview
TABLE WITHOUT ID
  link(file.link, jira) AS "Ticket",
  table AS "Table",
  file.mtime AS "Updated"
FROM "Jira"
WHERE jira != null AND workflow_status = "todo"
SORT file.mtime DESC
```

---

## 🔵 Doing

```dataview
TABLE WITHOUT ID
  link(file.link, jira) AS "Ticket",
  table AS "Table",
  file.mtime AS "Updated"
FROM "Jira"
WHERE jira != null AND workflow_status = "doing"
SORT file.mtime DESC
```

---

## 🟡 PR Open

```dataview
TABLE WITHOUT ID
  link(file.link, jira) AS "Ticket",
  table AS "Table",
  choice(pr_url != "" AND pr_url != null, link(pr_url, "View PR ↗"), "—") AS "PR",
  file.mtime AS "Updated"
FROM "Jira"
WHERE jira != null AND workflow_status = "pr"
SORT file.mtime DESC
```

---

## ✅ Done

```dataview
TABLE WITHOUT ID
  link(file.link, jira) AS "Ticket",
  table AS "Table",
  choice(pr_url != "" AND pr_url != null, link(pr_url, "PR ↗"), "—") AS "PR",
  file.mtime AS "Updated"
FROM "Jira"
WHERE jira != null AND workflow_status = "done"
SORT file.mtime DESC
```

---

## 🔢 Summary

```dataview
TABLE WITHOUT ID
  choice(workflow_status = "todo",  "⬜ Todo",
  choice(workflow_status = "doing", "🔵 Doing",
  choice(workflow_status = "pr",    "🟡 PR Open",
  choice(workflow_status = "done",  "✅ Done", "❓ Unknown")))) AS "Status",
  length(rows) AS "Count"
FROM "Jira"
WHERE jira != null
GROUP BY workflow_status
SORT choice(workflow_status = "doing", 0, choice(workflow_status = "pr", 1, choice(workflow_status = "todo", 2, 3))) ASC
```

---

## 📁 All tickets

```dataview
TABLE WITHOUT ID
  link(file.link, jira) AS "Ticket",
  table AS "Table",
  workflow_status AS "Status",
  repo AS "Repo",
  created AS "Created"
FROM "Jira"
WHERE jira != null
SORT created DESC
```

---

## See also

- [[_templates/purge-index-ticket]] — template for new purge index tickets
- [[Postgres CREATE INDEX CONCURRENTLY]] — CONCURRENTLY deep-dive
- [[Flyway Migrations at Gong]] — migration conventions
