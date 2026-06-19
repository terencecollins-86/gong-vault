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

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
