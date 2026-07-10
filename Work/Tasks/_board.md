---
cssclasses: []
---

# 📋 Task Board

---

## 🔵 In Progress

```dataview
TASK
WHERE !completed AND contains(tags, "in-progress")
AND file.folder != "_templates"
GROUP BY file.link
```

---

## 🟡 Backlog

```dataview
TASK
WHERE !completed AND !contains(tags, "in-progress")
AND file.folder != "_templates"
AND due >= date(today)
SORT due ASC
LIMIT 20
```

---

## ✅ Done This Week

```dataview
TASK
WHERE completed
AND completion >= date(today) - dur(7 days)
AND file.folder != "_templates"
SORT completion DESC
LIMIT 20
```

---

## By Type

### 🟦 Engineering
```dataview
TASK
WHERE !completed AND file.folder = "Work/Engineering"
SORT due ASC
```

### 🟩 Architecture
```dataview
TASK
WHERE !completed AND file.folder = "Work/Architecture"
SORT due ASC
```

### 🟥 Meetings (Actions)
```dataview
TASK
WHERE !completed AND file.folder = "Work/Meetings"
SORT due ASC
```

### 🟣 Research
```dataview
TASK
WHERE !completed AND file.folder = "Work/Research"
SORT due ASC
```
