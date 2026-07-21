---
title: Consent — New Engineer FAQ
tags: [consent, recording-consent, onboarding, faq, new-engineer]
created: 2026-07-20
aliases:
  - consent faq
  - new to consent
  - consent onboarding q&a
---

# 07 · New Engineer FAQ

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · [[03 - Ubiquitous Language]]

> [!note] Who this is for
> You just joined the Consent / Data Capture team and the domain is unfamiliar. These are the questions every new engineer asks in the first two weeks, answered from the code — not the marketing pitch.

---

## Domain & Business Context

**Q: What are the five ways Gong collects consent? I keep seeing different mechanisms mentioned.**

| Mechanism | Timing | Who sees it |
|---|---|---|
| **Consent page (jump page)** | Before joining — participant clicks the meeting link | External participant at join time |
| **Audio prompt** | At call start — bot plays a verbal notice | Everyone in the call |
| **Pre-call consent email** | 10–20 min before the meeting | External invitees |
| **Confirmation email (LA)** | 24/48/72h before the meeting | Calls ingested via assistant with a non-org organiser |
| **Native Zoom consent** | At recording start / participant join | Zoom handles it; Gong's audio prompt does not apply |

They are not mutually exclusive. A company might use the jump page (gate at join) and the audio prompt (in-call notice) together. See [[00 - Overview]] for the full picture, [[Audio Prompt]] and [[Confirmation Email (LA)]] for the two mechanisms with no dedicated notes previously.

---

**Q: What exactly is "Consent" and why does it exist?**

When a Gong rep records a meeting, some jurisdictions and company policies require that the other participants (customers, prospects) are told they're being recorded *before* the recording starts. Consent's job is to enforce that: intercept the participant before they enter the meeting room, show them a disclosure page, and either let them in (and allow recording) or flag that they declined (and suppress recording).

The subsystem also sends pre-call consent emails — some companies prefer to notify participants by email days before the call rather than at the join link.

---

**Q: What meeting providers does Consent support?**

Consent is provider-aware but not provider-specific. The canonical list lives in
`WebConferencing/.../identifiers/all/`: Zoom, Microsoft Teams, Cisco WebEx, Google Meet,
GoToMeeting, BlueJeans, RingCentral (Meetings + Video), Skype for Business, Join.me,
ClearSlide, Appointlet, Gong hardware device, and a fallback `DummyIdentifier`.

Provider identity flows through the system as a `String` code (via `Identifier.Descriptor#byCode`).
Two constants exist on `Identifier`: `ZOOM_CLOUD_PROVIDER_CODE` and `WEBEX_CLOUD_PROVIDER_CODE`.

---

**Q: Can a single DCP cover both Zoom and Teams simultaneously?**

Yes. `DcpJumpPageSettings.providers` is a `List<DcpJumpPageSettingsProvider>` — one element per
supported provider within that profile. Each element has its own `linkType` (PMI/Dynamic/OnlyDynamic)
and `recordingOptOut` (Explicit/Implicit), so Zoom and Teams can have different consent settings
within the same company policy.

For multi-provider profiles, `MultipleProviderJumpPageUrlService` generates one jump-page URL per
provider by appending `?provider=<code>`. When the participant arrives, `JumpPageController` reads
that query param and loads the correct provider's settings from `DcpJumpPageUrlSettings`.

See [[Meeting Providers & Multi-Provider DCP]] for the full model.

---

**Q: What is a DCP? I see it everywhere.**

**Data Capture Profile** — the company-level policy object. It answers: "Does this company require consent? Which providers (Zoom, Teams, Webex) are covered? What happens if a participant declines? What logo/language do they see?" Every jump-page URL contains a `profileKey` that picks which DCP applies.

See [[Jump Page & DCP]] for the full field breakdown.

---

**Q: What's the difference between a "jump page" and a "consent page"?**

