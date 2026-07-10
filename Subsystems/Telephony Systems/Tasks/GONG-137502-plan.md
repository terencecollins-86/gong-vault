# GONG-137502 — Plan: "Secret has the same value in prod and devTest"

**Type:** Bug (P1) · **Team:** Telephony / Coms Capture · **Status:** Ready for Development
**Jira:** https://gongio.atlassian.net/browse/GONG-137502
**Sentry:** JAVA-SYSTEMS-ATD9

> **Bottom line for a new engineer:** This is **not a code bug**. Nothing in `gong-telephony-systems` needs to change to make the alert stop. It is a **secrets-operations task**: the production value of the `natterbox.api` secret is byte-for-byte identical to its Dev/Test value, which is a security problem. The fix is to **rotate the credential so prod and Dev/Test no longer share a value**, plus a small descriptor cleanup. Most of the work is done through a web troubleshooter on VPN, not in an IDE.

---

## 1. Background — what you need to understand first

### 1.1 How Gong stores secrets
- Secrets live in **AWS Secrets Manager (ASM)**, in two separate AWS accounts: **Production** and **Dev/Test**.
- Every secret has a **protected entity** (the name, here `natterbox.api`), a **principal** (the module/role that uses it), and a **scope** (`COMMON` / `SHARED` / `APP`). `natterbox.api` is **SHARED** — used by more than one module.
- A SHARED secret is replicated to one ASM path per principal:
  - `GongSecretsStore/honeyfy/Shared/natterbox.api/WebFrontEnd`
  - `GongSecretsStore/honeyfy/Shared/natterbox.api/TelephonySystemsTroubleshooters`
  - `GongSecretsStore/honeyfy/Shared/natterbox.api/IngesterTelephonySystemsSupervisor`
