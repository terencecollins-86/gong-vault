---
title: Conferencing Providers
component_type: external-providers
tags: [call-scheduling, providers, conferencing]
---

# 🎥 Conferencing Providers

> [[Call Scheduling/Canvas/Call Scheduling - Data Flow.canvas|← Canvas]] · [[03 - Ubiquitous Language|Ubiquitous Language §2]]

The recording targets a call resolves to, via the generic `CallInDetails` / `Identifier.Descriptor`
abstraction: **Zoom, WebEx, Microsoft Teams, GoToMeeting, Google Meet** (+ RingCentral Video, Chime,
BlueJeans). One-time meeting URLs supported by Zoom / Google Meet / Teams / WebEx. Provider APIs called
via gong-clients services (`ZoomSyncService`, `WebexRefreshTokenService`, G2M integration).
