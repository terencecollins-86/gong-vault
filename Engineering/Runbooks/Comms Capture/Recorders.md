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

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Bot-Based Call Recording — gong-recorders]]
- [[Comms Capture Maven Modules#gong-recorders]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