- The secret value is JSON with two properties: **`client-id`** and **`client-secret`** (Natterbox API credentials).
- Runbook: [Secrets in Gong](https://gongio.atlassian.net/wiki/spaces/EN/pages/3194126474/Secrets+in+Gong) · [Secret Rotation Mechanism](https://gongio.atlassian.net/wiki/spaces/EN/pages/3226796191/Secret+Rotation+Mechanism)

### 1.2 What the alert actually is
A scheduled validator (`SecretsValidator.validateProdAndDevTestSecrets`, in `gong-dev-gateways` → `CredentialsManager`) compares every prod secret value against the Dev/Test values. When a prod value **equals** a Dev/Test value it raises a Sentry error routed to the owning team:

```
Secret has the same value in prod and devTest.
  prodSecrets=[ AsmSecretKey(principal=WebFrontEnd, secretScope=SHARED, protectedEntity=natterbox.api),
                AsmSecretKey(principal=TelephonySystemsTroubleshooters, ...),
                AsmSecretKey(principal=IngesterTelephonySystemsSupervisor, ...) ]
  devTestPaths=[ GongSecretsStore/honeyfy/Shared/natterbox.api/Shared,
                 GongSecretsStore/honeyfy/Shared/natterbox.api ]
  g-cell=gcell-eu-02
```

**Why it matters:** a real production credential is sitting in the lower-trust Dev/Test account. Anyone with Dev/Test access effectively holds the production Natterbox key. The platform now actively blocks this (the troubleshooter returns HTTP 400 if you try to set a prod value equal to a Dev/Test value), but these secrets predate that guard, so they must be remediated manually.

### 1.3 Where the credential is consumed (impact surface)
- `Dialers/.../services/NatterboxDialerService.java:94` →
  `gongCredentialsStore.shared("natterbox.api")` → fetches `client-id` + `client-secret`.
- Used by `NatterboxHttpClient` / `NatterboxSdrService` to authenticate to the Natterbox API (`IntegrationFlavor.NATTERBOX_API`).
- Runtime principals that load it: **IngesterTelephonySystemsSupervisor**, **TelephonySystemsTroubleshooters**, **WebFrontEnd**.
- Apps fetch the secret **at application-context startup** (bean init), and ASM serves the **latest version by default**. So a value change is picked up by **new pods / next deploy**, not necessarily live — see §4.

### 1.4 The likely root cause of the collision
The `natterbox.api-secret-descriptor.yaml` (in `gong-infra-core`) still carries a **`devTestVersion`** field:

```yaml
devTestVersion: "4fb6b01e-1192-4952-a9b7-e801824cc3bc"
secretScope: "SHARED"
team: "CLOUD_RECORDING"
properties: ["client-id", "client-secret"]
secretType: "API_KEY"
rotationInstructions:
  rotationStrategy: "MULTIPLE_TOKENS"
  applicationUrl: "https://nbapi.zapier.app/disclaimer"
```

The runbook explicitly calls `devTestVersion` the **old, deprecated flow** ("please don't create new descriptors with it… the secret value is fixed to a single value"). This pin is most likely what caused Dev/Test to hold the same value as prod. Removing it is part of the fix.

---

## 2. Success criteria (definition of done)
1. The Sentry alert JAVA-SYSTEMS-ATD9 stops re-firing for `natterbox.api` (validator runs per cell on a schedule).
2. `natterbox.api` prod value ≠ Dev/Test value in **every** cell that has both (at minimum `gcell-eu-02`; verify `gge`, `gcell-nam-01`).
3. Natterbox integration still authenticates successfully after rotation (no customer-facing breakage).
4. `devTestVersion` removed from `natterbox.api-secret-descriptor.yaml` (or a deliberate decision recorded to keep it).
5. New + old credentials handled per `MULTIPLE_TOKENS` strategy (old pair invalidated with the vendor).

---

## 3. Pre-work — access & confirmation (do this before touching anything)
- [ ] **Okta team check.** The descriptor's `team: CLOUD_RECORDING` controls who can edit this secret in the troubleshooter. Confirm your Okta team matches; if not, get added (see `Team.java` enum `oktaTeamName` in gong-infra-core). Without this you won't see the secret in the GGE tool.
- [ ] **GGE VPN access** to the Credentials Manager troubleshooter: `https://credentials-manager-vip.gge.prod.gongio.net/swagger-ui/index.html` → **Developer Secrets Troubleshooter**.
- [ ] **Confirm whether Dev/Test even needs `natterbox.api`.** Per §1.2 runbook, Dev/Test should only hold a secret if local/system tests actually integrate with Natterbox. Check `NatterboxDialerServiceTest` — if it uses WireMock/mocks (no real ASM value needed), the cleanest fix is **Option A (remove from Dev/Test)** rather than rotate. This single check decides your path in §4.
- [ ] **Identify all affected cells.** Alert names `gcell-eu-02`; the runbook stresses every operation is **per-cell**. List the cells where `natterbox.api` exists in both prod and Dev/Test before starting.
- [ ] **Get the rotation owner.** Rotation strategy is `MULTIPLE_TOKENS` and instructions require emailing **support@natterbox.com** to invalidate the old client-id/secret pair. Identify who holds the Natterbox vendor relationship.

---

## 4. Execution — choose ONE path

### Decision
- **If Dev/Test does NOT need real Natterbox creds** (tests are mocked) → **Path A** (simplest, no vendor involvement).
- **If Dev/Test genuinely integrates with Natterbox** → **Path B** (rotate so the two environments hold different real credentials).

> In both paths, **never set the prod value equal to the Dev/Test value** — the troubleshooter enforces this with HTTP 400.

### Path A — Remove the value from Dev/Test (preferred if viable)
1. [ ] In the Dev/Test account (troubleshooter `cell-id = devtest`), **archive** the `natterbox.api` secret for the affected entities (`archive` / `archive-shared-entities`). Per §1.2 runbook, missing Dev/Test secrets fall back to a random string locally — fine if tests don't need a real value.
2. [ ] Remove `devTestVersion` from `natterbox.api-secret-descriptor.yaml` (see §5).
3. [ ] Leave the **production** value untouched (it's the legitimate credential).
4. [ ] Verify (§6).

### Path B — Rotate so prod and Dev/Test differ
Because strategy is `MULTIPLE_TOKENS`, generate a **new** credential pair and retire the old one:
1. [ ] Generate a **new** Natterbox client-id/client-secret (follow `applicationUrl` + email support@natterbox.com). Decide which environment gets the new pair — typically **prod gets the new real pair**, Dev/Test keeps/gets a **separate** value.
2. [ ] Update **production** `natterbox.api` via troubleshooter (`update-secret-value`) **per cell**. For a SHARED secret, one update propagates to all principals (WebFrontEnd, TelephonySystemsTroubleshooters, IngesterTelephonySystemsSupervisor) and DRP auto-syncs.
3. [ ] Set the **Dev/Test** value to a **different** (test/sandbox) credential, or archive it (Path A) if not needed.
4. [ ] Ask Natterbox support to **invalidate the old pair** (share only the old client-id, never the secret).
5. [ ] Store the new credential in **1Password** (Team vault), per policy — never in Slack/tickets.
6. [ ] Remove `devTestVersion` from the descriptor (§5).
7. [ ] Verify (§6), including that the integration still authenticates.

---

## 5. Code change (the only repo edit)
**Repo:** `gong-infra-core`
**File:** `AWSIntegration/src/main/resources/com/honeyfy/secrets/natterbox.api-secret-descriptor.yaml`

- [ ] Remove the deprecated line: `devTestVersion: "4fb6b01e-1192-4952-a9b7-e801824cc3bc"`
- [ ] Keep `team`, `secretScope`, `secretType`, `properties`, `rotationInstructions` intact.
- [ ] Note the header says *"Auto-generated file; please do not modify manually. Use credentials manager instead."* — confirm with the secrets/platform owner whether this edit should be made by hand or regenerated via Credentials Manager. **Ask before hand-editing.**
- [ ] Branch name: `GONG-137502-remove-natterbox-devtestversion` (UPPERCASE key, lowercase desc, hyphens).
- [ ] After merge to `gong-infra-core` master, **redeploy CredentialsManager + DevDataGateway in GGE** (Harness, project `Gong_Dev_Gateways`) so the validator picks up the new descriptor.

---

## 6. Verification
- [ ] **Per-cell value check:** in the troubleshooter, `list secret keys` / fetch `natterbox.api` in prod vs Dev/Test for each cell — confirm values now differ (or Dev/Test is archived).
- [ ] **Validator re-run:** the validator runs on a schedule per cell; confirm no new JAVA-SYSTEMS-ATD9 occurrences after the next cycle. (If there's a manual trigger on CredentialsManager, run it for `gcell-eu-02` first.)
- [ ] **Integration smoke test:** confirm a Natterbox call sync still authenticates. Locally you can hit the telephony troubleshooter `syncOneCall` against a Natterbox integration; in prod, watch for auth failures in `NatterboxHttpClient` logs / Sentry after the value change rolls out to new pods.
- [ ] **DRP parity:** confirm DRP auto-synced (the validator also checks prod-vs-DRP equality, which is *expected* and must stay equal — don't confuse this with the prod-vs-devTest check).
- [ ] **Close the loop:** update GONG-137502 with what was done, link the gong-infra-core PR, mark the Sentry issue resolved.

---

## 7. Risks & gotchas
- **Rollout timing:** apps read the secret at **startup**. A prod value change only takes effect on new pods/next deploy. If you rotate prod, coordinate a restart/deploy of WebFrontEnd + IngesterTelephonySystemsSupervisor + TelephonySystemsTroubleshooters, or the old value stays cached in running pods until they cycle.
- **SHARED scope blast radius:** updating `natterbox.api` affects **3 principals at once**, including WebFrontEnd (not just telephony). Coordinate with those owners if doing Path B.
- **Per-cell repetition:** every step is per-cell. Missing a cell means the alert keeps firing for that cell.
- **Don't invert the problem:** prod-vs-DRP values are *supposed* to match; only prod-vs-Dev/Test must differ.
- **Vendor coupling (`MULTIPLE_TOKENS`):** the old pair must be invalidated by Natterbox support, otherwise a leaked prod-in-devtest credential remains live even after rotation.
- **Auto-generated descriptor:** confirm the correct way to edit the YAML (§5) before hand-editing.

---

## 8. Suggested sequencing
1. Pre-work §3 (access, cells, "does Dev/Test need it?", rotation owner).
2. Pick Path A or B from §4.
3. Execute the secret operation per cell.
4. Descriptor PR §5 + GGE redeploy.
5. Verify §6 across all cells.
6. Update ticket + resolve Sentry.

**Effort estimate:** Path A ≈ 0.5–1 day (mostly access + per-cell ops). Path B ≈ 2–3 days (vendor round-trip for new credentials + coordinated rollout).

---

### Open questions to resolve before starting
1. Does Dev/Test actually need real Natterbox credentials, or are tests mocked? (decides Path A vs B)
2. Who owns the Natterbox vendor relationship for generating/invalidating credentials?
3. Is hand-editing the auto-generated descriptor acceptable, or must it go through Credentials Manager regeneration?
4. Which cells currently have `natterbox.api` in both prod and Dev/Test?
