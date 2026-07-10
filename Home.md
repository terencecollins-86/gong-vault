---
cssclasses: []
---

# 🏠 Gong PKM — Home

> **Sections:** [[Subsystems/_dashboard|🧩 Subsystems]] · [[Work/_dashboard|🛠️ Work]] · [[PKM/_dashboard|🧠 PKM]] · [[_meta/_dashboard|⚙️ _meta]]
>
> **Jump to:** [[Work/Engineering/_dashboard|🟦 Engineering]] · [[Work/Architecture/_dashboard|🟩 Architecture]] · [[Work/Meetings/_dashboard|🟥 Meetings]] · [[Work/Research/_dashboard|🟣 Research]] · [[PKM/Goals & Growth/_dashboard|🌟 Growth]] · [[Work/Tasks/_board|📋 Tasks]] · [[Subsystems/Telephony Systems/_dashboard|☎️ Telephony]] · [[Subsystems/Calendar Ingestion/_dashboard|📅 Calendar]] · [[Subsystems/Call Scheduling/_dashboard|📞 Call Scheduling]] · [[Subsystems/Consent/_dashboard|✅ Consent]]

---

## 🧩 Subsystems

```dataview
TABLE length(rows) AS "Pages", max(rows.file.mtime) AS "Updated"
FROM "Subsystems"
WHERE file.name != "_dashboard"
GROUP BY file.folder AS "Subsystem"
SORT file.folder ASC
```

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
FROM "Work/Inbox"
WHERE file.name != "_README"
SORT file.mtime DESC
LIMIT 7
```

---

## 🟦 Open Engineering Work

```dataview
TABLE jira AS "Jira", status AS "Status", file.mtime AS "Updated"
FROM "Work/Engineering"
WHERE type = "engineering" AND status = "active"
SORT file.mtime DESC
LIMIT 8
```

---

## 🗓️ Upcoming Meetings

```dataview
TABLE date AS "Date", attendees AS "Attendees"
FROM "Work/Meetings"
WHERE type = "meeting" AND date >= date(today)
SORT date ASC
LIMIT 5
```

---

## 🏆 Recent Wins

```dataview
TABLE date AS "Date"
FROM "PKM/Goals & Growth/Wins"
WHERE contains(tags, "win")
SORT date DESC
LIMIT 5
```

---

## 📅 Recent Daily Notes

```dataview
TABLE file.day AS "Date"
FROM "PKM/Daily Notes"
SORT file.day DESC
LIMIT 7
```
