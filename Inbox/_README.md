---
cssclasses: inbox
---

# 📥 Inbox — Processing Guide

This folder is a **raw capture zone**. Drop anything here first — links, thoughts, Slack snippets, meeting jots. Process regularly (aim: clear weekly).

---

## How to Process an Item

1. **Detect type** from content:
   - Code / PR / bug / ticket → `engineering`
   - System design / trade-off / decision → `architecture` (ADR)
   - People interaction / action items → `meeting`
   - Something that went well → `win`
   - Exploring an idea / tech → `research`

2. **Apply the right template** (Templater → Insert template):
   - `engineering-note.md`
   - `architecture-adr.md`
   - `meeting-note.md`
   - `win-note.md`
   - `research-spike.md`

3. **Move to the correct folder**:
   - `Engineering/Notes/`, `Engineering/Bugs/`, or `Engineering/PRs/`
   - `Architecture/ADRs/` or `Architecture/Proposals/`
   - `Meetings/1-on-1s/` or `Meetings/Syncs/`
   - `Goals & Growth/Wins/`
   - `Research/Spikes/`

4. **Tag appropriately**: `#win`, `#learning`, `#goal`, `#blocker`, `#action`

5. **Delete or archive** the original inbox item.

---

## Agent Processing Prompt

If using an AI agent to process inbox items, provide this prompt:

> Read the inbox item. Detect its type (engineering/meeting/research/win/architecture). Extract key information. Suggest the correct template and destination folder. Propose appropriate tags. Do not move the file — present the suggestion for human approval.