Same thing, two names. **Jump page** is the code name (~2,183 uses in ~50 files). **Consent page** is what you'd say to a customer. Stick to "jump page" in code and tickets; say "consent page" in Slack to non-engineers.

---

**Q: What does "PMI" vs "dynamic" mean?**

| | PMI | Dynamic |
|---|---|---|
| URL | Never changes | New URL per scheduled meeting |
| URL segments | `profileKey/userKey` (2 segments) | `profileKey/userKey/meetingKey` (3 segments) |
| Use case | Rep has one personal room | Per-meeting page with specific settings |

`JumpPageUrlService.isPmiJumpPageUrl()` / `isOnetimeJumpPageUrl()` distinguish these at runtime based on segment count.

---

**Q: Who sends the jump-page URL to the participant? Does Consent do that?**

No. Consent *generates and stores* the URL. The URL is embedded in calendar invites by **Call Scheduling** (which calls `JumpPageUrlService` to build it). Consent never sends the URL itself — it just serves the page when the URL is hit.

---

## Architecture & Services

**Q: How many deployable services are there? What does each own?**

Five services, all in `gong-data-capture`:

| Service                     | Port | Public? | Core job                                                                     |
| --------------------------- | ---- | ------- | ---------------------------------------------------------------------------- |
| `MeetingFrontEnd`           | 8098 | **Yes** | Serves the jump page and consent-email landing page to external participants |
| `RecordingConsentApiServer` | 7254 | No      | DCP settings CRUD API; called by other Gong services                         |
| `RecordingConsentTasks`     | 9095 | No      | Kafka consumers + ~20 scheduled tasks (emails, Redis warming)                |
| `DcpChangeManager`          | 8121 | No      | Orchestrates DCP settings changes across all users via a state machine       |
| `ConsentWebApi`             | —    | Yes     | MS Teams attendance report downloads only                                    |

Plus a pile of **shared model / service code in the honeyfy monolith** (`ConsentProfile`, `RecordingCompliance`, `AppCommon`, `DataCaptureProfile`) that the above five services import. When you see `HF/` prefixed classes in docs, that's where they live.

---

**Q: Why is consent logic split between `gong-data-capture` and `honeyfy`?**

Historical growth. The domain model (entities, DAOs, core services) evolved in the honeyfy monolith first. When the web-facing and async-processing services were extracted into `gong-data-capture`, they imported the existing monolith code rather than duplicating it. You'll find yourself editing both repos for most feature work.

---

**Q: Does Consent use Feign clients?**

Mostly no — and this is a gotcha. Despite consuming honeyfy services, Consent uses **plain honeyfy HTTP client classes** (not `@FeignClient`). The two outbound HTTP callers are:

- `RecordingSupervisorClient` — tells the recorder to allow/suppress recording after a consent decision
- `FeatureFlagsClient` — feature-flag polling

There are zero `@FeignClient` annotations anywhere in `gong-data-capture`. See [[02 - Data Flow]] §6 for the verified list.

---

**Q: How do scheduled tasks work? I don't see `@Scheduled` anywhere.**

All scheduled tasks use a **`DistributedScheduledTaskExecutor`** — a programmatic `@Bean ScheduledTask` backed by a distributed lock in Postgres (`scheduled_tasks_01/02` DBs). There is no `@Scheduled` or `@EnableScheduling`. Look for `ScheduledTask` bean declarations in config classes (e.g. `RecordingConsentTasksConfig.java`).

This means: if `scheduled_tasks_01/02_dev` aren't Flyway-migrated locally, **zero scheduled tasks run** — including the 1-minute consent-email sender.

---

**Q: How does Consent communicate async changes back to the recorder?**

Via Kafka. `JumpPageController` publishes a `JumpPageInteractionEvent` to `audit-meeting-consent` (cluster `RECORDING_CONSENT`, keyed by `companyId`). `AuditMeetingConsentConsumer` picks it up in `RecordingConsentTasks` and writes the audit trail. The **synchronous** path to the recorder is `RecordingSupervisorClient#restrictCallRecording` — called inline by `JumpPageController` before the Kafka publish.

