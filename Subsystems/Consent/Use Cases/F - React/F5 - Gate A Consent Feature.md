---
title: "UC-F5 · Gate a Consent Feature"
tags: [consent, use-case, react, feature-flag]
created: 2026-07-13
group: F - React
---

# UC-F5 · Gate a Consent Feature

> [[04 - Use Cases|← Use Cases hub]] · Group **F — React** · prev → [[F4 - Purge Company]]

Feature-flag gate for consent code paths.

---

## What this is for

Toggling consent features on/off. No end-user action — this is internal plumbing that lets consent code branch on a named flag so a feature can be rolled out or disabled without a deploy.

## What triggers it

Any consent code path checking a flag.

---

## What the Consent module did

```
Consent code path checks a flag
  → ConsentFeatureDao#isFeatureEnabled(RecordingConsentFeatureName)
       → Guava-cached lookup
  NOTE: RecordingConsentFeatureName enum has only FOR_TEST today
        — this is scaffolding, not yet wired to real features
```

---

## What happens downstream / why it matters

Honestly, not much yet: the mechanism exists and is Guava-cached, but the `RecordingConsentFeatureName` enum currently holds only `FOR_TEST`. It is scaffolding — infrastructure ready for real flags, with no production feature gated through it today.

---

## Code map

| | |
|---|---|
| **Actor / trigger** | Consent code path checking a flag |
| **Command / process** | `ConsentFeatureDao#isFeatureEnabled(RecordingConsentFeatureName)` |
| **Event / topic** | — |
| **State / audit** | Guava-cached; enum has only `FOR_TEST` (scaffolding) |

## Related

[[F4 - Purge Company]]
