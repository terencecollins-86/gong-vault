---
limit: 20
mapWithTag: false
icon: ticket
tagNames:
extends:
version: "1.0"
excludes:
fields:
  - name: jira
    type: Input
    options: {}
    path: ""
    id: jt_jira
  - name: jira_url
    type: URL
    options: {}
    path: ""
    id: jt_jira_url
  - name: parent_epic
    type: Input
    options: {}
    path: ""
    id: jt_parent_epic
  - name: type
    type: Select
    options:
      valuesList:
        "0": engineering
        "1": bug
        "2": feature
        "3": spike
        "4": refactor
        "5": chore
    path: ""
    id: jt_type
  - name: workflow_status
    type: Select
    options:
      valuesList:
        "0": todo
        "1": doing
        "2": pr
        "3": done
    path: ""
    id: jt_workflow_status
  - name: priority
    type: Select
    options:
      valuesList:
        "0": P0
        "1": P0.5
        "2": P1
        "3": P2
        "4": P3
    path: ""
    id: jt_priority
  - name: assignee
    type: Input
    options: {}
    path: ""
    id: jt_assignee
  - name: pr_url
    type: URL
    options: {}
    path: ""
    id: jt_pr_url
  - name: repo
    type: Select
    options:
      valuesList:
        "0": honeyfy
        "1": gong-purging
        "2": gong-recorders
        "3": gong-data-capture
        "4": gong-ingestion
        "5": gong-web-ui
        "6": gong-design-system
        "7": gong-ai4dev
        "8": gong-ai4devops
        "9": gong-ai4product
    path: ""
    id: jt_repo
  - name: created
    type: Date
    options:
      dateFormat: YYYY-MM-DD
      defaultInsertAsLink: "false"
    path: ""
    id: jt_created
  - name: status
    type: Input
    options: {}
    path: ""
    id: jt_status
---

# jira-ticket — fileClass

Generic schema for Jira tickets tracked in the vault. Used by any engineering, bug, feature, spike, refactor, or chore ticket.

## Fields

| Field | Type | Enum values |
|---|---|---|
| `jira` | Input | free text (e.g. `GONG-138866`) |
| `jira_url` | URL | any URL |
| `parent_epic` | Input | free text (e.g. `GONG-131727`) — blank for standalone tickets |
| `type` | **Select** | `engineering` / `bug` / `feature` / `spike` / `refactor` / `chore` |
| `workflow_status` | **Select** | **`todo` / `doing` / `pr` / `done`** |
| `priority` | **Select** | `P0` / `P0.5` / `P1` / `P2` / `P3` |
| `assignee` | Input | free text |
| `pr_url` | URL | any URL (empty OK) |
| `repo` | **Select** | `honeyfy` / `gong-purging` / `gong-recorders` / `gong-data-capture` / `gong-ingestion` / `gong-web-ui` / `gong-design-system` / `gong-ai4dev` / `gong-ai4devops` / `gong-ai4product` |
| `created` | Date | `YYYY-MM-DD` |
| `status` | Input | Jira status text (free — mirrors Jira) |

Notes referencing this fileClass may also carry ticket-specific extras (e.g. `table:` on purge-index tickets). Metadata Menu will render them as untyped fields — safe to keep.

## Related

- [[_templates/jira-ticket]] — template that uses this schema
- [[Jira/_dashboard]] — Dataview dashboard driven by `workflow_status`
