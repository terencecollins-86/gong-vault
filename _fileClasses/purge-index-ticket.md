---
limit: 20
mapWithTag: false
icon: database
tagNames:
extends:
version: "1.0"
excludes:
fields:
  - name: jira
    type: Input
    options: {}
    path: ""
    id: jira_key
  - name: jira_url
    type: URL
    options: {}
    path: ""
    id: jira_url
  - name: parent_epic
    type: Input
    options: {}
    path: ""
    id: parent_epic
  - name: workflow_status
    type: Select
    options:
      valuesList:
        "0": todo
        "1": doing
        "2": pr
        "3": done
    path: ""
    id: workflow_status
  - name: pr_url
    type: URL
    options: {}
    path: ""
    id: pr_url
  - name: repo
    type: Select
    options:
      valuesList:
        "0": honeyfy
        "1": gong-purging
        "2": gong-recorders
        "3": gong-data-capture
    path: ""
    id: repo
  - name: table
    type: Input
    options: {}
    path: ""
    id: table
  - name: created
    type: Date
    options:
      dateFormat: YYYY-MM-DD
      defaultInsertAsLink: "false"
    path: ""
    id: created
  - name: status
    type: Input
    options: {}
    path: ""
    id: status_text
  - name: type
    type: Select
    options:
      valuesList:
        "0": engineering
        "1": runbook
        "2": research
    path: ""
    id: type
---

# purge-index-ticket — fileClass

FileClass schema for Jira purge-index tickets. Enforces typed frontmatter on notes that declare `fileClass: purge-index-ticket`.

## Fields

| Field | Type | Enum values |
|---|---|---|
| `jira` | Input | free text (e.g. `GONG-138866`) |
| `jira_url` | URL | any URL |
| `parent_epic` | Input | free text (e.g. `GONG-131727`) |
| `workflow_status` | **Select** | **`todo` / `doing` / `pr` / `done`** |
| `pr_url` | URL | any URL (empty OK) |
| `repo` | **Select** | `honeyfy` / `gong-purging` / `gong-recorders` / `gong-data-capture` |
| `table` | Input | free text (e.g. `public.stop_recording_request`) |
| `created` | Date | `YYYY-MM-DD` |
| `status` | Input | Jira status text (free — Jira mirrors this) |
| `type` | Select | `engineering` / `runbook` / `research` |

## Related

- [[_templates/purge-index-ticket]] — template that uses this schema
- [[Jira/_dashboard]] — Dataview dashboard driven by `workflow_status`
