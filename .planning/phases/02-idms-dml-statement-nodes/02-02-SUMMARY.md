---
phase: 02-idms-dml-statement-nodes
plan: 02
subsystem: testing
status: complete
tags: [tree-sitter, cobol, idms, shell, github-actions, regression-gates]

requires:
  - phase: 01-delivery-pipe-measurement-baseline
    provides: estate-leak guard, commit-separability hook, and pinned tree-sitter CLI
  - phase: 02-idms-dml-statement-nodes
    provides: navigation statement nodes and idms_unparsed_tail from plan 02-01
provides:
  - Re-runnable ACCEPT before/after inventory and comparison gate
  - Six-case proof that clean reclassifications fail while trailing-error conversions pass
  - Main-only CI enforcement for every non-comment corpus fixture
  - Complete grammar and fork-local path-family coverage in commit-separability checks
affects: [02-04-accept-containment, 02-06-tail-census, phase-03, phase-04, fork-hygiene]

actuals:
  tokens: 8517
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - Stable TSV inventories keyed by relative path and start position
    - Per-commit path-family enforcement with explicit zero-check reporting
    - Fork-local GitHub Actions gate beside untouched upstream workflows

key-files:
  created:
    - run_accept_differential.sh
    - run_accept_differential_selftest.sh
    - .github/workflows/fork-checks.yml
  modified:
    - .githooks/commit-separability.sh

key-decisions:
  - "Inventory rows use relative-path, startRow,startCol, node-type, and clean|trailing_error fields so later ACCEPT work can distinguish regression from intended conversion."
  - "tree-sitter error-bearing trees remain inventory inputs: their non-zero parse status is counted separately, while their ERROR nodes supply the trailing_error qualifier."
  - "The differential refuses to delete an existing DIFF_TMP worktree path and cleans only scratch directories it creates itself."
  - "The CI gate excludes only the long-standing comment fixture and carries its upstream commit plus WINDOWS.md debt pointer inline."

patterns-established:
  - "Differential proof: a passing gate is meaningful only after the synthetic failing direction has exited 1 and named the offending record."
  - "Separability proof: evaluate and report each commit independently, including empty commits and zero-commit ranges."

requirements-completed: [IDMS-03, IDMS-06, IDMS-07]

coverage:
  - id: D1
    description: ACCEPT inventories distinguish clean nodes from same-row trailing-error conversions and fail on standard-COBOL reclassification.
    requirement: IDMS-03
    verification:
      - kind: integration
        ref: "bash run_accept_differential_selftest.sh"
        status: pass
      - kind: other
        ref: "manual synthetic compare: identical exit 0; reclassified exit 1"
        status: pass
    human_judgment: false
  - id: D2
    description: Snapshot output is stable, regex-selectable, and refused inside the repository working tree.
    requirement: IDMS-07
    verification:
      - kind: integration
        ref: "snapshot idms_unparsed_tail/default-regex and repository-output refusal smoke checks"
        status: pass
      - kind: integration
        ref: "run subcommand smoke check against baseline 5ab7920"
        status: pass
    human_judgment: false
  - id: D3
    description: Pushes to main run generated-parser corpus tests while retaining the annotated pre-existing comment exclusion.
    requirement: IDMS-06
    verification:
      - kind: integration
        ref: "node_modules/.bin/tree-sitter test -e '^comment$'"
        status: pass
      - kind: other
        ref: "fork-checks.yml trigger, permission, annotation, and command assertions"
        status: pass
    human_judgment: false
  - id: D4
    description: Commit separability recognizes every Phase 2 grammar and fork-local path and reports ordering and empty-input edges explicitly.
    requirement: IDMS-07
    verification:
      - kind: integration
        ref: "throwaway git repository red-then-green separability matrix"
        status: pass
      - kind: integration
        ref: "bash .githooks/estate-guard-selftest.sh"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-08-31
---

# Phase 2 Plan 2: ACCEPT Differential and Fork-Local Gates Summary

**A fail-proven ACCEPT inventory differ, main-only corpus CI gate, and per-commit fork-separability enforcement now protect the remaining IDMS grammar work.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-31T00:47:02Z
- **Completed:** 2026-08-31T01:04:11Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `snapshot`, `compare`, and `run` commands that inventory ACCEPT-family nodes without permitting corpus-derived output inside the repository.
- Proved the differ discriminates all six required behaviors, including clean reclassification, intended trailing-error conversion, disappearance, new recognition, and empty inventories.
- Added a least-privilege `main`-only workflow that generates the parser and runs the 12 non-`comment` corpus fixtures, with the exclusion debt documented where it is enforced.
- Closed the FORK-03 blind spots for `queries/`, `test/idms/`, the differential scripts, and the exact fork-local workflow, including explicit empty-input and per-commit ordering reports.

