---
title: Consent — Link Creation Surfaces
tags: [consent, recording-consent, jump-page, link-creation, pmi, dynamic, reference]
created: 2026-07-21
aliases:
  - consent link
  - jump page link
  - consent link creation
  - where to create consent link
---

# Consent Link Creation Surfaces

> [[_dashboard|← Team Hub]] · [[Jump Page & DCP]] · [[03 - Ubiquitous Language]]

> [!note] TL;DR
> A **consent link** (jump-page URL) can be created in four ways. Static (PMI) links are reusable. Dynamic links are generated per meeting. Most teams enable both — dynamic for standard scheduling hygiene, static where workflow tools make persistence practical.

---

## The four creation surfaces

| Surface | Type | How it works |
|---|---|---|
| **1 · Copied static links** | PMI (static) | Reusable link tied to the host's personal meeting room. User copies it once and pastes it into calendar invites or scheduling tools (e.g. Calendly). The link never changes between meetings. |
| **2 · Outlook add-in** | Dynamic or static | Gong add-in for Outlook lets the rep create or insert consent-enabled meeting links while scheduling. |
| **3 · Google Calendar add-on** | Dynamic or static | Gong add-on for Google Calendar lets the rep add a Gong Meeting link during scheduling. |
| **4 · Gong API** | Dynamic or static | Programmatic option for external scheduling tools or custom workflow integrations. |

---

## PMI vs Dynamic — which to use

| | PMI (static) | Dynamic (per-meeting) |
|---|---|---|
| **URL** | Same link for every meeting | New URL per scheduled meeting |
| **Best for** | Scheduling on behalf of others, tools like Calendly where a persistent link is practical | Standard meeting hygiene — cleaner separation between meetings |
| **Managed by** | Set once at user onboarding; lives in Redis until changed | `JumpPageAdminService#scheduleMeeting` per event; `OneTimeMeetingStatus` lifecycle |
| **URL segments** | `profileKey/userKey` (2 segments) | `profileKey/userKey/meetingKey` (3 segments) |

> **Tip:** Many teams enable both. Dynamic is the recommended default; static/PMI links are kept for workflows where a persistent link is needed.

---

## How the URL reaches participants

The jump-page URL is **embedded in calendar invites by Call Scheduling**, not sent by Consent directly. Consent generates the URL (via `JumpPageUrlService`) and stores it in Redis; Call Scheduling reads it and puts it in the invite. See [[Jump Page & DCP#How the URL reaches the participant]] for the full three-trigger refresh lifecycle.

---

## See also

- [[Jump Page & DCP]] — full URL anatomy, PMI vs dynamic internals, Redis layout
- [[03 - Ubiquitous Language]] — `profileKey`, `userKey`, `meetingKey`, `PMI`, `OneTimeMeetingStatus`
- [[Use Cases/D - Configure/D2 - Manage One-Time Meeting|UC-D2]] — managing dynamic (one-time) jump-page meetings
- [[00 - Overview]] — the five consent mechanisms
- [[Subsystems/Call Scheduling/_dashboard|Call Scheduling]] — the downstream consumer that embeds the URL in invites
