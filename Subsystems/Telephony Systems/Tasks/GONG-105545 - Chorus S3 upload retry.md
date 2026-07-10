---
jira: GONG-105545
type: Task
priority: P2
status: Ready for Development
team: Telephony / Coms Capture
repo: gong-telephony-systems
module: Dialers
newbie_fit: "★★★★★ — recommended first real task"
tags: [telephony, chorus, s3, retry, onboarding]
---

# GONG-105545 — Chorus migration: add retry for uploading downloaded file to S3

**Jira:** https://gongio.atlassian.net/browse/GONG-105545
**Related (closed) Sentry/bug:** [GONG-105518](https://gongio.atlassian.net/browse/GONG-105518) — `SdkClientException: Unable to execute HTTP request: Remote host terminated the handshake`
**Reporter:** Naama Kari · **Created:** 2025-06-10

> **Why this is a good first task:** small, additive, contained to one method, with an obvious success criterion (a transient S3 upload error should retry instead of failing the call). It also walks you through the most important flow in the system — the dialer → download → S3 → import pipeline — without asking you to redesign anything. Hard to make things worse.

---

## 1. The problem in plain terms

When Gong imports calls from **Chorus** (a telephony provider, internal flavor `CUSTOM_IMPORT_1_API_SCRAPING`), each call recording is:
1. Downloaded from Chorus over HTTP, into a temp file.
2. Uploaded to **S3** (Gong's cloud storage).
3. (Later) picked up for processing.

If the **S3 upload throws** (observed: a transient TLS/connection error — *"Remote host terminated the handshake"*), the current code **immediately marks the call as failed to import**. Because it was a transient network blip, a simple retry would very likely succeed. Today there is no retry, so we permanently lose calls to a temporary glitch.

## 2. Exactly where it happens

**File:** `Dialers/src/main/java/com/honeyfy/dialers/services/ChorusDialerService.java`
**Method:** `submitDownloadTaskAndReport(...)` — around lines **584–604**.

```java
try (final AutoCloseableHolder<Path> fileHolder = AutoCloseableHolder.of(
        Files.createTempFile(tmpDownloadFSRoot, "chorus_recording", extension), FileUtilities::deleteSilently)) {
    HttpGet getRecordingRequest = new HttpGet(redirectLink);
    try (CloseableHttpResponse response = httpClient.execute(getRecordingRequest);
         FileOutputStream fos = new FileOutputStream(fileHolder.get().toFile())) {
        IOUtils.copy(response.getEntity().getContent(), fos);
        CompanyOwnedKeyData keyData = companyOwnedKeyRetrieval.getCompanyOwnedKeyDataForS3(callSyncContext.companyDto.companyId);
        dialerCloudStorage.uploadFile(callIdToCacheKey(callSyncContext.callId), fileHolder.get(), keyData);  // <-- line ~593: this throws
    }
} catch (Exception e) {
    logger.warn("File download failed. callId={}; url={}", callSyncContext.callId, redirectLink, e);
    callSyncContext.cachingRejectionReason = Optional.of(CallImportationRejectionReason.IMPORT_FROM_DIALER_FAILED);  // <-- line ~597: marks call failed
}
```

The `dialerCloudStorage.uploadFile(...)` call on **line ~593** is what fails. The `catch` on **line ~597** is what sets `IMPORT_FROM_DIALER_FAILED` — i.e. "this call won't be imported."

## 3. The fix (intended approach)

Add a **bounded retry with backoff** around the S3 upload so transient failures recover instead of failing the call.

**Good news — the pattern already exists in this same file.** The outer caching method uses Gong's `Robust.robust(...)` retry helper. Look at the end of `cacheCalls`/the calling method (line ~581):

```java
}, 2, 10000, 1);   // Robust.robust(action, retries=2, delayMs=10000, ...) — copy this style
```

### Suggested implementation
- Wrap **just the `uploadFile` call** (or the download+upload block) in `Robust.robust(...)` with a small retry count (e.g. 2–3) and a backoff delay.
- Only retry on **transient** exceptions (connection/TLS/`SdkClientException`), not on permanent ones (e.g. file-not-found, auth). If unsure, start by retrying broadly and refine — but mention this in the PR for reviewer input.
- Keep the existing `catch` → `IMPORT_FROM_DIALER_FAILED` as the **final** fallback once retries are exhausted, so behaviour after all retries fail is unchanged.

> ⚠️ **Scope discipline:** change only the upload retry. Do **not** restructure the thread-pool / download flow — that is the separate, much larger ticket [[GONG-139960 - Chorus stuck calls|GONG-139960]] (which I have NOT planned here). If you spot deeper issues, note them in the PR; don't fix them in this ticket.

## 4. Key terms / context for someone new
- **Dialer / telephony flavor** — Gong integrates with ~30 phone-call providers. Each has a `*DialerService`. Chorus = `ChorusDialerService`, flavor enum `IntegrationFlavor.CUSTOM_IMPORT_1_API_SCRAPING`.
- **`dialerCloudStorage.uploadFile(...)`** — Gong's S3 wrapper. See the [[Cloud Storage]] pattern / `com.honeyfy.filestorage`.
- **`CompanyOwnedKeyData` / `companyOwnedKeyRetrieval`** — BYOK (bring-your-own-key) encryption context; the file is encrypted with the customer's KMS key. You don't need to change this — just keep passing it through.
- **`callSyncContext.cachingRejectionReason`** — when set, downstream marks the call as not-imported.
- **`Robust.robust(...)`** — Gong's standard retry/resilience helper (`com.honeyfy.util.flow.Robust`).
- **`AutoCloseableHolder` + temp file** — the recording is streamed to a temp file that auto-deletes; retries must stay **inside** the `try-with-resources` so the downloaded file is still on disk when you re-attempt the upload (don't re-download unless you intend to).

## 5. How to verify
- [ ] **Unit test** in `Dialers/src/test/...` — mock `dialerCloudStorage.uploadFile` to throw a transient exception once (or N-1 times) then succeed; assert the upload ultimately succeeds and `cachingRejectionReason` is **not** set. Add a second test: always-throw → after retries exhausted, `IMPORT_FROM_DIALER_FAILED` IS set (unchanged fallback).
- [ ] Run the module's tests via the [[java-backend validator]] (do NOT run `mvn test` by hand — telephony tests need `host.docker.internal` flags in GCR).
- [ ] **Manual / debug (optional):** trigger a Chorus sync via the troubleshooter (see [[Postman - Ingester Telephony Supervisor]] → task `customimport1-import...`) and step through `submitDownloadTaskAndReport`. (Requires DEV profile — see the entry-points doc.)

## 6. Success criteria
1. A transient S3 upload failure is retried; if a retry succeeds the call imports normally.
2. After retries are exhausted, behaviour is identical to today (`IMPORT_FROM_DIALER_FAILED`).
3. New unit test(s) cover both paths.
4. No change to download logic, thread pool, or unrelated code.

## 7. Open questions to confirm with the team
- Preferred retry count / backoff for S3 uploads (any existing convention in `dialerCloudStorage`)?
- Should retry be limited to specific exception types, or is broad retry acceptable here?
- Is there a metric to emit on retry/exhaustion for observability?

**Estimate:** ~1–2 days including tests and review.

Related: [[GONG-139960 - Chorus stuck calls]] (the larger sibling problem — read it for context, don't fix it here).
