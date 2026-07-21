---
title: data_capture DB
component_type: datastore
tags: [consent, datastore, postgres, dcp]
---

# 🗄️ data_capture (PostgreSQL)

Owned by `DcpChangeManager`. Schema `dcp_change` holds the change-request state machine tables written by `DcpChangeManagerDao`. Tracks `ChangeRequestLifecycle` state (`INIT → RUNNING → DONE`) per company + user.

Separate from `honeyfy_dev.data_capture.profile` (the operational seed row) — see [[Subsystems/Consent/05 - Data Access & Storage]].
