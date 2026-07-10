# Entrypoints Within the Telephony System

Walkthrough for triggering each `IngesterTelephonySystemsSupervisor` entrypoint and hitting a
breakpoint, one at a time. Run the service locally first:  `gong-module-run --debug up --subsystem-names gong-telephony-systems`

- **Base URL:** `http://localhost:8097` (Local profile, no context path)
- **Auth:** none — internal-only service, no app-level auth filter locally
- **Companion Postman collection:** `gong-telephony-systems/postman/IngesterTelephonySystemsSupervisor.postman_collection.json` (in the project root) — import it into Postman; each entrypoint below names the exact **folder → request** to run, with payload and `{{variables}}` pre-filled. Set the collection variables (`companyId`, `integrationId`, `integrationFlavor`, etc.) once and reuse across requests.

## Call-processing entrypoints (the focus)

Of the ~61 total entrypoints, these are the paths that actually **process calls**. We walk them
in order of how directly they hit the core ingestion logic:

| # | Entrypoint | How it processes calls | Status |
|---|---|---|---|
| 1 | Backfill marked TSs | Smoke test only — proves the debug loop | ✅ added |
| 2 | Process one telephony call event | HTTP twin of the main Kafka consumer → `processCallEvent()` | ✅ added |
| 3 | Sync one call | Pulls a single call from the provider → full sync path | ✅ added |
| 4 | `TelephonyCallEventConsumer` (Kafka) | The real push path — produce to `gong-connect-dialer-events` | ✅ added |
| 5 | High/Low-priority SyncJob (SQS) | The real periodic/backfill sync executor | ✅ added |

**Two ways calls enter the system:**
- **Push** — a provider sends us an event as the call happens → entrypoints #2 (Kafka twin) and #4 (the real Kafka consumer). Origin `PUSH`.
- **Pull/Sync** — we poll the provider on a schedule (or on demand) and fetch calls → entrypoints #3 (single call) and #5 (the SQS-driven sync chain). Origin `SYNC`/`BACKFILL`.

Entrypoints #2 and #3 are HTTP troubleshooting twins that let you hit each core path on demand;
#4 and #5 are the production async triggers (Kafka topic / SQS queue) those twins shadow.

---

## 1. Backfill marked TSs (SFDC) — zero-arg smoke test

First entrypoint on purpose: no payload, no params. If the breakpoint hits, the whole
local-debug loop (request → Tomcat → controller → service) is working.

| | |
|---|---|
| **Postman request** | `HTTP — PCI-Compliant Troubleshooter` → **Backfill marked TSs (SFDC) — zero-arg, good breakpoint smoke test** |
| **Method + URL** | `POST http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/backfill/backfillMarkedTSs` |
| **Headers** | none required |
| **Payload** | none (empty body) |
| **Controller** | `IngesterTelephonySystemsTroubleshooter.backfillMarkedUsers()` |
| **File** | `IngesterTelephonySystemsShared/src/main/java/com/honeyfy/ingesterselephonysystemsshared/troubleshooters/IngesterTelephonySystemsTroubleshooter.java` |

### Breakpoint
Line **291** — `int backfillMarkedUsers = userBackfillService.backfillMarkedTss();`

(Set it on the controller method entry at line 290 if you want to catch the request before the
service call; line 291 is the first executable line and hits immediately. Step into
`userBackfillService.backfillMarkedTss()` to follow the actual backfill work.)

### curl
```bash
curl -X POST \
  http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/backfill/backfillMarkedTSs
```

### Expected response
`200 OK` with body `Backfilled <n> TSs`.

---

## 2. Process one telephony call event — core single-call ingestion

