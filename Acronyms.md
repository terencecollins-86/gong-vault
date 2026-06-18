---
tags:
- gong
- reference
- onboarding
created: 2026-06-18
---

# Acronyms & Abbreviations

Quick-reference glossary of acronyms used across these notes. Each entry links directly to the page (and section) where the term appears in context.

---

## A

### AI4Dev
**AI for Development** — Gong's internal initiative providing AI tooling, Claude Code agents, and shared workflows for engineers.
→ [[AI4Dev Use Cases - R&D]]

### APM
**Application Performance Monitoring** — umbrella term for tools that track runtime health and performance of applications. Gong uses **Dynatrace** as its APM.
→ [[Web application performance metrics and how to use them - R&D#APM in Gong]]

### AWS
**Amazon Web Services** — Gong's primary cloud provider. Profiles used internally: `prod`, `devtest`, `internal`.
→ [[Import Prod Data - Calls#Prerequisites]]
→ [[gong-module-run How To#Prerequisites]]

---

## C

### CDC
**Change Data Capture** — technique for streaming database changes as events. Used in Gong via Debezium on RDS and referenced in the activity store pipeline.
→ [[Comms Capture Architecture Overview#Email Capture — gong-ingestion → gong-email-digestion]]

### CQL
**Confluence Query Language** — query syntax for searching Confluence pages programmatically (e.g. `text="comms capture" AND space=EN`).
→ [[Comms Capture Architecture Overview#Confluence Docs (search links)]]

### CRM
**Customer Relationship Management** — refers to both the product category (Salesforce, HubSpot) and Gong's internal CRM integration subsystems (`gong-crm`, `gong-crm-enrichment`).
→ [[Comms Capture Architecture Overview#Telephony / Dialer Capture — gong-telephony-systems]]

### CWV
**Core Web Vitals** — Google's standard set of web performance metrics (LCP, FID, CLS). Used in Gong's Dynatrace dashboards.
→ [[Web application performance metrics and how to use them - R&D#Core Web vitals]]

---

## D

### DCP
**Data Capture Profile** — Gong's per-company and per-user consent and capture settings. Controls what is allowed to be recorded. Lives in the `data_capture` DB schema, managed by `gong-data-capture`.
→ [[Comms Capture Architecture Overview#Consent & Data Capture Profile (DCP) — gong-data-capture]]

### DD
**Datadog** — Gong's monitored metrics backend. More expensive than OpenSearch (~$0.10/metric vs ~$0.0000015). Monitored metrics go to both DD and ES; explorative metrics go to ES only.
→ [[Metrics in Gong - the complete guide - R&D#Pricing: Datadog vs. OpenSearch]]

### DSL
**Domain-Specific Language** — in the context of Software Defined Modules, the YAML descriptor format (`*.gong-app-descriptor.yaml`) used to declare a module's data sources, roles, and deployment config.
→ [[Software Defined Modules - R&D#Are we inventing a wheel here? Should we?]]

### DTO
**Data Transfer Object** — a plain object used to carry data between layers. `AppUser` is the primary user DTO in Gong.
→ [[gong-java-cheat-sheet#AppUser — core user DTO]]

### DT
**Dynatrace** — Gong's APM and RUM platform. Used for page load analysis, waterfall traces, and custom dashboards.
→ [[Web application performance metrics and how to use them - R&D#APM in Gong]]

### DWH
**Data Warehouse** — the `DWH_DB` PostgreSQL component. Imported separately from `OPERATIONAL_DB` in prod data imports.
→ [[Import Prod Data - Calls#What the Config Does]]

---

## E

### ES
**Elasticsearch / OpenSearch** — used interchangeably in older Gong docs. The current platform is **OpenSearch**, but code and config often still say `elasticsearch`. Explorative metrics are stored here; the call search index is `EsCallSchema`.
→ [[Metrics in Gong - the complete guide - R&D#Pricing: Datadog vs. OpenSearch]]
→ [[Import Prod Data - Calls#CALLS (OpenSearch / Elasticsearch)]]

---

## G

### GA
**Generally Available** — a release stage meaning a feature is live for all customers, no longer in limited rollout. Logging standards shift when a module goes GA (reduce verbose DEBUG → INFO or TRACE).
→ [[Adjustable Logging - R&D#Log Levels in Gong - Standards Review]]

### GDM
**Gong Data Mesh** — Gong's internal data platform for schema cataloguing, entity lineage, and downstream data access. Services: `GdmSchemaCatalogApiServer`, `GdmManagementServer`. Also surfaces in `GdmKafkaProducerHelper`.
→ [[Import Prod Data - Calls#Related Run Configs]]
→ [[gong-java-cheat-sheet#GdmKafkaProducerHelper — generic Kafka producer utility]]

### GGE
**Global Gong Environment** (also called **Global Cell**) — the shared global infrastructure cell. Some services (e.g. Credentials Manager) only exist in GGE.
→ [[Developer Data Gateway Spec - R&D#Request]]

### GTM
**Go-To-Market** — the sales, marketing, and customer success organisation at Gong. Relevant for Slack channels and cross-functional communication.
→ [[Gong Onboarding#Key Slack Channels]]

---

## I

### IAM
**Identity and Access Management** — AWS service that controls permissions for services, roles, and resources. Referenced in the module run how-to when provisioning new service access via `descriptor.app.yaml`.
→ [[gong-module-run How To#Relationship to descriptor.app.yaml / /infra]]

### IDE
**Integrated Development Environment** — the primary IDE at Gong is **IntelliJ IDEA**. Lightrun and Claude Code both integrate directly with it.
→ [[Lightrun - R&D#Installation]]

---

## J

### JWT
**JSON Web Token** — the auth token format used by Gong's troubleshooter mechanism. Set as a cookie (`troubleshootersAuthJWT`) after requesting access via the Developer Data Gateway.
→ [[Developer Data Gateway Spec - R&D#Result]]

### JVM
**Java Virtual Machine** — the runtime for all Gong Java services. `gong-module-run` sets JVM options (heap size, debug port, JMX) per container via `JAVA_OPTS`.
→ [[gong-module-run How To#Core Commands]]

---

## L

### LA
**Limited Availability** — a release stage between internal testing and GA. A feature is live but only for a subset of customers.
→ [[Adjustable Logging - R&D#Log Levels in Gong - Standards Review]]

### LCP
**Largest Contentful Paint** — a Core Web Vital measuring when the largest visible element on a page finishes rendering. Used in Gong's Dynatrace dashboards to track page load time.
→ [[Web application performance metrics and how to use them - R&D#How to measure a page's load time]]

---

## M

### MCP
**Model Context Protocol** — the open protocol that connects AI assistants (Claude) to external tools and data sources. Gong runs an MCP gateway (`MCPGatewayWebApi`, `MCPServer`).
→ [[gong-module-run How To#Bounded Contexts]]

### MDC
**Mapped Diagnostic Context** — SLF4J's mechanism for attaching key-value pairs (e.g. `cid` = company ID) to log entries. Used in Lightrun snapshot conditions to filter by tenant.
→ [[Lightrun - R&D#Tips]]

---

## O

### O365
**Microsoft Office 365** — Microsoft's cloud productivity suite. Gong ingests O365 calendar (`OfficeCalendarIngester`) and mail for communication capture.
→ [[Comms Capture Maven Modules#gong-ingestion]]
→ [[Comms Capture Architecture Overview#Calendar Capture — gong-ingestion]]

---

## P

### PR
**Pull Request** — a GitHub code review request. Referenced in AI4Dev use cases for the GongReviewer workflow and Claude Code plan-mode integration.
→ [[AI4Dev Use Cases - R&D#Use Case 2: Streamlining PR Fixes Using Claude Code Plan Mode with GongReviewer]]

---

## R

### RDS
**Relational Database Service** — AWS's managed PostgreSQL / Aurora service. Gong's `OPERATIONAL_DB` and `DWH_DB` run on RDS.
→ [[Import Prod Data - Calls#OPERATIONAL_DB (PostgreSQL)]]

### RUM
**Real User Monitoring** — Dynatrace's module for capturing real browser sessions to measure page load, API call timing, and user interaction performance.
→ [[Web application performance metrics and how to use them - R&D#APM in Gong]]

---

## S

### S3
**Simple Storage Service** — AWS object storage. Used by Gong for call recordings, prod snapshot exports (`gong-internal-export` bucket), and profile photos.
→ [[Import Prod Data - Calls#S3 Bucket Reference]]

### SMS
**Short Message Service** — text messaging. Captured in Gong via Dialpad (`DialpadSmsService`) and Gong Connect / Twilio (`GongConnectMessagingServer`).
→ [[Comms Capture Architecture Overview#SMS Capture]]

### SPA
**Single Page Application** — a web app architecture where content updates without full page reloads. Gong's web app is a **multi-SPA**, which affects how Dynatrace RUM measures page load metrics.
→ [[Web application performance metrics and how to use them - R&D#APM in Gong]]

### SPI
**Service Provider Interface** — a Java pattern for pluggable implementations. Used in the `SoftwareDefinedTopology` module (`Database.java`, `GongAppRole.java`) as extension points.
→ [[Software Defined Modules - R&D#Implementation details]]

### SQS
**Simple Queue Service** — AWS's managed message queue. One of the data stores audited by the Developer Data Gateway alongside Kafka and Redis.
→ [[Developer Data Gateway Spec - R&D#Request]]

### SSO
**Single Sign-On** — authentication via a central identity provider (Gong uses **Okta**). Required for Lightrun login; also used by the Developer Data Gateway portal.
→ [[Lightrun - R&D#Installation]]
→ [[Developer Data Gateway Spec - R&D#Request]]

---

## T

### TSA
**Troubleshooter Audit** — a Jira issue type automatically created when a developer requests access via the Developer Data Gateway. Tracks who accessed what data source and why.
→ [[Developer Data Gateway Spec - R&D#Result]]

---

## V

### VIP
**Virtual IP** — a stable network address fronting a service cluster. Gong internal service URLs follow the pattern `<service>-vip.<cell>.gongio.net` (e.g. `logs-manager-vip.prod.gongio.net`).
→ [[Adjustable Logging - R&D#Adjusting your logs temporarily]]

### VoIP
**Voice over Internet Protocol** — internet-based calling. Gong Connect is Gong's native VoIP dialer, built on Twilio.
→ [[Comms Capture Architecture Overview#Gong Connect (Native VoIP Dialer) — gong-connect]]

### VPC
**Virtual Private Cloud** — an isolated AWS network. The `gong-internal-export` S3 bucket is inside Gong's VPC, requiring VPN access to reach it from outside AWS.
→ [[Import Prod Data - Calls#Prerequisites]]

### VPN
**Virtual Private Network** — required for accessing Gong's internal AWS resources and Lightrun's on-premise server. Use **Gong VPN** before running prod data imports or using Lightrun.
→ [[Import Prod Data - Calls#Prerequisites]]
→ [[Lightrun - R&D#Installation]]
