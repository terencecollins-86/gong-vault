---
cssclasses: eng
---

# 🟦 Engineering Dashboard

> [[Home|← Home]] · [[Work/Tasks/_board|Task Board]]

---

## 🔵 Active Notes

```dataview
TABLE jira AS "Jira", status AS "Status", file.mtime AS "Updated"
FROM "Work/Engineering"
WHERE type = "engineering" AND status = "active"
SORT file.mtime DESC
```

---

## 🐛 Open Bugs

```dataview
TABLE jira AS "Jira", file.mtime AS "Updated"
FROM "Work/Engineering/Bugs"
WHERE type = "engineering" AND status != "done"
SORT file.mtime DESC
```

---

## 📚 Runbooks

```dataview
TABLE file.mtime AS "Updated"
FROM "Work/Engineering/Runbooks"
WHERE file.name != "_dashboard"
SORT file.mtime DESC
```

---

## 🔀 PRs

```dataview
TABLE jira AS "Jira", status AS "Status", file.mtime AS "Updated"
FROM "Work/Engineering/PRs"
SORT file.mtime DESC
LIMIT 10
```

---

## ✅ Recently Completed

```dataview
TABLE jira AS "Jira", file.mtime AS "Closed"
FROM "Work/Engineering"
WHERE type = "engineering" AND status = "done"
SORT file.mtime DESC
LIMIT 5
```
