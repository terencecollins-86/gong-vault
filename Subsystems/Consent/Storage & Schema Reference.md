---
title: Consent — Storage & Schema Reference
tags: [consent, recording-consent, storage, database, postgres, schema]
created: 2026-07-09
---

# Storage & Schema Reference

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · [[01 - Services & Modules]]

The datastore recording consent owns. Consent state persists in the **`recording_consent`**
Postgres database, split across three schemas.

> [!note]
> This is a **subsystem inventory** captured from the breakdown, not a column-level schema dump.
> Column-level DDL (columns / types / PKs / indexes) for every owned table is now captured in
> [[09 - Schema Reference (columns)]]. For anything not there, run `kb_table(action=schema)`.

---

## `recording_consent` database — schemas

| Schema | Owns |
|---|---|
| **`recording_consent_email`** | Consent email state (pre-call consent emails driven by `RecordingConsentTasks` / `ConsentEmailSender`). |
| **`recording_consent_settings`** | Consent settings (backing the DCP consent settings API — `RecordingConsentApiServer` / `DcpConsentSettingsController`, and per-user `DcpAppUserConsentService`). |
| **`recording_compliance`** | Recording compliance state. |

> Other Gong services (including [[Subsystems/Calendar Ingestion/_dashboard|Calendar Ingestion]]) *connect to* a
> `RECORDING_CONSENT` logical DB — see the calendar [[Subsystems/Calendar Ingestion/Storage & Schema Reference]],
> which lists `RECORDING_CONSENT` as an RW Aurora connection. Consent is the **owner** of that data.

---

## What I did not verify

- The exact Aurora logical-DB ↔ physical-schema mapping for `recording_consent` — confirm via KB
  before a migration or cross-service change.

> Table-level and column-level schemas are now captured in [[09 - Schema Reference (columns)]]
> (verified against Flyway migrations, 2026-07-22).

## See also

- [[00 - Overview]]
- [[01 - Services & Modules]]
- [[09 - Schema Reference (columns)]] — column-level DDL for every owned table
- [[05 - Data Access & Storage]] — datasource / DAO / schema map
- [[Subsystems/Calendar Ingestion/Storage & Schema Reference]] — lists the `RECORDING_CONSENT` connection from the calendar side
