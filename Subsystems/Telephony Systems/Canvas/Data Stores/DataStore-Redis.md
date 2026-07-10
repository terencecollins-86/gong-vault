---
title: DataStore-Redis
component_type: data-store
service: IngesterTelephonySystemsSupervisor
cluster: GONG_PROD
tags: [telephony-systems, redis, locks, data-store, oncall]
---

# 🗄️ Redis (GONG_PROD)

> [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Telephony Systems - External Data Flow.canvas|← Data-flow canvas]] · [[Subsystems/Call Scheduling/Canvas/Telephony Systems/Core/IngesterTelephonySystemsSupervisor]] · [[06 - Runbook & Troubleshooting|Runbook]] · [[05 - Observability|Observability]] · Owner: **yossi.rizgan@gong.io**

> [!danger] On-call TL;DR
> Redis (`GONG_PROD`) backs the Supervisor's **distributed locks** — the sync locks that serialise per-integration sync jobs. If Redis is unreachable or a lock is stuck, **syncs for an integration stop running** (or pile up) because the executor can't acquire the lock.
>
> 🔑 **Gotchas (verified in code):**
> 1. Lock acquisition uses a **short timeout and fails soft** — `tryToAcquireDistributedLock` waits **10s** then returns `false` (`DialersConnectService.java:111`); `evaluateWithSyncLocks` then throws `IllegalStateException("Failed to acquire lock")` (`:135`). A held periodic/initial lock looks like "sync silently not running".
> 2. Lock names are **per-integration string keys**: `com.honeyfy.ts.sync.periodic.{id}` / `...initial.{id}` / `...credentials.{id}` (`DialersConnectService.java:74–76`). Grep these in logs to see which integration is blocked.
> 3. `CIRCUIT_BREAKERS` is declared **`READ_ONLY`** (descriptor line 54) but is **not referenced by Supervisor code** — circuit-breaker state is managed transparently by the Feign/resilience framework, not read/written here.

---

## What it is

| | |
|---|---|
| **Role** | Distributed locks (sync-job serialisation) + framework caches; circuit-breaker state (framework-managed) |
| **Cluster / logical DBs** (descriptor lines 52–54) | `GONG_PROD: READ_WRITE`, `CIRCUIT_BREAKERS: READ_ONLY`; `locks: true` (line 7) |
| **What's stored** | Distributed lock keys (`com.honeyfy.ts.sync.*`), permissions-module cache, internal-access-control cache |
| **Lock accessor (local)** | `DialersConnectService` → injected `DistributedLockService` (`com.honeyfy.util.concurrent.lock`) |
| **Redis config beans** | `IngesterTelephonySystemsSupervisorConfig` — `lockSettings()` (`:286`), `redisSettingsProdV2()` (`:324`, `GONG_PROD` `:331`), `jedisAccessorSettingsProdV2()` (`:374`, `GONG_PROD` `:379`) |
| **Logical DB enums used** | `PERMISSIONS_MODULE_CACHING` (`:329`), `INTERNAL_ACCESS_CONTROL` (`:381`) |
| **Service id (logs/metrics)** | `ingestertelephonysystemssupervisor` |

---

## 👀 See it working

