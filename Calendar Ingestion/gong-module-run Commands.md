---
title: Calendar Ingestion — gong-module-run Commands
tags:
  - calendar-ingestion
  - runbook
  - gong-module-run
  - hybrid-dev
  - local-dev
created: 2026-06-26
aliases:
  - calendar module run
  - calendar grm commands
  - calendar ingestion setup
---

# Calendar Ingestion — gong-module-run Commands

> [[_dashboard|← Team Hub]] · see also [[Swagger Trigger Runbook]] · [[GRM  gong-module-run How To]]

Reference for every `gong-module-run` command you'll need when working on calendar ingestion.
Organised by **where it runs** (local vs remote) and **how much of the stack you need** (full pipeline vs one service).

> [!info] Module names
> All module names come from `gong-build-commons/dev/gong-module-runner/conf/gong-modules-base.yaml` — pass them exactly as shown.

---

## The four modules

| Module | Short name | Port (local) | Role |
|---|---|---|---|
| IngesterCalendarSupervisor | `ingestercalendarsupervisor` | 8885 | Orchestrator — REST entry points, scheduled sync, Kafka fan-out |
| GoogleCalendarIngester | `googlecalendaringester` | 8887 | Consumes `google-calendar-commands`, fetches GCal events |
| OfficeCalendarIngester | `officecalendaringester` | 8886 | Consumes `office-calendar-commands`, fetches O365 events |
| MeetingsIndexer | `meetingsindexer` | 9921 | Indexes meetings to OpenSearch, CRM association |

---

## Health checks (local)

Once a module is running locally, verify it with actuator:

```bash
# IngesterCalendarSupervisor (8885)
curl -s http://localhost:8885/actuator/health | jq .

# GoogleCalendarIngester (8887)
curl -s http://localhost:8887/actuator/health | jq .

# OfficeCalendarIngester (8886)
curl -s http://localhost:8886/actuator/health | jq .

# MeetingsIndexer (9921)
curl -s http://localhost:9921/actuator/health | jq .
```

Expected: `{"status":"UP"}` from each. Swap `/actuator/health` for `/actuator/health/readiness`, `/actuator/info`, or `/actuator` to dig deeper.

---

## Local (no `--remote`)

Local runs spin up Docker containers on your machine using the latest `main` image from ECR. Swagger UIs are reachable at `http://localhost:<port>/swagger-ui/index.html`.

> [!warning] Klopper must be connected
> All four services use datasources that route through the Klopper tunnel (`datasources.terry-collins-dev-env...`). Start the Klopper app before running any of these commands.

### Full pipeline — all 4 modules

Use this when you need to trace the end-to-end flow: Supervisor triggers a command → provider ingester fetches events → MeetingsIndexer indexes them.

```bash
gong-module-run up \
  --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer
```

With debug suspended (waits for IDE attach before any code runs — use when debugging startup):

```bash
gong-module-run up \
  --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer \
  --debug-suspend
```

### Partial — Supervisor only

Use when you're working on REST endpoints, scheduled tasks, or Kafka producers inside the Supervisor. The provider ingesters and indexer are not needed if you only care about what the Supervisor does.

```bash
gong-module-run up --image-names ingestercalendarsupervisor
```

### Partial — Supervisor + indexer (no provider ingesters)

Use when you're working on meeting indexing logic (MeetingsIndexer) and want to drive it from the Supervisor without needing Google or O365 connectivity.

```bash
gong-module-run up --image-names ingestercalendarsupervisor,meetingsindexer
```

### Partial — Google only

Use when you're working on Google Calendar-specific ingestion logic.

```bash
gong-module-run up --image-names ingestercalendarsupervisor,googlecalendaringester
```

### Partial — Office 365 only

Use when you're working on Office 365-specific ingestion logic.

```bash
gong-module-run up --image-names ingestercalendarsupervisor,officecalendaringester
```

### Tear down (local is not supported by `down`)

Local containers are stopped via Docker directly:

```bash
docker stop ingestercalendarsupervisor googlecalendaringester officecalendaringester meetingsindexer
```

---

