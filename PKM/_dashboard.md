---
cssclasses: growth
tags: [pkm, dashboard]
created: 2026-07-10
---

# 🧠 PKM — Hub

> [[Home|← Home]] · Personal knowledge: daily notes, goals & growth, clippings, resources.

Section hubs: [[PKM/Goals & Growth/_dashboard|🌟 Goals & Growth]]

---

## 📁 Folders in this section

```dataview
TABLE length(rows) AS "Pages", max(rows.file.mtime) AS "Last updated"
FROM "PKM"
WHERE file.folder != this.file.folder
FLATTEN regexreplace(replace(file.folder, this.file.folder + "/", ""), "/.*", "") AS Subfolder
GROUP BY Subfolder
SORT length(rows) DESC
```

---

## 🎯 Open goals

```dataview
TASK
WHERE !completed AND contains(tags, "goal") AND file.folder != "_templates"
SORT file.day DESC
```

---

## 🏆 Recent wins

```dataview
TABLE date AS "Date", file.link AS "Win"
FROM "PKM/Goals & Growth/Wins"
WHERE contains(tags, "win")
SORT date DESC
LIMIT 8
```

---

## 📚 Recent learnings

```dataview
TABLE file.day AS "Date", file.link AS "Note"
FROM "PKM/Daily Notes"
WHERE contains(tags, "learning")
SORT file.day DESC
LIMIT 10
```

---

## 📅 Recent daily notes

```dataview
TABLE file.day AS "Date"
FROM "PKM/Daily Notes"
SORT file.day DESC
LIMIT 7
```

---

## 🏷️ Tags used across PKM

```dataview
TABLE length(rows) AS "Pages"
FROM "PKM"
FLATTEN file.tags AS tag
WHERE tag
GROUP BY tag
SORT length(rows) DESC
LIMIT 30
```
