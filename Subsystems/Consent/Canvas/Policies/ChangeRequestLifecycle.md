---
title: ChangeRequestLifecycle (Policy)
component_type: policy
tags: [consent, policy, dcp, state-machine]
---

# 📋 ChangeRequestLifecycle (Policy)

> `DcpChangeManager/.../ChangeRequestLifecycle.java` · DcpChangeManager

**"Fan out a DCP change to every user, run per-user actions, close when all done."**

States: `INIT → RUNNING → DONE`. On new request: produce `batch-users-change-executor`. Per user: produce `single-user-change-executor` → run actions (`CancelNonCompliantCallsAction`, `SyncMeetingPmiAction`, `ConsentEmailSettingsChangeAction`, `ResetUserDefaultProviderAction`, …). On all users done: produce `reset-consent-redis-for-company` → Redis eviction.
