---
tags:
- gong
- hybrid-dev
- module-run
- deployment
- onboarding
aliases: [gong-module-run How To]
created: 2026-06-17
---

# gong-module-run — How To Use

`gong-module-run` is the CLI tool for spinning up Gong microservices in a **hybrid development environment**. Instead of running all services locally, you deploy selected modules to a shared remote cluster while keeping your local dev setup connected to it. This lets you test features end-to-end without running the full Gong stack on your machine.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| `gh` CLI | Authenticated to the `Honeyfy` GitHub org |
| `gong-module-run` installed | Ask your team lead for the install method if not already set up |
| Remote tunnel active | Via `gong-module-runner remote --connect` or the **Klopper app** |
| Python 3 + `pyyaml` | Needed only if running the module-discovery scripts manually |

### Connecting the tunnel

Before deploying anything, ensure the remote tunnel is up:

```bash
gong-module-runner remote --connect
```

Or open the **Klopper app** — it manages the connection. If `gong-module-run` commands time out or fail to reach the cluster, the tunnel is likely down.

---

## Core Commands

### Deploy modules

```bash
gong-module-run up --image-names module1,module2,module3 --remote
```

### Deploy from a specific branch

```bash
gong-module-run up --image-names module1,module2,module3 --remote --branch-name <your-branch>
```

Use `--branch-name` when you want the remote cluster to run your in-progress code, not `main`. Omit it to use the latest built image from `main`.

### Tear down modules

```bash
gong-module-run down --image-names module1,module2,module3 --remote
```

Always tear down when done — leaving modules running in the shared cluster consumes resources.

---

## Finding Which Modules You Need

This is the hard part. Every Gong page or feature involves multiple microservices; figuring out the complete list manually is error-prone.

### Option 1 — Ask Claude (recommended)

Use the `module-flow-analysis` skill. In Claude Code, describe what you're working on:

> "What modules do I need for `<feature name or URL>`?"

Claude will:
1. Resolve the module name or URL to the primary service
2. Ask you for the deployment scope (see below)
3. Return a ready-to-run `gong-module-run` command

### Option 2 — Run the scripts manually

```bash
# From gong-ai4dev/claude-code-plugins/plugins/module-flow-analysis/scripts/
python3 discover.py <module_name> --json 2>/dev/null | \
  python3 analyze.py --module <module_name> --deps /dev/stdin --format simple
```

The output is one module name per line. Pass those as `--image-names` to `gong-module-run`.

---

## Deployment Scope

When discovering dependencies, you choose a scope that determines which modules are included:

| Scope | What's included | Best for |
|-------|-----------------|----------|
| **Server dependencies only** | Target module + its direct/transitive deps | Integration tests, API-level testing, headless flows |
| **Full web stack (page only)** | Above + login/home page entry chain | Browser-based testing of a single page |
| **Full web stack + sub-pages** | Above + all sub-pages reachable from the URL | Testing a feature hub with navigation (settings pages, admin dashboards) |

**Why entry chain matters**: A real browser session always traverses login → home page → target page. Each phase calls different services. The full web stack scope adds those extra modules so the browser can actually navigate to your feature.

Two modules are always added for full web stack deployments (invisible to normal dependency tracing):
- `webfrontend` — serves the login page, home page, and page shell
- `resourceproxyserverwebapi` — serves the static JS/CSS bundles

---

## Module Registry

All valid module names live in a single source of truth:

```
gong-build-commons/dev/gong-module-runner/conf/gong-modules-base.yaml
```

If `gong-module-run` says a module name is unknown, check this file. Module names in `--image-names` must match entries here exactly.

---

## Worked Examples

### Example 1: Test an internal API service

You want to run `gong-some-api` and its dependencies:

```bash
gong-module-run up --image-names gong-some-api,dep-service-a,dep-service-b --remote
```

Use "server dependencies only" scope — no browser needed.

### Example 2: Test a feature in the browser

You're working on a feature at `https://gong.app.gong.io/company`. You need a full browser-navigable environment:

```bash
# Claude will generate this for you; it looks like:
gong-module-run up --image-names webfrontend,resourceproxyserverwebapi,gong-some-module,dep-a,dep-b,dep-c --remote
```

Use "full web stack + sub-pages" scope when asking Claude.

### Example 3: Test from your branch

You're developing on `feature/my-change` and want the cluster to run your branch:

```bash
gong-module-run up --image-names gong-my-module,dep-a --remote --branch-name feature/my-change
```

> [!important] `--branch-name` is **remote-only**
> `cli_args.sh` enforces that `--branch-name` may only be combined with `--remote`. It does **not** build or select a git branch for a *local* Docker run. For local testing of your branch, build the image yourself and run the `1.0-SNAPSHOT` tag — see Example 3b.

