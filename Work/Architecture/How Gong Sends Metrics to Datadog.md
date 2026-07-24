---
title: How Gong Sends Metrics to Datadog
tags: [architecture, observability, datadog, metrics, monitoring, kafka, onboarding]
created: 2026-07-24
aliases:
  - datadog metrics
  - how gong emits metrics
  - metrics pipeline
  - datadog integration
  - kafka metrics
  - http endpoint metrics
  - scheduled task metrics
---

# How Gong Sends Metrics to Datadog

> [!note] TL;DR
> You almost never write metric-emission code. When you register an **HTTP endpoint**, a **Kafka consumer/producer**, or a **scheduled task** through Gong's standard infra APIs, that infra wraps your code and emits metrics **automatically**. Metrics are sampled periodically and delivered to Datadog by one of **three mechanisms** — REST to a MetricsStreamer service, the OpenTelemetry SDK, or (for direct sampled metrics) Kafka `MultiMeasure` events — all separate from the Datadog host agent. Dashboards are then generated **separately** (see [[#Dashboards are a separate concern]]).

---

## The one mental model

There are **two independent halves**, and confusing them is the #1 source of "why is my widget empty":

```
  HALF 1 — EMISSION (automatic, runs continuously in every service)
  ─────────────────────────────────────────────────────────────────
  Your code (endpoint / consumer / task)
        │  wrapped by Gong infra (filter / configurer / decorator)
        ▼
  Metric registration + periodic sampling
        │
        ├── Dropwizard path → KafkaMetricsReporter → MetricConverter →
        │     ├─ RestMetricReporter    → MetricsStreamer (Feign HTTP)
        │     └─ OpenTelemetryMetricReporter → OTel SDK
        │
        └── Direct sampled path → MetricsConsumer.sendBlocking →
              KafkaMetricsConsumer → Kafka MultiMeasure events
        ▼
                              Datadog  (custom metrics, tagged)

  HALF 2 — VISUALIZATION (manual / dev-triggered, one-off)
  ─────────────────────────────────────────────────────────────────
  Dashboard generators (e.g. KafkaDashboardsCreator) build Datadog
  dashboard definitions whose widgets QUERY the metrics from Half 1.
```

**Half 1 happens for free. Half 2 is a deliberate, separate action.** A metric exists in Datadog whether or not a dashboard queries it.

---

## The shared foundation

There are **two distinct emission paths**, and they deliver to Datadog differently. Learn both:

### Path A — Dropwizard-registered metrics

| Piece | Repo / location | Role |
|---|---|---|
| `KafkaMetricsReporter` | `gong-infra-core` · `Datadog/.../reporters/kafka/` | Extends Dropwizard `ScheduledReporter`; on each interval hands metrics to `MetricConverter`, which fans out to a `List<MetricReporter>`. **Despite the name, it does not itself publish to Kafka.** |
| `RestMetricReporter` | `gong-infra-core` · `Datadog/.../reporters/kafka/reporter/` | Ships metrics over **Feign HTTP** to a MetricsStreamer service (`MetricsStreamerClient` / `MetricsStreamerApi#reportMetrics`). |
| `OpenTelemetryMetricReporter` | `gong-infra-core` · `Datadog/.../reporters/kafka/reporter/` | Delivers via the **OpenTelemetry SDK** (`OpenTelemetryMetricProducer`). |

### Path B — direct sampled metrics

| Piece | Repo / location | Role |
|---|---|---|
| `MetricsConsumer` | `gong-infra-core` · `Monitoring/.../metrics/MetricsConsumer.java` | Interface metric sources write to (`sendBlocking(...)`). |
| `DefaultSimpleMetricsReporter` | `gong-infra-core` · `Monitoring/.../metrics/DefaultSimpleMetricsReporter.java` | Convenience `report(prefix, name, value)` wrapper over a `MetricsConsumer`. |
| `PeriodicMetricsCollectionService` / `PeriodicallySampledMetric` | `gong-infra-core` · `Monitoring/.../metrics/` | Samples registered gauges/counters/timers on an interval. |
| `KafkaMetricsConsumer` | `gong-infra-core` · `Datadog/.../metrics/KafkaMetricsConsumer.java` | Builds `MultiMeasure` events (`com.honeyfy.kafka.events.metrics`) — **this** path is Kafka-based. |

