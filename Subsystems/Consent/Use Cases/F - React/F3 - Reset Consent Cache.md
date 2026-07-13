---
title: "UC-F3 · Reset a Company's Consent Cache"
tags: [consent, use-case, react, cache]
created: 2026-07-13
group: F - React
---

# UC-F3 · Reset a Company's Consent Cache

> [[04 - Use Cases|← Use Cases hub]] · Group **F — React** · prev → [[F2 - React To Calendar Update]] · next → [[F4 - Purge Company]]

Evicts a company's consent Redis cache on demand.

---

## What this is for

Forcing fresh consent policy reads after a change. There is no end-user action — this is an operational lever so that when consent configuration changes, cached policy is invalidated and the next read reloads from source.

## What triggers it

`ResetConsentRedisForCompanyEvent` on `reset-consent-redis-for-company`.

---

## What the Consent module did

```
ResetConsentRedisForCompanyEvent on reset-consent-redis-for-company
  → ResetConsentRedisForCompanyConsumer
       → evict company's RECORDING_COMPLIANCE Redis cache
```

---

## What happens downstream / why it matters

The next consent read for that company misses the cache and reloads current policy, so stale compliance data cannot linger after an update. Scoped per company, so eviction is cheap and does not disturb other tenants.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | `ResetConsentRedisForCompanyEvent` / `reset-consent-redis-for-company` |
| **Command / process** | `ResetConsentRedisForCompanyConsumer` |
| **Event / topic** | `reset-consent-redis-for-company` |
| **State / audit** | Evicts `RECORDING_COMPLIANCE` Redis cache |

## Related

[[F2 - React To Calendar Update]]
