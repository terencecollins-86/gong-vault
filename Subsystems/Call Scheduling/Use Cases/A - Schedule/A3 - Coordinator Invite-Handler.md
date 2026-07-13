---
title: "UC-A3 · Schedule from a Coordinator / Invite-Handler Email"
tags: [call-scheduling, use-case, schedule, invite-handler, email, gge]
created: 2026-07-13
group: A - Schedule
mechanism: COORDINATOR_EMAIL / CALENDAR_SYNC_EMAIL
resolution: NEW_CALL
crud: NEW
---

# UC-A3 · Schedule from a Coordinator / Invite-Handler Email

> [[04 - Use Cases|← Use Cases hub]] · Group **A — Schedule** · prev → [[A2 - Opt-In Email Invite]] · next → [[A4 - Manual Schedule]]

The out-of-band email path: an invite reaches Gong by email rather than through the calendar sync — often via a scheduling coordinator or a per-user invite-handler address.

> **Vocabulary caution:** `CALENDAR_SYNC_EMAIL` here means the **invite-handler** (`isInviteHandler()`), *not* the calendar-sync feed. See the jargon table in [[03 - Ubiquitous Language]].

---

## What the user wanted

*"Our meeting coordinator books calls on behalf of reps. When they send the invite, Gong should pick it up and record it — even though it didn't come through a rep's own calendar sync."*

## What the user did

1. A **coordinator** (or automated scheduler) created the meeting and sent the invite
2. The invite was addressed to a Gong **invite-handler address** for the company

---

## What fired the event

1. The email hits **InviteHandlerWebhooksServer** (or **GlobalInviteHandlerWebhooksServer** for GGE)
2. `EmailHandlerService#handle` validates and normalizes the invite
3. Routed via `getGenericFlowHandler` / `getTenantFlowHandler`
4. If from GGE, `GlobalInviteHandlerWebhooksController` resolves the cell from the recipient and **forwards raw to the correct GPE cell**
5. Produces a `CallSchedulingRequest` back onto **`call-scheduling-requests`** — **rejoining the UC-A1 engine path**

---

## What the Call Scheduler did

Once the request is on `call-scheduling-requests`, processing is **identical to [[A1 - Calendar Sync Schedule|UC-A1]]** — the same consumer, validation chain, and `NEW_CALL` resolution. This use case is distinct only in *how the request is produced* (email ingestion + GGE→GPE bridge), not in how it's scheduled.

---

## What happens downstream

Identical to UC-A1: `call-scheduling-updated` → recording infrastructure → capture → transcription + AI.

## What the user sees

The rep whose call was booked sees the recording appear in their Gong feed after the meeting — even though they never touched the invite.

---

## Code map

| | |
|---|---|
| **Mechanism** | `COORDINATOR_EMAIL` or `CALENDAR_SYNC_EMAIL` (`isInviteHandler()`) |
| **Command** | `EmailHandlerService#handle` → produce `CallSchedulingRequest` (rejoins A1) |
| **GGE bridge** | `GlobalInviteHandlerWebhooksController` (GGE → GPE forward) |
| **Resolution** | (rejoins A1) `NEW_CALL` |

## Related

- [[A1 - Calendar Sync Schedule]] — the engine path this rejoins
- [[02 - Entry Points (Inbound & Outbound)]] — the InviteHandler / GGE plumbing
