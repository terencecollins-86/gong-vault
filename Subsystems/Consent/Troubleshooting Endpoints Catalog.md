---
title: Consent — Troubleshooting Endpoints Catalog
tags: [consent, recording-consent, troubleshooting, runbook, endpoints, reference]
created: 2026-07-21
aliases:
  - consent troubleshooters
  - consent endpoints
  - how to trigger consent flows
---

# Troubleshooting Endpoints Catalog

> [[_dashboard|← Team Hub]] · [[06 - Local Dev Seed Data]] · [[04 - Use Cases]] · [[02 - Data Flow]]

Every `/troubleshooting/**` endpoint across the 13 consent controllers, organised by **use-case group** so you can find the right endpoint for the flow you want to drive or inspect. All paths/params are verbatim from source (KB-verified 2026-07-21).

> [!warning] Known quirks
> - `/delete_obfuscated company_id` has a **literal space** in the path — URL-encode as `%20`.
> - `/get-Dcp-Jump-Page-Url-Settings-for-preview` takes a `Meeting-key` param typed as `long` (a numeric preview ID), not a string meeting key.
> - `TroubleshootingMicrosoftTeams` lives in **RecordingConsentTasks (`:9095`)**, not ConsentWebApi.

---

## Ports at a glance

| Module | Port | Type |
|---|---|---|
| `MeetingFrontEnd` | `:8098` | Public — serves jump page & consent-email landing page |
| `RecordingConsentTasks` | `:9095` | Internal — Kafka consumers, scheduled tasks, most troubleshooters |
| `RecordingConsentApiServer` | `:7254` | Internal — DCP settings API, static links, purge |
| `DcpChangeManager` | `:8121` | Internal — change-request state machine |

---

## A — Solicit consent

### UC-A1 · Render the jump page

**Setup — warm Redis first (page renders from Redis, not DB):**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/consent_redis/populate-company-in-redis` | RCT `:9095` | `company-id` (long); `force=true` to skip freshness check |
| `GET` | `/troubleshooting/consent_redis/get-dcp-jump-page-url-settings` | RCT `:9095` | `profile-key`, `user-key`, `Meeting-key` (optional) — verify Redis has the data before hitting the page |
| `GET` | `/troubleshooting/consent_redis/get-company-id-by-profile-key` | RCT `:9095` | `profile-key` — resolve unknown profile key to company |
| `GET` | `/troubleshooting/consent_redis/get-user-id-by-user-key` | RCT `:9095` | `company-id`, `user-key` — resolve URL key to app-user ID |
| `GET` | `/troubleshooting/consent_redis/get-redis-dcp-jump-page-settings` | RCT `:9095` | `company-id`, `dcp-id` — read the full `RedisDcpJumpPageSettings` |
| `GET` | `/troubleshooting/consent_redis/get-redis-jump-page-user-settings` | RCT `:9095` | `company-id`, `app-user-id` — read per-user provider settings |

**Trigger (direct hit — no auth required on MeetingFrontEnd public path):**

```
GET http://localhost:8098/{profileKey}/{userKey}              ← PMI / static page
GET http://localhost:8098/{profileKey}/{userKey}/{meetingKey} ← dynamic / one-time
```

**Preview (render without a real participant session):**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `GET` | `/troubleshooting/consent_redis/set-url-settings-for-preview` | RCT `:9095` | `profile-key`, `user-key`, `Meeting-key` (optional) → returns preview ID (Long) |
| `GET` | `/troubleshooting/consent_redis/get-Dcp-Jump-Page-Url-Settings-for-preview` | RCT `:9095` | `company-id`, `Meeting-key` (Long preview ID) |

---

### UC-A2 · Send a pre-call consent email

**No "send now" endpoint.** The email is sent by `ConsentEmailsTasks#consentEmailScheduledTask` (every 1 min) when an eligible call exists. The call becomes eligible after `call-scheduling-updated` fires and `DcpConsentEmailSchedulingService#handleEvent` schedules it.

