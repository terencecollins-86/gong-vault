---
title: InviteHandlerWebhooksServer
component_type: webhook-server
tags: [call-scheduling, webhook, rest]
---

# 📨 InviteHandlerWebhooksServer

> [[Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §2]]

Public webhook receiver (**GPE**). `IncomingMailgunController` (`:42`) handles 10 email paths →
`EmailHandlerService.handle` (`:40`) → produces `CallSchedulingRequest` on `call-scheduling-requests`.
