---
title: Postgres CREATE INDEX CONCURRENTLY
tags:
  - postgres
  - database
  - index
  - flyway
  - performance
created: 2026-07-23
aliases:
  - concurrently
  - create index concurrently
  - non-blocking index
---

# Postgres CREATE INDEX CONCURRENTLY

> [!note] TL;DR
> `CREATE INDEX CONCURRENTLY` builds an index without blocking reads or writes, at the cost of two full table scans and a longer build time. Required when adding indexes to live production tables. Cannot run inside a transaction — Flyway migrations need `-- flyway:nonTransactional`.

---

## Why it exists

Normal `CREATE INDEX` takes an **AccessExclusiveLock** for the entire build. Nothing can read or write the table until the index is done. Acceptable in dev; unacceptable in production against a live table.

`CONCURRENTLY` trades speed for availability — the table stays fully live throughout.

---

## How it works — the three phases

```
Phase 1: Snapshot scan
  ┌─────────────────────────────────────────────────────┐
  │ Brief ShareUpdateExclusiveLock → record txn horizon │
  │ Full table scan → build initial index version       │
  └─────────────────────────────────────────────────────┘
           ↓ (table open for reads + writes the whole time)
Phase 2: Catch-up scan
  ┌──────────────────────────────────────────────────────────┐
  │ Second full scan → fold in writes that occurred during   │
  │ Phase 1 (tracked in "dead tuple" log)                    │
  └──────────────────────────────────────────────────────────┘
           ↓
Phase 3: Validation wait
  ┌────────────────────────────────────────────────────────────┐
  │ Wait for all transactions that started before Phase 1 to   │
  │ finish → ensures no txn holds a pre-index view of the data │
  │ → marks index VALID                                        │
  └────────────────────────────────────────────────────────────┘
```

---

## Lock profile

| Phase | Lock | Blocks |
|-------|------|--------|
| Phase 1 start | `ShareUpdateExclusiveLock` (brief) | Other `ALTER TABLE`, `VACUUM FULL`, `REINDEX` |
| Scanning | None on rows | Nothing — normal DML proceeds |
| Validation wait | Waits on *old* transactions | Does not block *new* ones |

`ShareUpdateExclusiveLock` only conflicts with schema changes and autovacuum. It does **not** conflict with `SELECT`, `INSERT`, `UPDATE`, or `DELETE`.

---

## Why it can't run in a transaction

Postgres manages its own internal transaction state during the multi-pass build — it needs to observe live MVCC state across multiple snapshots. If `CONCURRENTLY` is wrapped in an explicit transaction (`BEGIN...COMMIT`), Postgres raises:

```
ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block
```

### Flyway implication

Flyway wraps every migration in a transaction by default. To opt out, add this as the **first line** of the migration file:

```sql
-- flyway:nonTransactional
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_my_index
    ON public.my_table (company_id, some_column);
```

The comment must be on line 1 — Flyway reads the directive before executing any SQL.

See [[Flyway Migrations at Gong]] for full Flyway conventions.

---

## The INVALID index risk

If a `CONCURRENTLY` build fails mid-way (OOM, cancellation, crash), Postgres marks the index `INVALID` instead of rolling it back. An invalid index:

- Exists in the catalog and takes disk space
- Is **not used** by the query planner
- Is **not automatically cleaned up**

### Check for invalid indexes

```sql
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
JOIN pg_index USING (indexrelid)
WHERE NOT pg_index.indisvalid;
```

Or check a specific index:

```sql
SELECT indisvalid
FROM pg_index
JOIN pg_class ON pg_class.oid = pg_index.indexrelid
WHERE pg_class.relname = 'idx_my_index';
```

### Recovery

```sql
DROP INDEX CONCURRENTLY idx_my_index;
-- then re-run the CREATE INDEX CONCURRENTLY
```

### Why IF NOT EXISTS isn't a full safeguard here

`IF NOT EXISTS` skips re-creation if the index *name* already exists — even if it's `INVALID`. If you had a failed run that left an invalid index, `IF NOT EXISTS` will silently skip, leaving the broken index in place. Always check `indisvalid` after applying a migration that adds an index.

---

## Performance cost

Two full table scans instead of one, plus the validation wait phase. On a busy table with slow or long-running transactions, validation can stall for minutes. The total wall-clock time is typically 2–4× longer than a regular `CREATE INDEX`.

Rule of thumb: always use `CONCURRENTLY` in production, always skip it in test/dev migrations where table locking is acceptable and you want a faster build.

---

## Real example — GONG-138866

Added `idx_stop_recording_request_company_purge` on `public.stop_recording_request (company_id, call_id)` to fix sequential scans in the company purge DELETE query.

Before/after `EXPLAIN ANALYZE`:

| Metric | Before | After |
|--------|--------|-------|
| Outer scan | `Seq Scan` | `Index Scan` |
| Inner CTE scan | `Seq Scan` | `Index Only Scan` (0 heap fetches) |
| Planning time | 2.513 ms | 0.405 ms (−84%) |
| Execution time | 1.713 ms | 0.078 ms (−95%) |

The inner CTE path upgraded to an **Index Only Scan** — Postgres satisfied the filter and `LIMIT` entirely from the index without touching heap pages.

Migration: `honeyfy/Schema/src/main/resources/operational/db/migration/2026/V20260723_1000__add_stop_recording_request_company_purge_index.sql`

Full investigation notes: [[Jira/GONG-138866-Add Purge Index/GONG-138866-purge index]]

---

## See also

- [[Flyway Migrations at Gong]] — `flyway:nonTransactional`, migration conventions, local dev workflow
- [[Jira/GONG-138866-Add Purge Index/GONG-138866-purge index]] — worked example with full EXPLAIN output
- [[gong-java-cheat-sheet]] — general Postgres/Java patterns at Gong