**Inspect / seed Redis directly (skip the scheduled-task wait):**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `GET` | `/troubleshooting/consent_email/redis/email-id-to-consent-email-page-data` | RCT `:9095` | `company-id`, `email-id` — read `ConsentEmailPageData` from Redis |
| `GET` | `/troubleshooting/consent_email/redis/call-id-to-consent-email-call-details` | RCT `:9095` | `company-id`, `call-id` — read `ConsentEmailCallDetails` from Redis |
| `POST` | `/troubleshooting/consent_email/redis/set-consent-email-page-data-by-email-id` | RCT `:9095` | `company-id`, `email-id`, `call-id`, `is-email-id-obsolete` (bool), `response` (enum, default `NO_RESPONSE`), `consentEmailSettingsRevisionId`, `inviteeId`, `sentTime` (OffsetDateTime ISO-8601) |
| `POST` | `/troubleshooting/consent_email/redis/set-consent-email-call-details-by-call-id` | RCT `:9095` | `company-id`, `call-id`, `title`, `owner-id`, `start-time` (OffsetDateTime), `call-status` (enum, default `SCHEDULED`), `skip-code` (enum, optional) |

---

### UC-A3 · Render the consent-email landing page

**Setup — need obfuscated company ID in Redis:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `GET` | `/troubleshooting/consent_email/redis/obfuscated-company-id-to-company-id` | RCT `:9095` | `obfuscated-company-id` (long) — check if mapping exists |
| `POST` | `/troubleshooting/consent_email/redis/obfuscated-company-id-to-company-id` | RCT `:9095` | `obfuscated-company-id`, `company-id` — seed the mapping |
| `POST` | `/troubleshooting/consent_email/redis/set-consent-email-page-data-by-email-id` | RCT `:9095` | (same as A2 above) |

**Trigger:**

```
GET  http://localhost:8098/{CONSENT_EMAIL_URL}/{obfuscatedCompanyId}/{emailId}
POST http://localhost:8098/{CONSENT_EMAIL_URL}/{obfuscatedCompanyId}/{emailId}   ← body: UiConsentEmailResponse
```

---

## B — Capture the decision

### UC-B1 · Accept recording

**Trigger** (requires Redis warm from A1 setup):

```
POST http://localhost:8098/{profileKey}/{userKey}[/{meetingKey}]
```

No request body. Fires `RecordingSupervisorClient#restrictCallRecording` (sync, inline) + publishes `JumpPageInteractionEvent` on `audit-meeting-consent`.

---

### UC-B2 · Skip / decline recording

**Trigger:**

```
POST http://localhost:8098/{profileKey}/{userKey}[/{meetingKey}]/skip-answer
```

No request body. Same Kafka event with `denied_recording = true`.

---

### UC-B3 · Audit the decision

Audit is written **asynchronously** — `AuditMeetingConsentConsumer` consumes `audit-meeting-consent` and writes `recording_compliance.jump_page_session` + `jump_page_interaction`. Fires automatically after B1/B2 when `RecordingConsentTasks` is running. No direct trigger endpoint.

**Replay a consent-email interaction (bypasses Kafka for consent-email path):**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/consent_email/send-event-to-consent-email-page-interaction-service` | RCT `:9095` | `company-id`, `call-id`, `email-id`, `call-owner-id`, `consent-email-response` (enum: `NO_RESPONSE`/`ACCEPTED`/`DENIED`), `meeting-title`, `invitee-id` — directly calls `ConsentEmailInteractionService.handleInteraction` |

---

## C — Enforce consent on the recorder

### UC-C1 · Restrict recording on decision

**No dedicated troubleshooter.** `RecordingSupervisorClient#restrictCallRecording` fires inline inside `JumpPageController#acceptAnswer` (B1). The only way to trigger it is via B1/B2 above.

---

### UC-C2 · Stop recording

**No dedicated troubleshooter.** `AuditStopRecordingConsumer` consumes the `audit-stop-recording` event produced by the recorder side — it cannot be triggered from the consent subsystem itself. Must produce the event upstream.

---

## D — Configure the DCP

### UC-D1 · Read / write DCP consent settings

**Read:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/data-capture-profile/read-default-data-capture-profile` | RCAS `:7254` | `company-id` — returns default `DataCaptureProfile` as string |
| `POST` | `/troubleshooting/data-capture-profile/read-data-capture-profile` | RCAS `:7254` | `company-id`, `dcp-id` |
| `POST` | `/troubleshooting/data-capture-profile/list-data-capture-profiles` | RCAS `:7254` | `company-id` — returns JSON array of all profiles |

**Write:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/data-capture-profile/set-data-capture-profile-to-appuser` | RCAS `:7254` | `company-id`, `dcp-id`, `appuser-id` — assigns DCP to one user (uses `ModifiedByProcessType.GONG_TROUBLESHOOTER`) |
| `POST` | `/troubleshooting/data-capture-profile/set-data-capture-profile-from-file-by-company` | RCAS `:7254` | `companyId` (query param) + multipart CSV (`email`, `dcpId` columns) — bulk assign |
| `POST` | `/troubleshooting/consent_settings/set_pre_call_email_footnote_template` | RCT `:9095` | `company-id`, `dcp-id`, `legal-footnote` (String) — sets the legal footnote on the pre-call email template |

