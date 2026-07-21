---
title: Kafka at Gong
tags:
  - kafka
  - java
  - messaging
  - event-driven
  - cheatsheet
  - devops
created: 2026-07-20
aliases:
  - kafka
  - kafka patterns
  - event streaming
---

# Kafka at Gong

> [!note] TL;DR
> Kafka is Gong's async backbone — services talk to each other by producing and consuming events, not by calling each other directly. All Kafka code is tenant-aware (every message scoped to a `companyId`), wired programmatically (no `@KafkaListener`), and spread across domain-separated clusters.

---

## Core Terms

| Term | Meaning |
|---|---|
| **Topic** | Named channel for one type of event (e.g. `audit-meeting-consent`). One topic per event type is the Gong convention. |
| **Partition** | Ordered sub-stream within a topic. Messages with the same key always land in the same partition → ordering guarantee per key. Gong keys by `companyId` for tenant isolation. |
| **Offset** | Position of a message within a partition. A consumer tracks its offset to know what's been processed. |
| **Producer** | Code that writes messages to a topic. |
| **Consumer** | Code that reads messages from a topic. |
| **Consumer group** | A set of consumers sharing a topic — each partition is assigned to exactly one consumer in the group. Scale out by adding consumers (up to the partition count). |
| **Consumer lag** | How far behind the consumer is from the latest message. High lag = backlog. |
| **Cluster** | A Kafka deployment. Gong has multiple clusters, one per domain (see below). |
| **Broker** | A Kafka server node. A cluster has several brokers. |
| **Rebalance** | When a consumer joins or leaves a group, partitions are redistributed. Rebalances briefly pause consumption. |
| **Dead letter topic** | A topic where failed/poison messages are routed so they don't block processing. |
| **Retention** | How long Kafka keeps messages. Gong configures per-topic based on compliance and replay needs. |
| **At-least-once delivery** | Gong's default guarantee — a message may be delivered more than once. Consumers must be **idempotent**. |

---

## Gong's Kafka Clusters

Each business domain has its own cluster. When adding a consumer or producer, pick the cluster that owns the domain, not the one closest to your service.

| Cluster name (enum) | Domain |
|---|---|
| `RECORDING_CONSENT` | Consent / jump-page interactions, audit events |
| `CALL_SCHEDULER_V2` | Call scheduling events (e.g. `call-scheduling-updated`) |
| `DATA_CAPTURE` | DCP change-request orchestration |
| `APP_USER` | User/company lifecycle events |
| `OPERATIONAL_V1` | Operational events and system actions |
| `EMAIL_DIGESTION_KAFKA_CLUSTER` | Email processing and indexing |
| `ACCELERATE_KAFKA_CLUSTER` | Engage/Accelerate domain |
| `ACTIVITY_HISTORY_LOG_KAFKA_CLUSTER` | Activity tracking and history |

> The cluster enum lives in `KafkaClusterDetails` (honeyfy). Your service declares which clusters it uses in its `gong-app-descriptor.yaml` — missing declarations cause wiring-test failures.

---

## Kafka vs Feign — When to Use Which

| Situation | Use |
|---|---|
| Async, fire-and-forget event ("this happened") | **Kafka** |
| Request needs a response in the same flow | **Feign** |
| One service needs to notify many others | **Kafka** |
| High-throughput / bulk processing | **Kafka** |
| Need replay or audit trail | **Kafka** |
| Strict ordering per tenant | **Kafka** (key by `companyId`) |
| Sub-millisecond latency required | **Feign / direct HTTP** |

---

## Producer Pattern at Gong

### Configuration bean

```java
@Configuration
@Import({KafkaTemplateProvider.Beans.class})
public class MyProducerTemplateConfig {
    public static final String PRODUCER_BEAN_NAME = "my-producer";

    @Bean(PRODUCER_BEAN_NAME)
    public GongEventTenantBasedKafkaTemplate<Long, MyEvent> producerTemplate(
            KafkaTemplateProvider kafkaTemplateProvider) {
        return kafkaTemplateProvider.getGongEventBased(
                KafkaClusterDetails.RECORDING_CONSENT_KAFKA_CLUSTER,
                PRODUCER_BEAN_NAME,
                new KafkaProperties().keySerializer(LongSerializer.class),
                KafkaTopics.MY_TOPIC);
    }
}
```

### Producer service

```java
// Always wrap in Tenant.executeForCompany()
public void publishEvent(long companyId, MyEvent event) {
    Tenant.executeForCompany(companyId, () ->
        kafkaTemplate.send(topicName, companyId, event)
    );
}
```

**Rules:**
- Always execute within `Tenant.executeForCompany(companyId, ...)` — Gong's tenant context.
- Key by `companyId` (type `Long`) to guarantee per-tenant ordering.
- Use `@Qualifier(PRODUCER_BEAN_NAME)` when injecting the template if multiple producers exist.