This is the most valuable call-processing entrypoint to debug. It drives the **exact same code
path as the main `TelephonyCallEventConsumer` Kafka consumer** — both call
`dialerService.processCallEvent(...)` — but over HTTP, so you hit the core single-call logic
without producing a Kafka message. The only difference is the origin tag (`CallOrigin.TROUBLESHOOTER`
here vs the consumer's origin).

| | |
|---|---|
| **Postman request** | `Push — Telephony Call Events` → **Process one telephony call event** |
| **Method + URL** | `POST http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=GONG_CONNECT_API` |
| **Headers** | `Content-Type: application/json` |
| **Query param** | `integration-flavor` — an `IntegrationFlavor` enum value (e.g. `GONG_CONNECT_API`, `DIAL_PAD_API`, `AIRCALL_API`, `EIGHT_BY_EIGHT_API`) |
| **Controller** | `TelephonyCallEventsTroubleshooter.processTelephonyCallEvent()` |
| **File** | `IngesterTelephonySystemsSupervisor/src/main/java/com/honeyfy/ingestertelephonysystems/rest/TelephonyCallEventsTroubleshooter.java` |

### Breakpoint
Line **50** — `... dialerService.processCallEvent(telephonyCallEvent, Optional.of(CallOrigin.TROUBLESHOOTER)) ...`

Then **step into `processCallEvent(...)`** to follow the actual call-processing logic. Useful
companion breakpoints:
- Line **47** — `Tenant.evaluateForCompany(...)` — to see the tenant context being established.
- Line **48** — `dialerServiceProvider.getEventSupportingDialerServiceByFlavor(...)` — to see which
  `EventPushSupportingDialerService` implementation is selected for the flavor you passed.

> To exercise the Kafka wrapper itself (the consumer's `accept(...)`), produce to topic
> `gong-connect-dialer-events` instead — that's entrypoint #4.

### Payload
Body is a `TelephonyCallEvent`
(`com.honeyfy.kafka.events.call.external.dialer.TelephonyCallEvent`). Required (`@NonNull`) fields:
`companyId`, `providerIdentifier`, `providerIdentifierType`, `providerName`. The rest are optional
but `startTime`/`endTime`/numbers make the processed call realistic.

```json
{
  "companyId": 0,
  "providerIdentifier": "REPLACE_PROVIDER_CALL_ID",
  "providerIdentifierType": "ENGAGE_DIALER",
  "providerName": "gong-connect",
  "ownerIdentifier": [],
  "startTime": "2024-01-01T00:00:00Z",
  "endTime": "2024-01-01T00:05:00Z",
  "fromNumber": "+15550001111",
  "toNumber": "+15550002222",
  "direction": "OUTBOUND",
  "additionalData": {}
}
```

> Set `companyId` to a real company on your local DB and `providerIdentifier` to a provider call
> id. `integration-flavor` (query param) must match `providerName`'s provider, or
> `getEventSupportingDialerServiceByFlavor` will not resolve a service.

### curl
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=GONG_CONNECT_API' \
  -H 'Content-Type: application/json' \
  -d '{
    "companyId": 0,
    "providerIdentifier": "REPLACE_PROVIDER_CALL_ID",
    "providerIdentifierType": "ENGAGE_DIALER",
    "providerName": "gong-connect",
    "direction": "OUTBOUND"
  }'
```

### Expected response
`200 OK` with body `Done` (after `processCallEvent` completes and stats are reported).

---

## 3. Sync one call — single-call provider pull (SYNC path)

The pull-side counterpart to #2. Instead of accepting a pushed event, this **fetches one call
from the provider** by its id and runs it through the full sync pipeline
(`dialerServicesManager.syncOneCall(...)`). Best entrypoint for debugging provider API calls,
auth, and the sync→process handoff for a single, known call.

| | |
|---|---|
| **Postman request** | `HTTP — PCI-Compliant Troubleshooter` → **Sync one call** |
| **Method + URL** | `POST http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall` |
| **Headers** | none required (params are query string) |
| **Query params** | `company-id`, `integration-id`, `providerCallId` (required); `callDate` (ISO-8601, required for Amazon Connect), `callUrl` (optional) |
| **Controller** | `IngesterTelephonySystemsTroubleshooter.syncOneCall()` |
| **File** | `IngesterTelephonySystemsShared/src/main/java/com/honeyfy/ingesterselephonysystemsshared/troubleshooters/IngesterTelephonySystemsTroubleshooter.java` |

### Breakpoint
Line **489** — `SyncStats syncResults = dialerServicesManager.syncOneCall(dialerService, companyId, integrationId, integrationFlavor, providerCallId, call, CallOrigin.TROUBLESHOOTER);`

Companion breakpoints:
- Line **479** — `dialersConnectService.getIntegrationFlavor(...)` — resolves the flavor from the
  company+integration (returns null → you get the "enabled integrations" helper response, a sign
  the integration id is wrong).
- Line **485** — `dialerServiceProvider.getDialerService(...)` — selects the concrete
  `AbstractDialerService`. Step into `syncOneCall` from line 489 to follow the provider fetch.

### Payload
None — all inputs are query params. `integration-flavor` is **not** passed here; it's derived from
`company-id` + `integration-id`.

### curl
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=0&integration-id=0&providerCallId=REPLACE_PROVIDER_CALL_ID&callDate=2024-01-01T00:00:00Z'
```

### Expected response
`200 OK` with body `Done; check logs to see the sync results;` — the actual `SyncStats` are logged
(line 490), so watch the service logs / your breakpoint, not the response body.

---

## 4. TelephonyCallEventConsumer (Kafka) — the real push path

The production push entrypoint that #2 shadows. A dialer service produces a `TelephonyCallEvent`
to Kafka; this consumer's `accept(...)` deserializes it and calls the **same**
`dialerService.processCallEvent(...)` — but tagged `CallOrigin.PUSH` (vs `TROUBLESHOOTER` in #2).
There is **no dedicated HTTP trigger** for the consumer wrapper itself.

| | |
|---|---|
| **Type** | Kafka consumer (no HTTP) — wired programmatically, no `@KafkaListener` |
| **Topic** | `KafkaTopics.DIALER_EVENTS` → `gong-connect-dialer-events` |
| **Cluster** | `TELEPHONY_SYSTEMS` |
| **Wiring** | `TelephonyCallEventConsumer.Beans` → `kafkaConsumerConfigurer.configureSingle(... KafkaTopics.DIALER_EVENTS ...)` (line 42–46) |
| **Handler file** | `IngesterTelephonySystemsSupervisor/src/main/java/com/honeyfy/ingestertelephonysystems/consumers/TelephonyCallEventConsumerAbstract.java` |

### Breakpoint
Line **46** — `public void accept(ConsumerRecord<Long, TelephonyCallEvent> telephonyCallEventConsumerRecord)` (the consumer entry).
Line **57** — `... dialerService.processCallEvent(event, Optional.of(CallOrigin.PUSH)) ...` (the shared core, same method as #2 line 50).

### How to trigger
1. **Easiest — use #2** to hit the identical downstream logic over HTTP. Breakpoint line 57's
   `processCallEvent` is reached by both paths; only the `CallOrigin` differs.
2. **To exercise the consumer wrapper itself** (deserialization, MDC, `accept`), produce a
   `TelephonyCallEvent` JSON (same shape as #2's payload) to topic `gong-connect-dialer-events` on
   the `TELEPHONY_SYSTEMS` cluster — e.g. via `kafka-console-producer` or the Kafka UI for your
   local stack. Set the breakpoint at line 46 first.

### Other call-processing consumers (same pattern)
Set the breakpoint on each consumer's `accept(...)` and produce to its topic:

| Consumer | Topic | Cluster |
|---|---|---|
| `LowPriorityTelephonyCallEventConsumer` | `low-priority-dialer-events` | TELEPHONY_SYSTEMS |
| `GongConnectCallEventConsumer` | `gong-connect-call-event` | TELEPHONY_SYSTEMS |
| `TsNonRecordedCallsProcessingStatusConsumer` | `call-processing-status-event` | CALL_PROCESSOR |

---

## 5. High / Low-priority SyncJob (SQS) — the real sync executor

The production pull path that #3 shadows for a single call. The sync **chain** drops a `SyncJob`
message onto an SQS queue; the executor's `execute(...)` picks it up, establishes tenant + MDC
context, resolves the integration, and runs the full company sync. Two executors, one per priority.

| | |
|---|---|
| **Type** | SQS executor (no direct HTTP) — `AbstractSyncJobMsgExecutor implements SqsExecutorInterface<SyncJob>` |
| **High-priority queue** | `SQSQueues.DIALERS_SYNC_HIGH_PRIORITY` (`HighPrioritySyncJobMsgExecutor`, periodic syncs) |
| **Low-priority queue** | `SQSQueues.DIALERS_SYNC_LOW_PRIORITY` (`LowPrioritySyncJobMsgExecutor`, backfill) |
| **Handler file** | `IngesterTelephonySystemsSupervisor/src/main/java/com/honeyfy/ingestertelephonysystems/syncInfra/AbstractSyncJobMsgExecutor.java` |

### Breakpoint
Line **80** — `public void execute(SyncJob currentSyncJob, SqsMessageHandler<SyncJob> handler)` — the
SQS entry for every sync job. Step through to the `getEnabledIntegrationDataForCompany` guard
(line ~97) and onward into the per-provider sync.

### How to trigger (two on-demand HTTP options)
Both are in the **Time-Based Events Sync Infra** troubleshooter
(`IngesterTelephonySystemsSyncInfraTroubleshooter`):

**A. Run the existing chain now** — flips the scheduled event's run-time to now so the chain
enqueues a `SyncJob` on its own (most realistic):
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/time-based-events-sync-infra/syncJobInfra/SyncJobChain/runChainNow?company-id=0&integration-id=0&is-backfill=false'
```
Controller `runSyncJobChainNow()` at line **238**. `is-backfill=true` routes to the low-priority
(backfill) queue.

**B. Put a SyncJob on the queue directly** — bypasses the scheduler, hits `execute()` immediately:
```bash
curl -X POST \
  'http://localhost:8097/troubleshooting/time-based-events-sync-infra/sqs/sendMessage?high-priority=true' \
  --data-urlencode 'message={"companyId":0,"integrationId":0,"integrationFlavorId":"GONG_CONNECT_API","backfill":false}'
```
Controller `sendSqsMessage()` at line **103**. The `message` is a JSON `SyncJob`
(`com.honeyfy.dialers.services.syncjob.SyncJob`): `companyId`, `integrationId`,
`integrationFlavorId`, `backfill` (+ optional `syncStartDate`, `syncType`). `high-priority` picks
the queue. Set the breakpoint at line 80 first.

> Bulk variants exist for backfilling many integrations: `start-high-sync-for-multiple-integrations`
> and `start-low-priority-sync-for-integration` (see the SyncInfra troubleshooter / Postman
> `Other Troubleshooters → Time-Based Events Sync Infra`).
