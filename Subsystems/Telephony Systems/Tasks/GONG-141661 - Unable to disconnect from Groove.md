---
jira: GONG-141661
type: Bug
priority: P2
status: Ready for Development
team: Telephony / Coms Capture
repo: gong-telephony-systems
module: Dialers + IngesterTelephonySystemsSupervisor
newbie_fit: "★★★☆☆ — good if mentored; root cause not yet confirmed"
tags: [telephony, groove, salesforce, disconnect, bug, onboarding]
---

# GONG-141661 — Unable to disconnect from Groove (Salesforce)

**Jira:** https://gongio.atlassian.net/browse/GONG-141661
**Customer ticket:** [TKT-43188](https://gongio.atlassian.net/browse/TKT-43188) (Relay Financial)
**Created:** 2026-06-02

> **Fit note:** This is a real customer bug with good reproduction detail, so it's motivating onboarding work — but the **root cause is not yet confirmed**, so it carries more uncertainty than [[GONG-105545 - Chorus S3 upload retry|GONG-105545]]. Recommended **only with a mentor / reviewer** who knows the integration-connect flow. Do the investigation phase (§3) first and confirm the cause before writing code.

---

## 1. The bug (from the customer ticket)
A customer connected to the **Groove (Salesforce)** telephony integration wants to disconnect. In Admin Center → Telephony → Groove (Salesforce), they click **Disconnect** and get a **success message** — but on refresh/navigation, the integration **still shows as connected**. The disconnect doesn't stick.

- The user attempting it (Jennifer Kavanaugh, `1108363439923842984`) is a **technical/business admin but NOT the user who originally authorized** the connection. The reporter explicitly asks: *does the original auth-ing user have to be the one to disconnect?* — that's a live hypothesis to confirm.
- No network errors. A "200/successful" request was captured with **XTID `6sbl1ry7kzhk3ycf407`** — use this to find logs.
- Repro video (≈1 min): linked in the Jira ticket.

## 2. Background you need first
- **Groove** is a Salesforce-based telephony provider. Its flavor enum is `IntegrationFlavor.GROOVE_SFDC` (`Dialers/.../generic/IntegrationFlavor.java:37`) and crucially it is an **`isSalesForceFlavor = true`** integration (the `true` in the enum row). SFDC-flavored dialers behave differently from API dialers (their calls are synced via Salesforce tasks, not a direct provider API).
- **"Disconnect"** means: mark the company's integration `DISCONNECTED`, delete its stored credentials/tokens, and clear sync state.

### The disconnect code paths (there are two — this matters)
1. **`AbstractDialerService.disconnect(...)`** — `Dialers/.../generic/AbstractDialerService.java:297`
   ```java
   public void disconnect(Long companyId, Long integrationId, Optional<Long> appUserId) {
       getCompanyRecordingImportService().deleteCompanyRecordingImport(companyId, integrationId);
       getImportCallDao().deleteSyncPropertiesForDisconnect(companyId, integrationId);
       getDialersConnectService().updateCompanyConnectStatus(companyId, integrationId, IntegrationStatus.DISCONNECTED, appUserId);
       getIntegrationFailureManager().resetErrorState(...);
   }
   ```
2. **`DialersConnectService.disconnectDialer(...)`** — `Dialers/.../connect/DialersConnectService.java:519`
   ```java
   public void disconnectDialer(long companyId, long integrationId, Identifier.Descriptor descriptor, Optional<Long> appuserid) {
       try {
           updateCompanyConnectStatus(companyId, integrationId, IntegrationStatus.DISCONNECTED, appuserid);
           importCallDao.deleteSyncPropertiesForDisconnect(companyId, integrationId);
           companyRecordingImportService.deleteCompanyRecordingImport(companyId, integrationId);
           dialersAuthService.deleteToken(companyId, integrationId);
           dialersIntegrationFailureManager.resetErrorState(...);
       } catch (Exception e) {
           logger.error("Failed to disconnect company", e);   // <-- swallows exceptions! see §4
       }
   }
   ```

### The UI/controller entry points
- `TelephonySystemsWebApi/.../TelephonyIntegrationController.java:90` — `updateIntegrationStatus(...)` *(on disconnect)* — the API the UI calls.
- `IngesterTelephonySystemsSupervisor/.../rest/IntegrationsController.java:197` — `disconnectDialer(...)`.
- `IngesterTelephonySystemsSupervisor/.../services/front/IntegrationConnectorService.java:341` and `OAuthConnectionHelper.java:275` — orchestrate the disconnect.

## 3. Investigation plan (DO THIS FIRST)
1. **Pull the logs by XTID.** Search Coralogix for `6sbl1ry7kzhk3ycf407` (link in ticket). Confirm which code path ran and whether an exception was logged. → The [[Coralogix logs-debugger]] / observability skill can help.
2. **Look for the swallowed exception.** `DialersConnectService.disconnectDialer` (line 526–528) **catches and only logs** failures — so the UI would still get a "success" response while the DB update silently failed. **Strong candidate for the "says success but stays connected" symptom.** Check the logs for `"Failed to disconnect company"`.
3. **Check the "which user" hypothesis.** Does disconnect require the original authorizing `appUserId`? For an SFDC flavor, the OAuth token / connection may be keyed to the auth-ing user; a different admin's disconnect may target the wrong token row and no-op. Trace `appUserId` through `IntegrationConnectorService` → `disconnect`.
4. **Check status read-back.** After disconnect, what does the UI query to decide "connected"? If disconnect writes `DISCONNECTED` to one place but the UI reads connection state from another (e.g. company_sync vs creds vs token table), they can disagree — producing exactly this "reconnects on refresh" behaviour.
5. **Confirm SFDC-flavor specifics.** Because Groove is `isSalesForceFlavor`, check whether SFDC dialers need extra disconnect steps (Salesforce-side sync properties) that the generic path skips.

## 4. Most likely root causes (rank after investigation)
- **(A) Silently-swallowed exception** in `disconnectDialer` → returns success to UI but DB unchanged. *(Highest prior — matches symptom exactly.)*
- **(B) Status write/read mismatch** → disconnect updates one table, UI reads another, so it re-shows connected.
- **(C) `appUserId` coupling** → non-auth-ing admin's disconnect targets the wrong row and no-ops.

## 5. The fix (shape — finalize after §3)
- If (A): surface the failure instead of swallowing it — don't return success when the disconnect actually threw; propagate/return an error to the UI, and fix the underlying delete failure.
- If (B): make disconnect update **all** the state the UI reads, or make the UI read the authoritative field.
- If (C): allow any admin to disconnect (decouple from the auth-ing user), if that's the intended product behaviour — confirm with PM.

## 6. How to verify
- [ ] Reproduce locally: connect a (test) Groove integration, disconnect as a **different** admin user, refresh — confirm it stays disconnected.
- [ ] Unit/component test around the chosen disconnect path asserting status is persisted and a failure does not report success.
- [ ] Verify via the troubleshooter (see [[Postman - Ingester Telephony Supervisor]] → IntegrationsController disconnect).
- [ ] Run module tests through the [[java-backend validator]].

## 7. Success criteria
1. Clicking Disconnect on Groove (as a technical/business admin, even if not the auth-ing user — pending product confirmation) reliably disconnects and **persists** across refresh.
2. If a disconnect fails server-side, the user is **not** shown a false success.
3. Regression test covers the path.

## 8. Open questions
- **Product:** must the original authorizing user be the one to disconnect, or should any admin be able to? (Decides whether (C) is a bug or intended.)
- Is the "success but not persisted" caused by the swallowed exception in `disconnectDialer`, or by a status read/write mismatch? (Confirm in logs before coding.)

**Estimate:** ~2–4 days (investigation-heavy; depends on root cause).

Related: [[Coms Capture - Telephony Team — Open Backlog]]