---

**Q: What is `DcpChangeManager` and when does it activate?**

It's a state machine that propagates a DCP settings change (e.g. "company X just enabled consent") across every affected user. When a company changes its DCP profile, `ChangeRequestLifecycle` fans work out:

```
new change request
    → produce batch-users-change-executor  (fan to all users)
    → per user: produce single-user-change-executor
    → per user done: produce single-user-change-request-done
    → after all users: reset company Redis cache
```

It only activates on a DCP **settings change event** (`change-request-executor` topic, cluster `DATA_CAPTURE`). Normal jump-page renders don't touch it.

---

## Data & Storage

**Q: What database does Consent own?**

The `recording_consent` Postgres database, with three schemas:

| Schema | Owns |
|---|---|
| `recording_consent_settings` | Per-user consent settings, user provider defaults, calendar-event mirror |
| `recording_consent_email` | Pre-call consent email state (the email itself, audit, obfuscation keys) |
| `recording_compliance` | Audit trail: every jump-page session, every interaction decision, stop-recording audits |

There's also `recording_consent_timed_events` (its own DB) for the `TimeBasedEventsScheduler`, and `data_capture_dev` for DCP change-request state (`dcp_change` schema, owned by `DcpChangeManager`).

See [[Storage & Schema Reference]] and [[05 - Data Access & Storage]].

---

**Q: Why isn't there a `recording_consent` table in the `recording_consent_settings` schema?**

The schema holds the *settings* (per-user provider defaults, app-user consent flags, calendar event mirrors) not the profile definition itself. The DCP profile entity (`DcpJumpPageSettings`) lives in `honeyfy_dev.data_capture.profile` (operational DB), not in the `recording_consent` database.

---

**Q: What's in Redis and why does it matter for the jump page?**

Redis is the **hot path** for rendering the consent page — when a participant loads the URL, `JumpPageController` reads `DcpJumpPageUrlSettings` directly from Redis without touching Postgres. This means: if Redis is cold or stale, participants get wrong/missing consent pages. Redis is warmed every 5 minutes by `PopulateDcpJumpPageRedisTask` and invalidated on DCP changes via `reset-consent-redis-for-company`.

The logical DB is `RECORDING_COMPLIANCE` in code (confusingly, the descriptor names it `CONSENT_REDIS`).

---

**Q: Where does the consent-email data live vs the jump-page data?**

| Data type | Schema | Key tables |
|---|---|---|
| Jump-page audit | `recording_compliance` | `jump_page_session`, `jump_page_interaction` |
| Consent email content & history | `recording_consent_email` | `consent_email`, `audit`, `company_obfuscation`, `history` |
| Per-user consent settings | `recording_consent_settings` | `appuser_consent_settings`, `user_settings` |
| Calendar event mirror | `recording_consent_settings` | `calendar_event` |

---

## Flows & User Interactions

**Q: Walk me through what happens when a participant clicks the join link in their email.**

```
1. Browser GETs /{profileKey}/{userKey}[/{meetingKey}]
       → JumpPageController#viewJumpPage (MeetingFrontEnd :8098)

2. Controller looks up DcpJumpPageUrlSettings from Redis
       (no DB hit in the normal path)

3. Thymeleaf template renders the consent HTML
       (company logo, disclosure text, Accept / Decline buttons)

4a. Participant clicks Accept
       → POST /{profileKey}/{userKey}[/{meetingKey}]
       → JumpPageController#acceptAnswer
       → RecordingSupervisorClient#restrictCallRecording  (sync HTTP — allow recording)
       → publishes JumpPageInteractionEvent on audit-meeting-consent
       → HTTP 302 redirect → real Zoom/Teams/Webex URL

4b. Participant clicks Decline
       → POST /{profileKey}/{userKey}[/{meetingKey}]/skip-answer
       → JumpPageController#skipAnswer
       → same Kafka event, denied_recording = true
       → recording suppressed

5. AuditMeetingConsentConsumer (RecordingConsentTasks) picks up the Kafka event
       → writes recording_compliance.jump_page_session
       → writes recording_compliance.jump_page_interaction
```

