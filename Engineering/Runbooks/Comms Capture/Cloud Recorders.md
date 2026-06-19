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

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Cloud Recording Retrieval — gong-cloud-recorders]]
- [[Comms Capture Maven Modules#gong-cloud-recorders]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
