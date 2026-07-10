---
title: kubectl CLI — Intro to Advanced
tags:
  - kubernetes
  - kubectl
  - telephony
  - ops
  - debugging
created: 2026-06-25
aliases:
  - kubectl guide
  - kubectl advanced
  - k8s cli
---

# kubectl CLI — Intro to Advanced

> [!info] Scope
> A progressive kubectl reference anchored to Gong's telephony services (`ingestertelephonysystems`, `ingestertelephonysystemssupervisor`, `telephonysystemswebapi`, etc.) running in the `terry-collins-dev-env` namespace. Sections build on each other — skim the intro if you already know basics, land on Advanced for the power moves.

> [!tip] Relationship to k9s
> [[kubectl Cheatsheet — Telephony Services on Kubernetes]] covers the same ground via the k9s TUI. kubectl is better for scripting, repeatable ad-hoc queries, and CI. k9s is better for real-time browsing. Know both.

---

## 1. Orientation

### Config & context

```bash
# Which cluster/user is active?
kubectl config current-context

# List all configured contexts
kubectl config get-contexts

# Switch context (e.g. from prod to dev-env)
kubectl config use-context <context-name>

# Override namespace for one command (don't mutate context)
kubectl -n terry-collins-dev-env get pods
```

> [!tip] Set a default namespace for your session so you don't type `-n` every time:
> ```bash
> kubectl config set-context --current --namespace=terry-collins-dev-env
> ```

### Verify you can reach the cluster

```bash
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

---

## 2. Pods — the daily bread

### List and filter

```bash
# All pods in your namespace
kubectl get pods

# Wide output — shows node, IP, nominated node
kubectl get pods -o wide

# Watch live (refreshes in-place)
kubectl get pods -w

# Filter by label
kubectl get pods -l app=ingestertelephonysystemssupervisor

# Filter by field (only Running pods)
kubectl get pods --field-selector=status.phase=Running
```

### Describe a pod (your first stop when something is wrong)

```bash
kubectl describe pod <pod-name>
```

Key sections to read top-down:
- **Conditions** — Ready/Initialized/ContainersReady flags
- **Events** — scheduling failures, image pull errors, probe failures
- **Containers → Liveness/Readiness** — what the probe actually does

### Shell into a running pod

```bash
kubectl exec -it <pod-name> -- /bin/bash
# or if bash isn't available:
kubectl exec -it <pod-name> -- /bin/sh

# Target a specific container in a multi-container pod
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash
```

### Copy files in/out

```bash
# From pod to local
kubectl cp <pod-name>:/path/to/file ./local-file

# From local to pod
kubectl cp ./local-file <pod-name>:/path/in/pod
```

---

## 3. Logs

### Basic log retrieval

```bash
# Tail the last 100 lines
kubectl logs <pod-name> --tail=100

# Stream live
kubectl logs -f <pod-name>

# Specific container in a multi-container pod
kubectl logs <pod-name> -c <container-name>

# Previous container run (crash loop debugging)
kubectl logs <pod-name> --previous
```

### Time-bounded logs

```bash
# Logs from the last 10 minutes
kubectl logs <pod-name> --since=10m

# Logs since an absolute timestamp
kubectl logs <pod-name> --since-time="2026-06-25T09:00:00Z"
```

### Aggregate logs across all pods in a deployment

```bash
# All pods matching a label
kubectl logs -l app=ingestertelephonysystemssupervisor --tail=50

# All pods + prefix each line with pod name (essential when tailing multiple)
kubectl logs -l app=ingestertelephonysystemssupervisor --prefix=true -f
```

> [!tip] Gong services use structured JSON logs. Pipe through `jq` for readability:
> ```bash
> kubectl logs <pod-name> -f | jq '.'
> # Filter to ERROR level only
> kubectl logs <pod-name> | jq 'select(.level == "ERROR")'
> ```

---

## 4. Services & networking

```bash
# List services
kubectl get svc

# Check which pods a service actually routes to
kubectl get endpoints <service-name>
# or shorthand:
kubectl get ep <service-name>
```

> [!warning] Empty endpoints = no ready backends. The service exists but no traffic can flow. Check pod readiness probes first.

### Port-forward (reach a pod/service locally)

```bash
# Forward local 8080 → pod port 8080
kubectl port-forward pod/<pod-name> 8080:8080

