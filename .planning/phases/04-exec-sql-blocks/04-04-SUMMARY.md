---
phase: 04-exec-sql-blocks
plan: 04
subsystem: parser
status: complete
tags: [tree-sitter, cobol, exec-sql, include, data-division]
key-files:
  created: []
  modified:
    - grammar.js
    - test/corpus/exec_sql.txt
    - queries/sql.scm
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - run_sql_query_capture.sh
requirements-completed: [SQL-02, SQL-03, SQL-05, SQL-07]
metrics:
  tasks: 3
  commits: 5
  exact_captures: 47
---

# Phase 4 Plan 4: DATA DIVISION SQL Directives Summary

DATA DIVISION declaration markers and generic SQL includes now parse as named siblings without consuming adjacent COBOL data descriptions. Generic include members are directly queryable and are excluded from physical-table results.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 RED | `7e0255f` | Add failing declaration marker fixtures |
| 1 GREEN | `4bc02fa` | Parse declaration section markers |
| 2 | `dad52d3` | Add generic SQL include grammar and direct query capture |
| 3 | `648fd4b` | Lock exact include captures in the fork-local gate |

## What Changed

- Added separate `exec_sql_declare_section` markers around intact data descriptions in working-storage and shared record lists.
- Added generic `exec_sql_include` and `sql_include_name` nodes in DATA and PROCEDURE placements.
- Added direct `(sql_include_name) @include` query capture.
- Extended the exact query gate from 45 to 47 captures with SQLCA and TEAM-MEMBER text and ranges.
- Excluded include names from statement-scoped table assignment and physical-table output.

## Verification

- `tree-sitter generate` passed.
- All 145 non-comment corpus assertions passed, including declaration and include fixtures.
- `tree-sitter query queries/sql.scm test/corpus/exec_sql.txt` compiled successfully.
- `sh run_sql_query_capture.sh` passed all 47 exact capture and negative-table checks.
- `sh -n run_sql_query_capture.sh` passed.

## Deviations from Plan

- The executor subagent was interrupted twice. Work was recovered from committed and uncommitted state and completed inline without resetting any plan-owned changes.
- The Tree-sitter CLI emitted its existing package migration and parser-directory warnings while returning success.

## Self-Check: PASSED

All plan artifacts exist, grammar-family and fork-local changes are in separate commits, and all plan-specific gates pass.
