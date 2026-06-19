---
tags: [gong, comms-capture, runbook, hybrid-dev, module-run, index]
aliases: [Comms Capture Runbooks, Comms Capture - gong-module-run Runbook]
created: 2026-06-18
updated: 2026-06-19
---

# Comms Capture — Runbooks Index

Hub for the **Comms Capture** team's per-bounded-context runbooks. Each linked note is self-contained: repos, services (with derived Swagger links), and ready-to-run `gong-module-run` start/stop commands for both local and remote.

→ See [[GRM  gong-module-run How To]] for general CLI reference and prerequisites.

## Local vs Remote — the one rule
Same command both ways. **Append `--remote`** to deploy to your remote dev namespace; **omit it** to run locally. `up` starts, `down` stops.

```bash
gong-module-run up   --subsystem-names <subsystem>            # local start
gong-module-run up   --subsystem-names <subsystem> --remote   # remote start
gong-module-run down --subsystem-names <subsystem>            # local stop
gong-module-run down --subsystem-names <subsystem> --remote   # remote stop
```

---

## Bounded Contexts

| # | Context | Subsystem | Runbook |
|---|---------|-----------|---------|
| 1 | Data Capture | `gong-data-capture` | [[Data Capture]] |
| 2 | Recorders | `gong-recorders` | [[Recorders]] |
| 3 | Cloud Recorders | `gong-cloud-recorders` | [[Cloud Recorders]] |
| 4 | Call Scheduling | `gong-call-schedulers` | [[Call Scheduling]] |
| 5 | Telephony Systems | `gong-telephony-systems` | [[Telephony Systems]] |
| 6 | Ingestion | `gong-ingestion` | [[Ingestion]] |
| 7 | Call Orchestration | `gong-orchestration` | [[Call Orchestration]] |
| 8 | Processors | `gong-processors` | [[Processors]] |
| 9 | In-Meeting Experience | `gong-inmeeting-experience` | [[In-Meeting Experience]] |
| 10 | Conversations | `gong-conversations` | [[Conversations]] |
| 11 | Webconf Streaming | `gong-webconf-streaming` | [[Webconf Streaming]] |
| 12 | Communications Publisher | `gong-communications-publisher` | [[Communications Publisher]] |
| 13 | Communication Compliance | `gong-communication-compliance` | [[Communication Compliance]] |

---

## Common Multi-Context Combos

These span several contexts at once. Append `--remote` to run against your remote dev namespace; omit for local.

### End-to-end capture pipeline (scheduling → ingestion → recording → processing)
```bash
gong-module-run up \
  --subsystem-names gong-call-schedulers,gong-ingestion,gong-recorders,gong-cloud-recorders,gong-orchestration,gong-processors
```

### Capture + post-call (add conversations and summaries)
```bash
gong-module-run up \
  --subsystem-names gong-call-schedulers,gong-ingestion,gong-recorders,gong-cloud-recorders,gong-orchestration,gong-processors,gong-conversations
```

### Streaming capture path (webconf providers → cloud recorder → processor)
```bash
gong-module-run up \
  --subsystem-names gong-webconf-streaming,gong-cloud-recorders,gong-orchestration,gong-processors
```

### Consent + recording only (data capture team focus)
```bash
gong-module-run up \
  --subsystem-names gong-data-capture,gong-recorders
```

### Tear down everything above
```bash
gong-module-run down \
  --subsystem-names gong-call-schedulers,gong-ingestion,gong-recorders,gong-cloud-recorders,gong-orchestration,gong-processors,gong-conversations,gong-webconf-streaming,gong-data-capture,gong-communications-publisher,gong-communication-compliance,gong-inmeeting-experience
```

---

## Convergence Point

All capture paths ultimately write to the **`honeyfy.public.call`** table (RDS) — the single source of truth for a captured call/communication. Every ingestion path (recorders, cloud recorders, telephony, ingestion) converges here.

---

## Shared Reference Notes

- [[GRM  gong-module-run How To]] — CLI reference, prerequisites, deployment-scope guide
- [[Comms Capture Architecture Overview]] — capture domains, Kafka events, shared models
- [[Comms Capture Maven Modules]] — per-service Maven module breakdown
- [[Swagger Pages]] — internal Swagger VIP pattern + `troubleshootersAuthJWT` auth notes (org-wide; lives in `Engineering/`)
- [[Import Prod Data - Calls]] — getting real call data into local DBs for testing

---

## Assumptions & Caveats

- **Local syntax**: local = omit `--remote` (per [[GRM  gong-module-run How To]]); not independently verified against `gong-module-run` source.
- **Swagger URLs are derived** from the documented VIP pattern `https://<service>-vip.prod.gongio.net/swagger-ui/index.html` (see [[Swagger Pages]]). The pattern is confirmed; individual service URLs are not all verified live. Only HTTP-exposing services (`*apiserver`, `*webapi`, `*server`, `*frontend`) get a link; workers/supervisors/ingesters are marked `—`.
- **Repo names for contexts 7–13** (orchestration, processors, in-meeting, conversations, webconf-streaming, compliance) are inferred from subsystem names and marked `(?)` in each runbook — confirm against the module registry (`gong-build-commons/dev/gong-module-runner/conf/gong-modules-base.yaml`).
