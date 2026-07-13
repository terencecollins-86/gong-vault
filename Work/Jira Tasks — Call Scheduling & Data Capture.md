---
title: Jira Tasks — Call Scheduling & Data Capture
tags: [jira, tasks, call-scheduling, data-capture, consent, backlog, reference]
created: 2026-07-13
---

# Jira Tasks — Call Scheduling & Data Capture

> [!note] Snapshot
> Open/active Jira issues (status category ≠ Done) for the **gong-call-schedulers** and
> **gong-capture-data** (Data Capture / Consent) subsystems, pulled from `gongio.atlassian.net`
> on **2026-07-13**. This is a point-in-time snapshot — Jira is the live source of truth.

> [!warning] How these were matched — read before trusting the list
> Neither subsystem uses Jira **components** or **labels** (both are empty on every matching
> ticket), so there is no clean structured filter. These lists come from **text + summary search**
> in the `GONG` project. I kept only issues whose **summary** names the subsystem (a distinctive
> class, feature, or the repo) — that's the high-confidence set below. Broad text-only matches
> (tickets that merely mention "consent" or "data capture" in a description — e.g. Flows, Smart
> Trackers, CRM Enrich) were **excluded** as noise. Customer-support tickets (`TKT` project) and
> infra projects (`INFRA`, `APPINFRA`, `CLOUDENG`, `DPE`) were also excluded except where an
> `APPINFRA` migration explicitly names the repo.
>
> Verify JQL / adjust scope any time — the queries used are at the bottom.

---

## 🗓️ gong-call-schedulers