## Task Commits

Each task was committed atomically:

1. **Task 1: The ACCEPT before/after differential** -- `0a7f2cd` (`feat`)
2. **Task 2: Fork-local CI corpus gate and FORK-03 path-family closure** -- `431aa71` (`ci`)

Additional correctness commit:

- `5f89064` (`fix`) -- preserve caller-owned differential scratch data and clean only self-created scratch directories.

## Files Created/Modified

- `run_accept_differential.sh` -- Creates stable ACCEPT/tail inventories, compares before/after classifications, and orchestrates baseline/current snapshots.
- `run_accept_differential_selftest.sh` -- Exercises exactly six synthetic comparison cases without corpus or grammar dependencies.
- `.github/workflows/fork-checks.yml` -- Runs generated-parser corpus fixtures on pushes to `main` and manual dispatch with read-only permissions.
- `.githooks/commit-separability.sh` -- Classifies all Phase 2 paths and reports every checked commit, empty commit, and zero-commit range explicitly.

## Differential Evidence

### Inventory contract

`snapshot` emits one sorted tab-separated row per selected node:

```text
relative/path.cbl<TAB>startRow,startCol<TAB>node_type<TAB>clean|trailing_error
```

The default node regex is `accept_statement|idms_accept_statement`; the optional third argument was proven with `idms_unparsed_tail`. A node is `trailing_error` when an `ERROR` begins on the same row where that node ends. Error-bearing parse trees are retained for this classification and counted separately from files that emit no tree or contain zero matches.

### Compare direction proof

| Direction | Exit | Key output |
|---|---:|---|
| Identical `accept_statement/clean` before and after | 0 | `RECLASSIFIED_COUNT: 0`, `CONVERTED_COUNT: 0` |
| `accept_statement/clean` before to `idms_accept_statement` after | 1 | `RECLASSIFIED RECORD: sample.cbl:10,5`, `RECLASSIFIED_COUNT: 1` |
| `accept_statement/trailing_error` before to `idms_accept_statement` after | 0 | `CONVERTED_COUNT: 1`, `RECLASSIFIED_COUNT: 0` |

The six-case self-test printed exactly six case lines and exited 0.

## Commit-Separability Evidence

A throwaway repository under the system temporary directory produced this red-then-green matrix:

| Guard/version and changed paths | Exit | Result |
|---|---:|---|
| Pre-task guard: `queries/idms.scm` + `docs/x.md` | 0 | RED evidence: blind spot reproduced |
| Updated guard: `queries/idms.scm` + `docs/x.md` | 1 | Mixed families rejected |
| Updated guard: `queries/idms.scm` only | 0 | Grammar-only commit accepted |
| Updated guard: `.github/workflows/fork-checks.yml` + `grammar.js` | 1 | Mixed families rejected |
| Updated guard: empty commit | 0 | Explicit `0 changed paths` report |
| Updated guard: zero-commit range | 0 | Explicit `0 commits in range` report |
| Updated guard: clean/mixed/clean interleaved range | 1 | Three independent commit reports; exactly one mixed failure |

An unresolvable range also failed closed with exit 1 and explicitly reported `0 commits checked`.

## Verification Results

- `bash run_accept_differential_selftest.sh` -- PASS, exit 0, exactly 6 case lines.
- Task 1 `<verify>` command -- PASS, exit 0.
- Hand-run identical compare -- PASS, exit 0.
- Hand-run clean reclassification compare -- expected failure, exit 1, offending `sample.cbl:10,5` printed.
- Snapshot with `idms_unparsed_tail` regex -- PASS, emitted only `idms_unparsed_tail`; default regex emitted no tail record.
- Snapshot to `./inventory.txt` -- expected refusal, exit 1; snapshot under the system temporary directory -- PASS, exit 0.
- `run 5ab7920 <synthetic-corpus>` -- PASS, exit 0; one before and one after standard `accept_statement`, zero reclassifications.
- Existing `DIFF_TMP/accept-differential-worktree` preservation check -- expected refusal, exit 1; sentinel content remained intact.
- `node_modules/.bin/tree-sitter test -e '^comment$'` -- PASS, exit 0.
- `bash .githooks/estate-guard-selftest.sh` -- PASS, exit 0.
- Task 2 `<verify>` command -- PASS, exit 0.
- `bash -n run_accept_differential.sh run_accept_differential_selftest.sh .githooks/commit-separability.sh` -- PASS, exit 0.
- `git diff --quiet .github/workflows/test.yml .github/workflows/check-workflows.yml` -- PASS, exit 0; both upstream workflows remain untouched.
- Gortex post-edit contract checks -- ALLOW for `GRAMMAR_PATH_RE` and `cmd_run`; no configured guards were found.

