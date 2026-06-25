---
title: Hybrid Debugger — Step-by-Step Setup Guide
tags:
  - debugging
  - hybrid
  - intellij
  - kubernetes
  - telephony
  - how-to
created: 2026-06-25
aliases:
  - hybrid debug setup
  - debugger setup guide
  - breakpoint guide
---

# Hybrid Debugger — Step-by-Step Setup Guide

> [!info] What this guide covers
> How to attach an IntelliJ debugger to code running in your Kubernetes dev environment using the hybrid approach — so breakpoints in your local source hit requests arriving from the cluster.
>
> The telephony service `IngesterTelephonySystemsSupervisor` is used as the worked example throughout.

> [!tip] Two modes
> - **Option A — Hit the local Swagger** — fastest. Your local Spring Boot process handles requests directly. No cluster traffic involved. Best for REST endpoint debugging.
> - **Option B — Telepresence intercept** — routes real cluster traffic to your local JVM. Required for Kafka-triggered flows, SQS tasks, or anything that has to pass through the cluster first.

---

## Prerequisites

| Requirement | Check |
|---|---|
| Klopper app running (tunnel active) | Menu bar icon shows connected |
| `gong-module-run` installed on your Mac | `which gong-module-run` returns a path |
| IntelliJ hybrid run config present | `.run/IngesterTelephonySystemsSupervisor-hybrid.run.xml` exists |
| `gong-build-commons` checked out and up to date | `git pull` in that repo |

> [!warning] Klopper must be connected before IntelliJ starts
> The hybrid `application-Hybrid.properties` points all datasources (DB, Kafka, Redis, OpenSearch) at `datasources.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net`. This hostname is only reachable through the tunnel. If Klopper is not connected, the Spring context fails to start.

---

## Option A — Debug via local Swagger (fastest)

Use this when: you added a new REST endpoint or want to step through any HTTP-triggered controller.

### Step 1 — Start in Debug mode

In IntelliJ, select the run config and click **Debug** (the bug icon), not Run:

```
Run config: IngesterTelephonySystemsSupervisor - Hybrid
Profiles:   Linux, Dev, Secure, Hybrid, Hybrid-Overrides
Port:       8097
```

> [!tip] You can also right-click the config name in the Run toolbar and choose **Debug**.

### Step 2 — Wait for the service to start

Watch the IntelliJ console. Do not trigger anything until you see:

```
Started IngesterTelephonySystemsSupervisorInitializer in X seconds
```

> [!danger] Do not trigger endpoints while the context is still loading
> Spring registers controllers during startup. Hitting an endpoint before this line appears will get a 404 or a connection refused.

### Step 3 — Open local Swagger

Open in your browser:

```
# Regular API endpoints
http://localhost:8097/swagger-ui/index.html

# Troubleshooter / diagnostic endpoints
http://localhost:8097/troubleshooter/swagger-ui/index.html
```

> [!note] This is NOT the cluster Swagger
> The cluster URL (`ingestertelephonysystemssupervisor.modules.terry-collins-dev-env...`) points to the K8s pod — a different JVM. Always use `localhost:8097` when debugging locally.

### Step 4 — Set your breakpoint

In IntelliJ, click the gutter next to the line you want to break on. The red dot confirms it's active.

### Step 5 — Trigger the endpoint

Call the endpoint from `localhost:8097/swagger-ui` → IntelliJ pauses at your breakpoint.

---

## Option B — Telepresence intercept (cluster traffic → local JVM)

Use this when: the code path you're debugging is triggered by Kafka, SQS, a scheduled task, or another service calling the supervisor from within the cluster.

### Step 1 — Confirm Klopper is connected

The Klopper app must show a connected status. If not, open it and connect before proceeding.

Alternatively, from your Mac terminal:

```bash
gong-module-runner remote --connect
```

### Step 2 — Start the intercept

From your Mac terminal (not the GCR container — `gong-module-run` is installed on the Mac):

```bash
gong-module-run remote --intercept ingestertelephonysystemssupervisor
```

This registers a Telepresence intercept that redirects incoming traffic for `ingestertelephonysystemssupervisor` in the cluster to your local machine on port 8097.

> [!tip] The intercept name is the Kubernetes service name (lowercase, no camelCase).
> For other telephony services:
> - `gong-module-run remote --intercept telephonysystemswebapi`
> - `gong-module-run remote --intercept telephonysystemstroubleshooters`

### Step 3 — Start IntelliJ in Debug mode

Same as Option A Step 1 — click **Debug** on the hybrid run config.

Wait for `Started IngesterTelephonySystemsSupervisorInitializer` in the console.

