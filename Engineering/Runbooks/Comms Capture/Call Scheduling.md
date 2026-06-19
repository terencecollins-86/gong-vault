---
tags: [gong, comms-capture, runbook, gong-call-schedulers]
created: 2026-06-19
---

# Call Scheduling (`gong-call-schedulers`)

Bridges calendar events to bot-deployment decisions: matches calendar invites to upcoming calls and decides which capture method to use (bot vs cloud recording).

## Repos
- `gong-call-schedulers` — scheduling logic + calendar invite webhook handlers

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `callscheduler` | Schedules calls from calendar events | — |
| `invitehandlerwebhooksserver` | Handles calendar invite webhooks | [UI](https://invitehandlerwebhooksserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `globalinvitehandlerwebhooksserver` | Global invite webhook handler | [UI](https://globalinvitehandlerwebhooksserver-vip.prod.gongio.net/swagger-ui/index.html) |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live. Webhook servers expose HTTP, so they likely have a UI; confirm before relying on it.

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-call-schedulers
# Stop
gong-module-run down --subsystem-names gong-call-schedulers
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-call-schedulers --remote
gong-module-run down --subsystem-names gong-call-schedulers --remote
```

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Call Scheduling — gong-call-schedulers]]
- [[Comms Capture Maven Modules#gong-call-schedulers]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
