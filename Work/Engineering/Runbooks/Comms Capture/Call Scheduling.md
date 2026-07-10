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

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Call Scheduling.canvas]]

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

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names invitehandlerwebhooksserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `invitehandlerwebhooksserver` | [troubleshooter](https://invitehandlerwebhooksserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `globalinvitehandlerwebhooksserver` | [troubleshooter](https://globalinvitehandlerwebhooksserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `callscheduler` is non-HTTP (no troubleshooter UI) — drive it via a calendar-invite webhook hitting the servers above. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Call Scheduling — gong-call-schedulers]]
- [[Comms Capture Maven Modules#gong-call-schedulers]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
