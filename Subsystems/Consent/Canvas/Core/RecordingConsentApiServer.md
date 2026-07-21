---
title: RecordingConsentApiServer
component_type: service
tags: [consent, service, dcp, api]
---

# 🔌 RecordingConsentApiServer

> [[_dashboard|← Consent Hub]] · [[01 - Services & Modules|Services]] · Port **7254** · Internal

DCP settings CRUD API — `DcpConsentSettingsController` (`readDcpJumpPageSettingsWithUser`, `saveUserProviderDefault`). Static-link backfill (`StaticLinkService`). Purges company data on `purge-company` event. Entry point for all consent-settings reads from other Gong services via `DcpConsentSettingsClient` (Feign, honeyfy monolith).