## Decisions Made

- Used `path + start position` as the stable join key because the gate asks whether the same previously clean node retains its type.
- Preserved non-zero tree-sitter parse output rather than discarding it because the expected pre-change IDMS ACCEPT shape contains the `ERROR` node needed to derive `trailing_error`.
- Kept the full-estate differ manual rather than adding it to `pre-push`, honoring D-08's cost decision.
- Kept `.github/workflows/test.yml` and `.github/workflows/check-workflows.yml` byte-untouched; the new gate sits beside upstream CI.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Retained error-bearing parse trees for cleanliness classification**
- **Found during:** Task 1 acceptance verification
- **Issue:** The partial script treated every non-zero `tree-sitter parse` status as an unusable file. Tree-sitter returns non-zero for trees containing `ERROR`, which would discard the exact pre-change IDMS ACCEPT rows the `trailing_error` qualifier must classify.
- **Fix:** Count error-bearing trees separately but continue inventorying their nodes; reserve `files_failed_to_emit_tree` for empty output.
- **Files modified:** `run_accept_differential.sh`
- **Verification:** Optional-regex snapshot, standard ACCEPT run smoke test, and six comparison cases all passed.
- **Committed in:** `0a7f2cd`

**2. [Rule 2 - Missing Critical] Added fail-closed range and explicit zero-path reporting**
- **Found during:** Task 2 edge verification
- **Issue:** The original guard reported a zero-commit PASS for an unresolvable range and did not distinguish an empty commit from a normal no-family commit.
- **Fix:** Check `git rev-list` and path-enumeration statuses, fail closed when resolution fails, and emit explicit messages for empty commits and zero-commit ranges.
- **Files modified:** `.githooks/commit-separability.sh`
- **Verification:** Unresolvable range exited 1; empty commit and zero-commit range exited 0 with explicit reports.
- **Committed in:** `431aa71`

**3. [Rule 1 - Bug] Preserved caller-owned `DIFF_TMP` contents**
- **Found during:** Overall verification and destructive-operation review
- **Issue:** `run` unconditionally executed `rm -rf` on `$DIFF_TMP/accept-differential-worktree`, which could delete unrelated caller-owned content when `DIFF_TMP` was supplied.
- **Fix:** Refuse a pre-existing worktree path, track whether the script created `DIFF_TMP`, and remove only self-created inventories/directories.
- **Files modified:** `run_accept_differential.sh`
- **Verification:** A pre-existing sentinel worktree path caused exit 1 and remained intact; the normal `run` smoke test still exited 0 and left no worktree registration.
- **Committed in:** `5f89064`

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 2 missing critical behavior).
**Impact on plan:** All fixes were required for the stated evidence and data-safety contract. No feature scope was added.

## Issues Encountered

- Gortex `change.detect` does not include untracked files in this repository's detected change set, so post-edit detection saw tracked guard changes but not new files. Direct acceptance commands and Gortex contract checks covered the new artifacts.
- Local `actionlint` was unavailable. The existing `.github/workflows/check-workflows.yml` runs actionlint over all workflows in CI; source assertions and YAML structure checks passed locally.
- `tree-sitter generate` prints the repository's known `Failed to find tree-sitter section in package.json, unable to migrate` warning but exits 0 and leaves `grammar.js`/`src/` unchanged.

## Known Stubs

None.

## Threat Flags

None. The two planned trust-boundary surfaces were implemented with the registered mitigations: repository-root output refusal for corpus-derived inventories and read-only workflow permissions without `pull_request_target`.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- Plan 02-04 can use the committed TSV contract and proven failing direction for the authoritative DCC and estate ACCEPT differential.
- Plan 02-06 can pass `idms_unparsed_tail` as the snapshot regex for its tail census.
- Plan 02-03 is ready to implement the remaining non-ACCEPT IDMS verb classes.
- The upstream `comment` fixture remains an explicitly tracked open window; this plan enforces the other 12 fixtures without claiming 13/13.

## Self-Check: PASSED

- All four planned artifacts exist.
- Commits `0a7f2cd`, `431aa71`, and `5f89064` exist in history.
- Every task acceptance criterion and plan-level verification was rerun after the final source change.
- No inventory `.txt` artifact, proprietary corpus content, or `estate/` path was staged or committed.
- Unrelated `.gsd/`, `.planning/config.json`, `.planning/milestone.lock`, and `.planning/state.json` remain untracked and unstaged.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-08-31*