---

### UC-D2 · Manage a one-time (dynamic) jump-page meeting

**Inspect:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `GET` | `/troubleshooting/consent_redis/get-one-time-meeting-settings` | RCT `:9095` | `company-id`, `meeting-key` — returns `JumpPageOnetimeMeetingSettings` from Redis |
| `POST` | `/troubleshooting/consent_redis/check-meetings-in-redis-for-company` | RCT `:9095` | `company-id`, `from-date` (Instant, optional) — consistency check: Redis vs DB |
| `POST` | `/troubleshooting/consent-page-info/consent-urls-info` | RCT `:9095` | `company-id`, `last-days-count` — streams CSV of meeting IDs, provider URLs, iCal IDs, start/end times (max 25k rows) |

**Repair:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/consent_redis/reload-one-time-meeting-settings-to-redis` | RCT `:9095` | `company-id`, `meeting-key` — re-reads from DB, writes back to Redis; `404` if meeting key not found |
| `POST` | `/troubleshooting/consent-page-info/recreate-provider-url-for-existing-consent-page` | RCT `:9095` | `company-id`, `provider-id` (String); optional: `consent-page-created-after/before` (Instant), `meeting-start-after/before` (Instant), `gong-meeting-key` (String). Single-meeting mode when `gong-meeting-key` provided; otherwise batch up to 1,000 keys |

**Cleanup:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `DELETE` | `/troubleshooting/consent_redis/delete-old-meeting-data-for-company` | RCT `:9095` | `company-id`, `before-date` (Instant) |
| `DELETE` | `/troubleshooting/consent_redis/delete-old-meeting-data` | RCT `:9095` | `before-date` (Instant) — all companies |

---

## E — Propagate a settings change

### UC-E1 · Orchestrate a DCP change request

**Diagnose:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `GET` | `/troubleshooting/dcp-change-manager/list-stuck-change-requests` | DCM `:8121` | `durationSinceUpdate` (Duration ISO-8601, default `PT10M`); `limit` (int, default 100); `includeDetails` (bool, default `false`) |
| `GET` | `/troubleshooting/dcp-change-manager/list-stuck-changes-by-company` | DCM `:8121` | `companyId` (long); `durationSinceUpdate`; `includeDetails` (bool, default `true`) — returns `StuckChangesResponse` with queue chains |
| `POST` | `/troubleshooting/dcp-change-manager/list-running-change-requests-not-updated-for-duration` | DCM `:8121` | `durationSinceUpdate` (default `PT0M`); `limit` (default 100) |

**Force a state transition:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/dcp-change-manager/set-change-request-state` | DCM `:8121` | `company-id`, `change-request-id`, `change-request-state` (enum: `INIT`/`WAIT`/`RUNNING`/`DONE`) |

**Execute:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/dcp-change-manager/execute-running-change-request` | DCM `:8121` | `company-id`, `change-request-id`, `ignore-exception-and-run-next-request` (bool) — directly invokes the batch executor |
| `POST` | `/troubleshooting/dcp-change-manager/execute-first-stuck-change-request` | DCM `:8121` | `companyId`, `changeRequestId`, `durationSinceUpdate` (default `PT10M`), `dryRun` (bool, default `true`), `ignoreExceptions` (bool, default `false`) — use `dryRun=true` first |
| `POST` | `/troubleshooting/dcp-change-manager/execute-all-change-requests-notUpdated-for-mora-than-duration` | DCM `:8121` | `durationSinceUpdate` (default `PT0M`); `limit` (default 100); `ignore-exceptions-and-run-next-request` (bool, required) — validates no company has >1 RUNNING request first |
| `POST` | `/troubleshooting/dcp-change-manager/handle-user-changes-done` | DCM `:8121` | `company-id`, `change-request-id`, `appuser-id` — signals one user's changes are complete |

---

### UC-E2 · Run a concrete change action

**Unblock a stuck action (skip it and continue):**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/dcp-change-manager/mark-action-as-done-and-run-change-request` | DCM `:8121` | `company-id`, `change-request-id`, `action-type` (enum: `SINGLE`/`BATCH`), `action-name` (enum — see below) — marks the action as `SKIPPED`, re-triggers the consumer |

