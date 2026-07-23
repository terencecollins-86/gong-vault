---
title: "GONG-138866 — Purge index on stop_recording_request"
fileClass: purge-index-ticket
type: engineering
status: active
jira: GONG-138866
jira_url: "https://gongio.atlassian.net/browse/GONG-138866"
parent_epic: GONG-131727
workflow_status: pr
pr_url: "https://github.com/Honeyfy/honeyfy/pull/100018"
repo: honeyfy
table: public.stop_recording_request
cssclasses: eng
created: 2026-07-23
tags: [jira, engineering, postgres, index, purge, gong-recorders, Q1FY27]
---

# 🟦 GONG-138866 — Purge index on stop_recording_request

> [!eng] Engineering Context
> **Jira:** [GONG-138866](https://gongio.atlassian.net/browse/GONG-138866) · Sub-task of [GONG-131727](https://gongio.atlassian.net/browse/GONG-131727)
> **Parent epic:** Audit and fix missing DB indexes for company purge (P1 — Pending Action)
> **Status:** `Ready for Development` · **Priority:** `P0.5`
> **Assignee:** Terence Collins · **Reporter:** Nikol Mor Ribalchenko
> **Label:** `Q1FY27_Operational_Load`

---

## Problem

`public.stop_recording_request` is missing a compound index on `(company_id, call_id)` for company purge operations.

Purge queries filter by `company_id`. Without an index this causes:
- Full sequential scans on the full table
- High DB load and lock contention during purge runs
- Paginated purge batches are slow (`call_id`-based pagination unindexed)

**Purge script:** `gong-purging/PurgeOrchestrator/src/main/resources/sql/CompanyPurge/batched/operational/tables/1028500__public-stop_recording_request.sql`

```sql
WITH rows_to_delete AS (
    SELECT call_id
    FROM public.stop_recording_request srr
    WHERE srr.company_id = :companyId
    LIMIT :limit
)
DELETE FROM public.stop_recording_request t
    USING rows_to_delete
WHERE t.call_id = rows_to_delete.call_id
  AND t.company_id = :companyId;
```

**Pagination column = `call_id`** — the CTE selects a batch of `call_id`s for a given `company_id` (via `LIMIT`), then deletes by matching both. `call_id` is the table's PRIMARY KEY (confirmed in `V20220403_1620__create_stop_recording_request_table.sql`).

---

## Investigation

### EXPLAIN ANALYZE query

Wrapped in a rolled-back transaction — safe to run against any environment; no rows are actually deleted.

```sql
BEGIN;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH rows_to_delete AS (
    SELECT call_id
    FROM public.stop_recording_request srr
    WHERE srr.company_id = 12345          -- substitute a real company_id
    LIMIT 1000                            -- matches default purge batch size
)
DELETE FROM public.stop_recording_request t
    USING rows_to_delete
WHERE t.call_id = rows_to_delete.call_id
  AND t.company_id = 12345;

ROLLBACK;
```

### Explain Plan — Before Index

```
Delete on stop_recording_request t  (cost=0.00..32.52 rows=0 width=0) (actual time=0.056..0.056 rows=0 loops=1)
  Buffers: shared hit=8
  ->  Nested Loop  (cost=0.00..32.52 rows=1 width=38) (actual time=0.055..0.056 rows=0 loops=1)
        Join Filter: (t.call_id = rows_to_delete.call_id)
        Buffers: shared hit=8
        ->  Seq Scan on stop_recording_request t  (cost=0.00..16.25 rows=1 width=14) (actual time=0.055..0.055 rows=0 loops=1)
              Filter: (company_id = 12345)
              Rows Removed by Filter: 660
              Buffers: shared hit=8
        ->  Subquery Scan on rows_to_delete  (cost=0.00..16.26 rows=1 width=40) (never executed)
              ->  Limit  (cost=0.00..16.25 rows=1 width=8) (never executed)
                    ->  Seq Scan on stop_recording_request srr  (cost=0.00..16.25 rows=1 width=8) (never executed)
                          Filter: (company_id = 12345)
Planning:
  Buffers: shared hit=182 read=9
Planning Time: 2.513 ms
Execution Time: 1.713 ms
```

### Findings — Before Index

> [!danger] Index confirmed missing — sequential scans on both paths

**1. Two `Seq Scan` nodes, zero index usage**
Both the outer delete (`t`) and the inner CTE (`srr`) hit the table with a full sequential scan. No index is being used.

**2. Dev table is small (660 rows) but cost scales linearly**
The outer scan read all 660 rows to find 0 matches. In production, the planner does the same scan against a far larger row count — O(table size) per batch.

**3. CTE inner scan was never executed**
Because `company_id = 12345` matched 0 rows on the outer scan, the `rows_to_delete` subquery was short-circuited. The plan understates the true cost — in a real purge run both seq scans execute in full.

**4. Join strategy: Nested Loop with post-scan filter**
Without an index, Postgres applies the `call_id` match as a filter after the full scan rather than an index seek.

| Metric | Value |
|--------|-------|
| Scan type | `Seq Scan` ❌ |
| Rows scanned (dev) | 660 |
| Buffer pages | 8 (shared hit) |
| Planning time | 2.513 ms |
| Execution time | 1.713 ms |

**Verdict:** Index is missing. Proceed with the Flyway migration.

---

## Implementation

### Migration file

**Repo:** `honeyfy`
**Path:** `Schema/src/main/resources/operational/db/migration/2026/`
**Filename:** `V20260723_1000__add_stop_recording_request_company_purge_index.sql`

```sql
-- runInTransaction=false
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stop_recording_request_company_purge
    ON public.stop_recording_request (company_id, call_id);
```

> [!note] Why this exact form
> Mirrors sibling migration `V20260718_1300__add_call_stream_company_purge_index.sql` (same parent epic GONG-131727). `IF NOT EXISTS` for idempotency. `call_id` is the PK — the composite index lets Postgres satisfy `WHERE company_id = :companyId LIMIT :limit` with an index range scan.

> [!warning] Flyway + CONCURRENTLY
> `CREATE INDEX CONCURRENTLY` cannot run inside a transaction — `-- runInTransaction=false` on line 1 is required. See [[Postgres CREATE INDEX CONCURRENTLY]].

### Explain Plan — After Index

```
Delete on stop_recording_request t  (cost=0.55..16.61 rows=0 width=0) (actual time=0.031..0.032 rows=0 loops=1)
  Buffers: shared hit=5
  ->  Nested Loop  (cost=0.55..16.61 rows=1 width=38) (actual time=0.030..0.031 rows=0 loops=1)
        Join Filter: (t.call_id = rows_to_delete.call_id)
        Buffers: shared hit=5
        ->  Index Scan using idx_stop_recording_request_company_purge on stop_recording_request t  (cost=0.28..8.29 rows=1 width=14) (actual time=0.029..0.030 rows=0 loops=1)
              Index Cond: (company_id = 12345)
              Buffers: shared hit=5
        ->  Subquery Scan on rows_to_delete  (cost=0.28..8.30 rows=1 width=40) (never executed)
              ->  Limit  (cost=0.28..8.29 rows=1 width=8) (never executed)
                    ->  Index Only Scan using idx_stop_recording_request_company_purge on stop_recording_request srr  (cost=0.28..8.29 rows=1 width=8) (never executed)
                          Index Cond: (company_id = 12345)
                          Heap Fetches: 0
Planning:
  Buffers: shared hit=24 read=1
Planning Time: 0.405 ms
Execution Time: 0.078 ms
```

### Findings — After Index

> [!success] Index working — all acceptance criteria met

**1.** Both paths now use `idx_stop_recording_request_company_purge` — no `Seq Scan` nodes remain.
**2.** CTE upgraded to `Index Only Scan` — Postgres satisfies the filter and `LIMIT` entirely from the index (`Heap Fetches: 0`).
**3.** Buffer reads dropped 38% (8 → 5) on the dev table; saves scale with production row count.
**4.** Execution improved 22×; planning improved 6×.

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Outer scan type | `Seq Scan` | `Index Scan` | ✅ |
| Inner scan type | `Seq Scan` | `Index Only Scan` | ✅ |
| Heap Fetches | — | 0 | ✅ |
| Buffers | 8 (hit) | 5 (hit) | −38% |
| Planning time | 2.513 ms | 0.405 ms | −84% |
| Execution time | 1.713 ms | 0.078 ms | −95% |

**Verdict:** All acceptance criteria satisfied. Migration is ready to ship.

---

## Acceptance Criteria

- [x] No sequential scan — confirmed `Index Scan` + `Index Only Scan`
- [x] Index used by the query planner — `idx_stop_recording_request_company_purge` on both paths
- [x] Index covers `company_id` + pagination column (`call_id`)
- [ ] Flyway migration added (non-breaking, `CONCURRENTLY`) — migration file ready, not yet shipped
- [x] Measurable performance improvement — 22× execution, −84% planning, 0 heap fetches

---

## PR

- **Branch:** `GONG-138866-add-stop-recording-request-purge-index`
- **PR:** https://github.com/Honeyfy/honeyfy/pull/100018

---

## Notes

- Migration belongs in **`honeyfy/Schema`** — the `operational` schema is centralised there (the ticket says gong-recorders; that is incorrect).
- `call_id` is the table's PRIMARY KEY — confirmed in `V20220403_1620__create_stop_recording_request_table.sql`.
- `CREATE INDEX CONCURRENTLY` cannot run inside a transaction — `-- runInTransaction=false` required as the first line.
- Part of the broader purge-index audit (GONG-131727) — check sibling sub-tasks for conventions.

---

## Links & References

- [GONG-138866](https://gongio.atlassian.net/browse/GONG-138866) — this ticket
- [GONG-131727](https://gongio.atlassian.net/browse/GONG-131727) — parent: Audit and fix missing DB indexes for company purge
- Repo (migration): `honeyfy` — `Schema/src/main/resources/operational/db/migration/2026/`
- Repo (purge script): `gong-purging` — `PurgeOrchestrator/src/main/resources/sql/CompanyPurge/batched/operational/tables/`
- Table CREATE migration: `V20220403_1620__create_stop_recording_request_table.sql`
- Sibling purge-index migration: `V20260718_1300__add_call_stream_company_purge_index.sql`

---

## Related Notes

- [[Jira/GONG-138809-Add Purge Index/GONG-138809-purge index]] — sibling ticket, same pattern
- [[Postgres CREATE INDEX CONCURRENTLY]] — CONCURRENTLY deep-dive, runInTransaction=false, INVALID index risk
- [[Flyway Migrations at Gong]] — Flyway conventions and local dev workflow
- [[Subsystems/_dashboard]]