> [!info] Not the Datadog host agent
> All three delivery mechanisms above are separate from the standard Datadog host/infra agent. The `com.honeyfy.*` custom metrics you query in dashboards come from these application pipelines; host-level metrics (CPU, memory, etc.) come from the agent.

> [!warning] Metric names are explicit, not auto-derived
> A metric's name is the **`prefix` + `name` strings the developer passes** to `report(prefix, name, value)` — there is **no** reflective derivation from the emitting class's FQN. Some Kafka metrics happen to use FQN-looking prefixes (e.g. `com.honeyfy.kafka.infra.monitoring.KafkaConsumerMetrics.processed.total`) only because that literal string was chosen as the prefix. Different subsystems (HTTP filter, scheduled tasks) each wire their own prefix constants independently, so naming is **not** uniform across sources.

---

## Path 1 — HTTP endpoints

A servlet `Filter` times and counts requests per endpoint. **In services that install it, you do nothing** — but note this is a **copy-paste-by-convention pattern, not a universally inherited base class.** Each subsystem carries its own filter class:

- **Classes:** `RequestMetricsReporterFilter` (implements `jakarta.servlet.Filter`), copied per API-server subsystem — e.g. `gong-deals-and-forecast` · `DealsApiServer/.../init/RequestMetricsReporterFilter.java`, and three copies in `gong-genai` (`askmeanythingapi`, `genaiapi`, `themesapiserver`). A variant `MetricsReporterFilter` lives in `honeyfy` · `usersminiapp` with a slightly different API.
- **No shared base class / auto-config.** There is no `AbstractRequestMetricsFilter` or `@AutoConfiguration` that installs it everywhere. What's shared is only the *utilities* (`com.honeyfy.appcommon.metrics.DimensionalTimersCache` / `DimensionalCountersCache`, `com.honeyfy.webutil.servlet.FilterDynamicRegistration`, `com.honeyfy.webutil.http.ServletRequestUtils`). So a given service has endpoint metrics **only if it copied the filter** — don't assume universality; check the subsystem.
- **How:** in `doFilter(...)` it resolves the route via `ServletRequestUtils.extractCurrentRequiredPathPattern(...)` (so the tag is the **path pattern** `/deals/{id}`, not the raw URL — this keeps cardinality bounded), then records into two dimensional caches:

| Field | Type (`com.honeyfy.appcommon.metrics`) | Emits (live Datadog names) |
|---|---|---|
| `apiResponseTime` | `DimensionalTimersCache` | `com.honeyfy.<svc>.init.RequestMetricsReporterFilter.<svcname>.response.time.{mean,max,min,count,1MinuteRate}` |
| `endpointCounter` | `DimensionalCountersCache` | `com.honeyfy.<svc>.init.RequestMetricsReporterFilter.<svcname>.endpoint.count` |

> [!important] Metric names are per-service, not generic
> There is **no** single `apiResponseTime`/`endpointCounter` metric — the field names are Java-side. In Datadog, each service produces its **own** named variant embedding the service id. Verified live examples (2026-07-24):
> - `com.honeyfy.deals.api.server.init.RequestMetricsReporterFilter.deal.server.api.response.time.mean`
> - `com.honeyfy.deals.api.server.init.RequestMetricsReporterFilter.deal.server.api.endpoint.count`
> - `com.honeyfy.genaiapi.init.RequestMetricsReporterFilter.genaiapi.response.time.mean`
> - `com.honeyfy.themesapiserver.init.RequestMetricsReporterFilter.themesapiserver.endpoint.count`

**Tags (verified live on `dealsapiserver`):**

| Tag | Sample values |
|---|---|
| `path` | `get_/deal/search/byid`, `post_/deal/board/data/getdealboarddata` — format is `{method}_{path_lowercased}` |
| `status` | `200` (HTTP status as string) |
| `success` | `true` |
| `context` | `dealsapiserver` (service name) |
| `g-cell` | `gcell-eu-02`, `gcell-nam-01`, … |
| `build`, `jvmid` | build version, pod name |

