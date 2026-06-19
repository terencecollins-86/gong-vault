---
tags: [gong, comms-capture, runbook, gong-ingestion]
created: 2026-06-19
---

# Ingestion (`gong-ingestion`)

Provider connectivity plus the email (Gmail / O365) and calendar (Google / O365) ingestion pipelines. Email is the first stage of a two-stage pipeline: `gong-ingestion` → Kafka (`EmailIngested`) → `gong-email-digestion` → OpenSearch (`gong-emails`). Calendar uses polling/cursor (not webhooks) and feeds `MeetingsIndexer` → meetings DB used by `gong-call-schedulers`.

## Repos
- `gong-ingestion` — provider connectivity, mail + calendar ingestion
- `gong-email-digestion` — downstream email indexing/classification/privacy (separate subsystem; see below)

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `googlemailprocessingserver` | Processes Google mail | [UI](https://googlemailprocessingserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `providerconnectivity` | Manages OAuth connections to providers | — |
| `ingestermailsupervisor` | Supervises mail ingestion | — |
| `ingestermailworker` | Mail ingestion worker | — |
| `mailingester` | Mail ingest processor | — |
| `maillistener` | Listens for new mail events | — |
| `ingestercalendarsupervisor` | Supervises calendar ingestion | — |
| `googlecalendaringester` | Google Calendar ingester | — |
| `officecalendaringester` | O365 Calendar ingester | — |
| `meetingsindexer` | Indexes meeting records | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live. Most ingestion services are workers/supervisors/listeners and do not expose HTTP.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Ingestion.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-ingestion
# Stop
gong-module-run down --subsystem-names gong-ingestion
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-ingestion --remote
gong-module-run down --subsystem-names gong-ingestion --remote

# Image subsets (append --remote for remote)
# Provider connectivity only
gong-module-run up --image-names providerconnectivity
# Mail pipeline only
gong-module-run up --image-names ingestermailsupervisor,ingestermailworker,mailingester,maillistener
# Calendar pipeline only
gong-module-run up --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names googlemailprocessingserver --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `googlemailprocessingserver` | [troubleshooter](https://googlemailprocessingserver-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> Most ingestion services (`providerconnectivity`, the mail/calendar supervisors, ingesters, listeners, `meetingsindexer`) are non-HTTP workers — no troubleshooter UI. Drive them via their upstream provider events / cursor polls, or breakpoint the worker and replay a Kafka message. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Ingestion (`gong-ingestion`) - Entry Points]] — detailed entry-point breakdown
- [[Comms Capture Architecture Overview#Email Capture — gong-ingestion → gong-email-digestion]]
- [[Comms Capture Architecture Overview#Calendar Capture — gong-ingestion]]
- [[Comms Capture Maven Modules#gong-ingestion]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
