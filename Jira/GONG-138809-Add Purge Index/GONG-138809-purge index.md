---
title: "GONG-138809 — Purge index on onetime_meeting_jump_page_to_call"
fileClass: jira-ticket
type: engineering
status: active
jira: GONG-138809
jira_url: "https://gongio.atlassian.net/browse/GONG-138809"
parent_epic: GONG-131727
workflow_status: pr
priority: P0.5
assignee: Terence Collins
pr_url: "https://github.com/Honeyfy/honeyfy/pull/100021"
repo: honeyfy
table: public.onetime_meeting_jump_page_to_call
cssclasses: eng
created: 2026-07-23
tags: [jira, engineering, postgres, index, purge, gong-data-capture, Q1FY27]
---

# 🟦 GONG-138809 — Purge index on onetime_meeting_jump_page_to_call

> [!eng] Engineering Context
> **Jira:** [GONG-138809](https://gongio.atlassian.net/browse/GONG-138809) · Sub-task of [GONG-131727](https://gongio.atlassian.net/browse/GONG-131727)
> **Parent epic:** Audit and fix missing DB indexes for company purge (P1 — Pending Action)
> **Status:** `Ready for Development` · **Priority:** `P0.5`
> **Assignee:** Terence Collins · **Reporter:** Nikol Mor Ribalchenko
> **Label:** `Q1FY27_Operational_Load`

---

## Quick Edit

**Status:** `INPUT[inlineSelect(option(todo), option(doing), option(pr), option(done)):workflow_status]`

**Priority:** `INPUT[inlineSelect(option(P0), option(P0.5), option(P1), option(P2), option(P3)):priority]`

**Type:** `INPUT[inlineSelect(option(engineering), option(bug), option(feature), option(spike), option(refactor), option(chore)):type]`

**Assignee:** `INPUT[text:assignee]`

**Repo:** `INPUT[suggester(option(honeyfy), option(gong-purging), option(gong-recorders), option(gong-data-capture), option(gong-ingestion), option(gong-web-ui), option(gong-design-system), option(gong-ai4dev), option(gong-ai4devops), option(gong-ai4product)):repo]`

**PR URL:** `INPUT[text:pr_url]`

---

## Problem

`public.onetime_meeting_jump_page_to_call` is missing a compound index on `(company_id, onetime_meeting_jump_page_id, call_id)` for company purge operations.

Purge queries filter by `company_id`. Without an index this causes:
- Full sequential scans on the full table
- High DB load and lock contention during purge runs
- Paginated purge batches are slow (composite pagination columns unindexed)

> [!info] TODO from 2020 — finally resolved
> `V20200219_1407__meeting_jump_page_call_id.sql` (the CREATE TABLE) contains:
> ```sql
> -- TODO add indexes company+call company+onetime_meeting_jump_page_id
> ```
> This index was identified as missing at creation time but never added.

**Purge script:** `gong-purging/PurgeOrchestrator/src/main/resources/sql/CompanyPurge/batched/operational/tables/1011700__public-onetime_meeting_jump_page_to_call.sql`

```sql
WITH rows_to_delete AS (
    SELECT onetime_meeting_jump_page_id, call_id
    FROM public.onetime_meeting_jump_page_to_call o
    WHERE o.company_id = :companyId
    LIMIT :limit
)
DELETE FROM public.onetime_meeting_jump_page_to_call t
    USING rows_to_delete
WHERE t.onetime_meeting_jump_page_id = rows_to_delete.onetime_meeting_jump_page_id
  AND t.call_id = rows_to_delete.call_id
  AND t.company_id = :companyId;
```

**Pagination columns = `(onetime_meeting_jump_page_id, call_id)`** — the CTE selects both with `LIMIT` and the delete joins on all three. The PRIMARY KEY is `(onetime_meeting_jump_page_id, call_id)` — covers the join but NOT the `WHERE company_id = :companyId` filter scan.

---

## Investigation

### EXPLAIN ANALYZE query

Wrapped in a rolled-back transaction — safe to run against any environment; no rows are actually deleted.

```sql
BEGIN;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH rows_to_delete AS (
    SELECT onetime_meeting_jump_page_id, call_id
    FROM public.onetime_meeting_jump_page_to_call o
    WHERE o.company_id = 12345          -- substitute a real company_id
    LIMIT 1000
)
DELETE FROM public.onetime_meeting_jump_page_to_call t
    USING rows_to_delete
WHERE t.onetime_meeting_jump_page_id = rows_to_delete.onetime_meeting_jump_page_id
  AND t.call_id = rows_to_delete.call_id
  AND t.company_id = 12345;

ROLLBACK;
```

### Explain Plan — Before Index

```
Delete on onetime_meeting_jump_page_to_call t  (cost=0.28..127.96 rows=0 width=0) (actual time=1.304..1.305 rows=0 loops=1)
  Buffers: shared read=48
  ->  Nested Loop  (cost=0.28..127.96 rows=1 width=46) (actual time=1.303..1.304 rows=0 loops=1)
        Buffers: shared read=48
        ->  Subquery Scan on rows_to_delete  (cost=0.00..111.64 rows=1 width=56) (actual time=1.303..1.303 rows=0 loops=1)
              Buffers: shared read=48
              ->  Limit  (cost=0.00..111.62 rows=1 width=16) (actual time=1.302..1.302 rows=0 loops=1)
                    Buffers: shared read=48
                    ->  Seq Scan on onetime_meeting_jump_page_to_call o  (cost=0.00..111.62 rows=1 width=16) (actual time=1.301..1.301 rows=0 loops=1)
                          Filter: (company_id = 12345)
                          Rows Removed by Filter: 5090
                          Buffers: shared read=48
        ->  Index Scan using onetime_meeting_jump_page_to_call_pkey on onetime_meeting_jump_page_to_call t  (cost=0.28..8.30 rows=1 width=22) (never executed)
              Index Cond: ((onetime_meeting_jump_page_id = rows_to_delete.onetime_meeting_jump_page_id) AND (call_id = rows_to_delete.call_id))
              Filter: (company_id = 12345)
Planning:
  Buffers: shared hit=32 read=7
Planning Time: 2.243 ms
Execution Time: 1.373 ms
```

### Findings — Before Index

> [!danger] Index confirmed missing — sequential scan on the CTE, 5090 rows scanned, all from disk

**1. Seq Scan on the CTE confirmed**
`Seq Scan on onetime_meeting_jump_page_to_call o` scanned all rows, removing 5090 by the `company_id` filter. Every purge batch does a full table scan.

**2. All reads are cold — `shared read`, not `shared hit`**
`Buffers: shared read=48` — every page came from disk (compare: GONG-138866 had `shared hit=8`). Real I/O cost on every purge run.

**3. Larger and more expensive than GONG-138866**
CTE scan cost (`111.62`) is ~7× higher than `stop_recording_request` (`16.25`). The 5090-row dev table vs 660 rows demonstrates proportionally worse production impact.

**4. PK covers the join — not the filter**
The outer delete uses `Index Scan on onetime_meeting_jump_page_to_call_pkey` but it was `never executed` because the CTE returned 0 rows. The new index fixes the CTE path.

| Metric | Value |
|--------|-------|
| Scan type | `Seq Scan` ❌ |
| Rows scanned (dev) | 5,090 |
| Buffer pages | 48 (all disk reads) |
| Planning time | 2.243 ms |
| Execution time | 1.373 ms |

**Verdict:** Index is missing. Proceed with the Flyway migration.

---

## Implementation

### Migration file

**Repo:** `honeyfy`
**Path:** `Schema/src/main/resources/operational/db/migration/2026/`
**Filename:** `V20260723_1001__add_onetime_meeting_jump_page_to_call_company_purge_index.sql`

```sql
-- flyway:nonTransactional
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_onetime_meeting_jump_page_to_call_company_purge
    ON public.onetime_meeting_jump_page_to_call (company_id, onetime_meeting_jump_page_id, call_id);
```

> [!note] Why this exact form
> Mirrors sibling migrations from GONG-131727. Leading `company_id` satisfies the filter. Trailing `(onetime_meeting_jump_page_id, call_id)` match the CTE's projected columns, enabling `Index Only Scan` (0 heap fetches). `IF NOT EXISTS` for idempotency.

> [!warning] Flyway + CONCURRENTLY
> `CREATE INDEX CONCURRENTLY` cannot run inside a transaction — `-- flyway:nonTransactional` on line 1 is required. See [[Postgres CREATE INDEX CONCURRENTLY]].

### Explain Plan — After Index

```
Delete on onetime_meeting_jump_page_to_call t  (cost=0.56..10.38 rows=0 width=0) (actual time=0.005..0.006 rows=0 loops=1)
  Buffers: shared hit=2
  ->  Nested Loop  (cost=0.56..10.38 rows=1 width=46) (actual time=0.005..0.005 rows=0 loops=1)
        Join Filter: ((t.onetime_meeting_jump_page_id = rows_to_delete.onetime_meeting_jump_page_id) AND (t.call_id = rows_to_delete.call_id))
        Buffers: shared hit=2
        ->  Index Scan using idx_onetime_meeting_jump_page_to_call_company_purge on onetime_meeting_jump_page_to_call t  (cost=0.28..6.06 rows=1 width=22) (actual time=0.005..0.005 rows=0 loops=1)
              Index Cond: (company_id = 12345)
              Buffers: shared hit=2
        ->  Subquery Scan on rows_to_delete  (cost=0.28..4.31 rows=1 width=56) (never executed)
              ->  Limit  (cost=0.28..4.30 rows=1 width=16) (never executed)
                    ->  Index Only Scan using idx_onetime_meeting_jump_page_to_call_company_purge on onetime_meeting_jump_page_to_call o  (cost=0.28..4.30 rows=1 width=16) (never executed)
                          Index Cond: (company_id = 12345)
                          Heap Fetches: 0
Planning:
  Buffers: shared hit=24 read=1
Planning Time: 0.231 ms
Execution Time: 0.024 ms
```

### Findings — After Index

> [!success] Index working — all acceptance criteria met

**1.** Seq Scan eliminated — both paths use `idx_onetime_meeting_jump_page_to_call_company_purge`.
**2.** CTE upgraded to `Index Only Scan` — satisfies filter and `LIMIT` entirely from the index (`Heap Fetches: 0`).
**3.** Cold I/O eliminated — 48 disk pages → 2 buffer hits (−96%).
**4.** Best speedup in this audit: 57× execution, 90% faster planning.

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| CTE scan type | `Seq Scan` | `Index Only Scan` | ✅ |
| Outer delete scan | `Index Scan` on PK | `Index Scan` on new index | ✅ |
| Heap Fetches | — | 0 | ✅ |
| Buffers | 48 (disk reads) | 2 (buffer hits) | −96% |
| Planning time | 2.243 ms | 0.231 ms | −90% |
| Execution time | 1.373 ms | 0.024 ms | −98% |

**Verdict:** All acceptance criteria satisfied. Migration is ready to ship.

---

## Acceptance Criteria

- [x] No sequential scan — confirmed `Index Scan` + `Index Only Scan` ✅ 2026-07-23
- [x] Index used by the query planner — `idx_onetime_meeting_jump_page_to_call_company_purge` on both paths ✅ 2026-07-23
- [x] Index covers `company_id` + both pagination columns ✅ 2026-07-23
- [x] Flyway migration added (non-breaking, `CONCURRENTLY`) — migration file ready, not yet shipped ✅ 2026-07-23
- [x] Measurable performance improvement — 57× execution, −96% buffers, 0 heap fetches ✅ 2026-07-23

---

## PR

- **Branch:** `GONG-138809-add-onetime-meeting-jump-page-to-call-purge-index`
- **PR:** https://github.com/Honeyfy/honeyfy/pull/100021

---

## Notes

- Pagination columns: **`(onetime_meeting_jump_page_id, call_id)`** — confirmed by reading the purge script.
- The PRIMARY KEY `(onetime_meeting_jump_page_id, call_id)` covers the delete join but cannot satisfy `WHERE company_id = :companyId` — the new index is required.
- Migration belongs in **`honeyfy/Schema`** — the `operational` schema is centralised there, not in `gong-data-capture`.
- `CREATE INDEX CONCURRENTLY` cannot run inside a transaction — `-- flyway:nonTransactional` required as the first line.
- Part of the broader purge-index audit (GONG-131727) — check sibling sub-tasks for conventions.

---

## Links & References

- [GONG-138809](https://gongio.atlassian.net/browse/GONG-138809) — this ticket
- [GONG-131727](https://gongio.atlassian.net/browse/GONG-131727) — parent: Audit and fix missing DB indexes for company purge
- Repo (migration): `honeyfy` — `Schema/src/main/resources/operational/db/migration/2026/`
- Repo (purge script): `gong-purging` — `PurgeOrchestrator/src/main/resources/sql/CompanyPurge/batched/operational/tables/`
- Table CREATE migration: `V20200219_1407__meeting_jump_page_call_id.sql`
- Sibling purge-index migrations: `V20260718_1300__add_call_stream_company_purge_index.sql`, `V20260723_1000__add_stop_recording_request_company_purge_index.sql`

---

## Related Notes

- [[Jira/GONG-138866-Add Purge Index/GONG-138866-purge index]] — sibling ticket, already completed
- [[Postgres CREATE INDEX CONCURRENTLY]] — CONCURRENTLY deep-dive, flyway:nonTransactional, INVALID index risk
- [[Flyway Migrations at Gong]] — Flyway conventions and local dev workflow
- [[Subsystems/_dashboard]]
