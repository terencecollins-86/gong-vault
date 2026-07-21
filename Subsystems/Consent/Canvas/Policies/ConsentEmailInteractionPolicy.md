---
title: ConsentEmailInteraction (Policy)
component_type: policy
tags: [consent, policy, email, denial]
---

# 📋 ConsentEmailInteraction (Policy)

> `ConsentEmailInteractionService#handleInteraction` · RecordingConsentTasks

**"React to email response: only DENIED triggers action."**

`NO_RESPONSE` → immediate return, no action (call records). `ACCEPTED` → no action (call records). `DENIED` → `callSchedulerClient.cancelScheduledCallByConsentEmail` → `SkipCode.CANCEL_BY_COMPLIANCE_EMAIL`. Silence is treated as no objection. The email is a **notification**, not a gate.

See [[Subsystems/Consent/Consent Email — Default Allow & Outcome Matrix]].
