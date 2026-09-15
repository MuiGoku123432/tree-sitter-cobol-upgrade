---
phase: 04-exec-sql-blocks
plan: 02
subsystem: testing
tags: [tree-sitter, cobol, exec-sql, cte, shell, git-hooks]

requires:
  - phase: 04-exec-sql-blocks
    provides: "04-01 bounded EXEC SQL grammar and predicate-free raw capture contract"
provides:
  - "Executable exact SQL capture gate with statement-scoped CTE subtraction"
  - "Exact D-17 raw capture text, range, count, multiplicity, and source-order assertions"
  - "Additive fork-local hook classification for every root-level run_*.sh/run_*.c gate"
affects: [04-04, 04-05, 04-08, fork-hygiene]

actuals:
  tokens: 3522
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Lexicographic row-column containment with unique smallest enclosing statement assignment"
    - "Statement-local CTE definition subtraction from raw table captures"
    - "Ordered TSV golden contract for exact tree-sitter query output"

key-files:
  created:
    - run_sql_query_capture.sh
  modified:
    - .githooks/commit-separability.sh

key-decisions:
  - "D-18 role ownership is determined by the unique smallest enclosing statement range before CTE subtraction"
  - "D-17 is locked as one ordered exact TSV stream so text, spans, counts, multiplicity, and order fail together"
  - "FORKLOCAL_PATH_RE retains the broad run_accept_differential prefix and additively covers digit-bearing root run_*.sh and run_*.c paths"

requirements-completed: [SQL-03, SQL-05, SQL-07]

coverage:
  - id: D1
    description: "Exact statement-scoped physical-table results exclude only same-statement CTE names"
    requirement: SQL-03
    verification:
      - kind: integration
        ref: "sh run_sql_query_capture.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Raw SQL captures are locked by exact text, row-column range, count, multiplicity, and source order"
    requirement: SQL-03
    verification:
      - kind: integration
        ref: "run_sql_query_capture.sh#45-capture ordered TSV contract"
        status: pass
    human_judgment: false
  - id: D3
    description: "Commit separability rejects grammar commits mixed with current and planned root-level SQL gates"
    requirement: SQL-07
    verification:
      - kind: integration
        ref: ".githooks/commit-separability.sh synthetic mixed-commit range"
        status: pass
    human_judgment: false

duration: 9h 38m
completed: 2026-09-14
status: complete
---

# Phase 4 Plan 02: Exact SQL Capture Gate Summary

**A fork-local gate now converts raw EXEC SQL captures into exact statement-scoped physical tables and rejects capture drift or mixed grammar/tooling commits.**

## Performance

- **Duration:** 9h 38m
- **Started:** 2026-09-14T03:20:38Z
- **Completed:** 2026-09-14T12:58:48Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Added a re-runnable SQL query gate that parses tree-sitter-cli 0.24.5 row-column ranges, assigns each role to one smallest enclosing statement, and fails closed on malformed scope geometry.
- Proved exact physical-table sets for CTE-only, CTE-plus-JOIN, outer CTE-plus-physical, adjacent same-name CTE, nested source, boundary, dynamic-host-variable, and utility-statement cases.
- Locked all 45 currently emitted raw captures by exact text, start/end positions, multiplicity, count, and source order.
- Widened commit separability additively so root-level SQL gates and existing digit-bearing/C helper paths remain fork-local.

## Task Commits

1. **Task 1: Compute one exact physical-table result from raw SQL captures** - `dd933b1` (`feat`)
2. **Task 2: Enforce exact capture positions, multiplicity, order, and negative roles** - `c77276e` (`test`)
3. **Task 3: Widen the hook's fork-local path family** - `4144188` (`fix`)

## Files Created/Modified

- `run_sql_query_capture.sh` - Exact raw-capture parser, containment analyzer, CTE subtraction, golden stream, and negative scope tests.
- `.githooks/commit-separability.sh` - Additive root-level `run_*.sh` and `run_*.c` fork-local classification.

## Verification

- `sh run_sql_query_capture.sh` - PASS, including all exact physical sets, 45 raw captures, four malformed-range failures, and boundary containment.
- `sh -n run_sql_query_capture.sh` - PASS.
- `sh -n .githooks/commit-separability.sh` - PASS.
- Synthetic mixed `queries/sql.scm` plus `run_sql_query_capture.sh` commit - PASS as a negative test: hook exits nonzero and names both paths.
- Synthetic `grammar.js` plus `run_accept_differential_helper.c` commit - PASS as a negative test before and after widening.
- Synthetic fork-local-only commit - PASS.
- `node_modules/tree-sitter-cli/tree-sitter test -e '^comment$'` - PASS, 142 corpus assertions.
- Gortex review over the three task commits - REVIEW with zero findings; shell test coverage is externally verified by the executable gates.

## Decisions Made

- Compared the complete ordered normalized capture stream rather than maintaining separate fragile count and position checks.
- Reconstructed multiline capture text from the exact source range because tree-sitter-cli 0.24.5 omits inline text for multiline captures.
- Kept SQL-05 retired. No recall command or substitute recall metric was introduced.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Gortex has no Bash LSP provider, so diagnostics reported that limitation. Executable syntax, behavior, corpus, synthetic hook tests, contract analysis, and review supplied verification instead.

## Known Stubs

None. Empty shell/AWK initialization values are operational state, not UI or unwired-data stubs.

## Threat Model Verification

- T-04-04: CTE subtraction is statement-local and adjacent same-name statements are independently asserted.
- T-04-05: invented fixtures and all query/capture artifacts remain under `.sql-query-scratch`, excluded through `.git/info/exclude`; estate content is never emitted.
- T-04-16: the previously passing mixed SQL commit now fails while existing helper-C coverage remains intact.
- No unplanned network, authentication, file-access, or schema trust boundary was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 04-04 can extend the ordered role contract with include captures.
- 04-05 can add complete D-04 static source and dynamic-source expectations without changing statement assignment or CTE filtering.
- 04-08's `run_sql_tail_census.sh` is already classified as fork-local by the widened hook.

## Self-Check: PASSED

- `run_sql_query_capture.sh` exists and is executable.
- `.githooks/commit-separability.sh` contains the additive root-level run gate pattern.
- Task commits `dd933b1`, `c77276e`, and `4144188` exist and each contains only its planned fork-local path.
- All task and plan verification commands passed.

---
*Phase: 04-exec-sql-blocks*
*Completed: 2026-09-14*
