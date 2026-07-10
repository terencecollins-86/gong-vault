---
tags: [gong, comms-capture, runbook, gong-inmeeting-experience]
created: 2026-06-19
---

# In-Meeting Experience (`gong-inmeeting-experience`)

Live in-call features and real-time transcription during a meeting.

## Repos
- `gong-inmeeting-experience` (?) — repo name inferred from subsystem; verify against the module registry

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `zoomappwebapi` | Zoom app integration WebAPI | [UI](https://zoomappwebapi-vip.prod.gongio.net/swagger-ui/index.html) |
| `liveawstranscription` | Live real-time transcription via AWS | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[In-Meeting Experience.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-inmeeting-experience
# Stop
gong-module-run down --subsystem-names gong-inmeeting-experience
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-inmeeting-experience --remote
gong-module-run down --subsystem-names gong-inmeeting-experience --remote
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names zoomappwebapi --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `zoomappwebapi` | [troubleshooter](https://zoomappwebapi-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `liveawstranscription` is non-HTTP (no troubleshooter UI) — drive it via a live in-meeting audio stream. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