### Step 4 — Set your breakpoint

Click the gutter in IntelliJ next to the target line.

### Step 5 — Trigger from the cluster

Now call the endpoint using the **cluster URL** (not localhost) — Telepresence routes it to your local JVM:

```
# From Swagger (cluster URL — now intercepted):
https://ingestertelephonysystemssupervisor.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net/swagger-ui/index.html

# Or from Postman — use the collection at:
# gong-telephony-systems/postman/IngesterTelephonySystemsSupervisor.postman_collection.json
```

IntelliJ pauses at your breakpoint.

### Step 6 — Leave the intercept when done

```bash
gong-module-run remote --leave ingestertelephonysystemssupervisor
```

> [!warning] Always leave the intercept when done
> Leaving the intercept un-removed means the service is down for anyone else using the shared cluster. Run `--leave` before closing IntelliJ.

---

## Hot-swapping code changes without restarting

While the debugger is running, if you change a method body you can reload the class without stopping:

**`Cmd+Shift+F9`** (Mac) / **`Ctrl+Shift+F9`** (Linux/Windows)

IntelliJ recompiles the file and hot-swaps the class into the running JVM. The intercept stays active. Trigger the endpoint again — it returns the new behaviour.

> [!note] Hot swap limitations
> Hot swap works for **method body changes** only. These require a full restart:
> - Adding a new method or field
> - Changing a method signature
> - Adding or removing an annotation
> - Adding a new class
>
> For a restart: stop the Debug session → click Debug again → wait for `Started` → re-trigger. The Telepresence intercept survives the restart — no need to re-run `--intercept`.

---

## Running multiple intercepts simultaneously

You can intercept several services at the same time — each `--intercept` is registered independently:

```bash
gong-module-run remote --intercept ingestertelephonysystemssupervisor
gong-module-run remote --intercept telephonysystemswebapi
gong-module-run remote --intercept telephonysystemstroubleshooters
```

**Each intercepted service needs its own local process on a distinct port.** Start a separate IntelliJ Debug session per service using that service's hybrid run config. Confirm no port clashes by checking `-Dserver.port` in each `.run/*.hybrid.run.xml`.

```bash
# See all active intercepts
gong-module-run remote --status

# Tear down all when done
gong-module-run remote --leave ingestertelephonysystemssupervisor
gong-module-run remote --leave telephonysystemswebapi
gong-module-run remote --leave telephonysystemstroubleshooters
```

> [!warning] Memory cost
> Three Spring Boot services running locally simultaneously is a significant heap load. Run only the intercepts for services you're actively stepping through.

---

## Quick reference — telephony service names

| Service | Intercept name | Local port | Swagger path |
|---|---|---|---|
| IngesterTelephonySystemsSupervisor | `ingestertelephonysystemssupervisor` | 8097 | `/swagger-ui/index.html` |
| TelephonySystemsWebApi | `telephonysystemswebapi` | *(check `.run` config)* | `/swagger-ui/index.html` |
| TelephonySystemsTroubleshooters | `telephonysystemstroubleshooters` | *(check `.run` config)* | `/troubleshooter/swagger-ui/index.html` |

> [!tip] Find the local port for any service
> Open its `.run/*.hybrid.run.xml` file and look for `-Dserver.port=<value>` in `VM_PARAMETERS`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Spring context fails to start — datasource connection refused | Klopper tunnel is down | Open Klopper and reconnect, then restart IntelliJ Debug |
| Breakpoint not hit from `localhost:8097` | Service not fully started yet | Wait for `Started IngesterTelephonySystemsSupervisorInitializer` in console |
| Breakpoint not hit from cluster URL | Intercept not set up — Swagger calls the K8s pod, not your local JVM | Run `gong-module-run remote --intercept <service>` first (Option B), then use the cluster URL |
| Code change not reflected after hot swap | Structural change (new method/field) | Stop and restart the Debug session; intercept survives |
| `gong-module-run: command not found` | Running from inside GCR container | Run this command on your Mac terminal, not in the GCR session |
| `Unknown module` error on intercept | Service name casing is wrong | Use lowercase with no hyphens (e.g. `ingestertelephonysystemssupervisor`) |

---

## Related notes

- [[GRM  gong-module-run How To]] — full `gong-module-run` command reference
- [[kubectl CLI — Intro to Advanced]] — kubectl one-liners for checking pod state
- [[kubectl Cheatsheet — Telephony Services on Kubernetes]] — k9s TUI version
- [[Swagger Pages]] — troubleshooter JWT cookie for authenticated endpoints
- [[Dev Env Service URLs]] — all service hostnames in the dev environment
