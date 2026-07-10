---
cssclasses: eng
tags: [work, dashboard]
created: 2026-07-10
---

# 🛠️ Work — Hub

> [[Home|← Home]] · Engineering, architecture, research, meetings, tasks, and inbox — everything work-related in one place.

Section hubs: [[Work/Engineering/_dashboard|🟦 Engineering]] · [[Work/Architecture/_dashboard|🟩 Architecture]] · [[Work/Research/_dashboard|🟣 Research]] · [[Work/Meetings/_dashboard|🟥 Meetings]] · [[Work/Tasks/_board|📋 Tasks]]

---

## 📁 Folders in this section

```dataview
TABLE length(rows) AS "Pages", max(rows.file.mtime) AS "Last updated"
FROM "Work"
WHERE file.folder != this.file.folder
FLATTEN regexreplace(replace(file.folder, this.file.folder + "/", ""), "/.*", "") AS Subfolder
GROUP BY Subfolder
SORT length(rows) DESC
```

> Dynamic — every folder under `Work/` with its page count.

---

## 🔵 Active engineering work

```dataview
TABLE jira AS "Jira", status AS "Status", file.mtime AS "Updated"
FROM "Work/Engineering"
WHERE type = "engineering" AND status = "active"
SORT file.mtime DESC
LIMIT 10
```

---

## ⚡ Open action items & tasks

```dataview
TASK
WHERE !completed AND startswith(file.folder, "Work")
SORT due ASC
```

---

## 🏷️ Tags used across work

```dataview
TABLE length(rows) AS "Pages"
FROM "Work"
FLATTEN file.tags AS tag
WHERE tag
GROUP BY tag
SORT length(rows) DESC
LIMIT 30
```

---

## 🕐 Recently updated

```dataview
TABLE file.folder AS "Folder", file.mtime AS "Updated"
FROM "Work"
WHERE file.name != "_dashboard" AND file.name != "_board"
SORT file.mtime DESC
LIMIT 12
```
