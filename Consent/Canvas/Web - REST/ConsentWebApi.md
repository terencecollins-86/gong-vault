---
title: ConsentWebApi
component_type: webapi-server
tags: [consent, rest, public]
---

# 🌐 ConsentWebApi

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §1]]

**Public** web API (**GPE**, `/consentwebapi`). Hosts `MicrosoftTeamsAttendanceReportController` (`:31`) —
MS Teams attendance report download (CSV). Uses `OPERATIONAL` + `USER_AUTH` Postgres.
