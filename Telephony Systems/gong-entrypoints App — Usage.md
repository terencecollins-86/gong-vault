---
title: gong-entrypoints App — Usage
tags: [telephony-systems, entry-points, tooling, onboarding]
created: 2026-07-08
---

# 🚀 gong-entrypoints App — Usage

> [[_dashboard|← Team Hub]] · [[02 - Data Flows]] · [[Entrypoints Within the Telephony System]]

`gong-entrypoints` is a tiny Spring Boot app that gives new engineers **one button per entry
point** into Telephony Systems. Instead of hand-crafting curl/Postman calls to the
troubleshooters, you hit a simple local endpoint on this app and it fires the real flow for you.

> [!info] What this app is
> A thin trigger layer. Each trigger is a REST endpoint here that calls a **Telephony Systems
> troubleshooter** over HTTP (see [[Entrypoints Within the Telephony System]] for the underlying
> endpoints). Repo: `Honeyfy/gong-entrypoints`.

---

## First trigger: Backfill marked TSs (smoke test)

The first trigger fires the simplest entry point from [[02 - Data Flows]] — the zero-arg
**backfill marked TSs** smoke test. No payload, no params. If it returns `200`, the whole
loop (this app → Supervisor → troubleshooter → service) is working.

| | |
|---|---|
| **This app's endpoint** | `POST /telephonysystems/backfill` |
| **Calls downstream** | `POST /troubleshooting/telephony-system-pci-compliant/generic/backfill/backfillMarkedTSs` |
| **On** | `IngesterTelephonySystemsSupervisor` → `IngesterTelephonySystemsTroubleshooter.backfillMarkedUsers()` |
| **Payload** | none |
| **Expected response** | `200 OK`, body `Backfilled <n> TSs` |

---

## How to run it

### 1. Start the Telephony Systems Supervisor (the target)

```bash
gong-module-run --debug up --subsystem-names gong-telephony-systems
```

This listens on `http://localhost:8097` — the default target `gong-entrypoints` calls.

### 2. Start gong-entrypoints

```bash
cd gong-entrypoints
./mvnw spring-boot:run
```

Runs on the default Spring Boot port `http://localhost:8080`.

### 3. Fire the trigger

```bash
# Once
curl -X POST http://localhost:8080/telephonysystems/backfill

# N times (5s apart) — repeat logic lives in the endpoint, via the loop param
curl -X POST 'http://localhost:8080/telephonysystems/backfill?loop=10'

# Loop until stopped (this request blocks); stop from another shell:
curl -X POST 'http://localhost:8080/telephonysystems/backfill?loop=true'
curl -X POST http://localhost:8080/telephonysystems/backfill/stop
```

You should get `Backfilled <n> TSs`. To catch it in the debugger, set a breakpoint at
`IngesterTelephonySystemsTroubleshooter.backfillMarkedUsers()` line **291** first
(see [[Entrypoints Within the Telephony System]] §1).

> [!note] Per-entrypoint docs
> Each entrypoint also ships a `README.md` in its own package (e.g.
> `telephonysystems/backfill/README.md`) and a per-module Postman collection under
> `postman/`, per the repo's README conventions.

---

## Switching target environment (local vs remote)

The target base URL is config-driven. Default is local; switch with a Spring profile.

| Target | How | Base URL |
|---|---|---|
| **Local** (default) | nothing to do | `http://localhost:8097` |
| **Remote env** | `--spring.profiles.active=remote` | set in `application-remote.properties` |

```bash
# Local (default)
./mvnw spring-boot:run

# Remote
./mvnw spring-boot:run -Dspring-boot.run.profiles=remote

# Or override the URL inline, no profile needed
./mvnw spring-boot:run -Dspring-boot.run.arguments=--telephony.base-url=http://localhost:9097
```

> [!warning] Remote requires VPN + auth
> Remote troubleshooters are VPN-protected and need a `troubleshootersAuthJWT` cookie
> (see [[06 - Runbook & Troubleshooting]]). The current trigger sends **no auth header** — it's
> built for the local, auth-free flow. Add cookie/header forwarding before relying on it against
> a remote env. Also fill in the real URL in `application-remote.properties` (placeholder `<env>`).

---

## How it's wired (for the next trigger you add)

```
BackfillTrigger (@RestController)         POST /telephonysystems/backfill[?loop=N|true]
        │
        │ telephonyRestClient (RestClient bean)
        ▼
TelephonyClientConfig  ── reads ──▶  TelephonyProperties (telephony.base-url)
        │
        ▼
IngesterTelephonySystemsSupervisor  /troubleshooting/.../backfillMarkedTSs
```

Package convention (per the repo README): `<module>.<entrypoint>`, e.g. `telephonysystems.backfill`.
Files under `src/main/java/io/gong/gongentrypoints/`:

| File | Role |
|---|---|
| `telephonysystems/backfill/BackfillTrigger.java` | The REST endpoint + downstream call + loop logic |
| `telephonysystems/backfill/README.md` | Per-entrypoint usage (once / N-times / loop curl) |
| `telephonysystems/TelephonyClientConfig.java` | Builds the `RestClient` pointed at the base URL (module-level) |
| `telephonysystems/TelephonyProperties.java` | Binds `telephony.base-url` |
| `resources/application.properties` | Local default (`telephony.base-url=http://localhost:8097`) |
| `resources/application-remote.properties` | Remote override (profile `remote`) |
| `postman/telephonysystems.postman_collection.json` | Per-module Postman collection |

### Adding another entry point

1. Pick a flow from [[02 - Data Flows]] and its troubleshooter endpoint from
   [[Entrypoints Within the Telephony System]].
2. Add a new package `<module>.<entrypoint>` with a `@RestController` exposing
   `POST /<module>/<entrypoint>` (support `loop` for repeat/loop). Add a request body for flows
   that need one, e.g. Flow B's `process-one-event`.
3. Inject the same `telephonyRestClient` and call the troubleshooter path.
4. Add a `README.md` in the entrypoint package and a request to the module's Postman collection.

That's the whole pattern — one small controller per entry point.
