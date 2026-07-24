---
title: "{{TICKET}} — {{summary}}"
fileClass: jira-ticket
type: engineering
status: active
jira: "{{TICKET}}"
jira_url: "https://gongio.atlassian.net/browse/{{TICKET}}"
parent_epic: "{{parent_epic}}"
workflow_status: todo
priority: "{{priority}}"
assignee: "{{assignee}}"
pr_url: ""
repo: "{{repo}}"
cssclasses: eng
created: {{date}}
tags: [jira, engineering, {{repo}}]
---

# 🟦 {{TICKET}} — {{summary}}

> [!eng] Engineering Context
> **Jira:** [{{TICKET}}](https://gongio.atlassian.net/browse/{{TICKET}})
> **Parent epic:** {{parent_epic}}
> **Status:** `{{jira_status}}` · **Priority:** `{{priority}}`
> **Assignee:** {{assignee}} · **Reporter:** {{reporter}}

---

## Quick Edit

Widgets below write directly to frontmatter — no need to hand-edit YAML.

**Status:** `INPUT[inlineSelect(option(todo), option(doing), option(pr), option(done)):workflow_status]`

**Priority:** `INPUT[inlineSelect(option(P0), option(P0.5), option(P1), option(P2), option(P3)):priority]`

**Type:** `INPUT[inlineSelect(option(engineering), option(bug), option(feature), option(spike), option(refactor), option(chore)):type]`

**Assignee:** `INPUT[text:assignee]`

**Repo:** `INPUT[suggester(option(honeyfy), option(gong-purging), option(gong-recorders), option(gong-data-capture), option(gong-ingestion), option(gong-web-ui), option(gong-design-system), option(gong-ai4dev), option(gong-ai4devops), option(gong-ai4product)):repo]`

**PR URL:** `INPUT[text:pr_url]`

---

## Problem

{{problem_description}}

---

## Investigation

{{investigation_notes}}

---

## Implementation

### Approach

{{approach}}

### Files touched

- {{file_1}}
- {{file_2}}

---

## Acceptance Criteria

- [ ] {{criterion_1}}
- [ ] {{criterion_2}}
- [ ] {{criterion_3}}

---

## PR

- **Branch:** `{{branch}}`
- **PR:** {{pr_url}}

---

## Notes

{{notes}}

---

## Links & References

- [{{TICKET}}](https://gongio.atlassian.net/browse/{{TICKET}}) — this ticket
- {{additional_links}}

---

## Related Notes

- [[Jira/_dashboard]] — Jira dashboard
- {{related_wikilinks}}
