---
cssclasses: []
tags: [meta, dashboard]
created: 2026-07-10
---

# ⚙️ _meta — Hub

> [[Home|← Home]] · Vault infrastructure: attachments and backups. Not knowledge content.

---



---

## 📎 Assets (attachments)

Attachment folder for the vault (`.obsidian/app.json` → `attachmentFolderPath: _meta/Assets`).
Non-markdown files (images, etc.) aren't indexed by dataview — browse `Assets/` directly.

## 🗄️ Backups

Seed scripts, Postman collections, and other snapshots kept out of the knowledge folders:

```dataview
LIST
FROM "_meta/Backups"
SORT file.name ASC
```
