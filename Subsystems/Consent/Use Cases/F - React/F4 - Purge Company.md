---
title: "UC-F4 · Purge a Company (GDPR)"
tags: [consent, use-case, react, gdpr]
created: 2026-07-13
group: F - React
---

# UC-F4 · Purge a Company (GDPR)

> [[04 - Use Cases|← Use Cases hub]] · Group **F — React** · prev → [[F3 - Reset Consent Cache]] · next → [[F5 - Gate A Consent Feature]]

Removes a company's consent state on tenant offboarding.

---

## What this is for

GDPR / tenant offboarding compliance. No end-user action — when a company leaves, its consent state must be deleted to satisfy data-retention obligations, and this consumer does that removal on the Consent side.

## What triggers it

`PurgeCompany` on `purge-company` (`OPERATIONAL_V1`, concurrency 1).

---

## What the Consent module did

```
PurgeCompany on purge-company (OPERATIONAL_V1, concurrency 1)
  → RecordingConsentPurgeCompanyConsumer
       → remove the company's consent state
```

---

## What happens downstream / why it matters

The company's consent records are removed, completing the Consent module's part of tenant offboarding. Call Scheduling runs its own parallel purge for the same event, so the two subsystems clean up independently.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | `PurgeCompany` / `purge-company` (`OPERATIONAL_V1`) |
| **Command / process** | `RecordingConsentPurgeCompanyConsumer` |
| **Event / topic** | `purge-company` (concurrency 1) |
| **State / audit** | Company consent state removed |

## Related

[[F3 - Reset Consent Cache]] · Call Scheduling has its own purge (parallel)
