---
title: Rep / Call Owner (Actor)
component_type: actor
tags: [call-scheduling, actor, user]
---

# 👤 Rep / Call Owner

Gong-licensed user who schedules meetings. Their calendar (Google/Outlook) is synced by `gong-ingestion`. Owns the `Call` aggregate — can cancel and restore their scheduled recordings via the Gong UI. Marked `should_record=true` in the system for recordings to be scheduled automatically.
