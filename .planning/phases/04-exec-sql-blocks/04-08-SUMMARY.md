---
phase: 04-exec-sql-blocks
plan: 08
subsystem: verification
status: complete
tags: [exec-sql, census, differential, estate, nist]
key-files:
  created:
    - run_sql_tail_census.sh
    - docs/sql-tail-census.md
  modified:
    - grammar.js
    - test/corpus/exec_sql.txt
    - test/corpus/exec_cics.txt
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - forest-shim/cobol/parser.c
    - forest-shim/cobol/grammar.json
requirements-completed: [SQL-01, SQL-03, SQL-04, SQL-05, SQL-06, SQL-07]
metrics:
  tasks: 3
  corpus_assertions: 149
  dcc_selected_files: 533
  estate_selected_files: 1201
  estate_new_records: 244
  nist_success: 371
  nist_fail: 0
  nist_skip: 11
---

# Phase 4 Plan 8: SQL Census and Closing Evidence Summary

Phase 4 now has aggregate-only OCESQL and estate census evidence, explicit DCC and estate collision differentials, and green parser, query, shim, cascade, and NIST closing gates.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 support | `b5ef19b` | Close tracked-corpus SQL census grammar gaps |
| 1 | `2865908` | Add aggregate SQL tail census and OCESQL report |
| 2 support | `9cfc528` | Preserve qualified SQL tail references |
| 2 | `0a1d270` | Reconcile aggregate estate SQL census |
| 2 evidence | `3d27099` | Record DCC and estate differential evidence |
| 3 shim | `3a74bbd` | Refresh final SQL forest shim |
| 3 evidence | `76d721c` | Record closing regression evidence |

## Census Results

- OCESQL: every independently expected physical table reconciles with the D-18 query result in every category.
- Estate: SELECT 81/81, INSERT 7/7, UPDATE 19/19, DELETE 7/7, OTHER 68/68 physical tables.
- SQL-05 remains retired. Census data is accounting evidence, not replacement recall.
- Scratch wrappers isolate each EXEC SQL block, normalize fixed-format sequence areas, and persist aggregate counts only.
- The self-test proves a deliberately missing table capture fails reconciliation.

## Differential Results

- DCC selected 533 of 606 files with 3,779 records before and after; reclassified 0, converted 0, new 0, timeouts 0.
- Estate entered the dedicated selector and measured 1,201 selected files and 17,801 matching source-text statements.
- Estate produced 9,871 baseline and 10,115 current records; reclassified 0, converted 0, new 244, timeouts 0.
- Both calls supplied the explicit SQL/collision node regex and text prefilter; neither used the ACCEPT default selector.

## Closing Gates

- Generation passed.
- All 149 non-comment corpus assertions passed.
- Exact SQL query capture gate passed.
- Forest shim refresh, drift check, and Go smoke build passed.
- Gortex `TestErrorCascade -count=2` passed against the final shim.
- `skip_tests.txt` remains the exact ordered 11-name allowlist and is unchanged from the pre-Phase-4 baseline.
- NIST exited 0 with final line `382 tests. (Success: 371, Fail: 0, Skip: 11)`.

## Deviations from Plan

- Census-discovered grammar gaps were fixed before evidence was accepted: underscore identifiers, cursor SELECTs, DDL modifiers, qualified host/expression references, and bounded punctuation.
- Census execution batches isolated scratch files into bounded Tree-sitter query invocations to avoid process-start overhead while retaining per-block isolation.
- NIST and long differentials ran through detached Python wrappers with separate status files so OpenCode remained responsive and scratch cleanup was preserved.

## Self-Check: PASSED

All three tasks are complete, every closing gate is green, no estate source content is retained, and fork-local changes are separated by commit family.
