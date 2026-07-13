---
title: "UC-F4 · Hand Off to Recording"
tags: [call-scheduling, use-case, operational, boundary, recording]
created: 2026-07-13
group: F - Operational
---

# UC-F4 · Hand Off to Recording

> [[04 - Use Cases|← Use Cases hub]] · Group **F — Operational** · prev → [[F3 - Emit Scheduling History]]

The bounded-context boundary: where the Call Scheduler finishes deciding *what* to record and hands the decision to the recording infrastructure that actually captures it.

---

## What this is for

This is the shared exit point for **every** creational and mutating flow — Groups **A–E** all end here. The end user never sees it, but it is the whole point of the module: it is the moment a scheduling decision becomes a recording instruction. The beneficiary is the recording pipeline downstream, and by extension the user who eventually finds the call in their feed.

## What triggers it

The scheduler emits it after any Group A–E decision commits. `CallSchedulingUpdatedProducer` writes to the **`call-scheduling-updated`** topic, keyed by `callId` (cluster `CALL_SCHEDULER_V2`, max request size 20MB to carry large event payloads).

---

## What the Call Scheduler did

```
any scheduling decision (Groups A–E, committed)
  → CallSchedulingUpdatedProducer
      → call-scheduling-updated  (key = callId, cluster CALL_SCHEDULER_V2)
          subtypes:
            · CallSchedulingUpdated
            · CallSchedulingCalendarEventUpdated
            · ManualCallEventUpdated
          each stamped with CallSchedulingCRUDOperation
            (NEW / UPDATE / CANCEL)
```

Keying by `callId` guarantees per-call ordering; the CRUD stamp tells the consumer whether this is a brand-new recording, a change, or a cancellation.

---

## What happens downstream / why it matters

This is where scheduling **ends** and recording infrastructure **begins** — the bounded-context seam. Downstream, the recording pipeline consumes these events and drives capture → transcription → AI. Because every path in the module converges here, the correctness of this single topic is what keeps the whole scheduling → recording contract intact.

## Code map

| | |
|---|---|
| **Producer** | `CallSchedulingUpdatedProducer` |
| **Topic** | `call-scheduling-updated` (key = `callId`) |
| **Cluster** | `CALL_SCHEDULER_V2` (max request 20MB) |
| **Subtypes** | `CallSchedulingUpdated`, `CallSchedulingCalendarEventUpdated`, `ManualCallEventUpdated` |
| **CRUD stamp** | `CallSchedulingCRUDOperation` (NEW / UPDATE / CANCEL) |
| **For whom** | Recording infrastructure (the downstream context) |

## Related

- [[F3 - Emit Scheduling History]]
- [[Subsystems/Call Scheduling/Canvas/Downstream/Recording-Infrastructure|Recording Infrastructure]]
- [[Subsystems/Call Scheduling/Canvas/Outbound Topics/CALL-SCHEDULING-UPDATED|CALL-SCHEDULING-UPDATED]]
- Shared exit for Groups [[A - Schedule/A4 - Manual Schedule|A]], B, C, D, [[E - Recurring/E1 - Schedule Recurring Occurrences|E]]
