---
title: Consent — Audio Prompt
tags: [consent, recording-consent, audio-prompt, bot, reference]
created: 2026-07-21
aliases:
  - audio prompt
  - bot audio prompt
  - recording notice
---

# Audio Prompt

> [[_dashboard|← Team Hub]] · [[00 - Overview]] · [[Jump Page & DCP]]

> [!note] TL;DR
> The **audio prompt** is a verbal recording notice played by the Gong bot at the start of a call. It gives every participant in-call notice that the meeting is being recorded. Admins can customise the language, voice, and text. If a participant already consented via the **consent page**, the audio prompt can be suppressed.

---

## What it does

When the Gong recording bot joins a meeting, it plays a verbal recording notice into the call. Every participant hears it either once (when the call starts) or individually when each guest joins with audio on.

The audio prompt is Gong's in-call consent surface — distinct from the jump page (which gates the join link) and the pre-call email (which notifies before the meeting). It satisfies jurisdictions that require verbal notice at the point of recording.

---

## When it plays

1. **Call starts** or shortly after each guest **joins with audio on**.
2. Gong plays the verbal recording notice into the meeting.
3. Every participant hears it; company-side participants can be **excluded** from hearing the prompt.
4. If the participant already accepted on the **consent page**, the audio prompt can be **suppressed** for that participant.

---

## Admin configuration

Admins can customise:

| Setting | Options |
|---|---|
| **Prompt audience** | All participants, external only, or exclude company participants |
| **Language** | Localised audio prompt language |
| **Voice** | The TTS voice used for the prompt |
| **Text** | Custom recording-notice text |
| **Suppress if consent already captured** | Skip prompt for participants who already accepted on the consent page |

---

## Zoom — native audio prompt

For **Zoom meetings**, Gong can use Zoom's own built-in disclaimer instead of the Gong bot audio prompt.

| | Zoom native recording | Gong bot on Zoom |
|---|---|---|
| **Consent source** | Zoom's built-in disclaimer | Gong bot audio prompt |
| **Who owns the experience** | Zoom owns the disclaimer entirely | Gong controls language, voice, and text |
| **Customisable by admin** | Via Zoom Admin: confirmation flow, audience, host confirmation, consent buttons, dial-in notices | Via Gong: language, voice, text |
| **Participant experience** | Each participant hears it once; **not** Gong-customisable | Each participant hears it; suppressed if already consented via jump page |
| **Other DCP settings** | Still apply | Still apply |
| **Fallback** | N/A | If bot is not connected with a token, falls back to Gong's own audio prompt |

> **Note:** When native Zoom consent is active, Gong's audio prompt settings do **not** apply. All other DCP consent profile settings still apply.

---

## Relationship to the consent page

The audio prompt and the consent page are **complementary**, not alternatives:

- The **consent page** is a gate — the participant cannot enter the meeting without going through it.
- The **audio prompt** fires in-call, regardless of whether the participant went through the consent page.
- If a participant already accepted on the consent page, the audio prompt **can be suppressed** (admin-controlled setting).

Companies that use the consent page and want to avoid duplicate consent surfaces enable the suppression option so participants who already accepted aren't prompted again.

---

## What the audio prompt is NOT

- It does not create an audit record in `recording_compliance.jump_page_interaction` (that table is jump-page only).
- It does not produce a Kafka event in the consent subsystem.
- It is not controlled by `DcpJumpPageSettings` directly — it has its own consent-profile settings.
- It is not the **confirmation email (LA)** — that is a separate mechanism for calls organised by non-org members. See [[Confirmation Email (LA)]].

---

## See also

- [[00 - Overview]] — the five consent mechanisms and where audio prompt fits
- [[Jump Page & DCP]] — the consent page gate; suppression relationship
- [[Confirmation Email (LA)]] — the other non-jump-page consent mechanism
- [[Use Cases/A - Solicit/A2 - Send Pre-Call Consent Email|UC-A2]] — pre-call email (sends before the call; distinct from in-call audio)
- [[03 - Ubiquitous Language]] — domain vocabulary
