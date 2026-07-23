---
limit: 20
mapWithTag: false
icon: file-code
tagNames:
extends:
version: "1.0"
excludes:
fields:
  - name: title
    type: Input
    options: {}
    path: ""
    id: en_title
  - name: type
    type: Select
    options:
      valuesList:
        "0": engineering
        "1": runbook
        "2": research
        "3": architecture
        "4": meeting
        "5": reference
    path: ""
    id: en_type
  - name: status
    type: Select
    options:
      valuesList:
        "0": draft
        "1": active
        "2": archived
    path: ""
    id: en_status
  - name: created
    type: Date
    options:
      dateFormat: YYYY-MM-DD
      defaultInsertAsLink: "false"
    path: ""
    id: en_created
  - name: tags
    type: MultiSelect
    options:
      valuesList: {}
    path: ""
    id: en_tags
  - name: aliases
    type: MultiSelect
    options:
      valuesList: {}
    path: ""
    id: en_aliases
---

# engineering-note — fileClass

Base schema for engineering notes in the vault. Use this fileClass on any note under `Work/Engineering/`, `Subsystems/`, or free-standing engineering docs.

## Fields

| Field | Type | Enum values |
|---|---|---|
| `title` | Input | free text (usually matches H1 / filename) |
| `type` | **Select** | `engineering` / `runbook` / `research` / `architecture` / `meeting` / `reference` |
| `status` | **Select** | `draft` / `active` / `archived` |
| `created` | Date | `YYYY-MM-DD` |
| `tags` | MultiSelect | free — no controlled list |
| `aliases` | MultiSelect | free — used by Obsidian aliases |

## Extended by

- [[_fileClasses/runbook]] — operational runbook subtype
- [[_fileClasses/purge-index-ticket]] — Jira ticket subtype (currently free-standing)

## Related

- [[Work/_dashboard]] — Dataview dashboard for engineering work