**Coralogix (DataPrime)** — lock acquire attempts (`DialersConnectService.getSyncLock` logs at INFO):
> [!tip] Run in Coralogix US-01
> [Open in Coralogix](https://gong-prod-gge-use1.app.coralogix.us/) — paste the query below into the DataPrime tab.

```text
source logs
| filter $l.subsystemname == 'ingestertelephonysystemssupervisor'
| filter $d.body.contains('Try to get a lock') || $d.body.contains('Failed to acquire lock')
| limit 200
```
Scope to one company with `| filter $d.mdc.cid == '<companyId>'`. Errors only: swap the message filter for `| filter $m.severity == ERROR`.

**Datadog** — [Telephony Systems dashboard](https://app.datadoghq.com/dashboard/ptx-4jk-fkr/telephony-systems-dashboard). For Redis, watch the **Redis / ElastiCache metric family** (`aws.elasticache.*` — CPU, connections, evictions, latency) and connection-pool saturation. Filter `service:ingestertelephonysystemssupervisor` + your `g-cell`.

**Sentry** — [team `telephony-systems`](https://gong-io.sentry.io/issues/?query=assigned%3A%23telephony-systems&statsPeriod=14d). Investigate with *"investigate this Sentry issue <url>"* (`observability:sentry-investigation`).

---

## 🔌 Set a breakpoint (local)

Run the service: `gong-module-run --debug up --subsystem-names gong-telephony-systems` (base URL `http://localhost:8097`, no auth locally).

| Where | File : line | Why |
|---|---|---|
| **Lock acquire** | `Dialers/.../connect/DialersConnectService.java:111` | `lock.tryLock(10, SECONDS)` — the actual Redis lock attempt (returns false on timeout) |
| **Lock create** | `Dialers/.../connect/DialersConnectService.java:128` | `distributedLockService.newLock(name)` — see the per-integration key being built |
| **Both sync locks** | `Dialers/.../connect/DialersConnectService.java:134` | `evaluateWithSyncLocks` — acquires initial + periodic, throws on failure (`:135`) |
| **Lock-pool settings** | `IngesterTelephonySystemsSupervisor/.../config/IngesterTelephonySystemsSupervisorConfig.java:286` | `DistributedLocks.Settings` pool sizing for GONG_PROD |
| **Redis (GONG_PROD) settings** | `IngesterTelephonySystemsSupervisor/.../config/IngesterTelephonySystemsSupervisorConfig.java:331` | `.redisCluster(RedisCluster.GONG_PROD)` — confirms the cluster |

> The lock/Redis framework (`DistributedLockService`, `DistributedLocks`, `RedisAccessor`, `JedisAccessor`, `RedisLogicalDatabase`) lives in external Gong libs (`com.honeyfy.util.concurrent.lock`, `com.honeyfy.distributedlocks`) — **not mounted here**. The local hooks above are our call sites on that boundary.

## 🐞 Lightrun (production — no redeploy)

Virtual breakpoints/logs against the running prod service. Full setup: [[Work/Inbox/Lightrun - R&D|Lightrun guide]] · server `https://lightrun.c1-devops.use1.prod.gongio.net` (VPN + Okta) · `#lightrun-users`.

1. Open `DialersConnectService.java` in IntelliJ; match the file version to prod (Lightrun matches on **line number**).
2. Gutter → **Snapshot** at **line 111**. In **Source**, pick the tag for **`ingestertelephonysystemssupervisor`**.
3. Scope to one company so you don't flood — condition on MDC:
   ```java
   Objects.equals(org.slf4j.MDC.get("cid"), "<companyId>")
   ```
4. Inspect locally (below), read whether `tryLock` returned true/false, then **delete the breakpoint.**

> Use a **Log** action to inject the lock name / acquire result without snapshot overhead.

---

## 🔍 Inspect locally

Redis is read/written by lock operations, not "triggered". To observe a real lock acquire, drive a sync job — the executor wraps the per-integration sync in the sync locks.

**Put a SyncJob on the queue (hits the locked sync path)** — see [[Entrypoints Within the Telephony System]] §5:
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/time-based-events-sync-infra/sqs/sendMessage?high-priority=true' \
  --data-urlencode 'message={"companyId":0,"integrationId":0,"integrationFlavorId":"GONG_CONNECT_API","backfill":false}'
```
- Sync-lock state is read by `IngesterTelephonySystemsSyncInfraTroubleshooter.checkSyncJobChainStatus()` (verify line) — it reports whether the periodic/initial locks are currently held.
- For a local Redis you can also inspect keys directly with `redis-cli KEYS 'com.honeyfy.ts.sync.*'` against the local stack.

---

## 🧰 Troubleshooters

| Troubleshooter | Use for |
|---|---|
| `IngesterTelephonySystemsSyncInfraTroubleshooter` | Inspect sync-job chain + whether sync locks are held; enqueue a SyncJob to exercise the lock path (§5) |
| `TroubleshootingScheduledTaskController` | Inspect/trigger the scheduled sync that takes the locks |

Discover live paths via Swagger: `https://ingestertelephonysystemssupervisor-vip.prod.gongio.net/swagger-ui/index.html` (VPN + `troubleshootersAuthJWT` cookie). See [[Work/Architecture/Troubleshoot Endpoints]].

## 🚑 Common incidents

| Symptom | First checks |
|---|---|
| Sync silently not running for one integration | A sync lock is held — grep `com.honeyfy.ts.sync.periodic.{id}` / `...initial.{id}` in logs; check `IngesterTelephonySystemsSyncInfraTroubleshooter` lock status. Stuck lock ⇒ acquire times out at 10s (`DialersConnectService.java:111`). |
| `IllegalStateException: Failed to acquire lock` | Two jobs raced for the same integration; `evaluateWithSyncLocks` (`:135`) rejects the loser — usually transient, retries next cycle. |
| Redis cluster unreachable | Datadog ElastiCache metrics + connection-pool saturation; all lock-based syncs stall. Check `GONG_PROD` health. |
| Circuit-breaker confusion | `CIRCUIT_BREAKERS` is framework-managed and `READ_ONLY` here — chase the Feign client / resilience config, not Supervisor code. |
