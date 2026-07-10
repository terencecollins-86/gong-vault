---
title: Call Scheduling (upstream)
component_type: upstream-producer
tags: [consent, upstream]
---

# 📞 Call Scheduling

> [[Consent - Data Flow.canvas|← Canvas]] · [[Call Scheduling/_dashboard|Call Scheduling hub]]

Produces **`call-scheduling-updated`** (`CallSchedulingUpdated`) when a call is scheduled / rescheduled /
cancelled. Consent consumes it (`ConsentCallSchedulingUpdatedConsumer`) to schedule or cancel the
pre-call consent email. This is the direct hand-off documented in [[Call Scheduling/02 - Entry Points (Inbound & Outbound)|Call Scheduling entry points]].
