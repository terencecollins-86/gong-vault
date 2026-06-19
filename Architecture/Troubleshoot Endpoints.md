---
title: Troubleshoot Endpoints
tags: [architecture, security, backend, troubleshooting, internal-api]
created: 2026-06-19
---

# Troubleshoot Endpoints

> Research note compiled across backend modules using the Gong Code KB and the
> internal security pattern docs. Covers: what they are, whether they run in prod,
> how they're protected, what they do, and the rules for creating them.

## TL;DR

- **What**: Internal REST endpoints used by Gong support/engineering to inspect and
  manipulate production state — reprocess meetings, fix data, manage users, run
  Elasticsearch migrations, push to CRM, etc. There are **30+ such controllers across 15+ modules**.
- **Prod?** **Yes.** They are deployed and active in production by design — they exist
  *for* debugging and operating production. They are **not** gated by `@Profile` or feature flags.
- **Auth**: Two layers — **network** (support-team VPN ingress) + **application**
  (Okta-issued JWT in the `troubleshootersAuthJWT` cookie, validated by a filter on the
  `/troubleshooting/**` path group). Authorization is path/filter-based, **not** method annotations.
- **Rules**: Yes — documented pattern in `security-encryption.md`. Use the
  `/troubleshooting/**` path prefix, depend on `BackendService`, follow the
  `Troubleshooting{Domain}Controller` naming convention. Auth is then enforced automatically.

---

## 1. What is a troubleshoot endpoint?

A troubleshoot endpoint is an internal REST controller intended for **Gong support
personnel** (not tenant end-users) to debug, reproduce, and re-trigger behavior against
production. They are conventionally:

- Placed in package `com.honeyfy.{service}.rest.troubleshooting.*` (or `.controller.troubleshooting.*`)
- Named `Troubleshooting{Domain}Controller` (or `{Domain}TroubleshooterController`)
- Registered under a `/troubleshooting/**` path (the security-relevant suffix; controllers
  are often seen registered as `/rest/troubleshooting/{domain}` where `/rest` is the
  servlet context prefix)

They differ fundamentally from production API users:

| Aspect | Production API Users | Troubleshooters |
|--------|---------------------|-----------------|
| Identity | Service or end-user within a tenant | Gong support staff (Okta-authenticated) |
| Tenant scope | Scoped to a single company | **Cross-tenant by design** |
| `companyId` | Derived from auth context | **Passed as a request parameter** (intended) |
| Field access | Restricted to authorized data | **Full schema access** via Swagger (intended) |
| Purpose | Business operations | Debugging, reproducing issues, re-triggering events |

---

## 2. Do they get deployed to production?

**Yes — they are live in production by design.**

Evidence gathered across modules:

- **No `@Profile` restriction** — none of the 20+ troubleshoot controllers examined use
  `@Profile("!production")` or dev/test-only profiles.
