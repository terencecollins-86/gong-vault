# Dev Env Service URLs

Ingress hosts for my remote dev environment (`gong module run app` → remote), namespace `terry-collins-dev-env` on cluster `c1-devex.ilc1.internal.gongio.net`.

> [!note] Access notes
> - **VPN / cluster network required** — these `*.internal.gongio.net` hosts only resolve from inside the cluster network.
> - **Self-signed internal CA** — use `curl -sk` (and disable SSL cert verification in Postman).
> - **`*.app.*` vs `*.modules.*`** — most services answer on `*.modules.*`. Public-facing services (e.g. `telephonysystemswebapi`) are gated by `GongSpringSecurityConfig`, which **rejects any Host header that isn't `*.app.*`** → requests to their `*.modules.*` host return 404. See [[Swagger Pages]].
> - **Ingress ≠ running** — a host is listed while its ingress object exists, even if the pod is down. Cross-check with `kubectl get pods -n terry-collins-dev-env`.

---

## List the URLs

```bash
kubectl get ingress -n terry-collins-dev-env \
  -o jsonpath='{range .items[*].spec.rules[*]}https://{.host}{"\n"}{end}' \
  | sort -u
```

Cluster-internal Service DNS (reachable via `kubectl port-forward`):
`http://<service>.terry-collins-dev-env.svc.cluster.local:<port>`

---

## Services

| Service | Host |
|---------|------|
| apigateway | https://apigateway.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| communicationskillscalculator | https://communicationskillscalculator.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| digestermeetingreminders | https://digestermeetingreminders.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| digesterreminders | https://digesterreminders.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| digestersequenceremindersserver | https://digestersequenceremindersserver.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| engageasynctasksserver | https://engageasynctasksserver.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| engageflowautomationsserver | https://engageflowautomationsserver.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| engageflowsdigesterserver | https://engageflowsdigesterserver.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| engagesharedservices | https://engagesharedservices.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| engageusercontent | https://engageusercontent.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| engagewebapi | https://engagewebapi.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| featureflagsbrokerapiserver | https://featureflagsbrokerapiserver.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| ingestertelephonysystemssupervisor | https://ingestertelephonysystemssupervisor.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| keycloak | https://keycloak.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| prospectingmanager | https://prospectingmanager.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| prospectoptoutapiserver | https://prospectoptoutapiserver.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| prospectoptoutserver | https://prospectoptoutserver.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| telephonysystemstroubleshooters | https://telephonysystemstroubleshooters.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |
| telephonysystemswebapi | https://telephonysystemswebapi.app.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net ⚠️ use `*.app.*` (the `*.modules.*` host 404s) |
| textindexer | https://textindexer.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net |

---

## Telephony Swagger / api-docs

| Service | Spec (open) | Swagger UI (auth) |
|---------|-------------|-------------------|
| telephonysystemswebapi | https://telephonysystemswebapi.app.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net/v3/api-docs | https://telephonysystemswebapi.app.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net/swagger-ui/index.html |
| ingestertelephonysystemssupervisor | https://ingestertelephonysystemssupervisor.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net/v3/api-docs | …/swagger-ui/index.html |
| telephonysystemstroubleshooters | https://telephonysystemstroubleshooters.modules.terry-collins-dev-env.c1-devex.ilc1.internal.gongio.net/v3/api-docs | …/swagger-ui/index.html |

Postman collections built from these specs live in [[Telephony Systems/Postman Collections/]].

---

Related: [[Swagger Pages]] · [[Telephony Systems/03 - Services Reference]]
