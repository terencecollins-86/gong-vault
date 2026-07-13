---
title: "UC-E1 · Orchestrate a DCP Change Request"
tags: [consent, use-case, propagate, orchestration]
created: 2026-07-13
group: E - Propagate
---

# UC-E1 · Orchestrate a DCP Change Request

> [[04 - Use Cases|← Use Cases hub]] · Group **E — Propagate** · next → [[E2 - Run Change Action]]

An admin change to the DCP policy fans out across all affected users via a state machine.

---

## What this is for

Making one policy change reach every affected user reliably. When a compliance admin edits the Data Compliance Policy (DCP), the change must propagate to every impacted user and their calls without dropping anyone — this orchestration guarantees that fan-out.

## What triggers it

An admin change to the DCP.

---

## What the Consent module did

```
Admin changes DCP
  → DcpChangeActionsOrchestrator
       ├─ DcpBatchUserChangeActionOrchestrator
       └─ DcpSingleUserChangeActionOrchestrator
  → runs ChangeRequestLifecycle (keyed by changeRequestId)
  → emits DcpChangeRequestEvent
       → batch-users-change-executor   (BatchUsersChangeExecutorConsumer)
       → single-user-change-executor   (SingleUserChangeExecutorConsumer)
  → on completion: DcpUserChangeRequestDoneEvent
       → single-user-change-request-done (SingleUserChangeRequestDoneConsumer)
  Consumers back onto DcpChangeManager; state via DcpChangeManagerDao
```

---

## What happens downstream / why it matters

Each affected user gets a concrete change action dispatched (see UC-E2). The lifecycle, keyed by `changeRequestId`, makes the fan-out resumable and auditable so a partial failure does not leave users on a stale policy.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Admin DCP change |
| **Command / process** | `DcpChangeActionsOrchestrator` → `ChangeRequestLifecycle` |
| **Event / topic** | `DcpChangeRequestEvent` / `batch-users-change-executor`, `single-user-change-executor` |
| **State / audit** | `DcpChangeManagerDao` change-request tables |

## Related

[[E2 - Run Change Action]] · [[D - Configure/D1 - Read Write DCP Settings|UC-D1]]