# Forward to a service (load-balanced across ready pods)
kubectl port-forward svc/<service-name> 8080:80

# Forward the debug port (JDWP) for IDE attachment
kubectl port-forward pod/<pod-name> 5005:5005
```

> [!example] Attach IntelliJ debugger to a remote pod
> ```bash
> # 1. Find the pod
> kubectl get pods -l app=ingestertelephonysystemssupervisor
>
> # 2. Forward the JDWP port
> kubectl port-forward pod/<pod-name> 5005:5005
>
> # 3. IntelliJ → Run → Edit Configurations → Remote JVM Debug
> #    Host: localhost  Port: 5005
> ```
> Note: for `gong-module-run --remote` deployments prefer `gong-module-run remote --intercept` over raw port-forward — it also reroutes cluster traffic to your local instance.

### Ingress

```bash
# List all ingress rules
kubectl get ingress

# Describe a specific ingress (see hostnames, paths, backend services)
kubectl describe ingress <ingress-name>
```

> [!note] Gong dev-env ingress
> The dev-env cluster trusts `*.app.*` hostnames (via `GongSpringSecurityConfig`). `*.modules.*` hostnames are rejected at the security layer — use the `app.<env>.../<service-path>` pattern instead. See [[Dev Env Service URLs]].

---

## 5. Deployments, ReplicaSets & rollouts

```bash
# List deployments
kubectl get deployments

# Rollout status (is a deploy still in progress?)
kubectl rollout status deployment/<name>

# Rollout history
kubectl rollout history deployment/<name>

# Roll back to the previous version
kubectl rollout undo deployment/<name>

# Roll back to a specific revision
kubectl rollout undo deployment/<name> --to-revision=3

# Restart all pods in a deployment (triggers a rolling restart)
kubectl rollout restart deployment/<name>
```

> [!tip] Rolling restart vs delete: `rollout restart` replaces pods one by one respecting `maxUnavailable`, so it's safe on live services. Deleting pods manually is faster but can cause a brief outage if replicas=1.

### Scale

```bash
# Scale to 3 replicas
kubectl scale deployment/<name> --replicas=3
```

---

## 6. ConfigMaps & Secrets

```bash
# List
kubectl get configmaps
kubectl get secrets

# View a ConfigMap's data
kubectl describe configmap <name>

# Decode a Secret value (base64)
kubectl get secret <name> -o jsonpath='{.data.<key>}' | base64 -d

# Dump all secret keys (values stay encoded)
kubectl get secret <name> -o json | jq '.data | keys'
```

> [!warning] Editing a ConfigMap does NOT auto-reload the application. Most Gong Spring services require a pod restart (`rollout restart`) or an actuator refresh endpoint hit to pick up new config.

---

## 7. Events — the cluster audit trail

```bash
# All events in namespace, sorted by time
kubectl get events --sort-by='.lastTimestamp'

# Watch events live
kubectl get events -w

# Events for a specific resource
kubectl get events --field-selector involvedObject.name=<pod-name>

# Only Warning events
kubectl get events --field-selector type=Warning
```

> [!tip] Events expire after ~1 hour. If a pod crash-looped overnight, check logs with `--previous` instead.

---

## 8. Resource usage

```bash
# Top pods by CPU/memory (requires metrics-server)
kubectl top pods
kubectl top pods --sort-by=memory

# Top nodes
kubectl top nodes
```

---

## 9. Advanced: JSONPath & custom output

`-o jsonpath` lets you extract exactly the field you need.

```bash
# Get the image tag of the first container in every pod
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Get all pod IPs
kubectl get pods -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}'

# Get the restart count of a specific container
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[?(@.name=="<container>")].restartCount}'

# Get the node each pod is running on
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'
```

> [!tip] Use `-o json | jq` for interactive exploration, then crystallise the exact path into `-o jsonpath` for scripts.

---

## 10. Advanced: Labels & annotations

```bash
# Show all labels on pods
kubectl get pods --show-labels

