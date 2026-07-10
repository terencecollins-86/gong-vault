---
title: Call Scheduling — Services & Modules
tags: [call-scheduling, services, modules, reference]
created: 2026-07-09
---

# 01 · Services & Modules

> [[_dashboard|← Team Hub]] · [[00 - Overview]]

Per-module reference for call scheduling. The engine and webhook servers live in
**`gong-call-schedulers`**; the producer that feeds them lives in **`gong-ingestion`**.

---

## `gong-call-schedulers` (primary repo)

### CallScheduler  ⚙️ core engine

The core scheduling engine. Consumes the `CALL-SCHEDULING-REQUESTS` Kafka topic and writes to the
`scheduled_calls` Postgres table.

| Class | Role |
|---|---|
| **`SchedulingCallService`** | The scheduling brain. Key methods: `addCallFromCalendarAndReport`, `rescheduleCallUpdateAndReport`, `cancelExistingCallDueToResolutionChange`. |
| **`CancelCallService`** | Owns **all cancellation paths**. |
| **`CallBuilder`** | Registers / cancels calls from **email or calendar** in the DB. Shared by the engine and the webhook servers. |

| | |
|---|---|
| **Kafka in** | `CALL-SCHEDULING-REQUESTS` |
| **Postgres out** | `scheduled_calls` |

### InviteHandlerWebhooksServer  📨 email invite webhook processor

Processes **email invite webhooks** — calendar invites that arrive out-of-band rather than through
scheduled calendar sync. Routes through `CallBuilder` to register/cancel scheduled calls.

### GlobalInviteHandlerWebhooksServer  🌐 global variant

Global variant of the invite-handler webhook server (same invite-processing responsibility, global
scope).

---

## `gong-ingestion` — calendar feed into scheduling

The calendar sub-system is what *produces* scheduling requests. See the full calendar map at
[[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion]].

| Class | Role |
|---|---|
| **`IngesterCalendarSupervisor`** | Orchestrates calendar sync fan-out (see [[Subsystems/Calendar Ingestion/03 - Services Reference]]). |
| **`GoogleCalendarIngester`** | Ingests Google calendar events. |
| **`OfficeCalendarIngester`** | Ingests Office 365 calendar events. |
| **`CallSchedulingRequestProducer`** | **Produces to `CALL-SCHEDULING-REQUESTS`** — the hand-off from calendar ingestion into call scheduling. |

---

## Quick "which module do I touch?" guide

| I want to… | Module / class |
|---|---|
| Change *when/how* a call is scheduled or rescheduled | `SchedulingCallService` (`CallScheduler`) |
| Change cancellation behavior | `CancelCallService` |
| Change register/cancel DB writes (email **or** calendar) | `CallBuilder` |
| Handle an out-of-band email invite | `InviteHandlerWebhooksServer` / `GlobalInviteHandlerWebhooksServer` |
| Change *what* produces scheduling requests | `CallSchedulingRequestProducer` (in `gong-ingestion`) |

## See also

- [[00 - Overview]]
- [[Subsystems/Consent/_dashboard|Consent]] — resolution changes trigger cancellation
- [[Subsystems/Calendar Ingestion/02 - Data Flows]]
