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
> For columns / PKs / FKs, run `kb_table(action=schema)` against the specific table — that's the
> authoritative source.

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

- **Table-level and column-level schemas** within each schema — not captured here; confirm with
  `kb_table(action=schema)`.
- The exact Aurora logical-DB ↔ physical-schema mapping for `recording_consent` — confirm via KB
  before a migration or cross-service change.

## See also

- [[00 - Overview]]
- [[01 - Services & Modules]]
- [[Subsystems/Calendar Ingestion/Storage & Schema Reference]] — lists the `RECORDING_CONSENT` connection from the calendar side
