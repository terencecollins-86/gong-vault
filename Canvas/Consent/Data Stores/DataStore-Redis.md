---
title: Redis (RECORDING_COMPLIANCE)
component_type: datastore
tags: [consent, datastore, redis]
---

# ⚡ Redis — `RECORDING_COMPLIANCE`

> [[Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §8]]

Write-through cache (DB first, then Redis) for jump-page / DCP compliance settings and consent-email
accessors. Warmed by `PopulateConsentRedisWithAccessorsTask` / `PopulateDcpJumpPageRedisTask`; evicted per
company by `ResetConsentRedisForCompanyConsumer`. (Descriptors call the connection `CONSENT_REDIS`.)
