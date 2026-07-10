---
cssclasses: arch
tags: [subsystems, dashboard]
created: 2026-07-10
---

# 🧩 Subsystems — Hub

> [[Home|← Home]] · Every Gong subsystem I work on. Each has its own team hub, entry points, and canvas.

---

## 🗂️ Subsystem hubs

```dataview
TABLE
  file.folder AS "Folder",
  file.mtime AS "Updated"
FROM "Subsystems"
WHERE file.name = "_dashboard" AND file.folder != "Subsystems"
SORT file.folder ASC
```

---

## 📁 Folders in this section

```dataview
TABLE length(rows) AS "Pages", max(rows.file.mtime) AS "Last updated"
FROM "Subsystems"
GROUP BY file.folder AS "Folder"
SORT length(rows) DESC
```

> Dynamic map of every subsystem folder and how many pages each holds. Add a new subsystem folder and it appears here automatically.

---

## 📄 All subsystem pages

```dataview
TABLE
  file.folder AS "Subsystem",
  file.mtime AS "Updated"
FROM "Subsystems"
WHERE file.name != "_dashboard"
SORT file.folder ASC, file.name ASC
```

---

## 🏷️ Tags used across subsystems

```dataview
TABLE length(rows) AS "Pages"
FROM "Subsystems"
FLATTEN file.tags AS tag
WHERE tag
GROUP BY tag
SORT length(rows) DESC
```

---

## 🕐 Recently updated

```dataview
TABLE file.folder AS "Subsystem", file.mtime AS "Updated"
FROM "Subsystems"
WHERE file.name != "_dashboard"
SORT file.mtime DESC
LIMIT 10
```
