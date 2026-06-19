---
tags: [gong, comms-capture, runbook, gong-communications-publisher]
created: 2026-06-19
---

# Communications Publisher (`gong-communications-publisher`)

Publishes captured communication events downstream and provides stable entity IDs. Works alongside the Activity Store — the unified sink for all captured communication activities (calls, emails, LinkedIn, SMS).

## Repos
- `gong-communications-publisher` — communication sync + entity ID provider
- `gong-activity-store` — unified activity sink (`ActivityStoreGateway`, `CallActivityStoreGateway`, `MessagingActivityStoreGateway`); related, separate repo

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `entityidproviderserver` | Provides stable entity IDs | [UI](https://entityidproviderserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `communicationssyncserver` | Syncs communication data | [UI](https://communicationssyncserver-vip.prod.gongio.net/swagger-ui/index.html) |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Communications Publisher.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-communications-publisher
# Stop
gong-module-run down --subsystem-names gong-communications-publisher
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-communications-publisher --remote
gong-module-run down --subsystem-names gong-communications-publisher --remote
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names communicationssyncserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `communicationssyncserver` | [troubleshooter](https://communicationssyncserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `entityidproviderserver` | [troubleshooter](https://entityidproviderserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> Both services expose HTTP. Drive a publish flow via an upstream activity event, or call the sync server's troubleshooter directly. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Activity Store — gong-activity-store]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
