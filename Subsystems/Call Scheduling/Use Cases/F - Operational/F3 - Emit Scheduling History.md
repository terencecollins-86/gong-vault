---
title: "UC-F3 · Emit Scheduling History"
tags: [call-scheduling, use-case, operational, audit, opensearch]
created: 2026-07-13
group: F - Operational
---

# UC-F3 · Emit Scheduling History

> [[04 - Use Cases|← Use Cases hub]] · Group **F — Operational** · prev → [[F2 - Sync Provider Users And Tokens]] · next → [[F4 - Hand Off To Recording]]

Every scheduling decision leaves an audit trail, bulk-indexed into search so support and audit can answer "why did (or didn't) this call get recorded?"

---

## What this is for

This serves **support and audit**, not the end user directly. When someone asks why a meeting was scheduled, rescheduled, or cancelled, the answer needs to be searchable rather than reconstructed from logs. The end user benefits indirectly: faster, evidence-backed support answers when a recording is missing or unexpected.

## What triggers it

The scheduler itself emits it. `CallSchedulingHistoryProducer` writes each scheduling decision to the **`call-scheduling-history`** topic; `CallSchedulingHistoryConsumer` reads it back and bulk-indexes into OpenSearch.

---

## What the Call Scheduler did

```
scheduling decision (any of Groups A–E)
  → CallSchedulingHistoryProducer → call-scheduling-history topic
      → CallSchedulingHistoryConsumer
          (batched: ~100 events / 30s window)
          → bulk-index into OpenSearch CALENDAR_EVENTS_HISTORY
```

The consumer batches — roughly 100 events or a 30-second flush — to keep the OpenSearch bulk-index efficient rather than indexing one event at a time.

---

## What happens downstream / why it matters

The `CALENDAR_EVENTS_HISTORY` index makes every scheduling decision queryable for support and audit. It feeds search rather than the recording pipeline — a parallel observability trail alongside the operational handoff in [[F4 - Hand Off To Recording]].

## Code map

| | |
|---|---|
| **Producer** | `CallSchedulingHistoryProducer` |
| **Topic** | `call-scheduling-history` |
| **Consumer** | `CallSchedulingHistoryConsumer` (batched ~100 events / 30s) |
| **Sink** | OpenSearch `CALENDAR_EVENTS_HISTORY` |
| **For whom** | Support / audit (searchable trail) |

## Related

- [[F2 - Sync Provider Users And Tokens]] · [[F4 - Hand Off To Recording]]
- [[Subsystems/Call Scheduling/Canvas/Inbound Topics/CALL-SCHEDULING-HISTORY|CALL-SCHEDULING-HISTORY topic]]
- [[Subsystems/Call Scheduling/Canvas/Data Stores/DataStore-OpenSearch|OpenSearch data store]]
