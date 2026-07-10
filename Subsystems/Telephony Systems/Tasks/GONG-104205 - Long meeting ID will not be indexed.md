---
jira: GONG-104205
type: Task
priority: P2
status: Selected for Development
team: Telephony / Coms Capture
repo: "⚠️ NOT gong-telephony-systems — calendar ingester (com.honeyfy.ingester.calendar.*)"
module: calendar meetings ingester / meetings indexer
newbie_fit: "★★☆☆☆ — small fix, but in an unfamiliar repo; confirm ownership first"
tags: [telephony, indexing, elasticsearch, calendar, meetings, onboarding]
---

# GONG-104205 — Long meeting ID will not be indexed

**Jira:** https://gongio.atlassian.net/browse/GONG-104205
**Reporter:** Adi Magen · **Created:** 2025-05-27 · **Status:** Selected for Development
**Related (all Done):** [GONG-13745](https://gongio.atlassian.net/browse/GONG-13745), [GONG-103933](https://gongio.atlassian.net/browse/GONG-103933), [GONG-104759](https://gongio.atlassian.net/browse/GONG-104759)

> ⚠️ **READ THIS FIRST — repo mismatch.** This ticket is on the Telephony backlog, but the code it references is **NOT in `gong-telephony-systems`**. The classes named in the ticket —
> - `com.honeyfy.ingester.calendar.core.meetings.CalendarMeetingsProcessor#processMeeting`
> - `com.honeyfy.ingester.calendar.meetingsIndexer.consumer.MeetingUpsertRequestsConsumer#acceptWithResult`
>
> live in the **calendar ingestion / meetings-indexer** codebase (package `com.honeyfy.ingester.calendar.*`), not in this repo. I confirmed `CalendarMeetingsProcessor` and `MeetingUpsertRequestsConsumer` do not exist in `gong-telephony-systems`.
>
> **Before starting, confirm with the team which repo owns this and whether it's even a Telephony task.** It may be mis-tagged, or owned by a calendar/ingestion sub-team. This is the weakest fit of the three candidate tasks for that reason. The conceptual fix below still holds wherever the code lives.

---

## 1. The problem
A calendar meeting arrived with an **ID longer than 512 characters**. Elasticsearch rejects it:

> `_id` is limited to 512 bytes in size and larger values will be rejected.
> — https://www.elastic.co/docs/reference/elasticsearch/mapping-reference/mapping-id-field

So the meeting **silently fails to index** and is missing from search. Example offending id (truncated) from GONG-103933:
`4780464812205727211.8055772089776099321.040000008200E00074C5B7101A82E00807E9051D0000...` — these are Exchange/Outlook calendar UIDs, which can be very long.

## 2. Where it happens (in the calendar ingester repo)
- `CalendarMeetingsProcessor#processMeeting` — processes an incoming meeting.
- `MeetingUpsertRequestsConsumer#acceptWithResult` — Kafka consumer that upserts the meeting into the Elasticsearch meetings index, using the meeting id as the ES `_id`.

The related closed ticket **GONG-104759** ("MeetingUpsertRequestsConsumer accepted meeting to index with too long [id]") suggests a guard was partially added before; this ticket is the proper fix.

## 3. The fix (conceptual — applies wherever the code lives)
The meeting's natural id exceeds ES's 512-byte `_id` limit. Options, in rough order of preference:
1. **Hash/derive a bounded `_id`** when the natural id exceeds the limit — e.g. store the full original id as a normal indexed field, and use a stable hash (SHA-256 → ~64 hex chars) of it as the ES `_id`. Deterministic, so upserts still hit the same document. *(Usually the right answer.)*
2. **Reject + log gracefully** when too long (don't blow up the consumer), if dropping such meetings is acceptable — but that still loses the meeting from search, so #1 is better.

Watch for: the id is used as a **stable upsert key**, so whatever transformation you choose must be **deterministic** (same input → same `_id`) or you'll create duplicates on re-ingest.

## 4. How to verify (in the owning repo)
- [ ] Unit test: a meeting with a >512-byte id is indexed successfully (with the bounded/hashed `_id`), and re-processing the same meeting upserts the **same** document (no duplicate).
- [ ] A normal (short) id still indexes unchanged (no behaviour change for the common case).
- [ ] Consumer no longer logs/throws the "Meeting will not be indexed" warning for long ids.

## 5. Success criteria
1. Meetings with ids > 512 bytes are indexed instead of dropped.
2. Indexing is idempotent (deterministic `_id`).
3. Short-id behaviour unchanged.

## 6. Open questions (resolve before coding)
- **Which repo / team actually owns this?** (Calendar ingester ≠ telephony — confirm this isn't mis-routed.)
- Is the original full id needed for search/lookup? (If yes, store it as a separate field before hashing the `_id`.)
- Was a partial guard already added under GONG-104759? Check current state before duplicating.

**Estimate:** small (~1 day) *once you're in the right repo* — but the repo/ownership question must be settled first.

Related: [[Coms Capture - Telephony Team — Open Backlog]]
