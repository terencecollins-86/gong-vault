---
title: "UC-F2 · Sync Provider Users and Tokens"
tags: [call-scheduling, use-case, operational, provider, webex, zoom]
created: 2026-07-13
group: F - Operational
---

# UC-F2 · Sync Provider Users and Tokens

> [[04 - Use Cases|← Use Cases hub]] · Group **F — Operational** · prev → [[F1 - Purge A Company]] · next → [[F3 - Emit Scheduling History]]

Keep conferencing-provider auth and user mappings fresh, so that when a Zoom/WebEx URL arrives the scheduler can still resolve who owns it and how to join.

---

## What this is for

No user clicks "sync my provider." This runs for the **platform**, but the end user benefits indirectly and critically: their meetings keep getting recorded. Provider tokens expire and user rosters drift; if the scheduler's cached auth and user map go stale, `CallInDetails` can no longer resolve the owner of a conferencing URL and scheduling silently fails. This use case keeps that mapping alive.

## What triggers it

A mix of event-driven and scheduled refresh:
- `SyncUsersFromProviderEvent` on **`sync-users-from-web-conferencing-provider`** (cluster `DATA_CAPTURE`), consumed by `CallSchedulerWebexSyncUsersConsumer`
- Scheduled tasks: `webex-import-users`, `webex-refresh-tokens`, `zoom-import-meetings`

---

## What the Call Scheduler did

```
sync-users-from-web-conferencing-provider (DATA_CAPTURE)
  → CallSchedulerWebexSyncUsersConsumer → refresh provider user map

scheduled tasks:
  webex-import-users     → pull current WebEx user roster
  webex-refresh-tokens   → renew WebEx OAuth tokens before expiry
  zoom-import-meetings   → reconcile known Zoom meetings
  → provider auth + user↔URL mapping kept current
```

---

## What happens downstream / why it matters

With fresh tokens and an up-to-date user map, `CallInDetails` can resolve who owns a given Zoom/WebEx meeting URL — the precondition for every provider-based scheduling flow (Groups A–E). Let the tokens lapse and scheduling breaks quietly: the URL arrives but the owner can't be resolved, so nothing gets recorded.

## Code map

| | |
|---|---|
| **Event trigger** | `SyncUsersFromProviderEvent` on `sync-users-from-web-conferencing-provider` |
| **Cluster** | `DATA_CAPTURE` |
| **Consumer** | `CallSchedulerWebexSyncUsersConsumer` |
| **Scheduled tasks** | `webex-import-users`, `webex-refresh-tokens`, `zoom-import-meetings` |
| **For whom** | Platform (keeps `CallInDetails` resolvable) |

## Related

- [[F1 - Purge A Company]] · [[F3 - Emit Scheduling History]]
- [[Subsystems/Call Scheduling/Canvas/Inbound Topics/SYNC-USERS-FROM-WEB-CONFERENCING-PROVIDER|SYNC-USERS-FROM-WEB-CONFERENCING-PROVIDER topic]]
- [[Subsystems/Call Scheduling/Canvas/Providers/Conferencing-Providers|Conferencing Providers]]
- [[Subsystems/Call Scheduling/Canvas/Core/Scheduled-Tasks|Scheduled Tasks]]
