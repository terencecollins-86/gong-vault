---
tags: [gong, comms-capture, runbook, gong-orchestration]
created: 2026-06-19
---

# Call Orchestration (`gong-orchestration`)

Coordinates the call-processing pipeline: the central orchestrator that drives captured calls through processing steps and AI orchestration.

## Repos
- `gong-orchestration` (?) — repo name inferred from subsystem; verify against the module registry

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `callaiorchestrationserver` | AI processing orchestration | [UI](https://callaiorchestrationserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `orchestrator` | Central call processing orchestrator | — |
| `callpipelineexecutor` | Executes call processing pipeline steps | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Call Orchestration.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-orchestration
# Stop
gong-module-run down --subsystem-names gong-orchestration
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-orchestration --remote
gong-module-run down --subsystem-names gong-orchestration --remote
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names callaiorchestrationserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `callaiorchestrationserver` | [troubleshooter](https://callaiorchestrationserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `orchestrator` / `callpipelineexecutor` are non-HTTP (no troubleshooter UI) — drive them by submitting a call into the pipeline upstream, or breakpoint and replay the triggering event. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
