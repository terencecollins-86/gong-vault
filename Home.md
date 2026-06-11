---
cssclasses: []
---

# 🏠 Gong PKM — Home

> Quick nav: [[Engineering/_dashboard|🟦 Engineering]] · [[Architecture/_dashboard|🟩 Architecture]] · [[Meetings/_dashboard|🟥 Meetings]] · [[Research/_dashboard|🟣 Research]] · [[Goals & Growth/_dashboard|🌟 Growth]] · [[Tasks/_board|📋 Tasks]]

---

## 📋 Today's Tasks

```dataview
TASK
WHERE !completed AND (due = date(today) OR !due)
AND file.folder != "_templates"
SORT due ASC
LIMIT 10
```

---

## 📥 Recent Inbox

```dataview
TABLE file.mtime AS "Modified", file.size AS "Size"
FROM "Inbox"
WHERE file.name != "_README"
SORT file.mtime DESC
LIMIT 7
```

---

## 🟦 Open Engineering Work

```dataview
TABLE jira AS "Jira", status AS "Status", file.mtime AS "Updated"
FROM "Engineering"
WHERE type = "engineering" AND status = "active"
SORT file.mtime DESC
LIMIT 8
```

---

## 🗓️ Upcoming Meetings

```dataview
TABLE date AS "Date", attendees AS "Attendees"
FROM "Meetings"
WHERE type = "meeting" AND date >= date(today)
SORT date ASC
LIMIT 5
```

---

## 🏆 Recent Wins

```dataview
TABLE date AS "Date"
FROM "Goals & Growth/Wins"
WHERE contains(tags, "win")
SORT date DESC
LIMIT 5
```

---

## 📅 Recent Daily Notes

```dataview
TABLE file.day AS "Date"
FROM "Daily Notes"
SORT file.day DESC
LIMIT 7
```
