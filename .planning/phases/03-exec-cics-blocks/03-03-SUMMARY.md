---
phase: 03-exec-cics-blocks
plan: 03
subsystem: testing
tags: [go, tree-sitter, cobol, cics, cascade, cross-repo]

requires:
  - phase: 03-exec-cics-blocks
    provides: "03-02's complete EXEC CICS grammar and refreshed forest-shim/cobol parser"
provides:
  - "A blocking gortex CICS-03 cascade gate covering paren-option, no-option, bare-option and multi-line EXEC CICS shapes"
  - "Eight independent parity assertions: paragraph and data-item parity for each of four shapes"
  - "Fail-first proof that the pre-Phase-3 parser fails all four paragraph assertions at 1/20"
affects: [03-04, gortex-cobolprobe]

actuals:
  tokens: 18000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Observe new recovery cases before turning them into hard assertions"
    - "Compare every case independently to one immutable clean control"

key-files:
  created: []
  modified:
    - "~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go"

key-decisions:
  - "All four representative EXEC CICS shapes are hard gates at both paragraph and data-item parity."
  - "SCHEMA SECTION remains logged-only because locked decision D3 assigns it to preprocessing outside this grammar repo."
  - "The WORKING-STORAGE IDMS case remains a negative control asserting an error, not recovery parity."

patterns-established:
  - "Fail-first gate proof: temporarily measure with the prior parser, observe assertion failure, restore current parser, then prove GREEN."

requirements-completed: [CICS-03, CICS-06]

coverage:
  - id: D1
    description: "Four representative EXEC CICS shapes recover all 20 paragraphs and all 20 data items"
    requirement: CICS-03
    verification:
      - kind: integration
        ref: "go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v -count=2"
        status: pass
    human_judgment: false
  - id: D2
    description: "The cascade gate is fail-first: the pre-Phase-3 parser fails all four paragraph assertions at 1/20"
    requirement: CICS-03
    verification:
      - kind: integration
        ref: "TestErrorCascade with forest-shim/cobol temporarily restored from d29af7a"
        status: pass
    human_judgment: false
  - id: D3
    description: "The clean control remains first, SCHEMA SECTION remains unasserted, and the WORKING-STORAGE negative control remains intact"
    requirement: CICS-06
    verification:
      - kind: unit
        ref: "internal/parser/forest/cobolprobe/cascade_test.go"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-09-11
status: complete
---

# Phase 3 Plan 03: EXEC CICS Cascade Gate Summary

**CICS-03 is now a real blocking gate in gortex: all four representative EXEC CICS shapes must preserve 20/20 paragraphs and 20/20 data items, while the pre-Phase-3 parser demonstrably fails every paragraph assertion at 1/20.**

## Accomplishments

- Added the D-28 no-option, bare-option and multi-line shapes alongside the existing paren-option case, all injected after paragraph 1 against the same immutable clean control.
- Observed all four shapes logging 20/20 paragraph and 20/20 data-item recovery before introducing assertions.
- Added eight hard assertions: one paragraph and one data-item assertion for each shape.
- Preserved locked boundaries: SCHEMA SECTION remains logged-only under D3; the WORKING-STORAGE IDMS case remains a must-still-fail negative control.
- Proved determinism with `-count=2`: both runs returned identical counts.

## Task Commits

Commits live in `~/repos/mine/GoApps/gortex`:

1. **Task 1: inject and observe four D-28 shapes** — `99231882`
2. **Task 2: enforce blocking parity assertions** — `bdb98dd1`

## RED/GREEN Evidence

| Parser | Paren option | No option | Bare option | Multi-line | Data items |
|--------|--------------|-----------|-------------|------------|------------|
| Pre-Phase-3 (`d29af7a`) | 1/20 | 1/20 | 1/20 | 1/20 | 20/20 all |
| Current Phase 3 shim | 20/20 | 20/20 | 20/20 | 20/20 | 20/20 all |

With the pre-Phase-3 shim, all four paragraph assertions failed and `go test` exited non-zero. After restoring the current shim, the test returned green. This proves the assertions test the grammar change rather than merely restating the current output.

## Verification

- `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v -count=2` — PASS, identical counts in both runs.
- Four paragraph assertions present (`pa2`, `pa6`, `pa7`, `pa8`).
- Four data-item assertions present (`d2`, `d6`, `d7`, `d8`).
- Zero SCHEMA SECTION parity assertions.
- WORKING-STORAGE negative control still asserts `e5 != 0`.
- `countAll` unchanged.
- Gortex source diff confined to `internal/parser/forest/cobolprobe/cascade_test.go`; unrelated `.planning/config.json` changes remain unstaged.

## Deviations

None. The plan's two-step observe-then-assert sequence was followed exactly.

## Prohibition Compliance

- No assertion was weakened or scope-narrowed. Every shape reached full parity before the gate was added.
- Every injected command, map and mapset name is invented and neutral. No estate-derived identifier appears in gortex.