### Example 3b: Test your branch **locally** in Docker (no remote)

For local Docker runs, `gong-module-run` runs *images*, not git branches. To test your in-progress code you build a local image from your checked-out branch, then tell the runner to use that local image instead of pulling `latest` from ECR.

The trigger is the tag **`1.0-SNAPSHOT`** (the Maven `version` in the poms). `detect_ecr_repo` in `gong-module-run-cli` empties the ECR registry prefix when the tag is `1.0-SNAPSHOT` (or when `--ecr-repository local` is passed), so the runner uses your locally-built image:

```bash
# 1. Build the local image from your feature branch (in the service repo, on your branch)
mvn clean install -pl CallScheduler -am -DskipTests

# 2. Verify the image exists (else the runner silently falls back to ECR)
docker images | grep 'callscheduler.*1.0-SNAPSHOT'

# 3. Run it, forcing the local tag and recreating any running container
gong-module-run up --image-names callscheduler --tag-name 1.0-SNAPSHOT --force-recreate
```

`--ecr-repository local` is an equivalent alternative to `--tag-name 1.0-SNAPSHOT`. `core_infra` (DBs, Redis, Kafka, Traefik) is auto-included unless you pass `--exclude-core-infra-modules`.

| Goal | Command |
|------|---------|
| Latest built image from ECR (default) | `gong-module-run up --image-names callscheduler` |
| **Your local feature-branch code** | `gong-module-run up --image-names callscheduler --tag-name 1.0-SNAPSHOT --force-recreate` |

> [!note] The exact Maven goal that produces the local Docker image depends on the parent POM's image-build plugin (Jib or similar). If step 2 shows no image, check the service repo's build config for the image-producing goal/profile.

### Example 4: Clean up after testing

```bash
gong-module-run down --image-names gong-my-module,dep-a --remote
```

---

## Relationship to descriptor.app.yaml / `/infra`

These solve different problems:

| Tool | Purpose | When you need it |
|------|---------|------------------|
| `gong-module-run up` | Spin up module images for development/testing | Local dev, feature testing |
| `descriptor.app.yaml` + `/infra` | Provision IAM roles and datasource permissions in production environments | Adding a new module or new datasource access to an existing one |

`gong-module-run` runs code. The infra pipeline provisions network/auth permissions. A new service needs both.

---

## Debugging with Breakpoints

Every module launched by `gong-module-run` starts with a **JDWP remote-debug agent already enabled** — you don't pass a flag to turn it on. The JVM runs with:

```
-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
```

So the debugger listens on container port **5005**; you attach your IDE to it and set breakpoints in the running service.

### 1. Find the debug port (local)

`gong-module-run` maps container `5005` to a host port and **prints it on startup** next to the web/JMX ports, e.g.:

```
recorderapiserver   8123 ► 8080, 38123 ► 5005, 48123 ► 9012
                                  ^^^^^ host debug port
```

If not overridden, the host debug port is computed as `30000 + (web_port % 10000)`. Override or disable it with flags on the `up` verb:

| Flag | Effect |
|------|--------|
| `--debug-port <port>` | Pin the host debug port to a fixed value |
| `--debug-port none` | Disable the debug port mapping for that module |
| `--debug-suspend` | Start the JVM **suspended** — it waits for your debugger to attach before running (use to catch startup-time code) |
| `--jmx-port <port>` | Host port mapped to JMX `9012` (`none` to disable) |

### 2. Attach your IDE

**IntelliJ**: Run → Edit Configurations → **+ → Remote JVM Debug** → host `localhost`, port = the printed host debug port → Debug.
(`gong-module-run remote --generate-run-configurations` can generate Maven run configs for you.)

Then set breakpoints in the module's source as usual.

### 3. Trigger the breakpoint via the troubleshooter endpoints

Each HTTP-exposing service publishes a **troubleshooter Swagger UI** — calling an endpoint there drives the code path into your breakpoint without needing a full browser flow:

```
https://<service-name>-vip.prod.gongio.net/troubleshooter/swagger-ui/index.html
```

Requires VPN + the `troubleshootersAuthJWT` cookie (get it from the Developer Data Gateway portal — see [[Swagger Pages]]). The plain `…/swagger-ui/index.html` (no `/troubleshooter`) serves the service's regular API; the `/troubleshooter/` path serves the diagnostic/trigger endpoints.

**Workflow**: start the module with `--debug-suspend` (or just leave it running) → attach IDE to the printed debug port → set your breakpoint → invoke the relevant troubleshooter endpoint → execution stops at the breakpoint.

### Remote (`--remote`) debugging

