---
tags: [gong, comms-capture, runbook, gong-cloud-recorders]
created: 2026-06-19
---

# Cloud Recorders (`gong-cloud-recorders`)

Retrieves recordings from cloud provider storage after a meeting ends (Zoom, Webex). Trigger is a provider webhook; `CaptureStatusReporter` writes to `call_workflow_tracking` and `AsyncCallWorkflowClient#submit` kicks off the call-processing pipeline.

## Repos
- `gong-cloud-recorders` — cloud recording retrieval + provider webhook servers

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `globalzoomwebhooksserver` | Zoom webhook receiver | [UI](https://globalzoomwebhooksserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `webexwebhooksserver` | Webex webhook receiver | [UI](https://webexwebhooksserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `cloudrecorder` | Cloud bot recorder | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live. Webhook servers expose HTTP, so they likely have a UI; confirm before relying on it.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Cloud Recorders.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-cloud-recorders
# Stop
gong-module-run down --subsystem-names gong-cloud-recorders
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-cloud-recorders --remote
gong-module-run down --subsystem-names gong-cloud-recorders --remote
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names globalzoomwebhooksserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `globalzoomwebhooksserver` | [troubleshooter](https://globalzoomwebhooksserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `webexwebhooksserver` | [troubleshooter](https://webexwebhooksserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `cloudrecorder` is non-HTTP (no troubleshooter UI) — drive it via a provider webhook hitting the servers above. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Cloud Recording Retrieval — gong-cloud-recorders]]
- [[Comms Capture Maven Modules#gong-cloud-recorders]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
