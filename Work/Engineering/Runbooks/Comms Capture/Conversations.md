---
tags: [gong, comms-capture, runbook, gong-conversations]
created: 2026-06-19
---

# Conversations (`gong-conversations`)

Post-call conversation data: research queries, summaries, transcript translation, and call-data retrieval.

## Repos
- `gong-conversations` (?) — repo name inferred from subsystem; verify against the module registry

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `conversationresearcherapiserver` | API for conversation research queries | [UI](https://conversationresearcherapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `translationapiserver` | Transcript translation | [UI](https://translationapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `calldataapiserver` | API for call data retrieval | [UI](https://calldataapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `omnisearchdigester` | Digests data for omni-search | — |
| `conversationsummary` | Generates call summaries | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Conversations.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-conversations
# Stop
gong-module-run down --subsystem-names gong-conversations
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-conversations --remote
gong-module-run down --subsystem-names gong-conversations --remote
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names conversationresearcherapiserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `conversationresearcherapiserver` | [troubleshooter](https://conversationresearcherapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `translationapiserver` | [troubleshooter](https://translationapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `calldataapiserver` | [troubleshooter](https://calldataapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `omnisearchdigester` / `conversationsummary` are non-HTTP workers — no troubleshooter UI. Drive them via a post-call event or breakpoint and replay. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