---

**Q: How does a participant receive a pre-call consent email instead of a jump-page URL?**

Some DCP profiles are configured to send an email before the meeting rather than (or in addition to) the jump-page URL. The flow:

1. Call Scheduling produces `call-scheduling-updated`
2. `ConsentCallSchedulingUpdatedConsumer` (HF/ConsentProfile) reacts
3. `DcpConsentEmailSchedulingService#handleEvent` schedules an email job
4. `ConsentEmailsTasks` scheduled task (runs every 1 min) drains the queue
5. `PreCallEmailService#sendEmail` → `MailgunEmailSender` → participant inbox
6. Participant clicks link in email → lands on consent-email landing page served by `ConsentEmailController` on `MeetingFrontEnd` (separate controller from `JumpPageController`)

---

**Q: What happens when a company changes its DCP settings? Does it affect participants mid-meeting?**

No mid-meeting impact. The change flows through `DcpChangeManager`:

1. A DCP settings change fires `change-request-executor`
2. `DcpChangeManager` runs through the `ChangeRequestLifecycle` state machine per user
3. Concrete actions: `CancelNonCompliantCallsAction` (cancels already-scheduled calls that are now non-compliant), `ConsentEmailSettingsChangeAction` (updates email settings), `SyncMeetingPmiAction` (syncs the PMI meeting URL)
4. When done, `reset-consent-redis-for-company` flushes Redis — next page render picks up new settings

---

**Q: What does Consent do when a meeting is cancelled?**

It listens for `call-scheduling-updated` events with a cancellation payload. `ConsentCallSchedulingUpdatedConsumer` routes to `DcpConsentEmailSchedulingService#handleEvent`, which marks the related consent email as obsolete (`isEmailIdObsolete = true` on `ConsentEmailCall`). No jump-page state is changed — cancellation is an email concern, not a page concern.

---

## Local Dev

**Q: How do I get the consent subsystem running locally?**

The short answer: seed the same six-row operational base that Call Scheduling uses (company 9001, user 501, profile 2001 in `honeyfy_dev`), Flyway-migrate the consent DBs, then start the services and trigger a flow.

See [[06 - Local Dev Seed Data]] — it has the exact SQL verification queries and failure-mode table.

> [!warning] Consent has no seed scripts
> Unlike some subsystems, Consent's owned tables populate only when flows run — there is nothing to `INSERT` up front. The tables fill when you hit endpoints or produce Kafka events.

---

**Q: Which service do I start first? Do they depend on each other?**

They're loosely coupled via Kafka and Postgres. For the jump-page flow you only need `MeetingFrontEnd` (`:8098`) up. For consent emails you also need `RecordingConsentTasks` (`:9095`). `DcpChangeManager` (`:8121`) is only needed if you're testing DCP settings changes. `RecordingConsentApiServer` (`:7254`) is needed for DCP settings reads/writes.

---

**Q: How do I trigger the jump-page flow without a real calendar invite?**

Hit `MeetingFrontEnd` directly:

```
GET http://localhost:8098/{profileKey}/{userKey}
```

You need a valid `profileKey` and `userKey` in Redis. If Redis is cold, warm it:

```
POST http://localhost:9095/troubleshooting/dcp-jump-page-redis/populate-company?company-id=9001
```

Then load the URL in a browser. The consent page renders, and clicking Accept/Decline will fire the full Kafka → audit-trail flow.

---

**Q: The `calendar_event` table is empty. What's wrong?**

