---
tags: [gong, comms-capture, runbook, gong-communication-compliance]
created: 2026-06-19
---

# Communication Compliance (`gong-communication-compliance`)

Compliance enforcement over captured communications: compliance API backend, browser-facing WebAPI, and core compliance processing.

## Repos
- `gong-communication-compliance` (?) — repo name inferred from subsystem; verify against the module registry

## Services
| Service | Role | Swagger |
|---------|------|---------|
| `communicationcomplianceapiserver` | Compliance API backend | [UI](https://communicationcomplianceapiserver-vip.prod.gongio.net/swagger-ui/index.html) |
| `communicationcompliancewebapi` | Compliance WebAPI (browser-facing) | [UI](https://communicationcompliancewebapi-vip.prod.gongio.net/swagger-ui/index.html) |
| `communicationcomplianceserver` | Core compliance processing | [UI](https://communicationcomplianceserver-vip.prod.gongio.net/swagger-ui/index.html) |

> ⚠️ Swagger URLs are derived from the documented VIP pattern (see [[Swagger Pages]]); the pattern is confirmed but individual service URLs are not all verified live.

## Run — Local
```bash
# Full subsystem
gong-module-run up --subsystem-names gong-communication-compliance
# Stop
gong-module-run down --subsystem-names gong-communication-compliance
```

## Run — Remote
```bash
gong-module-run up --subsystem-names gong-communication-compliance --remote
gong-module-run down --subsystem-names gong-communication-compliance --remote
```

## Links
- [[GRM  gong-module-run How To]] — CLI reference & prerequisites
- [[Comms Capture Architecture Overview]]
- [[Comms Capture Maven Modules]] — per-service module breakdown
- [[Swagger Pages]] — auth notes for internal Swagger (VPN + `troubleshootersAuthJWT`)
