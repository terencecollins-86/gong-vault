---
limit: 20
mapWithTag: false
icon: book-open-check
tagNames:
extends: engineering-note
version: "1.0"
excludes:
fields:
  - name: subsystem
    type: Input
    options: {}
    path: ""
    id: rb_subsystem
  - name: env
    type: MultiSelect
    options:
      valuesList:
        "0": local
        "1": dev
        "2": staging
        "3": prod
    path: ""
    id: rb_env
  - name: destructive
    type: Boolean
    options: {}
    path: ""
    id: rb_destructive
  - name: last_verified
    type: Date
    options:
      dateFormat: YYYY-MM-DD
      defaultInsertAsLink: "false"
    path: ""
    id: rb_last_verified
---

# runbook — fileClass

Operational runbook subtype. Extends [[_fileClasses/engineering-note]] — inherits `title`, `type`, `status`, `created`, `tags`, `aliases`. When you apply `fileClass: runbook`, `type` defaults to `runbook`.

## Additional fields

| Field | Type | Enum values |
|---|---|---|
| `subsystem` | Input | free text (e.g. `telephony`, `calendar-ingestion`) |
| `env` | **MultiSelect** | `local` / `dev` / `staging` / `prod` |
| `destructive` | Boolean | `true` / `false` — flag if the runbook mutates prod state |
| `last_verified` | Date | last time the steps were re-run end-to-end |

## Related

- [[_fileClasses/engineering-note]] — parent schema
- [[Work/Engineering/Runbooks]] — where these notes live
