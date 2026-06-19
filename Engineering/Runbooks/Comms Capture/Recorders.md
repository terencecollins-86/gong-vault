---
tags: [gong, comms-capture, runbook, gong-recorders]
created: 2026-06-19
---

# Recorders (`gong-recorders`)

Bot-based call recording: records live meetings by joining as a bot participant (Google Meet, Microsoft Teams). Core abstraction is the `Connector` interface. Flow: scheduler deploys bot → bot joins → streams audio → uploads to S3 → triggers call-processing workflow.

## Repos
- `gong-recorders` — recorder process, supervisor, streamer, control APIs

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `recorderapiserver` | Internal API for recorder control | [UI](https://recorderapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `globalrecordingsupervisorapiserver` | Global recording supervisor API | [UI](https://globalrecordingsupervisorapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `recorder` | Core recording process | — |
| `recordingsupervisor` | Orchestrates recorder lifecycle | — |
| `recordingstreamer` | Streams raw audio/video | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Recorders.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-recorders
# Stop
gong-module-run down --subsystem-names gong-recorders
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-recorders --remote
gong-module-run down --subsystem-names gong-recorders --remote

# Core recording only (append --remote for remote)
gong-module-run up --image-names recorder,recordingsupervisor,recorderapiserver
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names recorderapiserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `recorderapiserver` | [troubleshooter](https://recorderapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `globalrecordingsupervisorapiserver` | [troubleshooter](https://globalrecordingsupervisorapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `recorder` / `recordingsupervisor` / `recordingstreamer` are non-HTTP (no troubleshooter UI) — drive them via the recorder API above or scheduler-triggered bot deployment. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Bot-Based Call Recording — gong-recorders]]
- [[Comms Capture Maven Modules#gong-recorders]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
