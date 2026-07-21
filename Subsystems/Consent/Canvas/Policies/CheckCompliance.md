---
title: CheckCompliance (Policy)
component_type: policy
tags: [consent, policy, compliance, call-scheduling]
---

# 🛡️ CheckCompliance (Policy)

> `CallScheduler/.../validation/CheckCompliance.java` · runs in call-scheduling pipeline

**"If DCP is enabled AND the meeting URL is not a Gong jump-page URL AND the call is not an interview → enforce."**

Reads `DcpJumpPageSettings` for the call owner. If `isEnabled=true` and a non-Gong URL is detected: optionally sends a non-compliant warning email to the rep. If `isEnforced=true` → `Resolution.COMPLIANCE_ENFORCING` — call blocked. If `isEnforced=false` → warning only, call schedules.

See [[Subsystems/Call Scheduling/Compliance URL Enforcement]].
