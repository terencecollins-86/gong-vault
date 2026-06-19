---
tags: [gong, comms-capture, runbook, gong-communications-publisher]
created: 2026-06-19
---

# Communications Publisher (`gong-communications-publisher`)

Publishes captured communication events downstream and provides stable entity IDs. Works alongside the Activity Store — the unified sink for all captured communication activities (calls, emails, LinkedIn, SMS).

## Repos
- `gong-communications-publisher` — communication sync + entity ID provider
- `gong-activity-store` — unified activity sink (`ActivityStoreGateway`, `CallActivityStoreGateway`, `MessagingActivityStoreGateway`); related, separate repo

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `entityidproviderserver` | Provides stable entity IDs | [UI](https://entityidproviderserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `communicationssyncserver` | Syncs communication data | [UI](https://communicationssyncserver-vip.prod.gongio.net/swagger-ui/index.html) |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-communications-publisher
# Stop
gong-module-run down --subsystem-names gong-communications-publisher
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-communications-publisher --remote
gong-module-run down --subsystem-names gong-communications-publisher --remote
```

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview#Activity Store — gong-activity-store]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
