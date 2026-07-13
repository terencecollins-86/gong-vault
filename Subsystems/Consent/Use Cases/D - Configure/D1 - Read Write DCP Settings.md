---
title: "UC-D1 · Read / Write DCP Consent Settings"
tags: [consent, use-case, configure, dcp, settings]
created: 2026-07-13
group: D - Configure
---

# UC-D1 · Read / Write DCP Consent Settings

> [[04 - Use Cases|← Use Cases hub]] · Group **D — Configure** · next → [[D2 - Manage One-Time Meeting|UC-D2]]

Another Gong service reads or writes a company's consent policy.

---

## What this is for

Exposing the company's consent policy — whether recording needs consent, and the
jump-page configuration — to other Gong services, and letting them persist changes to it.
The consumer is a service, not an end user.

## What triggers it

Another Gong service calls in via the `DcpConsentSettingsClient` Feign client, which hits
`RecordingConsentApiServer` (REST).

---

## What the Consent module did

```
Gong service ──(Feign DcpConsentSettingsClient)──▶ RecordingConsentApiServer
        │
        ▼
DcpConsentSettingsController#readDcpJumpPageSettingsWithUser   (read)
DcpConsentSettingsController#saveUserProviderDefault           (write)
        │
        ├─▶ recording_consent_settings.appuser_consent_settings  (DcpConsentSettingsDao)
        └─▶ user_settings                                        (UserSettingsDao)

per-user resolution: DcpAppUserConsentService (monolith) → effective policy
change detection:    JumpPageSettingsChangeDetectorController#detectChanges(DcpJumpPageSettings)
```

---

## What happens downstream / why it matters

Reads return the effective consent policy for a company/user; writes persist a new default
and can trigger change detection, which is what fans a change out to propagation
(see [[E - Propagate/E1 - Orchestrate Change Request|UC-E1]]). This is the config surface
the rest of the platform trusts.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | another Gong service (Feign `DcpConsentSettingsClient`) |
| **Command / process** | `DcpConsentSettingsController#readDcpJumpPageSettingsWithUser` / `#saveUserProviderDefault` |
| **Event / topic** | — (REST) |
| **State / audit** | `recording_consent_settings.appuser_consent_settings` / `user_settings` |

## Related

[[D2 - Manage One-Time Meeting|UC-D2]] · [[E - Propagate/E1 - Orchestrate Change Request|UC-E1]] (a write here can fan out)