**`action-name` enum values:**  
`SYNC_MEETING_PMI_ACTION`, `CANCEL_NON_COMPLIANT_CALLS_ACTION`, `CONSENT_EMAIL_SETTINGS_CHANGE_ACTION`, `CONSENT_EMAIL_SETTINGS_CHANGE_MULTI_PROVIDER_ACTION`, `CONSENT_EMAIL_BACK_FILL_ACTION`, `RESET_USER_DEFAULT_PROVIDER_ACTION`, `CLEAR_CALENDAR_CACHE_ACTION`, `HANDLE_SINGLE_TO_SINGLE_PROFILE_PMI_SWITCH`, `SEND_TECH_ADMIN_PROVIDER_SWITCH_EMAIL_ACTION`, `SEND_TECH_ADMIN_LINK_TYPE_SWITCH_TO_DYNAMIC_EMAIL_ACTION`, `SEND_REPS_JUMP_PAGE_SETTINGS_CHANGE_EMAIL_ACTION`, `SEND_TECH_ADMIN_JUMP_PAGE_DISABLED_EMAIL_ACTION`, `SEND_TECH_ADMIN_AUDIO_PROMPT_DISABLED_EMAIL_ACTION`

**Bulk-repair stalled request queues:**

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/dcp-change-manager/move-changes-from-wait-to-done` | DCM `:8121` | `company-id`, `update-before` (Instant ISO-8601), `limit` (int) |
| `POST` | `/troubleshooting/dcp-change-manager/move-changes-from-init-to-done` | DCM `:8121` | `company-id`, `update-before` (Instant ISO-8601) |
| `POST` | `/troubleshooting/dcp-change-manager/move-users-from-init-to-done` | DCM `:8121` | `company-id`, `update-before` (Instant ISO-8601) |
| `POST` | `/troubleshooting/dcp-change-manager/delete-old-change-request-data-for-company` | DCM `:8121` | `company-id`, `days-before` (int) — returns deleted row count |

---

## F — React to upstream & lifecycle events

### UC-F1 · React to a scheduled / cancelled call

**No troubleshooter endpoint** — `ConsentCallSchedulingUpdatedConsumer` fires only when `call-scheduling-updated` is produced by Call Scheduling. Must run the upstream flow; see [[Subsystems/Call Scheduling/06 - Local Dev Seed Data]].

**Verify the reaction landed:**
```sql
-- recording_consent_dev
SELECT * FROM recording_consent_settings.calendar_event WHERE company_id = 9001;
```

---

### UC-F2 · React to a calendar update

**No troubleshooter endpoint** — `CalendarUpdatesForConsentConsumer` requires an upstream `calendar-updates-for-consent` event from the Calendar Ingestion pipeline.

---

### UC-F3 · Reset a company's consent cache

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/consent_redis/populate-company-in-redis` | RCT `:9095` | `company-id`; `force=true` to bypass freshness check |
| `POST` | `/troubleshooting/consent_redis/populate-company-profiles-in-redis` | RCT `:9095` | `company-id`; `force=true` — profile data only (not meeting data) |
| `DELETE` | `/troubleshooting/consent_redis/delete-all-company-data` | RCT `:9095` | `company-id` — wipe all Redis keys for the company |
| `GET` | `/troubleshooting/consent_redis/populate-company-with-all-accessors-in-consent-redis` | RCT `:9095` | `company-id` — runs all accessor populators for one company |
| `GET` | `/troubleshooting/consent_redis/populate-company-with-one-accessor-in-consent-redis` | RCT `:9095` | `company-id`, `accessor-type` (enum: `OBFUSCATED_COMPANY_ID_TO_COMPANY_ID`/`CONSENT_EMAIL_ID_TO_CONSENT_EMAIL_PAGE_DATE`/`CALL_ID_TO_CONSENT_EMAIL_CALL_DETAILS`/`REVISION_ID_TO_CONSENT_EMAIL_SETTINGS`) |
| `POST` | `/troubleshooting/consent_redis/mark-data-loaded` | RCT `:9095` | `is-data-loaded` (bool) — manually flip the "legacy Redis loaded" flag |
| `POST` | `/troubleshooting/consent_redis/mark-data-loaded-with-accessors` | RCT `:9095` | `is-data-loaded` (bool) |
| `POST` | `/troubleshooting/consent_redis/mark-company-data-loaded-with-accessors` | RCT `:9095` | `company-id`, `is-data-loaded` (bool) |
| `GET` | `/troubleshooting/consent_redis/toggle-populate-redis-accessors-task-circuit` | RCT `:9095` | `new-toggle-state` (bool) — enable/disable the `PopulateConsentRedisWithAccessors` circuit breaker |
| `GET` | `/troubleshooting/consent_redis/reset-latest-loaded-company-creation-date-for-populate-redis-accessors` | RCT `:9095` | none — clears the high-water mark, forces accessor task to reprocess from the beginning |

