---
title: "Software Defined Modules - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/1999372521/Software+Defined+Modules"
author:
published:
created: 2026-06-16
description:
tags:
  - "clippings"
---
## Software Defined Modules

## Huddle

[https://app.gong.io/call?id=362551440636833666](https://app.gong.io/call?id=362551440636833666 "https://app.gong.io/call?id=362551440636833666")

## Motivation

An organized and clear way to define Gong modules and data sources.  
If these definitions are easily accessed and maintained in our source code, we can create some powerful tools.

This is another step towards Multi-Gong.  
Using the module definitions, we will be able to create Gong environments from scratch, and communicate changes to Devops that will be executed (after approval) across all of the environments.  
  
Having the module definitions in the same repository as the source code that depends on it, creates a necessary coupling (same as Db schema migration coupling with Flyway) that will prevent future bugs.

## Proposition - YAML

```
# Used to setup the application deployment strategy available as spring bean

# to detect current deployment id, whether being phased out etc

deployment: AwsAutoDiscoveryRollingDeployment

# Is public facing web-app;

# used to determine x-TraceId forwarding and response headers

publicFacing: True

applications:

  - Orchestrator

locks: True # Implies access to call locks DBs (locks-01, locks-02, ...)

scheduledTasks: False # Implies access to scheduled-tasks db and distributed locks

# Application data source access requirements

dataSources:

  postgres: # Postgres RDS / Aurora

    OPERATIONAL: GENERIC_READ_WRITE

    DWH: GENERIC_READ_WRITE

    REMINDER: GENERIC_READ_WRITE

  mongodb:

    TRANSCRIPTS: READ_ONLY

  elasticsearch:

#     See com.honeyfy.elasticsearch.client.MultiClusterClient.Cluster

    CALLS: [READ, WRITE]

    EMAILS: [READ, WRITE]

    PERSON: [READ, WRITE]

    DEALS: [READ, WRITE]

    CALENDAR_EVENTS_HISTORY: [READ, WRITE]

    OMNI_SEARCH_CRM: [READ, WRITE]

    DEAL_AGGREGATION: [READ, WRITE]

    AUDITS: [READ, WRITE]

    TEXTS: [READ, WRITE]

    DEAL_WARNING_HISTORY: [READ, WRITE]

  redis:

    - 'gong-prod'

    - 'feature-flags'

    - 'gong-session'

## Roles this app may assume to perform some activities

roles:

  - ResourceProxy:

      dataSources:

        s3:

          - 'honeyfy/call-recordings': READ_ONLY_AND_LIST # Use AWS JSON

          - 'honeyfy/snapshots': READ_ONLY

          - 'honeyfy/profile-photo': READ_ONLY

# Custom Policies using AWS JSON

# We already have YAMLS for Kafka
```

```
isTenantIsolationEnabled: True
```

## Applications

- **Wiring tests** - beans vs yaml  
	In master: WebFrontEnd, IngeseterCalendarSupervisor.  
	Already caught two incidents!  
	WIP

java.lang.AssertionError:  
ACTUAL represents the wired resources/configurations according to the bean wiring of the app/module.  
EXPECTED represents the values of the app descriptor (\[module name\].gong-app-descriptor.yaml).  
In case of a discrepancy, either change the configuration of the yaml file, OR change the wiring of the app.  
For example, if DbBeans are wired, the yaml file should declare `dataSources: postgres: OPERATIONAL: GENERIC_READ_WRITE`  
Discrepancies:

<locks>: DIFFERENT values;  
ACTUAL value = "false";  
EXPECTED value = "true"

<scheduledTasks>: EXPECTED value "false" is MISSING

<dataSources.postgres>: EXPECTED value "DWH" is MISSING

<dataSources.postgres>: ACTUAL value "ESCTRL" is REDUNDANT

<dataSources.postgres.REMINDER>: DIFFERENT values;  
ACTUAL value = "GENERIC\_READ\_ONLY";  
EXPECTED value = "GENERIC\_READ\_WRITE"

<dataSources.elasticsearch>: EXPECTED value "PERSON" is MISSING

<dataSources.elasticsearch.DEALS>: DIFFERENT values;  
ACTUAL value = "\[READ\]";  
EXPECTED value = "\[READ, WRITE\]"

<dataSources.elasticsearch.EMAILS>: DIFFERENT values;  
ACTUAL value = "\[\]";  
EXPECTED value = "\[READ, WRITE\]"

<dataSources.elasticsearch.DEAL\_AGGREGATION>: DIFFERENT values;  
ACTUAL value = "\[READ\]";  
EXPECTED value = "\[READ, WRITE\]"

at com.honeyfy.testutilweb.WebAppYamlTest.lambda$temp$6(WebAppYamlTest.java:157) at com.honeyfy.util.flow.Robust.robust(Robust.java:76) at com.honeyfy.testutilweb.WebAppYamlTest.temp(WebAppYamlTest.java:142) at com.honeyfy.testutilweb.WebAppWirerForTesting.testWiring(WebAppWirerForTesting.java:65) at com.honeyfy.testutilweb.WebAppWirerForTesting.testWiring(WebAppWirerForTesting.java:53) at com.honeyfy.test.webfrontend.WebFrontEndWiringTest.test1WebFrontEndWiringInDev(WebFrontEndWiringTest.java:22)  
…

- **Lu Haiti Rothschild** tests - prod vs yaml  
	check network, policies, permissions…  
	(inter-app, database resources, S3, etc)  
	Ready for development
- Communicating changes to **devops**:  
	Whatever necessary for a functioning environment, as described in the yaml above.  
	WIP
![](https://media-cdn.atlassian.com/file/73df62d5-5d95-4d2e-88e9-406fb837954b/image/cdn?allowAnimated=true&client=b73064ee-c850-4e4e-b54a-8a9d83b742bb&collection=contentId-1999372521&height=125&max-age=2592000&mode=full-fit&source=mediaCard&token=eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJiNzMwNjRlZS1jODUwLTRlNGUtYjU0YS04YTlkODNiNzQyYmIiLCJhY2Nlc3MiOnsidXJuOmZpbGVzdG9yZTpjb2xsZWN0aW9uOmNvbnRlbnRJZC0xOTk5MzcyNTIxIjpbInJlYWQiXX0sImV4cCI6MTc4MTYwNTU4OCwibmJmIjoxNzgxNjAyNzA4LCJhYUlkIjoiNzEyMDIwOmQ0YjBlYzA4LTY5OWMtNGYxNy04ZGQyLTA1OWU5Mzk2ZmU0MyIsImh0dHBzOi8vaWQuYXRsYXNzaWFuLmNvbS9hcHBBY2NyZWRpdGVkIjpmYWxzZSwiYXV0aFR5cGUiOiJzZXNzaW9uIn0.xx2K5iUP45SojFbd1tfvRgiXeyL31PjdxK-Wvs1AQpo&width=680#media-blob-url=true&id=73df62d5-5d95-4d2e-88e9-406fb837954b&clientId=b73064ee-c850-4e4e-b54a-8a9d83b742bb&contextId=contentId-1999372521&collection=contentId-1999372521)
- **Db Roles Migrator** for devtest  
	Integrated into: Flyway:migrate, mvn install, installerCli.dbMigrator.  
	DONE
- **Readiness** checks on deployment  
	Backlog
- **Initialize modules** from the yaml configuration files  
	Backlog

## Are we inventing a wheel here? Should we?

We are introducing a new Domain-specific language (DSL) - why not to use industry standards?

Advantages:

- It is tailored to our specific needs at gong (e.g., permission granularity).
- Programmers do not need to learn a new language (they already speak our current DSL).
- Difficult to read Terraform.

## Implementation details

SoftwareDefinedTopology module - a common module that contains SPIs  
(Database.java, GongAppRole.java, IntrospectableXXX)

## Open issues

Cannot infer required resources from Mongo and S3 accessors.  
We need to decide if and how to split the accessors into different beans.