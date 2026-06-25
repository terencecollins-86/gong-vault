---
title: Calendar Ingestion — Troubleshooting Endpoints Catalog & Gaps
tags: [calendar-ingestion, troubleshooting, runbook, endpoints, gaps]
created: 2026-06-25
---

# Troubleshooting Endpoints Catalog & Gaps

> [[_dashboard|← Team Hub]] · [[Swagger Trigger Runbook]] · [[System Diagram]] · [[02 - Data Flows]]

Every `/troubleshooting/**` endpoint in **IngesterCalendarSupervisor**, what it does, and — at the
bottom — the system paths that have **no** troubleshooting surface. All 18 controllers were read from
source; paths/params are verbatim. **All HTTP lives on the Supervisor (`:8885`)** — the provider
ingesters and MeetingsIndexer expose only a Swagger redirect.

> ⚠️ Two cross-cutting quirks (verified): provider param name is inconsistent (`mailboxProviderCode`
> vs `providerCode` vs `provider`), and some param names contain **literal spaces** (`calendar provider`,
> `scan window hours`) — URL-encode them. The `/sync/*` paths have a real **double slash**.

---

## 1. Import / sync — *make data flow now*

### `TroubleshootingCalendarEventsApiController` — tag `troubleshooting-calendar-events-api`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting//sync/company` | Re-import a whole company's calendars (synchronous fan-out for one company) |
| POST | `/troubleshooting//sync/user` | Re-import one user's calendar by email |

### `TroubleshootingCalendarKafkaMessages` — tag `troubleshooting-calendar-kafka`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting/calendar-import/user` | Produce a per-user `ImportCommand` with full control (scan window, azure user, admin user, company-connection flag) |
| POST | `/troubleshooting/calendar-import/company` | Produce a company-level import command |

---

## 2. Backfill — *historical re-processing & backfill-task admin*

### `TroubleshootingCalendarMeetingsBackfill` — tag `troubleshooting-calendar-meetings-backfill`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting/calendar-meetings-backfill/user` | Backfill meetings for user(s) over a date range (mode-driven) |
| POST | `/troubleshooting/calendar-meetings-snowflake/backfill-types-by-list` | Backfill meeting *types* to Snowflake for a company list (multi-threaded) |
| POST | `/troubleshooting/calendar-meetings-snowflake/backfill-types-by-db` | Backfill meeting types to Snowflake by DB batch |
| POST | `/troubleshooting/calendar-meetings-backfill/get-by-company` | Read backfill tasks for companies |
| POST | `/troubleshooting/calendar-meetings-backfill/get-by-state` | Read backfill tasks by state |
| POST | `/troubleshooting/calendar-meetings-backfill/set-state-by-user` | Force backfill-task state for users |
| POST | `/troubleshooting/calendar-meetings-backfill/delete-by-user` | Delete backfill tasks for users |
| POST | `/troubleshooting/calendar-meetings-backfill/delete-by-company` | Delete backfill tasks for companies |
| POST | `/troubleshooting/calendar-meetings-backfill/reset-failed-users` | Reset FAILED backfill tasks to retry |

---

## 3. Provider live-query — *read straight from Google / Microsoft, bypassing our store*

### `TroubleshootingGoogleCalendar` — tag `troubleshooting-google-calendar`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting/google-calendar/read-raw-events` | Read raw Google events for a user (optionally secondary calendars) |
| POST | `/troubleshooting/google-calendar/query/authenticating-user` | Resolve the authenticating (surrogate) user |
| POST | `/troubleshooting/google-calendar/query/person` | Query a Google Person record |
| POST | `/query/user/calendars` | List a user's Google calendars |
| POST | `/query/user/secondary-calendar-ids` | List a user's secondary calendar ids |
| POST | `/query/user/converted-events` | Show events *after* our conversion logic |
| POST | `/troubleshooting/update-import-company-non-recorded-meetings` | Toggle "import non-recorded meetings" for companies |

