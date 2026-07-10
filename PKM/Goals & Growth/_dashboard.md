---
cssclasses: growth
---

# 🌟 Goals & Growth

> Track wins, learnings, open goals, and evidence for manager reviews.

---

## 🏆 Wins

```dataview
TABLE date AS "Date", file.link AS "Win"
FROM "PKM/Goals & Growth/Wins"
WHERE contains(tags, "win")
SORT date DESC
```

---

## 📚 Learnings

```dataview
TABLE file.day AS "Date", file.link AS "Note"
FROM "PKM/Daily Notes"
WHERE contains(tags, "learning")
SORT file.day DESC
LIMIT 20
```

---

## 🎯 Open Goals

```dataview
TASK
WHERE !completed AND contains(tags, "goal")
AND file.folder != "_templates"
SORT file.day DESC
```

---

## 📁 End of Term Evidence

> Files collected for manager review / perf discussions:

```dataview
TABLE file.mtime AS "Updated"
FROM "PKM/Goals & Growth/End-of-Term"
SORT file.mtime DESC
```

---

## 📊 Summary Stats

```dataview
TABLE length(rows) AS "Count"
FROM "PKM/Goals & Growth/Wins"
WHERE contains(tags, "win")
GROUP BY "Total Wins"
```