---

## Consumer Pattern at Gong

Gong wires consumers **programmatically** — there is no `@KafkaListener` annotation. Consumers register via `KafkaConsumerConfigurer` in a `@Configuration static class Beans` that implements `SingleRecordConsumer` (or one of its siblings).

### Consumer interfaces

| Interface | Use when |
|---|---|
| `SingleRecordConsumer<T>` | Complex per-message processing (most common) |
| `MultipleRecordsConsumer<T>` | High-throughput batch processing |
| `TenantBatchConsumer<T>` | Tenant-isolated batch with multi-tenancy support |

### Wiring example

```java
// Consumer class
@Component
public class MyEventConsumer implements SingleRecordConsumer<MyEvent> {
    @Override
    public void accept(MyEvent event) {
        // process event — tenant context is already set by infrastructure
    }
}

// Config
@Configuration
public class MyConsumerConfig {
    @Configuration
    public static class Beans {
        @Autowired
        public void configure(KafkaConsumerConfigurer configurer,
                              MyEventConsumer consumer) {
            configurer.configureSingle(
                    KafkaClusterDetails.RECORDING_CONSENT_KAFKA_CLUSTER,
                    KafkaTopics.MY_TOPIC,
                    consumer);
        }
    }
}
```

Default concurrency: **4** (overridable). Tenant context is injected automatically by the infrastructure — you don't set it in the consumer.

---

## App Descriptor — Required Declaration

Every cluster your module **produces to or consumes from** must be declared in the module's `gong-app-descriptor.yaml`:

```yaml
# src/main/resources/descriptors/app/<Module>.gong-app-descriptor.yaml
kafka:
  - clusterName: RECORDING_CONSENT
    consumerTopics:
      - audit-meeting-consent
  - clusterName: CALL_SCHEDULER_V2
    consumerTopics:
      - call-scheduling-updated
```

Missing declaration → wiring test failure (`<cluster> not found in topology`). The wiring test (`*WiringTest.java`) validates this — run it before marking a Kafka task complete.

---

## Testing Kafka Code

Kafka consumer tests use `@Test(groups = "kafka")` and an **embedded Kafka broker** (`EmbeddedKafkaInfra`). They do **not** run in the standard `mvn test` build (only the `basic` group runs by default).

```bash
# Run kafka-group tests manually
mvn test -pl MyModule -Dgroups=kafka
```

Or run the test class directly in IntelliJ.

See [[TestNG Groups at Gong]] for the full groups reference.

### Resetting a stuck consumer (local / staging)

If a consumer is blocked by a poison message:

```bash
# Stop the service first (wait for session timeout)
kafka-consumer-groups.sh --bootstrap-server <broker> \
  --group <consumer-group> \
  --topic <topic> \
  --reset-offsets --to-latest --execute
```

The service must be stopped before resetting — Kafka won't allow an offset reset while the group has active members.

---

## Observability

| What to look at | How |
|---|---|
| Consumer lag | `kafka-consumer-groups.sh --describe --group <group>` or Datadog / Coralogix dashboards |
| Messages flowing | Coralogix logs filtered by topic name |
| Rebalance events | Application logs for `Rebalance` / `partition assigned` |
| Dead letter queue | Check for a `<topic>-dlt` or `<topic>-error` sibling topic |

---

## Gotchas & Surprises

**No `@KafkaListener` in the codebase.** If you search for it, you won't find it in Gong services. All consumers use `KafkaConsumerConfigurer.configureSingle(...)` in a programmatic `@Configuration` class. Don't add `@KafkaListener` — follow the existing pattern.

**Consumers are idempotent by design.** At-least-once delivery means a message can arrive twice (e.g. after a rebalance). Design `accept()` methods to be safe on re-processing.

**Tenant context is set by the framework, not your code.** Don't call `Tenant.executeForCompany()` inside a consumer — the infrastructure sets it before calling `accept()`. You *do* need it in producers.

**Concurrency = 4 by default.** One consumer instance handles 4 partitions in parallel. If your `accept()` is not thread-safe, this will cause races.

**Cross-cluster is intentional, not a mistake.** `RecordingConsentTasks` consumes from `CALL_SCHEDULER_V2` (`call-scheduling-updated`) even though it "belongs to" the Consent domain. The cluster follows the event's domain of origin, not the consumer's domain.

---

## Creating a New Kafka Topic — Infra Process

> [!warning] Two separate concerns
> **Topic creation** (declaring the topic on MSK) and **module access** (IAM + TLS certs for your service) are two distinct steps handled in two different places.

### Two-track overview

| What you need | Where | How |
|---|---|---|
| Create the topic itself on MSK | `honeyfy` monorepo, `KafkaInfra` module | PR with `topics.yaml` |
| Grant your module access to a cluster | `descriptor.app.yaml` in your subsystem repo | `/infra` PR comment |
| Provision a new MSK cluster | `infra-config/infra-*/gong-msk*/` | DevOps-only, not self-service |

