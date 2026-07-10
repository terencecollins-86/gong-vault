---
title: audit-meeting-consent
component_type: kafka-topic
cluster: RECORDING_CONSENT
tags: [consent, kafka, audit, oncall]
---

# 🔁 audit-meeting-consent

> [[Call Scheduling/Canvas/Consent/Consent - Data Flow.canvas|← Canvas]] · [[02 - Data Flow|Data Flow §2/§5]]

The consent **audit** topic. Produced by `JumpPageController.publishInteractionEvent` (`:765`) when a
participant answers; consumed by `AuditMeetingConsentConsumer` (`:26`) → writes the compliance audit trail
(`recording_compliance.jump_page_*`). Cluster `RECORDING_CONSENT`. Payload `JumpPageInteractionEvent`.