Almost certainly `RecordingConsentTasks` (`:9095`) is not running or hasn't received a `call-scheduling-updated` event. That table is populated only when `ConsentCallSchedulingUpdatedConsumer` fires — which requires Call Scheduling to have produced the event. Run the Call Scheduling flow first (see [[Subsystems/Call Scheduling/06 - Local Dev Seed Data]]), confirm the Kafka event was produced, and check `RecordingConsentTasks` logs.

---

**Q: Why are my scheduled tasks not running locally?**

`scheduled_tasks_01_dev` and `scheduled_tasks_02_dev` are probably not Flyway-migrated. The `DistributedScheduledTaskExecutor` takes a Postgres lock in those DBs before every scheduled task — if the schema doesn't exist, no lock, no task execution. Migrate them via:

```bash
mvn -f honeyfy/Schema/pom.xml \
  org.flywaydb:flyway-maven-plugin:migrate@scheduled_tasks_01 \
  -Dflyway.url="jdbc:postgresql://host.docker.internal:5432/scheduled_tasks_01_dev" \
  -Dflyway.locations="classpath:com/honeyfy/migration/common,filesystem:<ABS>/db/migration"
```

See [[Flyway Migrations at Gong]] for the full command reference.

---

## Gotchas & Surprises

**Q: I grep for `@FeignClient` in `gong-data-capture` and find nothing. Is there no service-to-service communication?**

There is — via plain honeyfy client classes, not Feign. `RecordingSupervisorClient` and `FeatureFlagsClient` are custom HTTP clients, not `@FeignClient` annotated interfaces. This is a divergence from the rest of Gong's service-to-service pattern.

---

**Q: The Redis logical DB is called `RECORDING_COMPLIANCE` in Java but `CONSENT_REDIS` in the app descriptor. Which is right?**

Both are correct but refer to different layers. `RECORDING_COMPLIANCE` is the Java `JedisWrapper` enum value used in code. `CONSENT_REDIS` is the descriptor connection name that the infra layer maps to the actual Redis cluster. Don't let the name mismatch confuse you — they point to the same Redis.

---

**Q: I see `data_capture.profile` in two different databases. Which one?**

Two `data_capture` schemas exist:
- `honeyfy_dev.data_capture.profile` — the operational seed record (company's profile row, seeded by the Call Scheduling scripts)
- `data_capture_dev.data_capture.*` — the DCP settings backing store (written by the DCP settings API)

They serve different purposes. The seeded row in `honeyfy_dev` doesn't appear in `data_capture_dev`. See [[05 - Data Access & Storage]] §2b.

---

**Q: I changed a DCP setting and the jump page still shows the old content. Why?**

Redis cache. The page renders from Redis, not Postgres. After a DCP change, wait for `PopulateDcpJumpPageRedisTask` to run (every 5 min in prod, runs at startup) or force it via the troubleshooter endpoint:

```
POST :9095/troubleshooting/dcp-jump-page-redis/populate-company?company-id=<id>
```

---

## See also

- [[00 - Overview]] — the mental model in prose
- [[03 - Ubiquitous Language]] — DDD glossary; every class name and enum value
- [[02 - Data Flow]] — every Kafka consumer, producer, DB write, and REST endpoint
- [[Jump Page & DCP]] — URL anatomy, PMI vs dynamic, Redis layout, Kafka topics
- [[06 - Local Dev Seed Data]] — seeding and triggering flows locally
- [[05 - Data Access & Storage]] — full logical → physical DB mapping
- [[Storage & Schema Reference]] — schema-level DB map
- [[Subsystems/Call Scheduling/06 - Local Dev Seed Data]] — upstream seed (Consent reuses it)
- [[Work/Architecture/Troubleshoot Endpoints]] — what troubleshooter endpoints are, auth model, how to use them safely in prod
- [[Work/Engineering/Notes/Flyway Migrations at Gong]] — migrating local DBs
