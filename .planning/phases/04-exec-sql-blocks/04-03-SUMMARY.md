---
phase: 04-exec-sql-blocks
plan: 03
subsystem: testing
tags: [shell, differential, exec-sql, corpus-selection, tdd]
requires:
  - phase: 02-idms-dml-statement-nodes
    provides: "Parser-cache-safe ACCEPT differential with repository-root output refusal"
  - phase: 04-exec-sql-blocks
    provides: "Named EXEC SQL and collision-sensitive COBOL nodes to measure"
provides:
  - "Caller-selected node regex propagation through isolated baseline/current helpers"
  - "Distinct source-text prefilter with explicit full-walk mode"
  - "Conditional estate denominator gate for custom differential selections"
  - "Fail-closed validation for empty and malformed run inputs"
affects: [04-04, 04-05, 04-06, differential-validation]
actuals:
  tokens: 8373
  tasks: 3
  commits: 7
tech-stack:
  added: []
  patterns:
    - "Separate node-type matching from source-text path selection"
    - "Retain recorded estate constants only for the historical default selection"
    - "Compile isolated baseline/current helpers to avoid tree-sitter parser-cache contamination"
key-files:
  created: []
  modified:
    - run_accept_differential.sh
    - run_accept_differential_selftest.sh
key-decisions:
  - "Custom selection is active when either the node regex or source-text prefilter differs from its ACCEPT default"
  - "The estate branch preserves structural 3781/1369 checks for every run, while the 2391 statement gate applies only to the default ACCEPT selection"
  - "The literal --no-prefilter mode selects every source file discovered by the existing extension filter"
requirements-completed: [SQL-05, SQL-06, SQL-07]
coverage:
  - id: D1
    description: "A caller-selected SQL/collision node regex reaches both isolated helpers and detects a changed record"
    requirement: SQL-07
    verification:
      - kind: integration
        ref: "sh run_accept_differential_selftest.sh#Case 7"
        status: pass
    human_judgment: false
  - id: D2
    description: "Custom text filtering and full-walk mode select ACCEPT-free collision files without weakening default ACCEPT selection"
    requirement: SQL-06
    verification:
      - kind: integration
        ref: "sh run_accept_differential_selftest.sh#Cases 8-11 and 16"
        status: pass
    human_judgment: false
  - id: D3
    description: "Omitted arguments retain ACCEPT defaults while empty and malformed inputs fail closed"
    requirement: SQL-07
    verification:
      - kind: integration
        ref: "sh run_accept_differential_selftest.sh#Cases 12-15"
        status: pass
      - kind: other
        ref: "sh -n run_accept_differential.sh && sh -n run_accept_differential_selftest.sh"
        status: pass
    human_judgment: false
duration: 11min
completed: 2026-09-14
status: complete
---

# Phase 4 Plan 03: Reusable SQL Differential Parameterization Summary

**The parser-cache-safe differential now measures caller-selected SQL and collision nodes over an independently selected source population while preserving the historical ACCEPT defaults.**

## Performance

- **Duration:** 11 min after checkpoint approval
- **Started:** 2026-09-14T03:06:56Z
- **Completed:** 2026-09-14T03:17:19Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Threaded a bare caller node alternation through run orchestration, both isolated helpers, anchored helper invocation, and reporting.
- Added a separate source-text ERE plus `--no-prefilter`, with real-selector proofs that an ACCEPT-free SQL collision file is retained.
- Kept the estate branch's structural 3781/1369 population checks, limited the 2391 ACCEPT-statement assertion to default selection, and reported measured custom denominators.
- Preserved omitted ACCEPT defaults and added fail-closed checks for empty node regexes, empty text filters, malformed EREs, zero files, and zero selections.

## Task Commits

1. **Task 1 RED: custom-regex run proof** -- `6198696` (`test(04-03): add failing custom regex run proof`)
2. **Task 1 GREEN: node-regex propagation** -- `80a2eb7` (`feat(04-03): parameterize run node regex`)
3. **Task 2 RED: corpus-selection proofs** -- `331ba39` (`test(04-03): add failing corpus selection proofs`)
4. **Task 2 GREEN: text-prefilter and estate behavior** -- `65f7c46` (`feat(04-03): parameterize corpus path selection`)
5. **Task 3 RED: default and invalid-input proofs** -- `2da85af` (`test(04-03): add failing run input validation proofs`)
6. **Task 3 GREEN: fail-closed validation** -- `0f46a8d` (`feat(04-03): validate differential run inputs`)
7. **Task 3 acceptance proof: default estate gate** -- `d0bb76a` (`test(04-03): prove default estate denominator gate`)

## Files Created/Modified

- `run_accept_differential.sh` -- Supports independent node and source-text selection, full walks, conditional estate denominators, and validated inputs.
- `run_accept_differential_selftest.sh` -- Proves custom/default selection behavior, estate branching, regression detection, and invalid-input refusal using scratch-only synthetic fixtures.

## Decisions Made

- Custom selection is determined independently from the two optional arguments so a custom node set cannot silently inherit the ACCEPT-only path population.
- Default estate selection retains its specialized fixed-format `^\s*ACCEPT` statement counter and exact recorded gate; custom estate selection uses the caller ERE or full walk and records observed counts.
- No SQL-specific walker was introduced; all paths continue through the existing reusable differential and isolated compiled helpers.

## Verification

- `sh run_accept_differential_selftest.sh` -- pass, 16 cases.
- `sh -n run_accept_differential.sh` -- pass.
- `sh -n run_accept_differential_selftest.sh` -- pass.
- Existing six synthetic comparison cases remain unchanged and pass.
- Scratch inventories and generated corpus fixtures remain under `mktemp` directories outside tracked repository paths.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None after the approved Task 1 checkpoint. The continuation re-verified commits `6198696` and `80a2eb7` and reran their self-test before Task 2.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 4 can invoke the established differential with SQL-relevant node types and either an explicit source-text prefilter or a complete source walk.
- SQL-05 remains retired; this plan enables trustworthy collision evidence and does not introduce a substitute recall claim.

## Self-Check: PASSED

- `run_accept_differential.sh` and `run_accept_differential_selftest.sh` exist.
- All seven `04-03` task commits are present in git history.
- All task and plan verification commands pass.

---
*Phase: 04-exec-sql-blocks*
*Completed: 2026-09-14*
