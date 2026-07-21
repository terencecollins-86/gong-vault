---
title: Consent — Meeting Providers & Multi-Provider DCP
tags: [consent, recording-consent, providers, dcp, multi-provider, reference]
created: 2026-07-21
aliases:
  - meeting providers
  - multi-provider
  - provider model
  - DcpJumpPageSettingsProvider
---

# Meeting Providers & Multi-Provider DCP

> [[_dashboard|← Team Hub]] · [[Jump Page & DCP]] · [[03 - Ubiquitous Language]]

> [!note] TL;DR
> A **Data Capture Profile (DCP)** can cover **multiple meeting providers** (Zoom, Teams, WebEx, …) simultaneously. Each provider gets its own settings (`linkType`, `recordingOptOut`, `isDefault`) inside the profile. The consent page resolves the right URL via a `?provider=` query parameter. A user's preferred provider is stored per-user in Redis and the DB so the consent page can pre-select it.

---

## The supported providers

Providers are identified by string codes that map to the `Identifier.Descriptor` enum
(`AppCommon/.../callproviders/identifiers/api/Identifier.java`). Each code has a concrete
`WebConferencingIdentifier` implementation in `WebConferencing/.../identifiers/all/`:

| Identifier class | Provider |
|---|---|
| `ZoomIdentifier` | Zoom |
| `RingCentralMeetingsIdentifier` | RingCentral (Zoom-based) |
| `RingCentralVideoIdentifier` | RingCentral Video |
| `MicrosoftTeamsIdentifier` | Microsoft Teams |
| `WebExIdentifier` | Cisco WebEx |
| `GoToMeetingIdentifier` | GoToMeeting |
| `BlueJeansIdentifier` | BlueJeans |
| `GoogleMeetIdentifier` | Google Meet |
| `SkypeForBusinessIdentifier` | Skype for Business |
| `JoinMeIdentifier` | Join.me |
| `ClearSlideIdentifier` | ClearSlide |
| `AppointletIdentifier` | Appointlet |
| `GongPhysicalRecordingDeviceIdentifier` | Gong hardware device |
| `DummyIdentifier` | fallback / unknown |

Two stable string constants exist on `Identifier`: `ZOOM_CLOUD_PROVIDER_CODE` and
`WEBEX_CLOUD_PROVIDER_CODE`. All other provider codes are resolved via
`IdentifierResolver#resolveWebConferencingIdentifier(String providerCode)` using
`Identifier.Descriptor#byCode`.

---

## Single-provider vs multi-provider DCP

`DcpJumpPageSettings` (`AppCommon/.../datacaptureprofile/DcpJumpPageSettings.java`) holds
provider configuration in two ways:

| Field | Type | Purpose |
|---|---|---|
| `meetingProvider` | `String` | **Legacy** single-provider field — still present for backward compatibility |
| `providers` | `List<DcpJumpPageSettingsProvider>` | **Current** multi-provider list — one entry per covered provider |
| `getDefaultProvider()` | `String` | Returns the default provider code for this profile |
| `isProviderInProfile(provider)` | `boolean` | Whether a given provider code is in the `providers` list |

Most companies have one entry in `providers`. A multi-provider company has two or more — e.g.
Zoom **and** Teams, each with its own settings.

---

## Per-provider settings — `DcpJumpPageSettingsProvider`

`DcpJumpPageSettingsProvider` (`AppCommon/.../datacaptureprofile/DcpJumpPageSettingsProvider.java`)
is the sub-object that holds one provider's settings within a DCP profile:

| Field | Type | Meaning |
|---|---|---|
| `meetingProvider` | `String` | Provider code — the key that ties this entry to a provider |
| `linkType` | `JumpPageLinkType` | `PMI` / `DYNAMIC` / `ONLY_DYNAMIC` — independent per provider |
| `recordingOptOut` | `JumpPageRecordingOptOut` | `EXPLICIT` (deny button shown) or `IMPLICIT` (no deny button) — independent per provider |
| `isDefault` | `Boolean` | Whether this is the default provider for the profile |
| `order` | `int` | Display ordering on a multi-provider consent page |
| `isProtectedPmi` | `boolean` | PMI link is in a transition-protection window |
| `protectedTransitionEndTime` | `Instant` | End of PMI protection window |

> **Key implication:** Zoom can be configured with `PMI` + `EXPLICIT` opt-out while Teams uses
> `DYNAMIC` + `IMPLICIT` within the same company profile. Provider-scoped lookups on
> `DcpJumpPageSettings` accept a `provider: String` parameter:
> `isProviderLinkTypePmi(provider)`, `isPmiEnabled(provider)`,
> `isProviderLinkTypeDynamic(provider)`, `isProviderLinkTypeOnlyDynamic(provider)`.

---

## Multi-provider jump-page URLs

**`MultipleProviderJumpPageUrlService`**
(`ComplianceCommon/.../service/MultipleProviderJumpPageUrlService.java`) extends the single-provider
URL builder for multi-provider profiles. Key methods:

| Method | What it does |
|---|---|
| `createMultiProviderUsersUrl(companyId, profileKey, userUrlKey, token, providers: Set<String>, globalDomain)` | Returns one URL **per provider** in the set — each URL gets a `?provider=<code>` query parameter appended |
| `extractProviderFromUrl(url)` | Parses the `?provider=` param back out of a URL; used to identify the provider at page-render time |
| `getWebConferencingIdentifier(url)` | Resolves the `WebConferencingIdentifier` for a given meeting URL |
| `isMultiProviderPmiJumpPageUrl(url)` | Returns `true` if the URL is a PMI URL **and** carries a valid `?provider=` param |

