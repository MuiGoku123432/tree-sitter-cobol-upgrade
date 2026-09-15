---
phase: 04-exec-sql-blocks
plan: 05
subsystem: parser
status: complete
tags: [tree-sitter, cobol, exec-sql, db2, query]
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
  tasks: 4
  static_table_records: 13
  non_comment_assertions: 148
---

# Phase 4 Plan 5: Static SQL Tables and Dynamic Sources Summary

Procedure SQL now exposes every required static DML/DDL table source and target, including MERGE USING and nested sources, while PREPARE exposes one bounded dynamic source that cannot become a table.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 RED | `5e9fee4` | Add failing static SQL forms |
| 1 GREEN | `37b0b51` | Parse static SQL table forms |
| 2 RED | `3b45d1f` | Add failing dynamic-source fixture |
| 2 GREEN | `2bf8c68` | Expose bounded SQL dynamic source |
| 3 | `ca3ab84` | Lock exact static SQL table captures |
| 4 | `7ff8959` | Lock exact SQL dynamic-source capture |

## What Changed

- Added modeled INSERT INTO, UPDATE, DELETE FROM, MERGE INTO/USING, CREATE TABLE, ALTER TABLE, and DROP TABLE forms.
- Preserved nested SELECT bases, duplicate sources, whole qualified names, and sibling aliases.
- Added `sql_prepare_statement` and `sql_dynamic_source` for the bounded PREPARE host-variable contract.
- Added direct `(sql_dynamic_source) @dynamic_source` query capture.
- Extended the fork-local gate with 13 exact static table records and one exact dynamic-source record.
- Kept CTE names, aliases, include members, and dynamic sources out of physical-table output.

## Verification

- Pinned Tree-sitter generation passed.
- All 148 non-comment corpus assertions passed.
- The complete SQL query compiled against the generated parser.
- The exact query gate passed its legacy 47-capture contract, 13 D-04 table ranges, dynamic-source range, CTE subtraction, alias exclusions, and malformed-range fail-closed cases.

## Deviations from Plan

- Invented DDL identifiers use hyphens rather than underscores because this COBOL grammar's `WORD` token does not admit underscores.
- The MERGE predicate uses invented unqualified hyphenated operands so unsupported text remains bounded without introducing an ambiguous dot token that competes with qualified table names.

## Self-Check: PASSED

Grammar-family and fork-local changes are separated by commit, all required forms have exact corpus trees, and all plan gates pass.
