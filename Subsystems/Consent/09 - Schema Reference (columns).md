---
title: Schema Reference (columns)
tags: [consent, recording-consent, database, postgres, schema, columns, ddl]
created: 2026-07-22
---

# Schema Reference — Column-Level

> [[_dashboard|← Team Hub]] · [[05 - Data Access & Storage]] · [[Storage & Schema Reference]] · [[Subsystems/Consent/Canvas/Data Stores/DataStore-PostgreSQL|PostgreSQL chip]]

The **column-level** companion to [[05 - Data Access & Storage]] (which maps datasources → schemas → table *names*) and [[Storage & Schema Reference]] (lighter inventory). Both of those explicitly deferred columns/PKs/FKs to `kb_table(action=schema)`; **this doc fills that gap** for every Consent-**owned** table.

**Scope**: owned schemas only. Cross-schema `public.*` (OPERATIONAL) tables — owned by other teams — are **not** dumped here; see [[05 - Data Access & Storage#3. Cross-schema access — `OPERATIONAL` DB (`public`)|§3 of the access doc]]. `webex_integration.*` is excluded (provider integration, not consent logic).

> [!note] Provenance of each column
> **Column names, types, PK membership, and indexes are verified ground truth** — from the schema-owning Flyway migrations (`honeyfy/Schema/.../{recording_consent,data_capture,operational}/db/migration/` and `gong-data-capture/RecordingConsentTasks/.../recording_consent_timed_events/db/migration/`), cross-checked with `kb_table(action=schema)`. Verified 2026-07-22.
> The **Usage** column is *derived* from column names, the migration DDL, and the subsystem domain docs ([[02 - Data Flow]], [[03 - Ubiquitous Language]], [[Jump Page & DCP]]) — **not** from exhaustive per-column code tracing. Standard columns (tenant key, timestamps, keys) are described with confidence; domain columns are described by apparent role, and cases where exact behavior isn't pinned to code are marked _(inferred)_.

> [!warning] Corrections to the existing docs (verified against migrations)
> - **`recording_user_consent` schema was DROPPED** (`V20231220_1532__drop_user_consent_schema.sql`). [[05 - Data Access & Storage]] §2a listed it as live — now fixed. Not included below.
> - **The `data_capture` *schema* and the `data_capture` *physical DB* differ.** The `data_capture.*` settings tables (`profile`, `audio_prompt_settings`, `jump_page_settings`, …) physically live in the **`honeyfy` / OPERATIONAL** DB (`database=honeyfy`); only **`dcp_change.*`** lives in the modern **`data_capture`** physical DB.
> - Legacy `data_capture.*` operational tables gone: `internal_domain`, `authorized_domain_mapping`, `additional_authorized_domain`, `sent_pre_call_email` (dropped); `consent_settings` → renamed `jump_page_settings`.

## Legend

- **Type** cell: PostgreSQL type · `PK` = part of primary key · unmarked = `NOT NULL` · `null` = nullable. Enum types shown as `schema.enum_name`.
- A **Keys / indexes** line under each table lists PK (`u:…_pkey`), other unique constraints (`u:`), and non-unique indexes (`i:`).
- Timestamp columns are `timestamp with time zone` unless the Type cell says `timestamp` (no zone).
- **Standard columns** repeated across nearly every table: `company_id` = tenant identifier and RLS partition key (single-/cross-tenant policies key on it); `create_date_time` / `update_date_time` = row insert / last-modified audit timestamps; `dcp_id` = the [[Jump Page & DCP|Data Capture Profile]] the row belongs to.

---

## `recording_consent` DB

Flyway: `honeyfy/Schema/.../recording_consent/db/migration/`. Accessor: `RecordingConsentDb`. Physical (local): **`recording_consent_dev`**.

### Schema `recording_consent_email`

Pre-call consent-email state, driven by `RecordingConsentTasks` / `ConsentEmailSender`.

#### `consent_email`
One row per consent email sent to a call invitee, recording their response.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | Surrogate key for the sent consent email. |
| `company_id` | bigint | Tenant. |
| `call_id` | bigint | The call (`public.call`) this consent email is about. |
| `invitee_id` | bigint | The invitee (`public.invitee`) the email was sent to. |
| `sent_time` | timestamptz | When the email was sent. |
| `is_email_id_obsolete` | boolean | Marks the email superseded (e.g. call rescheduled / re-sent). |
| `response` | recording_consent_email.consent_email_response | Enum capturing the recipient's consent decision (allow / deny / no response). |
| `consent_email_settings_revision_id` | bigint · null | The `consent_email_settings_history` revision in effect when sent. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:consent_email_pkey(id)`

#### `audit`
Interaction/audit trail for consent-email response pages.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | Surrogate key for the audit event. |
| `company_id` | bigint | Tenant. |
| `email_id` | bigint · null | The `consent_email.id` involved, if any. |
| `call_id` | bigint · null | Related call. |
| `invitee_id` | bigint · null | Related invitee. |
| `call_owner_id` | bigint · null | Appuser who owns the call. |
| `action` | character · null | Action code recorded for the interaction _(inferred)_. |
| `session_id` | bigint · null | Response-page session correlation _(inferred)_. |
| `ip` | character · null | Source IP of the interaction. |
| `response_page` | text · null | Snapshot / identifier of the response page shown _(inferred)_. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:audit_pkey(id)`

#### `company_obfuscation`
Maps a company to an obfuscated id used in public-facing consent-email URLs so the real `company_id` isn't exposed.

| Column | Type | Usage |
|---|---|---|
| `company_id` | bigint · PK | Tenant (real id). |
| `obfuscated_company_id` | bigint | Public-safe surrogate used in outbound email links. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:company_obfuscation_pkey(company_id)`

#### `consent_email_settings_history`
Versioned history of per-DCP consent-email settings; each row is one revision.

| Column | Type | Usage |
|---|---|---|
| `revision_id` | bigint · PK | Revision identifier (referenced by `consent_email.consent_email_settings_revision_id`). |
| `dcp_id` | bigint | Data Capture Profile these settings belong to. |
| `company_id` | bigint | Tenant. |
| `is_enabled` | boolean | Whether consent email is enabled for this revision. |
| `consent_type` | recording_consent_email.consent_type · null | Enum: the consent model applied. |
| `send_time_before_seconds` | integer · null | Lead time before the call to send the email. |
| `show_company_logo` | boolean · null | Whether to render the company logo. |
| `logo_url` | character · null | Logo image URL. |
| `company_name` | text | Company name shown in the email. |
| `privacy_policy_link` | character | Privacy-policy URL shown to recipients. |
| `email_text` | text · null | Body copy of the email. |
| `landing_page_text` | text | Copy shown on the consent landing page. |
| `is_current` | boolean | Marks the active revision for the (company, dcp). |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:consent_email_settings_history_pkey(revision_id)` · `u:profile_id_is_default_uindex(company_id,dcp_id,is_current)`

### Schema `recording_consent_settings`

Per-user / per-company consent settings backing the DCP consent-settings API.

#### `user_settings`
Per-appuser consent preferences.

| Column | Type | Usage |
|---|---|---|
| `appuser_id` | bigint · PK | The user these settings belong to. |
| `company_id` | bigint | Tenant. |
| `default_meeting_provider` | character · null | The user's default meeting provider (see [[Meeting Providers & Multi-Provider DCP]]). |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:user_settings_pkey(appuser_id)`

#### `appuser_consent_settings`
Per-user consent token (used to build the user's personal consent link).

| Column | Type | Usage |
|---|---|---|
| `appuser_id` | bigint · PK | The user. |
| `company_id` | bigint | Tenant. |
| `token` | character | Opaque token embedded in the user's consent link (see [[Consent Link Creation]]). |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:appuser_consent_settings_pkey(appuser_id)`

#### `appuser_static_link`
Per-user, per-provider static meeting link (e.g. a fixed PMI room) and its parsed coordinates.

| Column | Type | Usage |
|---|---|---|
| `appuser_id` | bigint · PK | The user. |
| `company_id` | bigint · PK | Tenant. |
| `provider` | character · PK | Meeting provider this static link is for. |
| `meeting_uri` | character · null | The static meeting URL. |
| `meeting_id` | character · null | Parsed meeting id. |
| `meeting_provider_uri_source` | public.provider_uri_source · null | Enum: where the URI was sourced from. |
| `meeting_key` | character · null | Parsed meeting passcode/key. |
| `meeting_key_extraction_successful` | boolean · null | Whether key parsing succeeded. |
| `is_legacy_uri` | boolean · null | Marks an older-format URI. |
| `token` | character · null | Consent token associated with the static link. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:appuser_static_link_pkey(company_id,appuser_id,provider)`

#### `calendar_event`
Calendar events mirrored into the consent domain (natural key is `company_id` + `icalid`). PK is a replication surrogate — this table is populated via replication rather than a local sequence _(inferred from the `replication_id` PK and absence of an `id`)_.

| Column | Type | Usage |
|---|---|---|
| `company_id` | bigint | Tenant. |
| `icalid` | text | iCal UID of the calendar event (natural business key). |
| `title` | text · null | Event title. |
| `is_recurring` | boolean | Whether the event is part of a recurring series. |
| `start_time` | timestamptz | Event start. |
| `provider` | character | Calendar provider (Google / Office). |
| `update_failure_reason` | character · null | Reason a consent update against this event failed, if any. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |
| `replication_id` | bigint · PK | Replication surrogate key / ordering. |

Keys / indexes: `u:calendar_event_pkey(replication_id)` · `u:company_and_icalid_idx(company_id,icalid)`

#### `consent_feature`
Feature-flag rows for consent features; no `company_id`, replication-populated _(inferred)_ — appears to be global/replicated feature config rather than tenant data.

| Column | Type | Usage |
|---|---|---|
| `feature_name` | character | Name of the consent feature. |
| `enabled` | boolean | Whether the feature is enabled. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |
| `replication_id` | bigint · PK | Replication surrogate key. |

Keys / indexes: `u:consent_feature_pkey(replication_id)`

#### `protected_pmi_feature_displayed`
Per-company counter tracking display of the protected-PMI feature (see [[Meeting Providers & Multi-Provider DCP]]).

| Column | Type | Usage |
|---|---|---|
| `company_id` | bigint · PK | Tenant. |
| `removal_counter` | integer | Count of times the protected-PMI prompt was removed/dismissed _(inferred)_. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:protected_pmi_feature_displayed_pkey(company_id)`

### Schema `recording_compliance`

Jump-page (consent-page) sessions/interactions and stop-recording audit. Written by `RecordingComplianceDao`.

> 🪤 A **legacy** `recording_compliance` schema also exists in the OPERATIONAL DB (`honeyfy_dev`) — the live tables below are the **`recording_consent_dev`** ones. See [[05 - Data Access & Storage#2a. `RECORDING_CONSENT` DB → 3 schemas (monolith-migrated)|§2a]].

#### `jump_page_session`
A visitor session on the consent (jump) page, keyed by a browser cookie.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | Session surrogate key (referenced by `jump_page_interaction.session_id`). |
| `company_id` | bigint | Tenant. |
| `cookie` | character | Browser cookie identifying the visitor session. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:jump_page_session_pkey(id)` · `i:jump_page_session_company_id_index(company_id)` · `i:jump_page_session_cookie_index(id,company_id,cookie)`

#### `jump_page_interaction`
One row per HTTP interaction on the jump page — the audit of what the consent proxy did and the consent decision reached.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | Interaction surrogate key. |
| `session_id` | bigint | Owning `jump_page_session.id`. |
| `request_method` | character | HTTP method of the intercepted request. |
| `request_url` | text | Requested URL. |
| `request_headers` | text | Captured request headers. |
| `request_data` | text | Captured request body. |
| `config_data` | text | Consent/proxy config applied to the interaction. |
| `response` | text | Response returned to the client. |
| `type` | recording_compliance.request_type | Enum: kind of interaction. |
| `provider_url` | text | Upstream meeting-provider URL. |
| `gong_url` | text | Gong-side jump-page URL. |
| `meeting_owner_id` | bigint | Appuser who owns the meeting. |
| `company_id` | bigint | Tenant. |
| `denied_recording` | boolean · null | Whether the participant denied recording. |
| `got_access` | boolean · null | Whether access to the meeting was granted. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |
| `per_meeting_consent` | boolean | Whether consent was captured per-meeting. |
| `skipped_consent_page` | boolean | Whether the consent page was skipped. |
| `skipped_consent_reason` | text · null | Why the consent page was skipped. |
| `conference_type` | text · null | Conferencing type of the meeting. |

Keys / indexes: `u:jump_page_interaction_pkey(id)` · `i:jump_page_interaction_partial_idx(company_id,gong_url,create_date_time,session_id)` · `i:jump_page_interaction_session_id_index(session_id,company_id)`

#### `stop_recording_audit`
Audit of stop-recording (compliance) decisions per call.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | Audit surrogate key. |
| `company_id` | bigint | Tenant. |
| `call_id` | bigint | The call recording was stopped on. |
| `status` | recording_compliance.stopping_status | Enum: outcome of the stop-recording action. |
| `create_date_time` | timestamptz | Audit insert time. |
| `restricted_by_person` | boolean · null | Whether a specific participant triggered the restriction. |

Keys / indexes: `u:stop_recording_audit_pkey(id)`

#### `stop_recording_session_audit`
Link table associating a stop-recording audit with jump-page sessions.

| Column | Type | Usage |
|---|---|---|
| `stop_recording_audit_id` | bigint · PK | The `stop_recording_audit.id`. |
| `session_id` | bigint · PK | The `jump_page_session.id`. |
| `create_date_time` | timestamptz | Audit insert time. |
| `company_id` | bigint | Tenant. |

Keys / indexes: `u:stop_recording_session_audit_pkey(stop_recording_audit_id,session_id)`

---

## `data_capture` DB → schema `dcp_change`

Flyway: `honeyfy/Schema/.../data_capture/db/migration/`. Accessor: `DataCaptureDb`. Physical (local): **`data_capture_dev`**. DCP change-orchestration state machine (see [[05 - Data Access & Storage]]).

#### `change_request_queue`
Head of the DCP-change state machine — one row per queued change request.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | Change-request id (referenced by the child tables below). |
| `company_id` | bigint | Tenant. |
| `change_action` | dcp_change.change_action_type | Enum: what kind of change is requested. |
| `state` | dcp_change.state | Enum: current state of the request. |
| `next_change_request_id` | bigint · null | Chains to the next queued request for ordering. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:change_request_queue_pkey(id)`

#### `change_request_action`
Individual named actions that make up a change request, each with its own state.

| Column | Type | Usage |
|---|---|---|
| `change_request_id` | bigint · PK | Owning `change_request_queue.id`. |
| `company_id` | bigint | Tenant. |
| `name` | character · PK | Action name (unique within the request). |
| `type` | dcp_change.action_type | Enum: action category. |
| `state` | dcp_change.action_state | Enum: per-action progress. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:change_request_action_pkey(change_request_id,name)`

#### `change_request_user`
Per-user fan-out of a change request (which users the change applies to and their state).

| Column | Type | Usage |
|---|---|---|
| `change_request_id` | bigint · PK | Owning change request. |
| `company_id` | bigint | Tenant. |
| `app_user_id` | bigint · PK | User the change targets. |
| `state` | dcp_change.state | Enum: per-user progress. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz · null | Audit update time. |

Keys / indexes: `u:change_request_user_pkey(change_request_id,app_user_id)`

#### `settings_change`
A change request that moves a DCP's settings from one revision to another.

| Column | Type | Usage |
|---|---|---|
| `change_request_id` | bigint · PK | Owning change request. |
| `company_id` | bigint | Tenant. |
| `dcp_id` | bigint | The DCP whose settings change. |
| `source_revision` | bigint | Revision moving from. |
| `target_revision` | bigint | Revision moving to. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:settings_change_pkey(change_request_id)`

#### `user_assignment_change`
A change request that reassigns users from one DCP to another. Supersedes the misspelled `user_assigment_change` (dropped in-migration).

| Column | Type | Usage |
|---|---|---|
| `change_request_id` | bigint · PK | Owning change request. |
| `company_id` | bigint | Tenant. |
| `source_dcp` | bigint | DCP users move from. |
| `target_dcp` | bigint | DCP users move to. |
| `source_revision` | bigint | Source DCP revision. |
| `target_revision` | bigint | Target DCP revision. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:user_assignment_change_pkey(change_request_id)`

#### `dcp_settings_revision`
Immutable, versioned snapshot of a DCP's settings (stored as JSON).

| Column | Type | Usage |
|---|---|---|
| `revision_id` | bigint · PK | Revision id (referenced by `settings_change`, `latest_completed_dcp_revision`). |
| `company_id` | bigint | Tenant. |
| `dcp_id` | bigint | The DCP. |
| `settings` | jsonb | Full settings payload for the revision. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:dcp_settings_revision_pkey(revision_id)`

#### `latest_completed_dcp_revision`
Pointer to the most recently completed revision per (company, DCP).

| Column | Type | Usage |
|---|---|---|
| `company_id` | bigint · PK | Tenant. |
| `dcp_id` | bigint · PK | The DCP. |
| `revision_id` | bigint | The latest completed `dcp_settings_revision.revision_id`. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz · null | Audit update time. |

Keys / indexes: `u:latest_completed_dcp_revision_pkey(company_id,dcp_id)`

---

## `honeyfy` / OPERATIONAL DB → schema `data_capture`

> [!important] Physical location
> These `data_capture.*` **settings** tables are migrated from `operational/db/migration` and reported by `kb_table` as `database=honeyfy` — they live in the **OPERATIONAL** physical DB (**`honeyfy_dev`** locally), *not* `data_capture_dev`. Accessor is still `DataCaptureDb`. See [[05 - Data Access & Storage#2b. `DATA_CAPTURE` datasource → `dcp_change` + `data_capture` (two physical DBs)|§2b]].

#### `profile`
A Data Capture Profile (DCP) — the top-level consent/compliance configuration unit users are assigned to.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | DCP id (the `dcp_id` referenced throughout the subsystem). |
| `company_id` | bigint | Tenant. |
| `name` | character · null | Profile display name. |
| `description` | text · null | Profile description. |
| `user_last_edit_appuser_id` | bigint · null | Last user to edit the profile. |
| `user_last_edit_date_time` | timestamptz · null | When it was last edited. |
| `is_default` | boolean · null | Marks the company's default profile. |
| `create_date_time` | timestamp | Audit insert time (no zone). |
| `update_date_time` | timestamp | Audit update time (no zone). |
| `is_for_avatar` | boolean | Marks a profile used for the avatar/bot flow. |
| `revision_id` | bigint · null | Current settings revision pointer. |

Keys / indexes: `u:profile_pkey(id)` · `u:company_id_is_avatar_uindex(company_id,is_for_avatar)` · `u:company_id_is_default_uindex(company_id,is_default)` · `u:profile_id_company_id_uindex(id,company_id)`

#### `jump_page_settings`  _(renamed from `consent_settings`)_
Per-DCP configuration of the jump (consent) page. See [[Jump Page & DCP]].

| Column | Type | Usage |
|---|---|---|
| `dcp_id` | bigint · PK | The DCP these jump-page settings belong to. |
| `company_id` | bigint | Tenant. |
| `is_enforced` | boolean · null | Whether the jump page is enforced. |
| `create_date_time` | timestamp | Audit insert time (no zone). |
| `update_date_time` | timestamp | Audit update time (no zone). |
| `is_enabled` | boolean | Whether the jump page is enabled. |
| `should_send_non_compliant_calls_email` | boolean | Whether to email owners about non-compliant calls. |
| `welcome_email_send_time` | timestamp · null | Scheduled welcome-email time. |
| `recording_opt_out` | data_capture.recording_opt_out · null | Enum: opt-out behavior. |
| `link_type` | data_capture.jump_page_link_type · null | Enum: kind of consent link. |
| `use_policy_link` | boolean | Whether to show a policy link. |
| `policy_link` | text · null | Policy URL. |
| `policy_link_title` | character | Policy link label. |
| `policy_text` | text | Policy body text. |
| `explain_text` | text | Explanatory copy on the page. |
| `logo_url` | character · null | Company logo URL. |
| `meeting_provider` | character · null | Provider this config targets (multi-provider DCP). |
| `is_protected_pmi` | boolean · null | Whether protected-PMI handling is on. |
| `protected_transition_end_time` | timestamptz · null | End of the protected-PMI transition window. |
| `providers` | jsonb · null | Per-provider settings payload (multi-provider DCP). |

Keys / indexes: `u:jump_page_settings_pkey(dcp_id)`

#### `jump_page_languages`
Per-language jump-page copy for a DCP.

| Column | Type | Usage |
|---|---|---|
| `company_id` | bigint · PK | Tenant. |
| `dcp_id` | bigint · PK | The DCP. |
| `language` | character · PK | Language code. |
| `is_default` | boolean | Marks the default language for the DCP. |
| `explain_text` | text | Localized explanatory copy. |
| `policy_text` | text | Localized policy text. |
| `use_policy_link` | boolean | Whether to show a policy link in this language. |
| `policy_link` | text | Localized policy URL. |
| `policy_link_title` | character | Localized policy link label. |
| `create_date_time` | timestamp | Audit insert time (no zone). |
| `update_date_time` | timestamp | Audit update time (no zone). |

Keys / indexes: `u:jump_page_languages_pkey(company_id,dcp_id,language)`

#### `jump_page_profile_key`
Opaque profile keys used to address a DCP's jump page publicly.

| Column | Type | Usage |
|---|---|---|
| `id` | bigint · PK | Surrogate key. |
| `company_id` | bigint | Tenant. |
| `profile_key` | character · null | Public-facing key mapping to a DCP jump page. |
| `create_date_time` | timestamp | Audit insert time (no zone). |

Keys / indexes: `u:jump_page_profile_key_pkey(id)`

#### `jump_page_profile_key_history`
History linking DCPs to profile keys, tracking the current mapping.

| Column | Type | Usage |
|---|---|---|
| `company_id` | bigint | Tenant. |
| `dcp_id` | bigint | The DCP. |
| `profile_key_id` | bigint | The `jump_page_profile_key.id`. |
| `is_current` | boolean | Marks the active key for the DCP. |
| `create_date_time` | timestamp | Audit insert time (no zone). |
| `update_date_time` | timestamp | Audit update time (no zone). |

Keys / indexes: `u:jump_page_profile_key_history_dcp_id_current_unique_idx(company_id,dcp_id)` · `u:jump_page_profile_key_history_dcp_id_profile_key_id_unique_idx(company_id,dcp_id,profile_key_id)`

#### `audio_prompt_settings`
Per-DCP audio-prompt (verbal compliance announcement) configuration. See [[Audio Prompt]].

| Column | Type | Usage |
|---|---|---|
| `dcp_id` | bigint · PK | The DCP. |
| `company_id` | bigint | Tenant. |
| `compliance_announcement_id` | bigint · null | The announcement audio asset to play. |
| `compliance_announcement_for_all_participants` | boolean | Play to all participants vs. some. |
| `compliance_announcement_only_if_not_join_page` | boolean | Suppress the prompt when the jump page already handled consent. |
| `create_date_time` | timestamp | Audit insert time (no zone). |
| `update_date_time` | timestamp | Audit update time (no zone). |
| `last_disabled_user_id` | bigint · null | Last user who disabled the prompt. |
| `last_disabled_time` | timestamptz · null | When it was last disabled. |

Keys / indexes: `u:audio_prompt_settings_pkey(dcp_id)`

#### `consent_email_settings`
Per-DCP consent-email settings (current state; history lives in `recording_consent_email.consent_email_settings_history`).

| Column | Type | Usage |
|---|---|---|
| `dcp_id` | bigint · PK | The DCP. |
| `company_id` | bigint | Tenant. |
| `is_enabled` | boolean | Whether consent email is enabled. |
| `consent_type` | data_capture.consent_type · null | Enum: consent model. |
| `send_time_before_seconds` | integer · null | Lead time before the call to send. |
| `show_company_logo` | boolean · null | Whether to show the logo. |
| `logo_url` | character · null | Logo URL. |
| `company_name` | text | Company name in the email. |
| `privacy_policy_link` | character | Privacy-policy URL. |
| `email_text` | text · null | Email body copy. |
| `landing_page_text` | text | Landing-page copy. |
| `create_date_time` | timestamptz | Audit insert time. |
| `update_date_time` | timestamptz | Audit update time. |

Keys / indexes: `u:consent_email_settings_pkey(dcp_id)`

#### `pre_call_email_settings`
Per-DCP settings for the pre-call compliance email. See [[Confirmation Email (LA)]].

| Column | Type | Usage |
|---|---|---|
| `dcp_id` | bigint · PK | The DCP. |
| `company_id` | bigint | Tenant. |
| `send_compliance_emails` | boolean | Whether to send pre-call compliance emails. |
| `compliance_email_legal_footnote` | text · null | Legal footnote copy. |
| `privacy_policy_link` | text · null | Privacy-policy URL. |
| `create_date_time` | timestamp | Audit insert time (no zone). |
| `update_date_time` | timestamp | Audit update time (no zone). |
| `language_tag` | character | Language of the email. |
| `show_company_logo` | boolean | Whether to show the logo. |
| `logo_url` | character · null | Logo URL. |
| `email_subject` | text · null | Subject line. |
| `email_sender` | text · null | Sender identity. |
| `email_opening` | text · null | Opening copy. |
| `email_signature_and_legal_footnote` | text · null | Combined signature + footnote copy. |
| `email_signature` | text · null | Signature copy. |
| `legal_footnote` | text · null | Legal footnote copy. |
| `company_name` | text · null | Company name shown. |

Keys / indexes: `u:pre_call_email_settings_pkey(dcp_id)`

---

## `recording_consent_timed_events` DB → schema `event_based_tasks`

The **only** schema migrated inside `gong-data-capture` (`RecordingConsentTasks/.../recording_consent_timed_events/db/migration/`). Accessor: `RecordingConsentTimedEventsDb`. Physical (local): **`recording_consent_timed_events_dev`**. A deferred/time-based event queue: rows are scheduled and, when `when_to_run` is reached, emitted to `out_topic`. Source: `V20220615_1200__create_events_table.sql`; RLS added in `V20231121_1006`.

#### `events`

| Column | Type | Usage |
|---|---|---|
| `id` | text · PK | Unique event id (caller-supplied, dedup key). |
| `company_id` | bigint · null | Tenant. |
| `event_type` | text · null | Logical type of the deferred event. |
| `out_topic` | text · null | Kafka topic to emit to when due. |
| `out_key` | text · null | Kafka message key to emit. |
| `out_value` | text · null | Kafka message payload to emit. |
| `when_to_run` | bigint · null | Epoch time at which the event should fire. |
| `create_date_time` | timestamp | Insert time (`default now()`). |
| `update_date_time` | timestamp | Last-modified time (`default now()`). |
| `retry_count` | smallint | Emission retry counter (`default 0`). |
| `original_requested_event_time` | timestamptz · null | Originally requested fire time (before any rescheduling). |

Keys / indexes: `u:events_pkey(id)` · `i:when_to_run_with_event_type_index(when_to_run,event_type)`

---

## See also

- [[05 - Data Access & Storage]] — datasources → schemas → table names, DAOs, tenancy, logical→physical mapping
- [[Storage & Schema Reference]] — lighter subsystem inventory
- [[06 - Local Dev Seed Data]] — seeding these tables locally
- [[Subsystems/Consent/Canvas/Data Stores/DataStore-PostgreSQL|PostgreSQL chip]]