# Add a label
kubectl label pod <pod-name> debug=true

# Remove a label
kubectl label pod <pod-name> debug-

# Select by multiple labels
kubectl get pods -l 'app=ingestertelephonysystemssupervisor,env=dev'

# Set-based selector
kubectl get pods -l 'version in (1.2,1.3)'
```

---

## 11. Advanced: Debugging crashes & OOMKills

### Pod stuck in CrashLoopBackOff

```bash
# 1. Get the termination reason
kubectl describe pod <pod-name>
# Look at: Last State → Exit Code, Reason (OOMKilled = 137, crash = 1)

# 2. Read the logs from the previous (dead) container
kubectl logs <pod-name> --previous

# 3. If the container exits before printing logs, use an init-container or add:
#    command: ["sh", "-c", "your-start-cmd || sleep 3600"]
#    to keep it alive long enough to inspect
```

### Pending pod (won't schedule)

```bash
kubectl describe pod <pod-name>
# Events section will say:
#   0/3 nodes are available: 3 Insufficient memory
#   0/3 nodes are available: 3 node(s) had untolerated taint
```

Common causes: resource requests too high, node selector / taint mismatch, PVC not bound.

---

## 12. Advanced: Ephemeral debug containers

When a pod has no shell (distroless/scratch image), inject a debug sidecar without restarting:

```bash
kubectl debug -it <pod-name> --image=busybox --target=<container-name>
```

The `--target` flag shares the process namespace of the named container so you can `ps`, `strace`, etc.

---

## 13. Advanced: Exec one-liners for Gong telephony

```bash
# Tail all supervisor logs, grep for ERROR, prefix with pod name
kubectl logs -l app=ingestertelephonysystemssupervisor -f --prefix=true | grep '"level":"ERROR"'

# Check which image tag is currently running
kubectl get pods -l app=ingestertelephonysystemssupervisor \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Port-forward the telephony web API swagger locally
kubectl port-forward svc/telephonysystemswebapi 8080:80
# then: http://localhost:8080/swagger-ui/index.html

# Dump environment variables of the supervisor pod (useful for confirming Spring profiles)
kubectl exec <pod-name> -- env | grep -E 'SPRING|JAVA|GONG'

# Watch restart counts across all telephony pods
kubectl get pods -l 'app in (ingestertelephonysystems,ingestertelephonysystemssupervisor,telephonysystemswebapi)' \
  -o wide -w

# List all ConfigMaps consumed by telephony services
kubectl get configmaps -l app=ingestertelephonysystemssupervisor

# Get the service account a pod is running as
kubectl get pod <pod-name> -o jsonpath='{.spec.serviceAccountName}'
```

---

## 14. Advanced: Namespace-wide audit

```bash
# Everything running in your namespace (broad view)
kubectl get all

# All resource types (incl. CRDs like HPA, PDB, etc.)
kubectl api-resources --verbs=list --namespaced=true | \
  awk '{print $1}' | \
  xargs -I{} kubectl get {} --ignore-not-found 2>/dev/null

# PodDisruptionBudgets (can block node drains — check before node work)
kubectl get pdb

# HPA — autoscaler status and current/desired replicas
kubectl get hpa
kubectl describe hpa <name>
```

---

## 15. Safety checklist before touching production

> [!danger] Pre-flight
> - [ ] `kubectl config current-context` shows the **correct cluster**
> - [ ] `-n` flag or default namespace is set to the **correct namespace**
> - [ ] You know whether your action is reversible (`rollout undo` ready?)
> - [ ] For scale-down or delete: confirm no single-replica services that would cause an outage
> - [ ] For ConfigMap edits: know whether the app hot-reloads or needs a restart
> - [ ] Low-traffic window confirmed for any action that recycles pods handling live calls

---

## Related notes

- [[kubectl Cheatsheet — Telephony Services on Kubernetes]] — k9s TUI version of this guide
- [[Dev Env Service URLs]] — service hostnames and port mappings for `terry-collins-dev-env`
- [[Swagger Pages]] — troubleshooter JWT cookie and swagger auth
- [[GRM  gong-module-run How To]] — deploying modules to remote namespace