### `TroubleshootingOffice365Integration` — base `/troubleshooting/office365/integration`
| Method | Path | Action |
|---|---|---|
| GET | `/company/groups/` | List Azure groups for company |
| GET | `/company/users/` | List Azure users for company |
| GET | `/company/shared-calendars/` | List shared calendars |
| POST | `/company/user/add` | Manually add an Azure user mapping |
| POST | `/company/users/update` | Force Azure user-list refresh (same work as `UpdateAzureUsersTask`) |
| POST | `/user/fill-company-ids-in-appuser-sync-status` | Backfill companyId into sync-status rows |
| POST | `/user/fill-company-ids-in-appuser-settings` | Backfill companyId into settings rows |
| POST | `/troubleshooting/update-import-company-non-recorded-meetings` | Toggle non-recorded import (Office variant) |
| GET | `/user/groups` | List a user's groups |
| GET | `/user/group/events` | List events for a user's group |
| GET | `/user/event` / `/user/event-as-string` | Read one calendar event (object / raw string) |
| GET | `/user/events` / `/company/user/events` | List a user's events (by email / by appUserId) |
| GET | `/user/calendars` / `/company/user/calendars` | List a user's calendars (by email / via company) |
| GET | `/user` / `/user/photo` | Find user / fetch user photo |
| GET | `/company/organization` | Read the Azure org |
| POST | `/user/reset-issues` | Reset a user's integration-issue counter |
| POST | `/user/disconnect` | Disconnect a user's Office integration |

---

## 4. Re-processing & deletion via ICS API

### `TroubleshootingIcsApiClient` — base `/troubleshooting/ics-api-client`
| Method | Path | Action |
|---|---|---|
| POST | `/reprocess-company-scheduled-calls` | Re-run scheduled-call processing for a company |
| POST | `/reprocess-user-scheduled-calls` | Re-run scheduled-call processing for users |
| POST | `/reprocess-meetings-by-meeting-id` | Re-process specific meetings |
| POST | `/reprocess-meetings-by-provider-event-id` | Re-process meetings by provider event id |
| POST | `/async-delete-meetings` | Async-delete meetings by id |
| POST | `/permanently-delete-meeting` | Hard-delete one meeting |
| GET | `/is-calendar-import-enabled-for-user` | Check import-enabled flag |
| GET | `/find-appuser-mappings-by-address` | Resolve email → app-user mappings |
| GET | `/is-admin-fallback-enabled-for-company` | Read admin-fallback flag |
| POST | `/disable-admin-fallback-for-company` | Disable admin fallback |

---

## 5. Store maintenance — *mirror cache, OpenSearch, event-history, hashes*

### `TroubleshootingCalendarEventsDeletion` — base `/troubleshooting`
| Method | Path | Action |
|---|---|---|
| DELETE | `calendar-all-events-mirror-deletion/company` | Delete a company's all-events mirror cache |
| DELETE | `calendar-all-meetings-mirror-deletion/company` | Delete a company's all-meetings mirror cache |
| GET | `calendar-all-events-mirror-count/user` | Count a user's mirror entries (organizer/invitee) |
| DELETE | `calendar-all-events-mirror-deletion/user` | Delete a user's mirror entries |
| DELETE | `calendar-ES-deletion/company` | Delete a company's future meetings from OpenSearch |
| GET | `calendar-ES-deletion/user` | **Count** matching user meetings in OpenSearch (dry-run) |
| DELETE | `calendar-ES-deletion/user` | Delete user meetings from OpenSearch (role / recording-status / opp / account filters) |

### `TroubleshootingEventCacheController` — tag `troubleshooting-calendar-mirror`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting/calendar-mirror/search` | Search the event mirror cache for a user |
| POST | `/troubleshooting/calendar-mirror/delete` | Delete mirror cache for companies |
| POST | `/troubleshooting/calendar-mirror/purge` | ⚠️ **Cross-tenant purge — flagged UNSAFE in code** |
| POST | `/troubleshooting/calendar-mirror/reprocess` | Reprocess mirror entries by last-updated time range |

### `TroubleshootingAllEventsCacheController` — tag `troubleshooting-calendar-all-events-mirror`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting/calendar-all-events-mirror/delete` | Clear all-events cache for a company |
| POST | `/troubleshooting/calendar-all-events-mirror/delete-list` | Clear all-events cache for a company list |

