---
phase: 04-exec-sql-blocks
plan: 07
subsystem: downstream-validation
status: complete
tags: [gortex, cobol, exec-sql, cascade, cross-repo]
key-files:
  created: []
  modified:
    - /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go
requirements-completed: [SQL-04, SQL-05, SQL-07]
metrics:
  tasks: 2
  sql_assertions: 4
  green_runs: 2
---

# Phase 4 Plan 7: Gortex SQL Cascade Contract Summary

Gortex now blocks regressions where procedure or DATA DIVISION EXEC SQL recovery loses downstream COBOL paragraphs or data items.

## Cross-Repository Commit

| Repository | Commit | Description |
|------------|--------|-------------|
| gortex | `861edf7c` | Enforce EXEC SQL cascade parity in `TestErrorCascade` |

## Evidence

- The procedure SQL observation preserved 20/20 paragraphs and 20/20 data items twice.
- The DATA DIVISION SQL observation preserved 20/20 paragraphs and 20/20 data items twice.
- Four independent assertions compare each count directly with the immutable clean control.
- RED with `GOWORK=off` and upstream forest v1.9.1:
  - Procedure SQL preserved 1/20 paragraphs.
  - DATA DIVISION SQL preserved 1/20 data items.
- GREEN with the refreshed local shim passed `TestErrorCascade -count=2` before and after commit.
- Commit `861edf7c` changes only `internal/parser/forest/cobolprobe/cascade_test.go`.

## Deviations from Plan

- RED used `GOWORK=off` to select the immutable upstream forest v1.9.1 module rather than physically restoring shim files. This provides the required pre-Phase-4 parser comparison without mutating delivery artifacts.
- Work was committed on gortex branch `test/phase4-sql-cascade-mainwt` because feature work must not be committed directly to `main`.

## Self-Check: PASSED

The downstream contract has deterministic RED/GREEN evidence, four independent parity assertions, and a one-path gortex commit.
