---
title: GlobalInviteHandlerWebhooksServer
component_type: webhook-server
tags: [call-scheduling, webhook, rest, gge]
---

# 🌐 GlobalInviteHandlerWebhooksServer

> [[Call Scheduling - Data Flow.canvas|← Canvas]] · [[02 - Entry Points (Inbound & Outbound)|Entry Points §2]]

Public receiver on **GGE**. A GGE→GPE **bridge**: single wildcard router (`:50`) reads the
invite-handler name from `recipient`, resolves the cell (`InviteHandlerRoutingService`), and forwards the
raw request to the right GPE cell (`RequestForwarder`). It does **not** schedule anything itself.