### `TroubleshootingAllEventsMeetings` — base `/troubleshooting/allEventsMeetings`
| Method | Path | Action |
|---|---|---|
| POST | `/add-call-id-to-meetings-during-time-range` | Attach call-ids to meetings in a window |
| POST | `/fix-meeting-with-appuser-and-unclassified-affiliation-by-id` | Repair affiliation for one meeting |
| POST | `/fix-meetings-with-appuser-and-unclassified-affiliation` | Bulk-repair affiliation for companies |
| POST | `/change-meetings-workspace-id` | Move meetings between workspaces (batched, multipart) |

### `TroubleshootingEventHistoryController` — tag `troubleshooting-event-history`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting/event-history/delete` | Delete event history older than a timestamp |
| POST | `/troubleshooting/event-history/get-events-for-user` | Export a user's event history |
| POST | `/troubleshooting/event-history/get-events-for-company` | Export a company's event history (CSV) |
| POST | `/troubleshooting/event-history/get-call-events-for-company` | Export call events by call-id (CSV) |

### `TroubleshootingCalendarEventsHash` — base `/troubleshooting/calendarEventsHash`
| Method | Path | Action |
|---|---|---|
| POST | `/all-events-add-hash-field-event` | Add hash field to one event |
| POST | `/all-events-add-hash-field-company` | Add hash field for a company |
| POST | `/all-events-add-hash-field-user` | Add hash field for a user |
| POST | `/all-events-add-hash-field-companies` | Add hash field for a company list |
| GET | `/find-by-time-range` | Read persisted events by time range |
| GET | `/find-by-time-range-projection` | Same, with field projection |

---

## 6. Azure user data

### `TroubleshootingAzureUserService` — tag `troubleshooting-azure-user-service`
| Method | Path | Action |
|---|---|---|
| POST | `/troubleshooting/azure-users/sync-company` | Sync Azure users for a company (manual `UpdateAzureUsersTask`) |
| DELETE | `/troubleshooting/azure-users/delete-redundant-data` | Purge redundant Azure-user rows (limit) |
| GET | `/troubleshooting/azure-users/get-users-in-tenant` | List Azure users in a tenant |
| DELETE | `/troubleshooting/azure-users/delete-user-in-tenant` | Delete one Azure user |
| DELETE | `/troubleshooting/azure-users/delete-all-users-in-tenant` | Delete all Azure users in a tenant |

---

## 7. Admin fallback

### `TroubleshootingEnableAdminFallback` — tag `troubleshooting-enable-admin-fallback`
| Method | Path | Action |
|---|---|---|
| POST | `…/enable-admin-fallback-for-company` | Enable admin fallback for a company |
| POST | `…/add-admin-fallback-usage-per-user` | Increment per-user fallback usage |
| POST | `…/disable-admin-fallback-for-company` | Disable for one company |
| POST | `…/disable-admin-fallback-for-companies` | Disable for many companies |
| GET | `…/is-enabled` | Read fallback flag |
| POST | `/troubleshooting/clear-admin-fallback-usage-table` | Clear the whole usage table |
| POST | `…/delete-mailbox-sync-status-for-never-connected-Google-users` | ⚠️ Declared `private` — **not exposed over HTTP despite the mapping** (dead endpoint) |

---

## 8. Diagnostics & recruiting

### `TroubleshootingCalendarEventsUtils` — tag `troubleshooting-calendar-events-utils`
| Method | Path | Action |
|---|---|---|
| GET | `/troubleshooting/calendarEventsUtils/why-meeting-was-blacklisted` | Explain why a meeting subject was blacklisted |

### `TroubleshootingRecruitingEventsDeletion` — base `/troubleshooting/recruitingEventsDeletion`
| Method | Path | Action |
|---|---|---|
| GET | `/find-by-time-range-and-invitee-email` | Find recruiting events by time range + invitee |

### `TroubleshootingRecruitingGoogleSync` — tag `troubleshooting-recruiting-google-sync`
Read/test surface for the recruiting (interview) Google sync: `list-user-calendars`,
`filter-recruiting-events`, `filter-all-recruiting-coordinators-events`,
`find-recruiting-coordinator-event-by-icaluid`, `find-by-icaluid`, `interview-api-test`,
`company-interview-api-test`, `analyze-api-test`, `recorded-user-interview-api-test`,
`recruiting-calendar-raw-events`. **All GET / read-only — no write actions.**

