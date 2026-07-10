# Coms Capture / Telephony Team — Open Backlog

Source: Jira project **GONG**, filtered by Team field (`Telephony Team`) + `telephony-systems-on-call@gong.io` queue. Status category = To Do (Backlog / Ready for Development / Selected for Development). Pulled 2026-06-19.

**Total: 11 open items — 1× P1, 10× P2**

## 🔴 P1 — Do first

| Key | Type | Status | Summary |
|---|---|---|---|
| [GONG-137502](https://gongio.atlassian.net/browse/GONG-137502) | Bug | Ready for Dev | Secret has the same value in prod and devTest issues (Sentry JAVA-SYSTEMS-ATD9) |

## 🟠 P2 — Ready for Development

| Key | Type | Status | Summary |
|---|---|---|---|
| [GONG-141661](https://gongio.atlassian.net/browse/GONG-141661) | Bug | Ready for Dev | Unable to disconnect from Groove |
| [GONG-139960](https://gongio.atlassian.net/browse/GONG-139960) | Task | Ready for Dev | Fix Chorus backfill calls permanently stuck in IMPORT_REQUESTED on service restart |
| [GONG-105545](https://gongio.atlassian.net/browse/GONG-105545) | Task | Ready for Dev | Chorus migration — add retry for uploading downloaded file to S3 |
| [GONG-104205](https://gongio.atlassian.net/browse/GONG-104205) | Task | Selected for Dev | Long meeting ID will not be indexed |
| [GONG-104035](https://gongio.atlassian.net/browse/GONG-104035) | Task | Ready for Dev | Update inContact Dialer Tile — New Branding |

## 🟠 P2 — Backlog (not yet groomed to Ready)

| Key | Type | Status | Summary |
|---|---|---|---|
| [GONG-143245](https://gongio.atlassian.net/browse/GONG-143245) | Sub-task | Backlog | APPINFRA-2268: Migrate Kafka ACL descriptors in gong-telephony-systems |
| [GONG-102080](https://gongio.atlassian.net/browse/GONG-102080) | Story | Backlog | [Telephony out of Honeyfy] gong-public-api |
| [GONG-102079](https://gongio.atlassian.net/browse/GONG-102079) | Story | Backlog | [Telephony out of Honeyfy] gong-frontend — FrontEndApi |
| [GONG-96776](https://gongio.atlassian.net/browse/GONG-96776) | Story | Backlog | Talkdesk API — Scoping |
| [GONG-91532](https://gongio.atlassian.net/browse/GONG-91532) | Story | Backlog | Move to new JWT mechanism |

## Notes

- **Start with GONG-137502** — only P1, security/secret-handling bug, already Ready for Dev.
- **GONG-139960 + GONG-105545** are related Chorus reliability items (both touch `ChorusDialerService` / download pipeline) — worth tackling together. GONG-139960 has a detailed RCA with 5 fix options.
- **"Telephony out of Honeyfy"** (GONG-102079 / 102080) is a multi-story migration still in Backlog — larger initiative, not a quick win.

### Accuracy caveats
- Jira Team field is sparsely populated: only 1 of 11 carries the explicit "Telephony Team" tag; the rest came via the `telephony-systems-on-call@gong.io` assignee. Real backlog may be larger.
- The Jira "Telephony Team" field ≠ the engineering Coms-Capture team that owns `gong-data-capture` / `gong-cloud-recorders` / `gong-communications-publisher` / `gong-ingestion`. Data-capture/recorder/email-capture tickets may live under other Team values (e.g. EcoSystem, Web Conferencing).