> ⚠️ **Full rebuild** (production-use with caution):
> `POST :9095/troubleshooting/consent_redis/reset-all-data` — deletes all keys for all companies then synchronously repopulates everything.

---

### UC-F4 · Purge a company (GDPR)

**No troubleshooter** for the `RecordingConsentPurgeCompanyConsumer` — the full GDPR purge requires the `purge-company` event from upstream. Partial consent-settings cleanup:

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `POST` | `/troubleshooting/consent_settings/recording_settings_deletion` | RCT `:9095` | `company-id` — deletes all `recording_consent_settings` rows for the company |
| `POST` | `/troubleshooting/dcp-change-manager/delete-old-change-request-data-unsafe` | DCM `:8121` | `days-before` (int) — cross-tenant deletion (⚠️ no tenant isolation) |

---

### UC-F5 · Gate a consent feature

| Method | Path | Module:port | Key params |
|---|---|---|---|
| `GET` | `/troubleshooting/recording-consent-feature/all-features` | RCT `:9095` | none — returns JSON map of all `RecordingConsentFeatureName` → enabled state |
| `POST` | `/troubleshooting/recording-consent-feature/get-feature-state` | RCT `:9095` | body: `RecordingConsentFeatureName` enum value (e.g. `FOR_TEST`) |
| `POST` | `/troubleshooting/recording-consent-feature/enable-feature` | RCT `:9095` | body: `RecordingConsentFeatureName` enum value |
| `POST` | `/troubleshooting/recording-consent-feature/disable-feature` | RCT `:9095` | body: `RecordingConsentFeatureName` enum value |

> **Note:** `RecordingConsentFeatureName` currently has only `FOR_TEST` — the enum is scaffolding. These endpoints exist but have no production-meaningful values yet.

---

## Controllers not mapped to a use-case group

### Provider integrations — MS Teams & WebEx

**`TroubleshootingMicrosoftTeams`** (RCT `:9095`, base `/troubleshooting/msteams`):  
All endpoints resolve the company from `user-id` via `UserService`.

| Method | Path | Key params |
|---|---|---|
| `POST` | `/create-meeting` | `user-id`, `from` (Date), `to` (Date) |
| `POST` | `/update-meeting` | `user-id`, `provider-meeting-id`, `from`, `to`, `title` |
| `POST` | `/delete-meeting` | `user-id`, `provider-meeting-id` |
| `POST` | `/get-meeting` | `user-id`, `provider-meeting-id` |
| `POST` | `/list-meeting-attendance-reports` | `user-id`, `provider-meeting-id` |
| `POST` | `/get-meeting-attendance-report` | `user-id`, `provider-meeting-id`, `report-id` |

**`TroubleshootingWebex`** (RCT `:9095`, base `/troubleshooting/webex`):

| Method | Path | Key params |
|---|---|---|
| `POST` | `/sync-meeting-uris` | `companyId` (long) — syncs WebEx meeting room URIs |
| `GET` | `/sync-users-for-one-company` | `companyId` (long) — triggers WebEx user-matching task |

### Static links & PMI protection

**`TroubleshootingStaticLinks`** (RCAS `:7254`, base `/troubleshooting/static-links`):

| Method | Path | Key params |
|---|---|---|
| `POST` | `/backfill-static-links-for-company` | `company-id` |
| `POST` | `/backfill-static-links-for-all-companies` | `batch-size`, `sleepInMillis`, `max` (optional), `startFrom` (optional, default 0) |
| `DELETE` | `/cleanup-invalid` | none — removes users with no / multiple legacy static links |

**`TroubleshootingProtectPmiFeatureDisplayed`** (RCT `:9095`, base `/troubleshooting/protected_pmi_displayed`):

| Method | Path | Key params |
|---|---|---|
| `GET` | `/fill-in-protected-pmi-feature-displayed-table-with-all-active-companies` | none |
| `GET` | `/list_companies-for-which-protected-pmi-should-be-displayed` | none |
| `POST` | `/add-company-that-should-see-feature` | `company-id` |
| `POST` | `/remove-company-that-should-see-feature` | `company-id` |
| `POST` | `/try-software-defined-alerts` | none — fires the `TryOutForProtectedPmi` monitor marker |