- **No `@ConditionalOnProperty` gate** on the controllers themselves (one exception:
  `TasksTroubleshooter` in gong-smart-trackers is gated on `PINECONE_ENABLED_PROPERTY`,
  but that's a feature dependency, not a prod kill-switch).
- They are **unconditionally registered Spring beans**.
- Their entire purpose is operating/debugging **production** state.

So the answer is not "they leak into prod" — they are **intended for prod** and protected
by the auth model below.

---

## 3. What auth protects them?

Two independent layers.

### Layer 1 — Network (VPN ingress)

Troubleshoot traffic is fronted by a dedicated **support-team VPN ingress**
(`ingress-nginx-support-team-vpn`), deployed to production clusters (observed in
`gpe-us-01`, `gpe-us-02`, `gpe-us-04`, `gpe-eu-02` devops clusters). Only Gong employees
on the support VPN can reach `/troubleshooting/**`; it is not exposed to the public internet.

### Layer 2 — Application (Okta JWT, dual-auth filter chain)

Modules that depend on `BackendService` inherit a **dual-auth filter chain**. Two filters
operate on different path groups:

| Filter | Applies to | Mechanism |
|--------|-----------|-----------|
| `NonTroubleshootersAuthorizationFilter` | Production endpoints (everything not excluded) | Service-to-service JWT (ES256) |
| `TroubleshootersAuthenticationFilter` | `/troubleshooting/**`, `/actuator/**` | Okta JWT via `troubleshootersAuthJWT` cookie |

> **Key principle:** excluded from standard auth ≠ unauthenticated. The `/troubleshooting/**`
> paths are excluded from the *service* filter because they have their *own* (Okta) filter.

**Authentication flow:**

1. User authenticates with **Okta** via DevDataGateway (`OAuth2AuthorizedConfig`).
2. DevDataGateway generates a signed JWT (`TroubleshootersAuditRequestService`) containing:
   email, Okta authorities/groups, authorized modules, troubleshooter type, `companyId`,
   `userId`, and **`jiraId`** (audit trail link). Signed with an RSA private key from AWS
   Secrets (`troubleshooters-audit-private/private-key`). TTL: 8 hours.
3. User is redirected to the target module at `/authorize-troubleshooters?jwt=<TOKEN>`.
4. `TroubleshootersAuthorizationController` validates the JWT against the public key
   (`troubleshooters-audit/public-key`), checks module access, and sets an **HttpOnly**
   cookie `troubleshootersAuthJWT` (TTL: 48 hours).
5. Subsequent requests to `/troubleshooting/**` are authenticated by
   `TroubleshootersAuthenticationFilter` (extracts + validates the cookie JWT).
6. `TroubleshooterAuthorityFilter` performs additional role-based authorization
   (e.g. `Team.CREDENTIALS_MANAGER` for secrets endpoints).

**Spring Security config** (`BackendModuleSpringSecurityConfig`, when
`...spring.security.extended=true`):
- `/authorize-troubleshooters/**` → `permitAll` (controller validates JWT internally)
- `/troubleshooting/**` → `authenticated`
- `/actuator/**` → `authenticated`

**Important:** authorization is enforced by the **filter on the path**, *not* by method
annotations. Troubleshoot controllers generally have **no** `@PreAuthorize` / `@Secured` /
`@RolesAllowed` / `@InternalApi`. Adding the controller under `/troubleshooting/**` in a
`BackendService`-dependent module is what makes it secure.

#### Key implementation classes

- `BackendService/.../config/filter/TroubleshootersAuthenticationFilter.java`
- `BackendService/.../config/filter/custom/TroubleshooterAuthorityFilter.java`
- `BackendService/.../config/filter/NonTroubleshootersAuthorizationFilter.java`
- `BackendService/.../config/filter/BackendModuleExcludedRequestPredicate.java`
- `BackendService/.../troubleshooters/rest/TroubleshootersAuthorizationController.java`
- `BackendService/.../config/BackendModuleSpringSecurityConfig.java`
- `BackendService/.../service/ModuleValidator.java`
- `gong-dev-gateways/DevDataGateway/.../service/TroubleshootersAuditRequestService.java`
- `gong-dev-gateways/DevDataGateway/.../config/OAuth2AuthorizedConfig.java`

---

## 4. What actions do the endpoints take?

Grouped by behavior. (Full per-module inventory in the appendix.)

**Read state / inspect (diagnostic):**
health checks, certificate listing, CRM mappings/settings, ES index & Redis metadata,
long-running task status, integration versions & OAuth client IDs, encryption-key &
storage metadata, RAG pipeline debugging (retrieval/reranker/prompt inspection).

**Mutate data (create/update/delete):**
CRM engagements (HubSpot emails/tasks/calls/meetings, LinkedIn messages), CRM field
updates, custom-object mappings, contact-provider data deletion, AI fields
(save/publish/unpublish/delete), compliance restrictions, meeting/call metadata
(call IDs, statuses, external IDs, recording types), Zoom global-app mappings,
recording settings (recording type, Zoom plan, UBU conversion), integration/app-catalog
versions, dashboards/metrics/forecast boards, sequences, bookings/plans (CSV upload),
user management (enable/disable, permissions, timezone, home workspace), smart-tracker
model state.

**Trigger reprocessing / jobs:**
meeting reprocessing (Zoom/Webex, single & bulk), chat-file & timeline reprocessing,
deal-stage participant collection, AI-fields sync, forecast week recalculation,
sequence-step formatting, activity-store backfill, smart-tracker workers
(dataset creation, supervision, opt-in, tracker activation), ES migrations
(schedule, run next step, move tenants).

**Reset cache / infra:**
ES reader-alias rebuild, Redis metadata cache clearing, ES task cancellation,
Webex credential refresh.

> ⚠️ Note: some endpoints execute **arbitrary REST calls with company/user context**
> (e.g. `CloudRecorderTroubleshootingController.executeRestCall` / `executeRestCallForUser`)
> and bulk operations from uploaded CSVs. These are powerful — the VPN + Okta + Jira-linked
> audit model is what justifies them.

---

## 5. Rules & guidance for creating them

Official guidance **exists** and lives in
`gong-ai4dev/docs/java/patterns/security-encryption.md` (Authentication & Authorization section).

| Aspect | Rule |
|--------|------|
| **Path prefix** | Register under `/troubleshooting/**` — **required** for the auth filter to apply. |
| **Module dependency** | Service must depend on `BackendService` (directly or via parent POM) to inherit the dual-auth filter chain. |
| **Authentication** | Okta JWT via `troubleshootersAuthJWT` cookie — enforced automatically by path, no per-method security code needed. |
| **Controller annotations** | Standard `@RestController` + `@RequestMapping("/troubleshooting/{domain}")`. No shared base class. |
| **Package** | `com.honeyfy.{service}.rest.troubleshooting.*` or `.controller.troubleshooting.*`. |
| **Class naming** | `Troubleshooting{Domain}Controller`. |
| **Production** | Allowed and expected — designed for production debugging. |
| **Authorization model** | Cross-tenant by design; pass `companyId` as a parameter. |

### Security-review implications (documented)

- Cross-tenant access on troubleshoot endpoints is **not a vulnerability** — it's intended.
- **Mass assignment (CWE-915)** findings are typically **false positives** here:
  troubleshooters intentionally have full request-schema access via Swagger.
- CVSS: **PR=L** (requires authenticated Okta user with module access + Okta group membership).
- Don't inflate CVSS VC/VI/SC/SI for cross-tenant access — it's authorized for this user class.

### Multi-module caveat

In multi-module Maven projects, `BackendService` may be declared in the **parent POM**.
A module's own `pom.xml` might only list `BaseServer` while still inheriting the
`BackendService` security filters. Check **both** the module POM and the parent POM when
verifying the auth chain applies.

### Gaps / not formally documented

- No formal **approval/security-review checklist** for adding a new troubleshoot endpoint.
- No written guidance on **what belongs** in a troubleshoot endpoint vs. a regular API.
- Confluence was **not reachable** during this research — there may be additional
  team-level guidance in the EN / DevOps / AppSec spaces worth checking
  (search: "troubleshoot endpoint", "BackendService security", "DevDataGateway").

---

## Appendix — Per-module endpoint inventory

> Paths shown as observed in controllers (servlet prefix `/rest`); the security-relevant
> match is the `/troubleshooting/**` suffix. Action tag in parentheses.

**gong-logs-and-metrics (Watchdog)** — `TroubleshootingInterModuleRestAccess` `/rest/troubleshooting`:
`POST /healthCheck` (read), `GET /listLocalCertificates` (read).

**gong-crm-enrichment (CrmEnricher)**
- `TroubleshootingHubspotEngagementController` `/rest/troubleshooting/hubspot`: create/delete HubSpot emails, LinkedIn messages, tasks, calls, meetings (mutate CRM).
- `TroubleshootingEnrichSettingsController` `/rest/troubleshooting/enrich-settings`: align/delete workspace settings, push-flow/custom-object/dialer settings, bulk CSV inserts (mutate settings).
- `TroubleshootingPushToCrmController` `/rest/troubleshooting/push-to-crm`: push contacts/activity/custom steps, field updates, activity-store backfill (mutate CRM / reprocess).
- `TroubleshootingCustomObjectMappingController` `/rest/troubleshooting/custom-object-mapping`: upsert mapping (mutate), get reference field (read).

**gong-persons (PersonRecommender)** — `TroubleshootingRecommendedContactsController` `/rest/troubleshooting/recommended-contacts`:
collect deals/model-title data (reprocess), purge/delete contact-provider data (mutate).

**gong-cards (CardManager)** — `TroubleshootingAiFields` `/rest/troubleshooting/ai-fields`:
save/get/publish/unpublish/delete AI fields, smart-tracker details, `syncAiFieldsV1` (mutate / reprocess).

**gong-cloud-recorders (CloudRecorder)**
- `CloudRecorderTroubleshootingComplianceController` `/rest/troubleshooting/cloud-recorder/compliance`: room/meeting restrictions get/add/delete (read/mutate).
- `CloudRecorderTroubleshootingController` `/rest/troubleshooting/cloud-recorder`: reprocess meetings (single/bulk), chat/timeline reprocess, **executeRestCall(ForUser)**, set call ID/status/external IDs (reprocess/mutate/debug).
- `CloudRecorderTroubleshootingGlobalAppsController` `/rest/troubleshooting/cloud-recorder/global-apps`: Zoom global-app mappings add/delete/get (mutate/read).
- `CloudRecorderTroubleshootingSettingsController` `/rest/troubleshooting/cloud-recorder/settings`: recording settings get/set, Zoom plan, UBU conversion, verification checks (read/mutate).
- `WebexCloudRecorderTroubleshootingController` `/rest/troubleshooting/webex-cloud-recorder`: refresh credentials, recording type, send call to Kafka/preprocessor, owner details (refresh/reprocess/mutate).

**gong-collective**
- `TroubleshootingCompanyIntegrationsServiceRestController` `/rest/troubleshooting/company-integrations`: app-version create/update/status, installable versions (mutate/read).
- `TroubleshootingAppCatalogDirectory2` `/rest/troubleshooting/app-catalog-directory`: create/update REST/OpenIn/OAuth integration versions, install actions, activation points (mutate).
- `TroubleshootingIntegrationService` `/rest/troubleshooting/integration-service`: telephony/app-version & OAuth client lookups, activation points, install actions (read).

**gong-controllers (CloudStorageControllerServer)** — `TroubleshootingController` `/rest/troubleshooting/cloud-storage-controller`:
get company-owned key data, storage metadata (read).

**gong-conversations (ConversationResearcherApiServer)** — `AskAnythingOnAllCallsTroubleshooter` `/rest/troubleshooting/ask-anything-on-all-calls`:
RAG pipeline debugging — question expansion, retrieval, reranker, answer-gen input, prompt content (read/debug).

**gong-dashboards (RevenueAnalyticsApi)** — `TroubleshootingController` `/rest/troubleshooting/revenue-analytics`:
dashboard layout fix, move demo configs, public-restriction apply, metric update/delete, foundation permissions (mutate).

**gong-deals-and-forecast (ForecastDigester)** — `TroubleshootingForecast` `/rest/troubleshooting/forecast`:
shadow-board warnings/fixes, delete forecast setup/board/history, recalculate week numbers (mutate/reprocess).

**gong-elasticsearch (ElasticSearchController)**
- `TroubleshootingElasticsearchController` `/rest/troubleshooting/elasticsearch`: rebuild reader aliases, delete obsolete indices, ripen/run deletions, cluster/node status (mutate-infra/read).
- `TroubleshootingMetadataController` `/rest/troubleshooting/elasticsearch/metadata`: reader/writer metadata get/list/clear, Redis existence checks (read/reset-cache).
- `TroubleshootingMigrationsController` `/rest/troubleshooting/elasticsearch/migrations`: schedule migrations/recreations/tenant moves, run next step, reindex/migration status (reprocess/read).
- `TroubleshootingTasksController` `/rest/troubleshooting/elasticsearch/tasks`: long-running task queries, task tree, cancel task (read/mutate-infra).

**gong-engage (ProspectingManager)** — `TroubleshootingSequences` `/rest/troubleshooting/sequences`:
delete/bulk-delete sequences, starter flows, format steps, unassign sequences/flows, status updates (mutate/reprocess).

**gong-enterprise-custom-data (CustomerDataServer)**
- `BookingTroubleshooterController` `/rest/troubleshooting/bookings`: publish bookings, CSV upload (mutate). `@EvaluateForTenant`.
- `PlanTroubleshooterController` `/rest/troubleshooting/plans`: publish plans, CSV upload (mutate). `@EvaluateForTenant`.

**gong-user-management (BackofficeManager)** — `TroubleshootingUserService` `/rest/troubleshooting/user-service`:
enable/disable users, recording flags, timezone, settings/extensions/permission-profiles/home-workspace (often from CSV) (mutate).

**gong-smart-trackers (SmartTrackers)** — `TasksTroubleshooter` `/rest/troubleshooting/tasks` (gated by `@ConditionalOnProperty(PINECONE_ENABLED_PROPERTY)`):
dataset-creation/supervision/opt-in/tracker-activation workers, reset retry counts, retrain model, training status, running/zombie tasks (trigger-job/mutate/read).

**gong-call-schedulers (CallScheduler)** — `TroubleshootingRecordingSettings` `/rest/troubleshooting/recording-settings`:
update Teams bot robot name (mutate settings).

---

*Sources: Gong Code KB (code + infra topology), `gong-ai4dev/docs/java/patterns/security-encryption.md`. Confluence not accessible at time of writing.*
