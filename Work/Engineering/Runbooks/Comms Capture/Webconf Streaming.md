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

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Webconf Streaming.canvas]]

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

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names streamingwebhookapiserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `streamingwebhookapiserver` | [troubleshooter](https://streamingwebhookapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `streamingaccountmanagementapiserver` | [troubleshooter](https://streamingaccountmanagementapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `streamingapiserver` | [troubleshooter](https://streamingapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> All three services expose HTTP. Drive a streaming flow by posting a provider streaming webhook to `streamingwebhookapiserver`. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
