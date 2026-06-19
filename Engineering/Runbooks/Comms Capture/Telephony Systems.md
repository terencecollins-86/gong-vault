---
tags: [gong, comms-capture, runbook, gong-telephony-systems]
created: 2026-06-19
---

# Telephony Systems (`gong-telephony-systems`)

Captures calls made through third-party dialers (RingCentral, Groove, ConnectAndSell, Salesloft, Outreach, Amazon Connect) and direct API uploads. Base class `AbstractDialerService`; Kafka producers `GdmCallEventSender`, `DialerCallsUpdatesProducer`. Also handles Dialpad SMS capture (`DialpadSmsService`).

## Repos
- `gong-telephony-systems` — telephony ingestion, dialer adapters, troubleshooters
- `gong-connect` — Gong's native Twilio-backed VoIP dialer (closely related; SMS/WhatsApp + call-status webhooks)

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `telephonysystemswebapi` | Telephony WebAPI (browser-facing) | [UI](https://telephonysystemswebapi-vip.prod.gongio.net/swagger-ui/index.html) |
| `ingestertelephonysystemssupervisor` | Supervises telephony ingestion | — |
| `telephonysystemstroubleshooters` | Diagnostic tools | — |
| `textindexer` | Indexes transcribed text | — |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.
>
> ℹ️ `gong-connect` modules (`GongConnectWebApi`, `GongConnectWebhooksServer`, `GongConnectTasks`, `GongConnectMessagingServer`) ship in their own repo and are not part of the `gong-telephony-systems` subsystem — run them separately if needed.

## Diagram
Bounded-context map — services (green = HTTP/troubleshooter, orange = worker) and convergence point. Open in Obsidian Canvas:

![[Telephony Systems.canvas]]

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-telephony-systems
# Stop
gong-module-run down --subsystem-names gong-telephony-systems
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-telephony-systems --remote
gong-module-run down --subsystem-names gong-telephony-systems --remote
```

## Debug — Breakpoints
Full attach/suspend workflow: [[GRM  gong-module-run How To#Debugging with Breakpoints]]. JDWP is always on (container `5005` → host port printed at startup).

```bash
# Run just the service you want to debug, suspended until your IDE attaches
gong-module-run up --image-names telephonysystemswebapi --debug-suspend
```
Attach IntelliJ *Remote JVM Debug* to `localhost:<printed debug port>`, set a breakpoint, then trigger it via this context's troubleshooter UI:

| Service | Troubleshooter UI |
|---------|-------------------|
| `telephonysystemswebapi` | [troubleshooter](https://telephonysystemswebapi-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |
| `telephonysystemstroubleshooters` | [troubleshooter](https://telephonysystemstroubleshooters-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html) |

> `ingestertelephonysystemssupervisor` / `textindexer` are non-HTTP (no troubleshooter UI) — drive them via a dialer call upload or the WebAPI above. `telephonysystemstroubleshooters` is purpose-built for diagnostics. Troubleshooter URLs are derived from the documented pattern (see [[Swagger Pages]]); requires VPN + `troubleshootersAuthJWT`.

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Telephony / Dialer Capture — gong-telephony-systems]]
- [[Comms Capture Architecture Overview#Gong Connect (Native VoIP Dialer) — gong-connect]]
- [[Comms Capture Maven Modules#gong-telephony-systems]]
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
