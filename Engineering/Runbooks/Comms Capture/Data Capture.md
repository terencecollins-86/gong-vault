---
tags: [gong, comms-capture, runbook, gong-data-capture]
created: 2026-06-19
---

# Data Capture (`gong-data-capture`)

Recording consent management and Data Capture Profile (DCP) change tracking — controls what is allowed to be captured per company and user. DB: `data_capture` schema.

## Repos
- `gong-data-capture` — consent settings, DCP change detection, consent API/tasks

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `meetingfrontend` | Meeting join page (browser-facing) | [UI](https://meetingfrontend-vip.prod.gongio.net/swagger-ui/index.html) |
| `consentwebapi` | Consent WebAPI (browser-facing) | [UI](https://consentwebapi-vip.prod.gongio.net/swagger-ui/index.html) |
| `recordingconsentapiserver` | Consent API backend | [UI](https://recordingconsentapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `dcpchangemanager` | DCP change event management | — |
| `recordingconsenttasks` | Async consent processing tasks | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Data Capture.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-data-capture
# Stop
gong-module-run down --subsystem-names gong-data-capture
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-data-capture --remote
gong-module-run down --subsystem-names gong-data-capture --remote

# Consent services only (append --remote for remote)
gong-module-run up --image-names recordingconsentapiserver,recordingconsenttasks,consentwebapi
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names recordingconsentapiserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `recordingconsentapiserver` | [troubleshooter](https://recordingconsentapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `consentwebapi` | [troubleshooter](https://consentwebapi-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `meetingfrontend` | [troubleshooter](https://meetingfrontend-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `dcpchangemanager` / `recordingconsenttasks` are non-HTTP (no troubleshooter UI) — exercise them via their upstream events or the consent API above. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Consent & Data Capture Profile (DCP) — gong-data-capture]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