The host-port mapping above is for **local** runs. For modules deployed to your remote namespace with `--remote`, route traffic to locally-running code via Telepresence instead of a port map:

```bash
gong-module-run remote --intercept <module>     # route remote traffic to your local instance
gong-module-run remote --leave <module>          # stop intercepting
```

Run the intercepted module locally (debug agent on 5005) and attach your IDE to it as above.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Command hangs / connection timeout | Remote tunnel is down | Run `gong-module-runner remote --connect` or reconnect via Klopper |
| `Unknown module: <name>` | Module name doesn't match registry | Check `gong-modules-base.yaml` for the exact entry |
| Module deploys but feature doesn't work | Missing dependencies in the module list | Use "full web stack + sub-pages" scope with Claude to get the complete list |
| Branch image not found | Branch hasn't been built yet by CI | Wait for the Jenkins build, or omit `--branch-name` to use `main` |
| Teardown leaves stale state | Module not fully shut down | Re-run `gong-module-run down` with the same `--image-names` |

---

---

## CLI Reference

### Global options

These go **before** the verb and affect the runner itself, not the module.

| Option | Argument | Description |
|--------|----------|-------------|
| `--runner-tag-name` | `<tag>` | Docker tag for the internal runner image (default: `latest`) |
| `--runner-ecr-repository` | `<repo>` | ECR repository URL for the runner image |
| `--use-proxy` | — | Route image pulls through the local/remote proxy |
| `--external-tool` | — | Signal that the call comes from an external tool (suppresses some interactive output) |

### Verbs overview

| Verb | What it does |
|------|--------------|
| `up` | Start one or more modules (local Docker or remote K8s) |
| `down` | Stop and remove deployed modules |
| `remote` | Manage the remote dev environment (connect, intercept, sleep, etc.) |
| `synthetic-data` | Spin up or reset lightweight test-data containers |
| `prod-data` | Import production data into local databases |
| `generate-ssl-certificate` | Create/renew the local `*.local.gong-it.net` SSL certificate |
| `clean-images` | Delete stale Docker images from local cache |
| `install-bash-completion` | Register tab-completion for the shell |
| `db-migrate` | ~~Run Flyway migrations~~ **Deprecated** — migrations now run automatically inside each module's installer |

---

### `up` — start modules

**One of these is required:**

| Option | Argument | Description |
|--------|----------|-------------|
| `--image-names` | `a,b,c` | Comma-separated list of module names |
| `--image-name` | `name` | Single module name (singular alias) |
| `--group-names` | `a,b` | Comma-separated list of group names (e.g. `deals`, `engage`) |
| `--subsystem-names` | `a,b` | Comma-separated list of subsystem names (e.g. `gong-ingestion`) |

**Optional:**

| Option | Argument | Description |
|--------|----------|-------------|
| `--remote` | — | Deploy to your personal K8s namespace instead of running locally |
| `--branch-name` | `<branch>` | Use the image built from this branch (requires `--remote`; branch must have a CI build) |
| `--tag-name` | `<tag>` | Override the Docker image tag (defaults to `latest` from `main`). Pass `1.0-SNAPSHOT` to run your **locally-built** image instead of pulling from ECR — see Example 3b |
| `--ecr-repository` | `<url>` | Override the ECR registry URL |
| `--exclude-images` | `a,b` | Modules to exclude when using a group or subsystem selector |
| `--exclude-core-infra-modules` | — | Don't auto-include the `core_infra` group (local runs include it by default) |
| `--preserve-tags-for-groups` | `<groups>` | Keep the tag already defined in YAML for modules in these groups (useful for mixed-branch setups) |
| `--web-port` | `<port>` | Override the host port mapped to the module's HTTP server |
| `--debug-port` | `<port>\|none` | Pin the JDWP debug port to a fixed host port; `none` disables the mapping |
| `--debug-suspend` | — | Start the JVM **suspended** — execution waits until an IDE debugger attaches (useful for catching startup code) |
| `--jmx-port` | `<port>\|none` | Pin the JMX port; `none` disables it |
| `--java-max-mem-value` | `<val>` | Override the JVM `-Xmx` value (alias: `--max-memory`) |
| `--extra-jvm-options` | `<opts>` | Append arbitrary JVM flags (e.g. `-XX:+HeapDumpOnOutOfMemoryError`) |
| `--spring-profiles` | `a,b` | Activate additional Spring profiles |
| `--extra-env-vars` | `k=v,k=v` | Inject extra environment variables into the container |
| `--skip-health-check` | — | Don't wait for the module's `/welcome/_healthcheck` to pass |
| `--skip-core-infra-health-check` | — | Skip the startup check for DBs, Traefik, CoreDNS, etc. |
| `--force-recreate` | — | Tear down and recreate containers even if their config hasn't changed (docker-compose `--force-recreate`) |
| `--remove-orphans` | — | Remove containers that belong to the compose project but aren't in the current service list |
| `--skip-installer` | — | Don't run the per-module installer (DB migrator) container |
| `--only-installer` | — | Run only the installer containers — skip the main module containers |