### Consent settings & email text

**`TroubleshootingConsentSettings`** (RCT `:9095`, base `/troubleshooting/consent_settings`):

| Method | Path | Key params |
|---|---|---|
| `POST` | `/recording_settings_migration` | `limit` (int), `migrate-all` (bool, default `false`), `last-position` (Instant, optional) — migrates `AppUserConsentSettings` to new store |
| `POST` | `/recording_settings_deletion` | `company-id` |
| `POST` | `/set_pre_call_email_footnote_template` | `company-id`, `dcp-id`, `legal-footnote` (String) |

**`TroubleshootingJumpSettingChangesEmailText`** (RCT `:9095`, base `/troubleshooting/emailText`):

| Method | Path | Key params |
|---|---|---|
| `POST` | `/uploadProperties` | `baseName` (String, query param) + multipart `.properties` file — override email text templates at runtime |
| `DELETE` | `/removeUploadedProperties` | `baseName` (String, query param) |

**`TroubleshootingDataCaptureEmails`** (RCAS `:7254`, base `/troubleshooting/data-capture-consent-change-emails`):

| Method | Path | Key params |
|---|---|---|
| `POST` | `/sendJumpPageSettingsChangedEmail` | `userId` (Long, query param) + request body: `JumpPageSettingsChangedMultiProviderEmailData` (JSON) — manually sends the consent-change email |

---

## Gaps — flows with no HTTP trigger

Cross-referenced against [[02 - Data Flow]] and [[04 - Use Cases]].

### 🔴 Kafka consumers with no HTTP trigger (must produce upstream)

| Consumer | Topic | Workaround |
|---|---|---|
| `ConsentCallSchedulingUpdatedConsumer` (UC-F1) | `call-scheduling-updated` | Run the Call Scheduling flow — see [[Subsystems/Call Scheduling/06 - Local Dev Seed Data]] |
| `CalendarUpdatesForConsentConsumer` (UC-F2) | `calendar-updates-for-consent` | Produce from Calendar Ingestion |
| `AuditMeetingConsentConsumer` (UC-B3 audit) | `audit-meeting-consent` | Fires automatically after B1/B2 when `RecordingConsentTasks` is running |
| `AuditStopRecordingConsumer` (UC-C2) | `audit-stop-recording` | Must be produced by the recorder subsystem |
| `RecordingConsentPurgeCompanyConsumer` (UC-F4) | `purge-company` | Full GDPR purge requires `purge-company` from upstream; partial cleanup via `recording_settings_deletion` |

### 🔴 Inline calls with no standalone trigger

| Flow | Where it fires | Workaround |
|---|---|---|
| `RecordingSupervisorClient#restrictCallRecording` (UC-C1) | Inline in `JumpPageController#acceptAnswer` — fires synchronously as part of B1 | Drive via UC-B1 (`POST :8098/{profileKey}/{userKey}`) |
| Pre-call email send for a specific call (UC-A2) | `ConsentEmailsTasks` scheduled task (every 1 min) | Seed the email Redis directly via `TroubleshootingConsentEmail` endpoints and wait for the task cycle; or inspect via `get-feature-state` to confirm the scheduler is enabled |

### 🟠 Observability gaps

- **No "read audit trail" endpoint** — `recording_compliance.jump_page_session` and `jump_page_interaction` rows written by `AuditMeetingConsentConsumer` are readable only via SQL. There is no troubleshooter that queries the audit tables.
- **No "read consent email send history"** — `recording_consent_email.consent_email` and `audit` tables have no read endpoint; use SQL or the `consent-urls-info` endpoint for meeting-level data.
- **No "inspect DCP change history"** — `data_capture_dev.dcp_change.*` tables have no read troubleshooter. The `list-stuck-change-requests` endpoint covers in-flight state only.

---

## See also

- [[04 - Use Cases]] — use case hub (all A–F groups)
- [[06 - Local Dev Seed Data]] — prerequisites and the base seed sequence
- [[02 - Data Flow]] — Kafka consumers, producers, and scheduled tasks behind each use case
- [[Jump Page & DCP]] — profileKey/userKey lookup and Redis warm details
- [[Work/Architecture/Troubleshoot Endpoints]] — auth model and how to use troubleshooter endpoints safely in prod