### `TroubleshootingRecruitingRawCalendarEvents` — tag `troubleshooting-recruiting-raw-calendar-events`
Raw recruiting calendar reads: `list-user-raw-calendars`, `filter-user-all-calendars-raw-events`
(note source typo `ecruiting` in the path), `filter-recruiting-coordinators-raw-events`,
`find-recruiting-coordinator-event-by-icaluid`, `find-recorded-user-event-by-icaluid`,
`find-by-icaluid`, `query-recruiting-calendar-raw-events`. **All GET / read-only.**

---

# Gaps — paths with no troubleshooting endpoint

Cross-referenced against the entry points and async paths in [[02 - Data Flows]]. These are the
places you **cannot drive or inspect over HTTP** today.

### 🔴 Whole services with zero troubleshooting surface
- **MeetingsIndexer (`:9921`)** — no troubleshooting controller at all. You cannot force a re-index,
  read an indexed `MEETINGS` doc, or trigger `MeetingUpsertRequestsConsumer` from HTTP. The only
  inbound path is Kafka. *Workaround:* re-produce `calendar-meeting-upsert-requests` upstream.
- **GoogleCalendarIngester (`:8887`) / OfficeCalendarIngester (`:8886`)** — `HomeController` only. Their
  `UserCalendarImporter.accept()` is reachable **only** by producing a command from the Supervisor —
  there is no "import this user right here on the ingester" endpoint.

### 🔴 Scheduled tasks with no manual trigger
| Task | Manual trigger? |
|---|---|
| `ImportGoogle/OfficeCalendarEventsTask` | ✅ via `/sync/*` and `/calendar-import/*` |
| `UpdateAzureUsersTask` | ✅ via `azure-users/sync-company` + office `company/users/update` |
| `CalendarDeletionRequestsTask` (24h delayed deletes) | ❌ no "run now" — only enqueue via `CalendarRequestsController` |
| `DeleteObsoleteCalendarEventsTask` (>14d cleanup) | ❌ none |
| `PurgeMeetingsTask` (retention purge) | ❌ none |

### 🔴 Kafka consumers with no HTTP trigger (must produce upstream)
- `MeetingUpsertRequestsConsumer` (MeetingsIndexer) — the indexing sink.
- `meetings-crm-association-updated-consumer` — CRM re-enrichment (`association-updated`).
- `meetings-call-scheduler-updated-consumer` — call-id update (`call-scheduling-updated`).
- `calendar-call-scheduling-updated-consumer` (Supervisor) — scheduling reaction.
- `CalendarSyncStatusConsumer` — per-user/company sync-status aggregation.

> ICS `reprocess-*-scheduled-calls` partly covers the *producing* side of scheduling, but there is
> no way to replay a single `call-scheduling-updated` or `association-updated` event into a consumer.

### 🟠 Observability / read gaps
- **No "read sync status for user/company"** endpoint. You can backfill companyIds into sync-status
  rows and delete never-connected rows, but there's no diagnostic *read* of where a user is stuck in
  the sync pipeline — the single most common on-call question.
- **No "read the indexed OpenSearch meeting by id"** — you can count and delete `MEETINGS` docs, and
  read from Mongo/mirror, but not fetch the actual indexed document to compare against source.
- **Office365 has no raw-event reprocess parity** with Google's `read-raw-events` /
  `converted-events` — Office reads are live-API only; there's no "show converted Office event".

### 🟡 Code-quality flags found while cataloging (not gaps, but worth a ticket)
- `TroubleshootingEnableAdminFallback.…delete-mailbox-sync-status-for-never-connected-Google-users`
  is annotated `@PostMapping` but declared **`private`** → Spring won't expose it. Dead mapping.
- `/troubleshooting/calendar-mirror/purge` is a **cross-tenant** operation the code itself labels
  `UNSAFE` and takes no params — easy to fire by accident from Swagger.
- Path typo: `…/ecruiting-raw-calendar-events/…` (missing leading `r`) in
  `TroubleshootingRecruitingRawCalendarEvents`.

> Everything above is from source as of 2026-06-25. Line numbers intentionally omitted — open the
> controller and confirm before relying on a signature.