> [!note] `--force-recreate` vs `--force`
> - **`--force-recreate`** (on `up`): passes `--force-recreate` to `docker-compose up`, forcing containers to be destroyed and rebuilt from scratch even if their configuration is unchanged. Use this when a container is in a bad state or you want to guarantee a clean start.
> - **`--force`** (on `remote`): a lower-level override that bypasses certain safety guards in the remote environment management (e.g. forces an operation that would otherwise be blocked by a conflict check). It does **not** affect container recreation.

---

### `down` — stop modules

**One of these is required:**

| Option | Argument | Description |
|--------|----------|-------------|
| `--image-names` | `a,b,c` | Modules to stop |
| `--group-names` | `a,b` | Group(s) to stop |
| `--subsystem-names` | `a,b` | Subsystem(s) to stop |

**Optional:**

| Option | Argument | Description |
|--------|----------|-------------|
| `--remote` | — | Remove deployments from your K8s namespace (not local Docker) |

---

### `remote` — manage the remote environment

All sub-actions are single flags; most are mutually exclusive.

| Option | Argument | Description |
|--------|----------|-------------|
| `--connect` | — | Start the Telepresence tunnel to your remote namespace (required before most remote operations) |
| `--disconnect` | — | Quit Telepresence and tear down the local tunnel |
| `--init` | — | Bootstrap your personal remote namespace (first-time setup) |
| `--status` | — | Print the current state of your remote namespace (deployed modules, intercepts) |
| `--refresh-modules` | — | Re-pull the latest image tags for all currently deployed modules |
| `--sleep` | — | Scale all workloads to zero (save cluster resources while you're away) |
| `--wake-up` | — | Scale workloads back up from sleep |
| `--intercept` | `<module>` | Route remote cluster traffic for `<module>` to your local machine (Telepresence intercept) |
| `--port` | `<port>` | Local port to receive intercepted traffic (used with `--intercept`; default: 8080) |
| `--leave` | `<module>` | Stop intercepting traffic for `<module>` and restore normal routing |
| `--generate-run-configurations` | — | Generate IntelliJ Maven run configurations for the modules in your namespace |
| `--force-recreate` | — | Force full recreation of the remote environment, **including core infra services** |
| `--force` | — | Override conflict/safety guards for the remote operation (use with caution) |
| `--skip-core-infra-health-check` | — | Skip the health check for core infra (DBs, Traefik, CoreDNS) during remote init |
| `--disable-ff-mock` | — | Disable the feature-flags mock service in the remote env (routes FF requests to real infra instead) |
| `--shared` | — | Use shared environment mode (multi-developer namespace) |
| `--env-name` | `<name>` | Target a named environment other than your personal namespace |
| `--with-external-url` | `<url>` | Register an external URL for the remote environment |
| `--synthetic-data-image-tag` | `<tag>` | Override the synthetic-data image tag for the remote env |

---

### `synthetic-data` — test data containers

| Option | Argument | Description |
|--------|----------|-------------|
| `--synthetic-data-image-tag` | `<tag>` | Use a specific tag of the synthetic data image (default: latest) |
| `--synthetic-volume-init` | — | **Destructive** — reinitialise the synthetic data Docker volume from scratch |
| `--synthetic-data-sync-from-existing-containers` | — | Copy data from currently running containers into fresh volumes |
| `--remote` | — | Apply to the remote environment instead of local |

---

### `prod-data` — production data import

| Option | Description |
|--------|-------------|
| `--import-prod-data` | Run the import-prod-data pipeline to sync real production data into local databases |

---

### `generate-ssl-certificate`

| Option | Description |
|--------|-------------|
| `--force-recreate` | Regenerate the SSL certificate even if a valid one already exists |
| `--remote` | Generate/renew the certificate for the remote environment |

---

### `clean-images`

| Option | Argument | Description |
|--------|----------|-------------|
| `--image-tag-prefix` | `<prefix>` | Delete images whose tag matches this prefix regex (default: `11-main\|11-master`) |

---

## Related Notes

- [[Comms Capture Maven Modules]] — module breakdown per service if you're working in comms capture
- [[Comms Capture Architecture Overview]] — which services own which capture domain
- [[Import Prod Data - Calls]] — getting real call data into your local databases for testing
- [[_index|Comms Capture Runbooks]] — all bounded contexts, services, and ready-to-run commands for the Comms Capture team
