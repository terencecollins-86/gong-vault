# Swagger Pages

Live and deployed Swagger/OpenAPI endpoints for testing.

> For my remote dev environment (`terry-collins-dev-env`) service URLs, see [[Dev Env Service URLs]].

**Auth notes:**
- Internal services (`*.prod.gongio.net`) — requires VPN + troubleshooters cookie (`troubleshootersAuthJWT`)
- Public API (`app.gong.io`) — requires OAuth2 Bearer token (Authorize button in UI)

---

## Confirmed Live Endpoints

| Service | Environment | Swagger URL | Auth |
|---------|-------------|-------------|------|
| **Public API v1/v2** | Prod | https://app.gong.io/swagger-ui/index.html | OAuth2 Bearer |
| **Logs Manager** (adjustable logging) | Prod | https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html | VPN + troubleshootersAuthJWT |

---

## Logs Manager — Notable Troubleshooter Endpoints

| Endpoint | Direct Link |
|----------|-------------|
| Get logger level | https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/get |
| List all logging levels | https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/listLoggingLevels |
| Set logger level | https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/set |
| Clear adjusted loggers | https://logs-manager-vip.prod.gongio.net/swagger-ui/index.html#/adjustable-logging-levels-troubleshooter/clear |

---

## Public API — OpenAPI Spec URLs

| Resource | URL |
|----------|-----|
| Swagger UI | https://app.gong.io/swagger-ui/index.html |
| OpenAPI JSON (all) | https://app.gong.io/v3/api-docs |
| OpenAPI JSON (v1) | https://app.gong.io/v3/api-docs/v1 |
| OpenAPI JSON (v2) | https://app.gong.io/v3/api-docs/v2 |
| Raw spec (v1 JSON) | https://app.gong.io/resources/v1/swagger.json |
| Raw spec (v2 JSON) | https://app.gong.io/resources/v2/swagger.json |

---

## Internal Service URL Pattern

All ~180 backend services expose Swagger under the same path pattern when on VPN:

```
https://<service-name>-vip.prod.gongio.net/swagger-ui/index.html
https://<service-name>-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html
```

**Getting the troubleshooters cookie:** Use the Developer Data Gateway portal (OKTA → "Developer Data Gateway") — it sets `troubleshootersAuthJWT` in your session automatically. Direct audit request endpoint: `https://dev-data-gateway-vip.prod.gongio.net/troubleshooter-audit-request`

---

## Adding an Entry

Add a row to the confirmed table above:

```
| Service Name | prod/staging | https://...-vip.prod.gongio.net/swagger-ui/index.html | VPN + troubleshootersAuthJWT |
```
