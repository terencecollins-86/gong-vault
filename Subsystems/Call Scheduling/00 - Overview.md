---
title: Call Scheduling — Overview
tags: [call-scheduling, overview, onboarding]
created: 2026-07-09
---

# 00 · Overview

> [[_dashboard|← Team Hub]] · next → [[01 - Services & Modules]]

## What the sub-system owns

**Call Scheduling** decides *which upcoming meetings become scheduled calls (recordings)* and
records that decision durably. It lives primarily in the **`gong-call-schedulers`** repo, fed by
calendar ingestion.

The core engine:

1. **Consumes** scheduling requests off the `CALL-SCHEDULING-REQUESTS` Kafka topic,
2. **Registers / reschedules / cancels** scheduled calls in the `scheduled_calls` Postgres table,
3. **Handles email invite webhooks** (invites that arrive out-of-band from calendar sync), and
4. **Cancels** calls when the underlying meeting or consent resolution changes.

## The mental model (one paragraph)

> **Calendar ingestion** ([[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion]]) fans out per-user
> syncs and, for meetings that need recording, produces to **`CALL-SCHEDULING-REQUESTS`** via
> `CallSchedulingRequestProducer`. The **`CallScheduler`** engine consumes that topic and, through
> `SchedulingCallService`, **adds**, **reschedules**, or **cancels** a row in **`scheduled_calls`**.
> In parallel, email invites arriving directly (not via calendar sync) hit the
> **`InviteHandlerWebhooksServer`** (and its global variant), which route through the same
> `CallBuilder` register/cancel logic.

## The two ways a call gets scheduled

```mermaid
graph TD
    subgraph gong-ingestion — Calendar
        Sup[IngesterCalendarSupervisor]
        GCI[GoogleCalendarIngester]
        OCI[OfficeCalendarIngester]
        Prod[CallSchedulingRequestProducer]
        Sup --> Prod
        GCI --> Prod
        OCI --> Prod
    end
    subgraph gong-call-schedulers
        Topic[[CALL-SCHEDULING-REQUESTS]]
        CS[CallScheduler engine]
        SCS[SchedulingCallService]
        CB[CallBuilder]
        IHW[InviteHandlerWebhooksServer]
        GIHW[GlobalInviteHandlerWebhooksServer]
        DB[(scheduled_calls)]
    end

    Prod --> Topic --> CS --> SCS --> CB --> DB
    Email[Email invite webhook] --> IHW --> CB
    Email --> GIHW --> CB
```

## Key interaction with consent

A scheduled call is only meaningful if the meeting can be recorded — that's gated by
[[Subsystems/Consent/_dashboard|recording consent]]. Scheduling uses
`com.honeyfy.appcommon.compliance.JumpPageUrlService` to build the consent jump-page URL, and
consent-resolution changes are one of the triggers that **cancel** an existing scheduled call
(`cancelExistingCallDueToResolutionChange`).

## Glossary pointers

- Org-wide acronyms: [[Acronyms]]
- Upstream feeder: [[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion]]
- Consent gating: [[Subsystems/Consent/_dashboard|Consent]]

## See also

- [[01 - Services & Modules]]
- [[Subsystems/Calendar Ingestion/02 - Data Flows]] — where `CALL-SCHEDULING-REQUESTS` is produced
