---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-08-29T15:28:58.876Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | test/corpus/comment.txt |  | Pre-existing, out-of-scope: 'comment' corpus fixture fails tree-sitter test (identical failure against both the committed src/parser.c and a freshly-regenerated-with-pinned-0.24.5 one) - a grammar/fixture defect unrelated to VEND-04's refresh mechanism; CI has the tree-sitter test step commented out, consistent with this being long-unverified. Out of scope for Phase 1 (no grammar changes, D-13). | open |  | 2026-08-29T15:28:58.876Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "01",
    "file": "test/corpus/comment.txt",
    "line": null,
    "description": "Pre-existing, out-of-scope: 'comment' corpus fixture fails tree-sitter test (identical failure against both the committed src/parser.c and a freshly-regenerated-with-pinned-0.24.5 one) - a grammar/fixture defect unrelated to VEND-04's refresh mechanism; CI has the tree-sitter test step commented out, consistent with this being long-unverified. Out of scope for Phase 1 (no grammar changes, D-13).",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-29T15:28:58.876Z",
    "resolved_at": null
  }
]
````