## Remote (`--remote`)

Remote deploys the images to your personal K8s namespace (`terry-collins-dev-env`). Services are reachable via the dev-env ingress — see [[03 - Services Reference]] for the URLs.

> [!tip] When to use remote vs local
> - **Local** — breakpoint debugging, fast iteration, no cluster quota needed.
> - **Remote** — realistic Kafka/Kafka-consumer flows, testing with real infra, or when you can't run the JVM locally.

### Full pipeline — remote

```bash
gong-module-run up --remote \
  --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer
```

### Full pipeline — remote, from your branch

Use `--branch-name` to deploy the image built from your in-progress branch instead of `main`. The branch must have been built by CI first.

```bash
gong-module-run up --remote \
  --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer \
  --branch-name <your-branch>
```

### Partial — Supervisor only, remote

```bash
gong-module-run up --remote --image-names ingestercalendarsupervisor
```

### Partial — Supervisor + indexer, remote

```bash
gong-module-run up --remote --image-names ingestercalendarsupervisor,meetingsindexer
```

### Partial — Google only, remote

```bash
gong-module-run up --remote --image-names ingestercalendarsupervisor,googlecalendaringester
```

### Partial — Office 365 only, remote

```bash
gong-module-run up --remote --image-names ingestercalendarsupervisor,officecalendaringester
```

### Tear down — remote

Always tear down when done to free cluster resources.

```bash
# Full pipeline
gong-module-run down --remote \
  --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer

# Supervisor only
gong-module-run down --remote --image-names ingestercalendarsupervisor

# Supervisor + indexer
gong-module-run down --remote --image-names ingestercalendarsupervisor,meetingsindexer
```

---

## Whole subsystem (all `gong-ingestion` modules)

This also brings up `ingestermailsupervisor`, `ingestermailworker`, `mailingester`, and others. Use only if you need the mail ingestion stack too.

> [!warning] **NOTE:** The commands below resulted in an error when trying to get images from remote

```bash
# Local
gong-module-run up --subsystem-names gong-ingestion

# Remote
gong-module-run up --remote --subsystem-names gong-ingestion

# Tear down (remote)
gong-module-run down --remote --subsystem-names gong-ingestion
```

---

## Intercept (hybrid debugging — remote traffic → local JVM)

When a module is deployed remotely and you want breakpoints to fire in your local IDE:

```bash
# Intercept — route remote cluster traffic to your local port 5005
gong-module-run remote --intercept ingestercalendarsupervisor --port 5005

# Intercept a second module simultaneously (use a different local port)
gong-module-run remote --intercept meetingsindexer --port 5006

# Stop intercepting
gong-module-run remote --leave ingestercalendarsupervisor
gong-module-run remote --leave meetingsindexer

# Check what's currently intercepted
gong-module-run remote --status
```

> [!warning] Each intercept needs a distinct local port
> Running two intercepts on the same port fails silently. Use `:5005`, `:5006`, etc. for each module.

---

## Quick-reference decision table

| Goal | Command |
|---|---|
| Debug a REST endpoint on the Supervisor | `up --image-names ingestercalendarsupervisor` |
| Trace full Google Calendar import | `up --image-names ingestercalendarsupervisor,googlecalendaringester` |
| Trace full O365 import | `up --image-names ingestercalendarsupervisor,officecalendaringester` |
| Trace end-to-end (any provider → index) | `up --image-names ingestercalendarsupervisor,googlecalendaringester,officecalendaringester,meetingsindexer` |
| Same, but in remote cluster | Add `--remote` to any of the above |
| Deploy your branch code | Add `--remote --branch-name <branch>` |
| Intercept remote traffic into local IDE | `remote --intercept <module> --port <port>` |
| Free cluster resources | `down --remote --image-names <same list>` |

---

## See also

- [[Swagger Trigger Runbook]] — how to drive breakpoints once modules are running
- [[GRM  gong-module-run How To]] — general gong-module-run reference
- [[03 - Services Reference]] — remote dev-env URLs for each service
- [[Entrypoints Within the Calendar System]] — REST/Kafka entry points by controller