---

### Track 1 — Declaring a new topic (KafkaInfra YAML)

Topics are defined in YAML files in the `honeyfy` monorepo, not via Crossplane or Terraform:

```
KafkaIntegration/KafkaInfra/src/main/resources/kafkaTopics/
  <ClusterName>/
    <ComponentName>/
      topics.yaml       ← your new topic goes here
      fact-topics.yaml  ← reference / "fact" topics
```

The `KafkaOperations` service reads these at startup and applies them via `AdminClient`. It is **idempotent** — only creates topics that don't already exist.

**Key parameters** (from `Topic.java` in `KafkaIntegration/KafkaInfra/`):

| Parameter | Notes |
|---|---|
| `name` | Required. Must be unique within the cluster. |
| `partitions` | Resolved per-environment via `AppPropertyWithGPEFallbackResolver`; can differ per cell. |
| `replicationFactor` | Always **3** in production. Never less. |
| `retentionMs` | Long; defaults to `DEFAULT_RETENTION_MS`. Tiered-storage topics use a separate local-retention field. |
| `cleanupPolicy` | Defaults to `"delete"`. Set `"compact"` only if you need log compaction. |
| `minInSyncReplicas` | Defaults to `DEFAULT_MIN_IN_SYNC_REPLICAS`. |
| `errorTopic` | Boolean. Set `true` to mark as a DLQ/error topic. |
| `shouldTrack` | Boolean. Opts into monitoring. |
| `createAclsOnly` | Boolean. Skip topic creation, only manage ACLs. |

**CI validation**: `KafkaTopicsYamlValidationTest` (`Installer/src/test/`) runs automatically and enforces:
- No duplicate topic names within a cluster.
- Valid YAML schema.
- Valid tenant consumer declarations.

**Review**: standard PR to `honeyfy`, reviewed by owning team.

---

### Track 2 — Granting your module access (descriptor.app.yaml + /infra)

This is the self-service path. It generates IAM policies and a TLS client cert for your module per cell.

**Step 1 — Edit your descriptor**

```yaml
# src/main/resources/descriptors/app/<Module>.yaml  (in your subsystem repo)
managedByCrossplane: true   # required — without this the pipeline does nothing
dataSources:
  kafka:
    - logicalClusterName: RECORDING_CONSENT   # must exist in cluster-mappings.yaml
      permissions: READ_WRITE                 # READ_ONLY | WRITE_ONLY | READ_WRITE
```

**Step 2 — Trigger the pipeline**

Open a PR with the descriptor change, then comment `/infra` on it.

**What happens next (automated):**
1. GitHub Actions generates an `infra-config` PR with IAM policy + cert workflow entries.
2. The `infra-config` PR requires approval from **DevOps + original developer**.
3. After merge: ArgoCD syncs → Crossplane reconciles → `mskcertworkflow` Argo Workflow runs per cell.
4. TLS client cert stored in Secrets Manager at `/gong/<gcell>/<module>/kafka/<logicalClusterName>/client.crt`.
5. GitHub Actions posts a completion comment back on your original PR.
6. `Wait for healthy infra signal` check turns green → you can merge.

**The `logicalClusterName` must exist in `cluster-mappings.yaml`** (in `gong-app-properties` and `infra-config`). If it doesn't, the generator fails with "cluster not found".

---

### Infra gotchas

**Partition count is immutable downward.** You can only increase partitions, never decrease. Get this right before production — think about consumer parallelism headroom now, not later.

**Certs don't appear immediately.** `mskcertworkflow` fires *after* the `infra-config` PR merges and ArgoCD syncs. Don't expect certs at PR-creation time.

**Never hand-edit generated files.** Everything under `infra-config/infra-gpe/gong-module/<module>/` is generated. Edit the descriptor and re-run `/infra`.

**`managedByCrossplane: true` is mandatory.** Without it, `/infra` is a no-op.

**infra-config PR labels are required.** The PR must have `<module>-gpe` or `<module>-gge` labels to trigger GitOps. No labels = no deployment = no cert = stuck check.

**Descriptor filename**: the infra pipeline looks for `src/main/resources/descriptors/app/<module>.yaml` (plain `.yaml`). Some modules also have a `<Module>.gong-app-descriptor.yaml` for the wiring test — these are different files; check your module's existing convention.


## See also

- [[TestNG Groups at Gong]] — running `@Test(groups = "kafka")` tests
- [[Subsystems/Consent/02 - Data Flow]] — all Kafka topics in the Consent subsystem
- [[Subsystems/Consent/Jump Page & DCP]] — jump-page Kafka flows in detail
- [[gong-java-cheat-sheet]] — general Java patterns at Gong
