---
tags:
- gong
- hybrid-dev
- kubernetes
- telepresence
- debugging
- onboarding
created: 2026-07-17
---

# Hybrid Debugging — How It Works

> **TL;DR** In "hybrid" mode, Telepresence tunnels Kubernetes cluster traffic to a JVM running on your laptop. Your local code runs inside IntelliJ, but it receives real cluster requests — so you get full breakpoint debugging against live traffic without redeploying to the cluster.

---

## The Three Modes

| Mode | JVM runs... | Traffic source | Use when |
|------|-------------|----------------|----------|
| **Local** | Docker container on your laptop | Synthetic only (Postman / troubleshooter) | Fast iteration, unit-level testing |
| **Remote** | K8s pod in your personal namespace | Real cluster traffic (Kafka, downstream calls) | Realistic end-to-end flows, no IDE breakpoints needed |
| **Intercept (hybrid debug)** | IntelliJ on your laptop | Intercepted from the cluster via Telepresence | Full breakpoint debugging against live traffic |

"Hybrid" is shorthand for the third row: the JVM is local, but the network traffic is remote.

---

## What Telepresence Does

Telepresence is an open-source tool (CNCF project) that creates a **two-way network bridge** between your laptop and a Kubernetes cluster:

```
┌─────────────────────────────────────────┐
│           Kubernetes cluster            │
│                                         │
│   ┌──────────────┐   ┌──────────────┐  │
│   │  Traffic     │   │  Your pod    │  │
│   │  Manager     │   │  (still live)│  │
│   │  (sidecar)   │   │              │  │
│   └──────┬───────┘   └──────┬───────┘  │
│          │  intercepts       │          │
│          │  inbound traffic  │          │
└──────────┼───────────────────┼──────────┘
           │ encrypted tunnel  │ (bypassed)
           ▼
┌─────────────────────────────────────────┐
│              Your laptop                │
│                                         │
│   Telepresence daemon                   │
│        │                                │
│        ▼                                │
│   IntelliJ JVM (your local code)        │
│   listening on port 8080 / 5005         │
└─────────────────────────────────────────┘
```

**What Telepresence sets up:**

1. **Traffic Manager** — a pod in the cluster that watches intercepted services
2. **Local daemon** — a process on your laptop that handles the encrypted tunnel (managed by Klopper or `gong-module-runner remote --connect`)
3. **DNS injection** — your laptop can resolve `*.svc.cluster.local` names while the tunnel is active, so your local JVM can call other cluster services by their K8s DNS names just like a real pod would
4. **Environment forwarding** — the intercepted pod's environment variables are forwarded to your local process, so your code sees the same config as the cluster pod

---

## The Intercept Lifecycle

```bash
# 1. Ensure tunnel is active (do this once per session)
gong-module-runner remote --connect
# Or: open Klopper app

# 2. Deploy your module to the cluster (runs the ECR image, not your local code yet)
gong-module-run up --image-names ingestercalendarsupervisor --remote

# 3. Start the intercept — now cluster traffic → your laptop port 8080
gong-module-run remote --intercept ingestercalendarsupervisor --port 8080
#                                                               ^^^^
#                                           local port your IntelliJ process listens on

# 4. Run/debug the module in IntelliJ on port 8080 (with JDWP on 5005)
#    Set breakpoints, modify code, hot-swap, etc.

# 5. Stop intercepting — traffic goes back to the cluster pod
gong-module-run remote --leave ingestercalendarsupervisor
```

> [!important] The cluster pod stays running during an intercept
> Telepresence does not kill the pod. It injects a sidecar that intercepts inbound connections before they reach the pod's process. If your local JVM is down or crashes, requests are held/dropped — not served by the cluster pod. Keep your local process running while intercepting.

---

## Can You Change Code Locally During an Intercept?

**Yes — completely.** The cluster has no idea what code is answering its requests. You can:

- **Modify logic** — add branches, change return values, rewrite handlers
- **Add log statements** — they appear in IntelliJ's console, not Coralogix
- **Set breakpoints** — execution pauses in your IDE when cluster traffic hits the breakpoint
- **Hot-swap** — IntelliJ can reload changed class files into the running JVM without a restart (limited to method-body changes in standard HotSwap; more extensive with DCEVM/JRebel)
- **Introduce completely different behavior** — the cluster doesn't validate what your JVM returns; you own the response

This is the key power of the intercept mode: you get a **production-like traffic environment** with **full local debuggability**.

---

## How the Debug Port Works

Every module launched by `gong-module-run` (local or remote) starts with JDWP already enabled:

```
-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
```

For **intercept mode**: you run the module in IntelliJ in debug mode yourself (the cluster pod isn't the one being debugged — your local IntelliJ process is). Configure a standard Remote JVM Debug run config pointing to `localhost:5005`.

For **local mode**: `gong-module-run` maps container port 5005 to a host port (printed at startup, formula: `30000 + (web_port % 10000)`). Attach IntelliJ to that host port.

### The `--debug-suspend` flag

Pass `--debug-suspend` to `gong-module-run up` to make the JVM wait for a debugger before starting execution. Useful for catching startup-time failures or initialization code you can't trigger after boot.

---

## Debugging Two Modules Simultaneously

Telepresence supports multiple concurrent intercepts. Use different local ports:

```bash
gong-module-run remote --intercept ingestercalendarsupervisor --port 8080
gong-module-run remote --intercept meetingsindexer --port 8081
```

Run each as a separate IntelliJ process with its own debug config on ports 5005 and 5006. Traffic for each service routes independently.

---

## Gotchas for K8s Newcomers

| Gotcha | What's happening | Fix |
|--------|-----------------|-----|
| `svc.cluster.local` names don't resolve | Tunnel is down | Reconnect via Klopper or `gong-module-runner remote --connect` |
| Breakpoints never fire | Your local port is wrong, or intercept isn't active | Verify with `gong-module-run remote --status` |
| Changes appear to have no effect | Hot-swap silently failed (class structure changed) | Restart the local JVM |
| Logs missing from Coralogix | Your local JVM doesn't ship to Coralogix | Check IntelliJ console instead (or NP Coralogix env) |
| Other services can't reach your intercepted module | Local process not binding on the right port | Check `--port` matches what IntelliJ binds to |
| Cluster pod answers instead of your local JVM | Intercept wasn't started | `gong-module-run remote --intercept <module>` |

---

## Local vs Intercept — When to Use Which

```
┌─────────────────────────────────────┐
│ Does your bug require               │
│ real Kafka events / cluster traffic?│
└──────────┬──────────────────────────┘
           │ No                  │ Yes
           ▼                     ▼
     Local mode           Do you need
     (Docker)             breakpoints?
                          │ No      │ Yes
                          ▼         ▼
                       Remote    Intercept
                       mode      mode
```

---

## See Also

- [[GRM  gong-module-run How To]] — full command reference for `gong-module-run`
- [[Comms Capture Architecture Overview]] — which services own which domain (helps pick what to intercept)
- [[Comms Capture Maven Modules]] — Maven module breakdown per service
