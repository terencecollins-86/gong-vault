---
cssclasses: research
---

# 🟣 Research Dashboard

> [[Home|← Home]]

---

## 🔬 Active Spikes

```dataview
TABLE status AS "Status", file.mtime AS "Updated"
FROM "Research"
WHERE type = "research" AND status = "active"
SORT file.mtime DESC
```

---

## ✅ Completed Research

```dataview
TABLE status AS "Status", file.mtime AS "Completed"
FROM "Research"
WHERE type = "research" AND status = "done"
SORT file.mtime DESC
LIMIT 10
```

---

## 📎 All Spikes

```dataview
TABLE status AS "Status", created AS "Created"
FROM "Research/Spikes"
SORT created DESC
```
