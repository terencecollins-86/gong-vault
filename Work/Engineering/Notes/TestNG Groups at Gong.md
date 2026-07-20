---
title: TestNG Groups at Gong
tags:
  - testing
  - testng
  - java
  - maven
  - cheatsheet
created: 2026-07-20
aliases:
  - test groups
  - testng groups
  - @Test groups
---

# TestNG Groups at Gong

> [!note] TL;DR
> TestNG `@Test(groups = "...")` controls which tests run in Maven builds. In every standard build (`mvn test`, CI `-Pci`) only the `basic` group runs. All other groups — `kafka`, `manual`, `extended`, etc. — are silently skipped unless you override on the command line or run the class directly in IntelliJ.

---

## All known groups

| Group | What it means | Runs in `mvn test`? |
|---|---|---|
| `basic` | Standard unit / in-process Spring test (Mockito, test DB) | **Yes** |
| `kafka` | Requires embedded Kafka broker (`EmbeddedKafkaInfra`) | No |
| `manual` | Needs external infra or human intervention | No |
| `extended` | Heavy DB tests via real Postgres container | No |
| `run_locally` | Dev machine only | No |
| `performance` | Benchmarks | No |
| `localstack` | Requires LocalStack (AWS emulation) | No |
| `health` | Redis health-check tests | No |
| `unit` | Isolated unit tests (a few CRM modules) | No |
| `inmemory-test` / `mockserver` | Test-specific infra mocks | No |
| `masking` | Regex masker tests (Calendar ingestion) | No |
| `integration-basic` | Integration tests (all currently `enabled = false`) | No |
| `comprehensive` | Long-running ML tests (all currently disabled) | No |
| `serial` | Reserved for sequential test runs | No |

Group name constants live in `gong-infra-core/TestUtil/.../testutil/utils/TestGroups.java`:
`BASIC = "basic"`, `MANUAL = "manual"`, `IGNORED = "ignored"`. Most code uses the string literals directly.

---

## How Maven wires groups

The `gong-parent-pom` Surefire config drives everything:

```xml
<groups>${unit.test.groups}</groups>
```

The active Maven profile sets `unit.test.groups`:

| Profile | `unit.test.groups` | Activated |
|---|---|---|
| `dev` | `basic` | Default (every `mvn test`) |
| `ci` (`-Pci`) | `basic` | CI builds |
| `serial` (`-Pserial`) | `serial` | Sequential runs |
| `skip-tests` | — | `skipTests=true` |

There is **no `<excludedGroups>`** in the current stable pom — it is pure include-only. Any test whose group doesn't match `basic` is silently not run.

> [!tip] Incoming change
> A branch pom (`17.support-basic-and-empty-test-group-in-ci-profile`) is switching to **exclude-only** mode. The `dev`/`ci` profiles will drop the `<groups>` include filter and instead set `<excludedGroups>integration,system,manual,kafka,integration-basic`. This lets un-grouped tests run without requiring `groups = "basic"`.

---

## Running non-basic groups

```bash
# Run only kafka tests in a module
mvn test -Dgroups=kafka

# Run kafka tests in a specific module
mvn test -pl DcpChangeManager -Dgroups=kafka

# Run kafka + basic together
mvn test -Dgroups="basic,kafka"
```

Or run the test class directly in IntelliJ — it bypasses the Surefire group filter entirely.

---

## The `kafka` group in practice

Tests tagged `kafka` spin up a **real embedded Kafka broker** — too heavy for parallel CI unit runs. Both `@BeforeClass` and `@Test` are scoped to the same group so the Spring context (with embedded broker + topic creation) only starts when the group is active.

Example from `gong-data-capture/DcpChangeManager`:

```java
@BeforeClass(groups = {"kafka"})
public void setupClass() { ... }

@Test(groups = "kafka")
public void consumerReceivesEvent() { ... }
```

Under the default `dev` / `ci` profile this test never runs. It's intended for local verification of Kafka consumer wiring before pushing.

---

## See also

- [[gong-java-cheat-sheet]] — general Java patterns at Gong
- [[Flyway Migrations at Gong]] — how DB migrations interact with test setup
- [[Subsystems/Consent/03 - Ubiquitous Language]] — domain context for `DcpChangeManager` tests
