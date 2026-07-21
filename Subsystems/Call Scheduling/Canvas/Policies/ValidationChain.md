---
title: Validation Chain (Policy)
component_type: policy
tags: [call-scheduling, policy, validation, resolution]
---

# 📋 Validation Chain (Policy)

> `EventValidationFactory` · `CallScheduler/.../validation/`

**"Run the chain selected by `CallCreationMechanism`; the first failing validator sets the `Resolution`."**

Validators include: `CheckProviderEnabled`, `CheckUserShouldRecord`, `CheckBlacklist`, `CheckInternalMeeting`, `CheckCompliance` (reads DCP from Consent), `CheckDoNotRecord`. Resolution drives the CRUD operation: `NEW_CALL` → `NEW`, compliant failure → `CANCEL`, `COMPLIANCE_ENFORCING` → blocked. 60+ `Resolution` values.
