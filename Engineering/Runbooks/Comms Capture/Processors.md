---
tags: [gong, comms-capture, runbook, gong-processors]
created: 2026-06-19
---

# Processors (`gong-processors`)

Call-processing jobs and workflow execution: runs the core processor, launches Kubernetes processing jobs, and drives call-processing Temporal workflows.

## Repos
- `gong-processors` (?) — repo name inferred from subsystem; verify against the module registry

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `kubernetesjoblauncherapiserver` | Launches K8s processing jobs | [UI](https://kubernetesjoblauncherapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `processorjobsupervisor` | Supervises processing jobs | — |
| `processor` | Core call processor | — |
| `callprocessingworkflowrunner` | Runs call processing Temporal workflows | — |
| `callprocessingworkflowcoordinator` | Coordinates workflow execution | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-processors
# Stop
gong-module-run down --subsystem-names gong-processors
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-processors --remote
gong-module-run down --subsystem-names gong-processors --remote

# Workflow runner only (append --remote for remote)
gong-module-run up --image-names callprocessingworkflowrunner,callprocessingworkflowcoordinator
```

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
