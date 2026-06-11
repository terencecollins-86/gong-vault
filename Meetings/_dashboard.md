---
cssclasses: meet
---

# 🟥 Meetings Dashboard

> [[Home|← Home]]

---

## 🗓️ Upcoming Meetings

```dataview
TABLE date AS "Date", attendees AS "Attendees"
FROM "Meetings"
WHERE type = "meeting" AND date >= date(today)
SORT date ASC
LIMIT 10
```

---

## 🕐 Recent Meetings

```dataview
TABLE date AS "Date", attendees AS "Attendees", file.mtime AS "Updated"
FROM "Meetings"
WHERE type = "meeting"
SORT date DESC
LIMIT 10
```

---

## ⚡ Open Action Items

```dataview
TASK
WHERE !completed AND file.folder = "Meetings"
SORT due ASC
```

---

## 👥 1-on-1s

```dataview
TABLE date AS "Date"
FROM "Meetings/1-on-1s"
SORT date DESC
LIMIT 8
```
