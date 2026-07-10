---
cssclasses: arch
---

# 🟩 Architecture Dashboard

> [[Home|← Home]]

---

## 📋 ADRs

```dataview
TABLE status AS "Status", file.mtime AS "Updated"
FROM "Work/Architecture/ADRs"
WHERE type = "adr"
SORT file.mtime DESC
```

---

## 💡 Open Proposals

```dataview
TABLE status AS "Status", file.mtime AS "Updated"
FROM "Work/Architecture/Proposals"
SORT file.mtime DESC
```

---

## 🗺️ Diagrams

```dataview
LIST
FROM "Work/Architecture/Diagrams"
SORT file.mtime DESC
```

---

## 📊 ADR Status Summary

```dataview
TABLE length(rows) AS "Count"
FROM "Work/Architecture/ADRs"
WHERE type = "adr"
GROUP BY status
```