> [!tip] What you get automatically per endpoint
> Request count and response-time timers, dimensioned by route (`path` tag). If you need a **business** metric inside a handler (e.g. "deals recalculated"), inject a reporter / use `CodeBlockMeasurer` — see [[#Path 4 — arbitrary business code]].

> [!important] There is more than one HTTP-metrics filter
> `RequestMetricsReporterFilter` is one family. Other services (including **Call Scheduler** and **Recording Consent**) emit HTTP metrics via `com.honeyfy.webutil.http.ReportPageHitDataFilter` instead — a **single shared** metric name `com.honeyfy.webutil.http.ReportPageHitDataFilter.webPageHitsTimer.{mean,min,max,count,1MinuteRate}`, dimensioned by `path`/`status`/`success`/`context` (verified live). So when you look for a service's endpoint metrics, check **both** the per-service `RequestMetricsReporterFilter.*` names and the shared `ReportPageHitDataFilter.webPageHitsTimer.*`. See the worked examples below.

---

## Path 2 — Kafka consumers & producers

**You do nothing metric-specific.** Registering through the standard infra is enough.

- **Emitter:** `KafkaMonitoring` (`honeyfy` · `KafkaIntegration/KafkaInfra/.../monitoring/KafkaMonitoring.java`) — an `ApplicationListener<ContextRefreshedEvent>`. On context refresh it walks every registered consumer/producer and calls `registerConsumerMetrics`, `registerProducerMetrics`, `registerConsumerTopicMetrics`, `registerTenantBatchMetrics`, etc.
- **Sink:** those samples flow through `KafkaMonitoredMetricsConsumer` → `KafkaMetricsConsumer` → Datadog.
- **Tags:** `context` (the app name, kebab-cased), `topic`, `consumer`, `producer`, `build`, `host`. Verified live (2026-07-24): the three names below exist as-is; consumer/producer-tagged metrics like `ConsumersLagSampling.lag` carry a `consumer` tag, while `events.sent.success` is tagged `context` (service), **not** `producer`.

**Producer** — register a template; `events.sent.success/failed` are emitted tagged `producer:<bean-name>`:

```java
@Configuration
@Import({KafkaTemplateProvider.Beans.class})
public class MyFeatureProducerTemplateConfig {
    public static final String PRODUCER_BEAN_NAME = "my-feature-producer";

    @Bean(PRODUCER_BEAN_NAME)
    public GongEventTenantBasedKafkaTemplate<Long, MyEvent> producerTemplate(
            KafkaTemplateProvider provider) {
        return provider.getGongEventBased(
                KafkaClusterDetails.OPERATIONAL_V1_KAFKA_CLUSTER,
                PRODUCER_BEAN_NAME,                      // ← becomes the `producer:` tag
                new KafkaProperties().keySerializer(LongSerializer.class),
                KafkaTopics.MY_FEATURE_TOPIC);
    }
}
```

**Consumer** — register via `KafkaConsumerConfigurer`; `processed.total`, `processed.time.mean`, `messageTimeInTopic.mean`, and `ConsumersLagSampling.lag` are emitted tagged `consumer:<name>`, `topic:<topic>`:

```java
configurer.configureSingle(
        clusterInfo,
        MyEvent.class,
        myFeatureConsumer,
        KafkaTopics.of(KafkaTopics.MY_FEATURE_TOPIC),
        new KafkaProperties()
                .persistErrors(true)                 // ← adds error-topic + error-count metrics
                .persistErrorWithReprocessing(true)); // ← adds reprocessing metrics
```

> [!warning] The `persistErrors*` flags gate the error metrics
> `persistErrors(true)` / `persistErrorWithReprocessing(true)` are the exact flags the dashboard generator reads (`isPersistErrors()`, `isPersistErrorWithReprocessing()`) to decide whether to add error/reprocessing widgets. No flag → no error widget.

---

## Path 3 — scheduled / distributed tasks

**You do nothing.** Tasks scheduled through the distributed scheduler are wrapped with a monitoring decorator.

- **Factory:** `MonitoredTaskSchedulerFactory` (`gong-infra-core` · `Datadog/.../scheduler/MonitoredTaskSchedulerFactory.java`) builds the `DistributedScheduledTaskExecutor`.
- **Decorator:** `ScheduledTasksDecorator.decorate(ScheduledTask)` wraps each task with:
  - `RunnableExecutionTimeMonitor` → execution-time metric via `MetricsConsumer`
  - `DatadogEventsReporter` → start/finish/failure **events** (correlatable with metrics)
  - `MaintenanceCircuitBreaker` + `TaskCircuitBreakerDao` → trip/skip state
  - a fresh `XTraceId` + MDC context per run (so logs/traces correlate)

**Live Datadog metric names (verified 2026-07-24):**

| Metric | Kind | Notes |
|---|---|---|
| `com.honeyfy.task.<taskid>.executionTimeSeconds` | gauge | One per task id (hundreds exist, e.g. `...task.daily_digest_GMT.executionTimeSeconds`). **Wall-clock time only — no success/failure tag.** |
| `com.honeyfy.distributedtask.DistributedTaskMetricReporter.executions` | counter | **This** is where success/failure lives — tagged `status:success\|failure`, `tasktype`, `queuename`, `context`, `g-cell`. |
| `...DistributedTaskMetricReporter.submit` / `.longExecutionsCounter` / `.executeTimingHistogram` / `.batchSubmitTimingHistogram` | counters/histograms | Submission counts and timing distributions. |

> [!note] Two different task metric families
> Simple scheduled tasks emit only `com.honeyfy.task.<taskid>.executionTimeSeconds` (duration, no status). Success/failure counts come from the **distributed** task reporter (`DistributedTaskMetricReporter.executions` with a `status` tag) — not from a metric named after `ScheduledTasksDecorator` or `RunnableExecutionTimeMonitor` (no such metric exists in Datadog; those are the Java-side wiring).

---

## Path 4 — arbitrary business code

When the built-in paths don't cover a metric you need (a business KPI, a hot code block), instrument explicitly:

- **`CodeBlockMeasurer`** (`gong-dashboards` · `com.honeyfy.monitoring.CodeBlockMeasurer`) — wrap a block to emit its execution time.
- **`DefaultSimpleMetricsReporter.report(prefix, name, value)`** — emit a one-off gauge/counter into the same `MetricsConsumer` pipeline.
- **`LogicalEventsService`** (`honeyfy` · `Observability/.../logicalevents/`) — for platform-agnostic **business events** (also fan out to Dynatrace), not raw metrics.

Keep tag cardinality bounded — never tag by raw user id, raw URL, or unbounded free text.

---

## Worked examples — Call Scheduler & Recording Consent

Two real Gong domains, showing exactly what the paths above produce in live Datadog (verified 2026-07-24). Note the **hyphen-stripped, concatenated** tag values throughout.

### Call Scheduler (`context: callscheduler`)

**Kafka — infra metrics** (the generic `com.honeyfy.kafka.infra.*` family):

| Metric | Example tag values |
|---|---|
| `...KafkaConsumerMetrics.processed.total` | `consumer:callschedulerpurgecompanyconsumer`, `consumer:meetingscallschedulerupdatedconsumer` |
| `...ConsumersLagSampling.lag` | `consumer:callschedulerwebexsyncusersconsumer`; `consumergroup:callschedulercallschedulingrequestsconsumer`; `topic:callschedulerpurgecompanyconsumererrors` |
| `...KafkaMonitoring.events.sent.success` | `producer:callschedulinghistorycallschedulerproducer` |

**Kafka — per-consumer class metrics** (each consumer class also emits its own richer set, more detailed than the infra family):

```
com.honeyfy.callscheduler.kafka.consumer.CallSchedulingRequestsConsumer.received
com.honeyfy.callscheduler.kafka.consumer.CallSchedulingRequestsConsumer.processed
com.honeyfy.callscheduler.kafka.consumer.CallSchedulingRequestsConsumer.exceptions
com.honeyfy.callscheduler.kafka.consumer.CallSchedulingRequestsConsumer.timeMillis.{min,max,mean,count,1MinuteRate}
com.honeyfy.callscheduler.kafka.consumer.CallSchedulingRequestsConsumer.waitForLockTimeMillis.{min,max}
com.honeyfy.callscheduler.kafka.producer.CallSchedulingUpdatedProducer.messagesize.count
```

**HTTP endpoints** — via `ReportPageHitDataFilter.webPageHitsTimer.*`, sample `path` values:
`/scheduledcallsactions/schedulenewcallmanually`, `/scheduledcallsactions/cancelscheduledcallbyowner`, `/scheduledcallsactions/restorecancelledcallbyowner`, `/cancelblacklistedcalls`.

**Scheduled tasks:** none found — Call Scheduler drives its work through Kafka consumers/producers, **not** the `com.honeyfy.task.*` scheduled-task framework. (A good illustration that not every service uses every path.)

### Recording Consent (`context: recordingconsentapiserver`, `recordingconsenttasks`)

**Kafka — infra metrics:**

| Metric | Example tag values |
|---|---|
| `...KafkaConsumerMetrics.processed.total` | `context:recordingconsenttasks`, `consumer:recordingconsentpurgecompanyconsumer`, `topic:recordingconsenttimebasedevents` |
| `...ConsumersLagSampling.lag` | `consumergroup:recordingconsenttasksconsentcallschedulingupdatedconsumer` (← the [[Call Scheduling]] → Consent handoff consumer), `...consentemailexecutorconsumer`, `...timebasedeventsconsumer` |
| `...KafkaMonitoring.events.sent.success` | `context:recordingconsenttasks`, `topic:recordingconsenttimebasedevents` |

> The `consentcallschedulingupdatedconsumer` tag is the live proof of the cross-domain flow: Call Scheduler publishes to `call-scheduling-updated`, and Recording Consent's `ConsentCallSchedulingUpdatedConsumer` consumes it (Java class name → hyphenless tag).

**HTTP endpoints** — `ReportPageHitDataFilter.webPageHitsTimer.*`, sample `path` values:
`/admincenter/recordingconsent`, `/ajax/company/recordingconsent/validatelink`, `/ajax/company/recordingconsent/validatelogo`.

**Scheduled tasks** — Consent **does** use the `com.honeyfy.task.*` framework (unlike Call Scheduler):

```
com.honeyfy.task.dcp_consent_email_comparison.executionTimeSeconds
com.honeyfy.task.populate_consent_redis_with_all_accessors.executionTimeSeconds
com.honeyfy.task.populate_all_companies_in_consent_redis.executionTimeSeconds
com.honeyfy.task.log_db_recording_consent_statement_stats_producer.executionTimeSeconds
```

**Domain-specific business metrics** (hand-instrumented, not from the automatic paths — see [[#Path 4 — arbitrary business code]]):

```
com.honeyfy.recording.consent.jump_page_audit.failure.counter
com.honeyfy.recording.consent.audit_service_executor.queue_size
recording.consent.redis.populate.company.execution.time.{min,max,mean,count,1MinuteRate}
recording.consent.redis.populate.failures.count
```

> [!note] `DistributedTaskMetricReporter.executions` — neither domain
> Neither Call Scheduler nor Recording Consent appears in the `context`/`tasktype`/`queuename` values of `com.honeyfy.distributedtask.DistributedTaskMetricReporter.executions`. That SQS-backed distributed-task metric is used by other services (e.g. CRM mirror, themes, engage async tasks). Consent uses the simpler `com.honeyfy.task.*` scheduled tasks instead.

## Dashboards are a separate concern

Emission (Half 1) puts metrics *in* Datadog. Turning them into charts is a **separate, deliberate step**. For Kafka, `KafkaDashboardsCreator` (`honeyfy` · `KafkaIntegration/KafkaInfra/.../monitoring/KafkaDashboardsCreator.java`) programmatically builds dashboard definitions whose widgets *query* the metrics above, then create-or-updates them via the Datadog REST API and files them into a dashboard list.

> [!warning] Naming gotcha when reading dashboard queries
> `KafkaDashboardsCreator.dd(name)` strips hyphens because metric tag values arrive in Datadog **without dashes** — **confirmed live**: the `consumer` tag on `ConsumersLagSampling.lag` shows values like `accountactivityeventsconsumer` and `dealschangeeventsconsumer` (words concatenated, no separator). A consumer named `my-feature-consumer` is queried as `consumer:myfeatureconsumer`. If a widget is empty, suspect this hyphen mismatch (or a `context`/`appName` mismatch) **before** suspecting a missing metric — the metric is almost certainly there.

The dashboard-creator beans are `@Profile(DEV)` — dashboard generation is a dev/manual action, not part of the running service.

---

## Debugging "my metric isn't showing up"

Work the pipeline in order:

1. **Is it emitted?** Confirm your code is registered through the infra path (filter installed / consumer registered via `KafkaConsumerConfigurer` / task via the distributed scheduler). If you hand-rolled it, it's not automatic.
2. **Is the pipeline running?** Metrics are sampled periodically then delivered by one of the three mechanisms (MetricsStreamer REST, OTel SDK, or Kafka `MultiMeasure` events) — allow for the sample interval; nothing is instantaneous.
3. **Are the tags what you think?** Check `context` (kebab-cased app name), and remember hyphen-stripping on Kafka consumer/producer tag values (see the dashboard-query gotcha below).
4. **Is a flag gating it?** Kafka error metrics require `persistErrors*`.
5. **Only then** look at the dashboard query — an empty widget usually means a query/tag mismatch, not a missing metric.

---

## Reference — where the code lives

| Concern | Class | Repo |
|---|---|---|
| Shared sink | `MetricsConsumer`, `DefaultSimpleMetricsReporter` | `gong-infra-core` / `Monitoring` |
| Periodic sampling | `PeriodicMetricsCollectionService`, `PeriodicallySampledMetric` | `gong-infra-core` / `Monitoring` |
| Deliver to Datadog (Dropwizard) | `KafkaMetricsReporter` → `RestMetricReporter` (MetricsStreamer/Feign), `OpenTelemetryMetricReporter` (OTel SDK) | `gong-infra-core` / `Datadog` |
| Deliver to Datadog (direct sampled) | `MetricsConsumer` → `KafkaMetricsConsumer` (Kafka `MultiMeasure` events) | `gong-infra-core` / `Datadog` |
| HTTP endpoints | `RequestMetricsReporterFilter` (per-service) **or** `ReportPageHitDataFilter` (shared `webPageHitsTimer.*`, used by Call Scheduler & Consent) (+ `DimensionalTimersCache`, `DimensionalCountersCache`) | per API-server subsystem; filters in `webutil` |
| Kafka emission | `KafkaMonitoring`, `KafkaMonitoredMetricsConsumer`, `KafkaConsumerConfigurer` | `honeyfy` / `gong-infra-core` |
| Scheduled tasks | `MonitoredTaskSchedulerFactory`, `ScheduledTasksDecorator`, `RunnableExecutionTimeMonitor` | `gong-infra-core` / `Datadog` |
| Business code | `CodeBlockMeasurer`, `LogicalEventsService` | `gong-dashboards`, `honeyfy` / `Observability` |
| Dashboards (Kafka) | `KafkaDashboardsCreator`, `Dashboards`, `Widgets`, `DashboardList` | `honeyfy`, `gong-infra-core` / `DatadogMonitorCommon` |

---

## Verification status

Fully verified 2026-07-24. Architecture and class-level claims (emission paths, delivery mechanisms, filter/decorator wiring, naming convention) verified against source via the Gong Code KB. Live metric names and tags (HTTP endpoint, scheduled/distributed task, and the three Kafka metrics, plus hyphen-stripping on `consumer` tags) verified against live Datadog. The **Call Scheduler** and **Recording Consent** worked examples are real production metric names + tag values pulled from live Datadog on that date. All metric-name strings in this doc are real production names as of then.

## Related Notes

- [[Recording Architecture — How Gong Records Meetings]]
- [[Troubleshoot Endpoints]]