| Key | Type | Status | Assignee | Summary |
|-----|------|--------|----------|---------|
| [GONG-144521](https://gongio.atlassian.net/browse/GONG-144521) | Bug | In Progress | Alaa Elias | InviteHandlerWebhooksServer: IndexOutOfBoundsException in InviteEmailRequestBeta |
| [GONG-144564](https://gongio.atlassian.net/browse/GONG-144564) | Task | In Review | Almog Roitman | Increase Zoom concurrent client slots to 8 in CallScheduler |
| [GONG-124297](https://gongio.atlassian.net/browse/GONG-124297) | Task | In Progress | Omer Vertman | Call Scheduler — add logs |
| [GONG-131220](https://gongio.atlassian.net/browse/GONG-131220) | Task | In Progress | — | StreamingAccountManagement: admin token refresh job (DF-3) |
| [GONG-124680](https://gongio.atlassian.net/browse/GONG-124680) | Task | In Progress | — | Deprecate FF → CALL_SCHEDULER_CHANGED_FROM_RECURRING_TO_NON_RECURRING |
| [GONG-148004](https://gongio.atlassian.net/browse/GONG-148004) | Bug | Ready for Development | user-journey-on-… | Home page: Call status jumps from "Setting up" directly to "Recorded" |
| [GONG-137337](https://gongio.atlassian.net/browse/GONG-137337) | Task | Ready for Development | — | Add logging to detect URL validation timeout issues in CallScheduler |
| [GONG-134934](https://gongio.atlassian.net/browse/GONG-134934) | Task | Ready for Development | — | Migrate RequestForwarder from REST to Feign |
| [GONG-147113](https://gongio.atlassian.net/browse/GONG-147113) | Epic | Ready for DEV | — | Support future meetings information in the Gong assistant |
| [GONG-143236](https://gongio.atlassian.net/browse/GONG-143236) | Sub-task | Backlog | — | APPINFRA-2268: Migrate Kafka ACL descriptors in gong-call-schedulers |
| [GONG-132795](https://gongio.atlassian.net/browse/GONG-132795) | Task | Backlog | Omer Vertman | CallScheduler — opt-in for a call already in progress should not… |
| [GONG-66817](https://gongio.atlassian.net/browse/GONG-66817) | Task | Backlog | Doron Tohar | CallScheduler \| Duplicate calls |
| [GONG-132761](https://gongio.atlassian.net/browse/GONG-132761) | Scoping | Ready for handoff | Salvatore Denaro | [Stripe] Google Chrome ext to "Make it a Gong Meeting" |
| [GONG-8409](https://gongio.atlassian.net/browse/GONG-8409) | Story | Ideation | Dani Cohen | Feature request: Add Zoom call UUID to the calls public API |

---

## 🔒 gong-capture-data (Data Capture / Consent)

### Emails-as-private / data capture settings

| Key | Type | Status | Assignee | Summary |
|-----|------|--------|----------|---------|
| [GONG-147579](https://gongio.atlassian.net/browse/GONG-147579) | Epic | Ready for DEV | Yoav Benishoo | New data capture option to set emails as private |
| [GONG-118299](https://gongio.atlassian.net/browse/GONG-118299) | Story | Ready for Development | Yoav Benishoo | New data capture option to set emails as private (BE) |
| [GONG-144640](https://gongio.atlassian.net/browse/GONG-144640) | Story | Backlog | Adi Langerman | New data capture option to set emails as private (FE) |
| [GONG-147211](https://gongio.atlassian.net/browse/GONG-147211) | Task | Ready for Development | Yoav Benishoo | WFE UI — "Set emails as private" toggle in data capture settings |
| [GONG-102685](https://gongio.atlassian.net/browse/GONG-102685) | Epic | Backlog | — | Data capture settings > Emails > "Set as private" |
| [GONG-95811](https://gongio.atlassian.net/browse/GONG-95811) | Story | Backlog | Dudi Marklovsky | Ensure data capture settings update on company downgrade to 'Call interactions' |
| [GONG-129140](https://gongio.atlassian.net/browse/GONG-129140) | Bug | Ready for Development | Avshi Avital | Update tooltip for data capture settings |

### Consent

| Key | Type | Status | Assignee | Summary |
|-----|------|--------|----------|---------|
| [GONG-142379](https://gongio.atlassian.net/browse/GONG-142379) | Task | Ready for Development | Alaa Elias | Move available consent providers in Users endpoint to a new endpoint |
| [GONG-141627](https://gongio.atlassian.net/browse/GONG-141627) | Task | Ready for Development | Omer Vertman | Validate Stop Recording (Consent, WFE) operates |
| [GONG-142006](https://gongio.atlassian.net/browse/GONG-142006) | Story | Backlog | Shahar Ben-Ari | Admin center → Recording consent → Edit consent profile |
| [GONG-140183](https://gongio.atlassian.net/browse/GONG-140183) | Task | Ready for Development | Alaa Elias | ChiliPiper — Displaying Consent web-conference providers (separate endpoint) |
| [GONG-137761](https://gongio.atlassian.net/browse/GONG-137761) | Epic | Backlog | — | Consent auto-join support for meeting-room tablets |
| [GONG-80233](https://gongio.atlassian.net/browse/GONG-80233) | Epic | Backlog | Alaa Elias | Use consent with multiple providers |
| [GONG-133000](https://gongio.atlassian.net/browse/GONG-133000) | Sub-task | Ready for Development | — | Emit Dynatrace event on Recording Consent profile changes |
| [GONG-120505](https://gongio.atlassian.net/browse/GONG-120505) | Task | In Review | Dvir Avraham | Display consent-profile metadata in Team Members instead of providers |
| [GONG-112786](https://gongio.atlassian.net/browse/GONG-112786) | Epic | GA | Elad Swisa | Multilingual Pre-trained AI trackers — Recording Consent tracker |

### Company purge / GDPR (purge indexes + resumption)

| Key | Type | Status | Assignee | Summary |
|-----|------|--------|----------|---------|
| [GONG-143519](https://gongio.atlassian.net/browse/GONG-143519) | Story | Ready for Development | — | Track company purge stage progress in DB for safe cross-day resumption |
| [GONG-138790](https://gongio.atlassian.net/browse/GONG-138790) | Sub-task | Ready for Development | Alaa Elias | Audit & add purge index on `public.invitee` (company_id + pagination) |
| [GONG-138792](https://gongio.atlassian.net/browse/GONG-138792) | Sub-task | Ready for Development | Alaa Elias | Audit & add purge index on `recording_compliance.jump_page_interaction` |
| [GONG-138809](https://gongio.atlassian.net/browse/GONG-138809) | Sub-task | Ready for Development | Alaa Elias | Audit & add purge index on `public.onetime_meeting_jump_page_to_call` |
| [GONG-138810](https://gongio.atlassian.net/browse/GONG-138810) | Sub-task | Ready for Development | Alaa Elias | Audit & add purge index on `public.onetime_meeting_jump_page` |

### Other

| Key | Type | Status | Assignee | Summary |
|-----|------|--------|----------|---------|
| [GONG-113665](https://gongio.atlassian.net/browse/GONG-113665) | Task | Ready for Development | Alaa Elias | Backfill data from `operational.recording_compliance` to consent DB |
| [GONG-143257](https://gongio.atlassian.net/browse/GONG-143257) | Sub-task | Backlog | — | APPINFRA-2268: Migrate Kafka ACL descriptors in gong-data-capture |

---

## Queries used

Run in Jira (`gongio.atlassian.net`) to refresh. Kept the high-confidence subset — summary names
the subsystem, or an `APPINFRA` sub-task explicitly names the repo.

```sql
-- Call scheduling
statusCategory != Done AND project = GONG
  AND (text ~ "gong-call-schedulers" OR text ~ "CallScheduler"
       OR text ~ "InviteHandlerWebhooksServer" OR summary ~ "call schedul")
ORDER BY updated DESC

-- Data capture / consent
statusCategory != Done AND project = GONG
  AND (text ~ "gong-capture-data" OR text ~ "gong-data-capture"
       OR text ~ "DataCaptureService" OR summary ~ "data capture" OR summary ~ "consent")
ORDER BY updated DESC
```

---

## See also

- [[00 - Overview]] — Call Scheduling subsystem overview
- [[03 - Ubiquitous Language]] — Call Scheduling domain glossary
- [[Gong Environment Abbreviations (GGE, GPE)]] — GGE→GPE routing (the invite-handler flow)
- [[Acronyms#D]] — DCP (Data Capture Profile) glossary entry