The `?provider=` query param is the **discriminator**: when a participant arrives at the consent page,
`extractProviderFromUrl` tells `JumpPageController` which provider's settings to load from the DCP.

---

## User provider default

For multi-provider profiles, the consent page can pre-select the provider a user normally uses.
This preference is stored **per user** in two places:

### DB — `recording_consent_settings.user_settings`

| Column | Type | Value |
|---|---|---|
| `appuser_id` | `bigint` (PK) | Gong app user ID |
| `default_meeting_provider` | `character` | Provider code string (nullable) |

- **Written by** `DcpConsentSettingsService#saveUserProviderDefault` → `ConsentUserSettingsClient#saveUserSettings`
- **Read by** `DcpConsentSettingsService#determineDefaultProvider` / `#newDetermineDefaultProviderLogic` when selecting which provider to show as default on the page
- **Cleared by** `ResetUserDefaultProviderAction#resetUserDefaultIfNeeded` when a provider is removed from the DCP — prevents a stale preference pointing at a now-removed provider

The API surface is `DcpConsentSettingsController#saveUserProviderDefault(appUserId, meetingProvider)` on `RecordingConsentApiServer`.

### Redis — `RedisConsentUserSettings`

`RedisConsentUserSettings` (`DataCaptureProfile/.../dto/RedisConsentUserSettings.java`) is the
per-user Redis-cached object. Provider-related fields:

| Field | Type | Purpose |
|---|---|---|
| `providerMeetingUri` | `String` | Legacy single-provider meeting URI |
| `providerMeetingId` | `String` | Legacy single-provider meeting ID |
| `providerMeetingSettings` | `Map<String, JumpPageUserSettings.ProviderMeetingSettings>` | Multi-provider map: provider code → meeting settings |
| `token` | `Optional<String>` | PMI access token |

The composite `DcpJumpPageUrlSettings` object exposes
`getMultiProviderMeetingUri(provider: String): Optional<String>` to pick the right meeting URI
for the provider the participant arrived from.

---

## Per-user per-provider meeting room URI — `appuser_static_link`

The `appuser_static_link` table (in the `data_capture_dev` DB, `data_capture` schema) stores each
user's actual meeting room URI for each provider:

| Column | Notes |
|---|---|
| `company_id` | |
| `appuser_id` | |
| `provider` | Provider code string — part of the composite PK |
| `meeting_provider_uri_source` | Enum: `MANUAL` or `PROVIDER` |

This is separate from `user_settings.default_meeting_provider` (which is just a preference) — 
`appuser_static_link` holds the actual Zoom/Teams/WebEx meeting room URL that the consent page
redirects the participant to after they accept.

---

## How provider changes propagate — `SyncMeetingPmiAction`

When a DCP settings change transitions a provider's `linkType` to PMI (or changes the provider
itself), `SyncMeetingPmiAction` (`DcpChangeManager/.../action/batch/SyncMeetingPmiAction.java`)
fires as part of the `ChangeRequestLifecycle`:

1. `shouldExecute(previousSettings, currentSettings, changeType)` — checks if `linkType` now has PMI enabled (`JumpPageLinkType#isPmiEnabled`) or if the provider string changed.
2. `execute(users)` — for each affected user, calls `MeetingRoomApi#syncMeetingRoomSingleDcp(companyId, dcpId, meetingProvider)` asynchronously via a `ScheduledExecutorService`.
3. `MeetingRoomApi` tells the meeting-room orchestrator to re-fetch and register the PMI link for the new DCP + provider combination.

The `meetingProvider` parameter is passed explicitly — so the sync is **provider-scoped**, not a full company resync.

`DcpMultiProviderService#isProviderChanged(oldSettings, newSettings)` is the detection method: if the
`providers` list changes (providers added or removed), a change request is raised.

---

## How the consent page resolves the right provider

At page-render time the resolution chain is:

```
GET /{profileKey}/{userKey}[/{meetingKey}]?provider=<code>
    │
    ▼
JumpPageController#viewJumpPage
    → DcpJumpPageUrlSettings assembled from Redis:
        - RedisDcpJumpPageSettings     ← profile (DcpJumpPageSettings with providers list)
        - RedisConsentUserSettings     ← user (providerMeetingSettings map)
    → extractProviderFromUrl(?provider= param)
    → getMultiProviderMeetingUri(provider)   ← picks the right meeting room URI
    → render consent page with provider-specific settings
          (recordingOptOut, linkType from DcpJumpPageSettingsProvider)

Participant clicks Accept
    → redirect to meeting URI for that provider
    → JumpPageInteractionEvent carries provider context
```

If no `?provider=` is present (single-provider or legacy URL), the default provider from
`DcpJumpPageSettings#getDefaultProvider()` is used.

---

## See also

- [[Jump Page & DCP]] — full DCP field breakdown, PMI vs dynamic, Redis layout
- [[03 - Ubiquitous Language]] — `DCP`, `profileKey`, `userKey`, `linkType`, `recordingOptOut`, `PMI`, `OneTimeMeetingStatus`
- [[Use Cases/D - Configure/D1 - Read Write DCP Settings|UC-D1]] — how DCP settings are read/written
- [[Use Cases/D - Configure/D2 - Manage One-Time Meeting|UC-D2]] — per-meeting provider selection via `chooseMeetingProvider`
- [[Use Cases/E - Propagate/E1 - Orchestrate Change Request|UC-E1]] — `ChangeRequestLifecycle` that triggers `SyncMeetingPmiAction`
- [[Audio Prompt]] — Zoom native consent (provider-specific audio behavior)
- [[02 - Data Flow]] — `saveUserProviderDefault` REST entry point; `SyncMeetingPmiAction` in the change-request flow
