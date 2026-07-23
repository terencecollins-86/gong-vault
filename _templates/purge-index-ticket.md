---
title: "{{TICKET}} — Purge index on {{table}}"
fileClass: purge-index-ticket
type: engineering
status: active
jira: "{{TICKET}}"
jira_url: "https://gongio.atlassian.net/browse/{{TICKET}}"
parent_epic: GONG-131727
workflow_status: todo
pr_url: ""
repo: "{{repo}}"
table: "public.{{table}}"
cssclasses: eng
created: {{date}}
tags: [jira, engineering, postgres, index, purge, {{repo}}, Q1FY27]
---

# 🟦 {{TICKET}} — Purge index on {{table}}

> [!eng] Engineering Context
> **Jira:** [{{TICKET}}](https://gongio.atlassian.net/browse/{{TICKET}}) · Sub-task of [GONG-131727](https://gongio.atlassian.net/browse/GONG-131727)
> **Parent epic:** Audit and fix missing DB indexes for company purge (P1 — Pending Action)
> **Status:** `{{status}}` · **Priority:** `{{priority}}`
> **Assignee:** {{assignee}} · **Reporter:** {{reporter}}
> **Label:** `Q1FY27_Operational_Load`

---

## Problem

`public.{{table}}` is missing a compound index on `(company_id, {{pagination_columns}})` for company purge operations.

Purge queries filter by `company_id`. Without an index this causes:
- Full sequential scans on the full table
- High DB load and lock contention during purge runs
- Paginated purge batches are slow (pagination columns unindexed)

**Purge script:** `gong-purging/PurgeOrchestrator/src/main/resources/sql/CompanyPurge/batched/{{domain}}/tables/{{script_file}}`

```sql
{{purge_query}}
```

**Pagination column(s) = `{{pagination_columns}}`** — {{pagination_explanation}}

---

## Investigation

### EXPLAIN ANALYZE query

Wrapped in a rolled-back transaction — safe to run against any environment; no rows are actually deleted.

```sql
BEGIN;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
{{explain_query}};

ROLLBACK;
```

### Explain Plan — Before Index

```
{{explain_plan_before}}
```

### Findings — Before Index

> [!danger] Index confirmed missing — {{before_summary}}

{{before_findings}}

| Metric | Value |
|--------|-------|
| Scan type | `Seq Scan` ❌ |
| Rows scanned (dev) | {{rows_scanned}} |
| Buffer pages | {{buffers_before}} |
| Planning time | {{planning_before}} |
| Execution time | {{execution_before}} |

**Verdict:** Index is missing. Proceed with the Flyway migration.

---

## Implementation

### Migration file

**Repo:** `honeyfy`
**Path:** `Schema/src/main/resources/operational/db/migration/2026/`
**Filename:** `{{migration_filename}}`

```sql
-- runInTransaction=false
CREATE INDEX CONCURRENTLY IF NOT EXISTS {{index_name}}
    ON public.{{table}} (company_id, {{pagination_columns}});
```

> [!warning] Flyway + CONCURRENTLY
> `CREATE INDEX CONCURRENTLY` cannot run inside a transaction — `-- runInTransaction=false` on line 1 is required. See [[Postgres CREATE INDEX CONCURRENTLY]].

### Explain Plan — After Index

```
{{explain_plan_after}}
```

### Findings — After Index

> [!success] Index working — all acceptance criteria met

{{after_findings}}

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Scan type | `Seq Scan` | `Index Scan` / `Index Only Scan` | ✅ |
| Heap Fetches | — | 0 | ✅ |
| Buffers | {{buffers_before}} | {{buffers_after}} | {{buffers_delta}} |
| Planning time | {{planning_before}} | {{planning_after}} | {{planning_delta}} |
| Execution time | {{execution_before}} | {{execution_after}} | {{execution_delta}} |

**Verdict:** All acceptance criteria satisfied. Migration is ready to ship.

---

## Acceptance Criteria

- [ ] No sequential scan on purge DELETE query
- [ ] Index used by the query planner (`EXPLAIN` confirms `Index Scan`)
- [ ] Index covers `company_id` + pagination column(s)
- [ ] Flyway migration added (non-breaking, `CONCURRENTLY`)
- [ ] Measurable performance improvement noted (before/after `EXPLAIN ANALYZE` costs)

---

## PR

- **Branch:** `{{branch}}`
- **PR:** {{pr_url}}

---

## Notes

- Pagination column(s): **`{{pagination_columns}}`** — confirmed by reading the purge script.
- Migration belongs in **`honeyfy/Schema`** — the `operational` schema is centralised there, not in the owning service repo.
- `CREATE INDEX CONCURRENTLY` cannot run inside a transaction — Flyway migration requires `-- runInTransaction=false` as the first line.
- Part of the broader purge-index audit (GONG-131727) — check sibling sub-tasks for established conventions.

---

## Links & References

- [{{TICKET}}](https://gongio.atlassian.net/browse/{{TICKET}}) — this ticket
- [GONG-131727](https://gongio.atlassian.net/browse/GONG-131727) — parent: Audit and fix missing DB indexes for company purge
- Repo (migration): `honeyfy` — `Schema/src/main/resources/operational/db/migration/2026/`
- Repo (purge script): `gong-purging` — `PurgeOrchestrator/src/main/resources/sql/CompanyPurge/batched/{{domain}}/tables/`
- Table CREATE migration: `{{create_migration}}`

---

## Related Notes

- [[Postgres CREATE INDEX CONCURRENTLY]] — CONCURRENTLY deep-dive, runInTransaction=false, INVALID index risk
- [[Flyway Migrations at Gong]] — Flyway conventions and local dev workflow
- [[Subsystems/_dashboard]]
