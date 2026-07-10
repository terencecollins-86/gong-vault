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

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Processors.canvas]]

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

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names kubernetesjoblauncherapiserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `kubernetesjoblauncherapiserver` | [troubleshooter](https://kubernetesjoblauncherapiserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `processor` / `processorjobsupervisor` / `callprocessingworkflowrunner` / `callprocessingworkflowcoordinator` are non-HTTP workers — no troubleshooter UI. Drive them via a queued processing job or a Temporal workflow trigger. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
