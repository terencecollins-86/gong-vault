---
title: RecordingConsentApiServer
component_type: api-server
tags: [consent, rest, api, internal]
---

# 🔌 RecordingConsentApiServer

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §1]] · Owner: **yaakov.lifshitz@gong.io**

Internal **DCP consent-settings API** (**GPE**, private). `DcpConsentSettingsController` (`:25`, implements
`DcpConsentSettingsApi`), `JumpPageSettingsChangeDetectorController` (`:27`). Consumes `purge-company`
(GDPR). Hosts the `DistributedScheduledTaskExecutor` engine backing the scheduled tasks.
