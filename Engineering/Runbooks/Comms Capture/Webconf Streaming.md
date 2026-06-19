---
tags: [gong, comms-capture, runbook, gong-webconf-streaming]
created: 2026-06-19
---

# Webconf Streaming (`gong-webconf-streaming`)

Streaming-webhook infrastructure for web-conferencing providers: receives streaming webhooks, manages streaming account config, and serves the core streaming API.

## Repos
- `gong-webconf-streaming` (?) — repo name inferred from subsystem; verify against the module registry

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `streamingwebhookapiserver` | Receives streaming webhooks | [UI](https://streamingwebhookapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `streamingaccountmanagementapiserver` | Manages streaming account config | [UI](https://streamingaccountmanagementapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `streamingapiserver` | Core streaming API | [UI](https://streamingapiserver-vip.prod.gongio.net/swagger-ui/index.html) |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-webconf-streaming
# Stop
gong-module-run down --subsystem-names gong-webconf-streaming
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-webconf-streaming --remote
gong-module-run down --subsystem-names gong-webconf-streaming --remote
```

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
