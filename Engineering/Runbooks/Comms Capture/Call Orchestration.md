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

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
