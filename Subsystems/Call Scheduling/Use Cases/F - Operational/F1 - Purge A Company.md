---
title: "UC-F1 · Purge a Company"
tags: [call-scheduling, use-case, operational, purge, gdpr]
created: 2026-07-13
group: F - Operational
---

# UC-F1 · Purge a Company

> [[04 - Use Cases|← Use Cases hub]] · Group **F — Operational** · next → [[F2 - Sync Provider Users And Tokens]]

Tenant offboarding: when a company leaves Gong (or a compliance request lands), its scheduled calls must be removed so no stale recording state survives.

---

## What this is for

This is not an end-user action — nobody schedules a purge from the product UI. It exists for the **platform and compliance**: GDPR / right-to-be-forgotten and tenant offboarding demand that a departing company's scheduling footprint disappears cleanly. The indirect beneficiary is the departing customer, whose data stops being tracked.

## What triggers it

A `PurgeCompany` event on the **`purge-company`** topic (cluster `OPERATIONAL_V1`), consumed by `CallSchedulerPurgeCompanyConsumer`. The event is emitted centrally by the platform's tenant-lifecycle machinery, not by the Call Scheduler itself.

---

## What the Call Scheduler did

```
purge-company (OPERATIONAL_V1)
  → CallSchedulerPurgeCompanyConsumer
      → resolve the company being purged
      → delete the company's scheduled calls + associated
        scheduling state (public.call rows, provider upcoming-meeting rows)
  → aggregate for that tenant is emptied
```

---

## What happens downstream / why it matters

Removing the scheduled calls keeps the aggregate correct and the tenant clean: `CallInDetails` will no longer resolve stale meetings for a company that no longer exists, and no orphaned scheduling rows linger to confuse search, audit, or recording handoff. It closes the tenant lifecycle on the scheduling side.

## Code map

| | |
|---|---|
| **Trigger** | `PurgeCompany` event on `purge-company` topic |
| **Cluster** | `OPERATIONAL_V1` |
| **Consumer** | `CallSchedulerPurgeCompanyConsumer` |
| **Effect** | Delete the company's scheduled calls + scheduling state |
| **For whom** | Platform / compliance (GDPR, offboarding) |

## Related

- [[F2 - Sync Provider Users And Tokens]] — the next operational concern
- [[Subsystems/Call Scheduling/Canvas/Inbound Topics/PURGE-COMPANY|PURGE-COMPANY topic]]
- [[Subsystems/Call Scheduling/Canvas/Data Stores/DataStore-PostgreSQL|PostgreSQL data store]]
