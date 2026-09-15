---
phase: 01-delivery-pipe-measurement-baseline
plan: 05
subsystem: infra
tags: [cobolprobe, recall-measurement, documentation, go-workspace, gortex]

# Dependency graph
requires:
  - phase: 01-01
    provides: "forest-shim/cobol/ and the go.work-based resolution path this plan measured through"
  - phase: 01-03
    provides: "the SYMBOL_COUNT/TOKEN_COUNT (1215/585 vs 1153/523) grammar-lineage finding this plan's docs/baseline.md cites when explaining the observed recall agreement"
  - phase: 01-04
    provides: "docs/vendoring.md, which docs/baseline.md cross-references for the reproduction commands rather than duplicating them"
provides:
  - "docs/baseline.md — the VEND-05 recall baseline (raw counts + percentages for .cbl/.cpy, grammar-alone and neutralized) and the SEQ-01 build order with its measured volumes, outside .planning/ so Phases 2-4 can cite it after milestone archival"
  - "The baseline of record for Phases 2-4's recall deltas: this run's dataItems counts (17,905 / 32,360 for .cbl, 0 / 22,800 for .cpy), measured through this fork's own grammar lineage via the local vendoring path"
affects: [02, 03, 04]

# Actuals (#2632)
actuals:
  tokens: 2890
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Recording a divergence-that-didn't-happen as plainly as one that did: this run's raw dataItems counts came out numerically identical to the previously published forest v1.9.1 figures despite a genuine, separately-recorded grammar-lineage difference (SYMBOL_COUNT/TOKEN_COUNT 1215/585 vs 1153/523) - the agreement is stated as observed, not engineered toward"

key-files:
  created:
    - docs/baseline.md
  modified: []

key-decisions:
  - "This run's numbers are declared the baseline of record for Phases 2-4, even though they are numerically identical to the previously published forest v1.9.1 figures on this corpus - because they were measured through this fork's own grammar lineage via the local vendoring path this phase built, not inherited from a different parser build that happens to agree today"
  - "The percentage denominators (121,457 for .cbl, 24,478 for .cpy) are explicitly recorded as borrowed from cobolprobe/README.md's published source-truth counts, not re-derived in this run - neither probe_test.go nor neutralize_test.go emits a source-truth denominator, so presenting it as measured here would misstate provenance"
  - "The anticipated ~20-minute run duration (from the test's own -timeout 20m flag) did not materialize - the real run completed in 18.4 seconds - recorded as a genuine finding in docs/baseline.md rather than silently omitted, since 01-VALIDATION.md gated this run to once per phase specifically because a 20-minute cost was expected"

patterns-established:
  - "House docs/ style (SPEC-001's numbered ## headings, bold metadata block, > ⚠ blockquote callouts, GitHub-flavoured tables) extended to a third document (docs/spec/SPEC-001, docs/vendoring.md, now docs/baseline.md)"

requirements-completed: [VEND-05, SEQ-01]

coverage:
  - id: D1
    description: "A cobolprobe recall baseline is re-measured through the local vendoring path on the DCC corpus (606 .cbl, 958 .cpy), recording all four cells (raw count + percentage) for .cbl/.cpy grammar-alone and with neutralize(), with denominator provenance stated and the comparison against the previously published 15%/27%/0%/93% figures recorded honestly rather than reconciled"
    requirement: VEND-05
    verification:
      - kind: other
        ref: "go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m -corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC (exit 0, all 4 sub-tests PASS, per-extension lines for both .cbl and .cpy)"
        status: pass
      - kind: other
        ref: "grep-based acceptance criteria on docs/baseline.md: corpus counts (606/958/cam-corpus-dcc), both -corpus/-neut-corpus flags, four-cell table, denominator-provenance sentence, published figures 15/27/0/93 alongside this run's, baseline-of-record sentence, 1215/1153 grammar-lineage pair, .cpy 958-file denominator, zero estate-path matches"
        status: pass
    human_judgment: true
    rationale: "Task 1's own <verify> embeds an explicit <human-check> requiring a human to read the recall table in docs/baseline.md and confirm it reads as an honest record - a narrative-honesty judgment automated grep cannot substitute for. Per workflow.human_verify_mode=end-of-phase (the project default), this is harvested into the phase's consolidated UAT rather than halted on mid-flight; recorded here as requiring human sign-off rather than auto-passed."
  - id: D2
    description: "The SEQ-01 build order (IDMS DML first, EXEC CICS second, EXEC SQL third, EXEC DLI not built) is recorded in docs/baseline.md with the measured volumes that justify it, transcribed cell-for-cell from PROJECT.md, including the population measured over (1,369 programs) and the ACCEPT verb-mix split (634 IDMS / 1,757 standard COBOL) that makes Phase 2's ambiguity concrete"
    requirement: SEQ-01
    verification:
      - kind: other
        ref: "grep -Fq '14,764'/'3,539'/'489'/'EXEC DLI' docs/baseline.md && bash .githooks/estate-guard-selftest.sh && sh .githooks/commit-separability.sh (all pass, per the plan's task-2 <automated> verify block)"
        status: pass
      - kind: other
        ref: "grep-based acceptance criteria: 5 numbered ## headings (first '1.'), 541/14,764/221/3,539/49/489 + EXEC DLI zero row, 1,369, 634 and 1,757, locked decision D4 named, > ⚠ no-target-yet callout, docs/vendoring.md cross-referenced (not duplicated), every §3 number matching PROJECT.md cell for cell, zero estate-path matches, git show --stat listing only docs/baseline.md"
        status: pass
    human_judgment: false

duration: 6min
duration_note: "Elapsed executor time, dominated by required reading; the cobolprobe run itself (the plan's designated 20-minute phase-gate item) completed in 18.4 seconds, a recorded finding in docs/baseline.md itself, not a discrepancy in this duration figure."
completed: 2026-08-29
status: complete
---

# Phase 1 Plan 5: cobolprobe Recall Baseline and Build Order Summary

**Re-measured the cobolprobe recall baseline through the local vendoring path against the DCC corpus (606 `.cbl`, 958 `.cpy`) — dataItems counts came out numerically identical to the previously published forest v1.9.1 figures (17,905/32,360 for `.cbl`, 0/22,800 for `.cpy`) despite a genuine, separately-recorded grammar-lineage difference — and recorded the SEQ-01 build order with its measured volumes in `docs/baseline.md`.**

## Performance

- **Duration:** 6 min (executor time; the cobolprobe run itself completed in 18.4 seconds, not the anticipated ~20 minutes — see below)
- **Started:** 2026-08-29T16:04:00Z (approx)
- **Completed:** 2026-08-29T16:10:00Z (approx)
- **Tasks:** 2
- **Files created:** 1 (`docs/baseline.md`)

## Accomplishments

- Verified the precondition before measuring anything: `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` holds exactly 606 `.cbl` and 958 `.cpy` files, and `go list -m -f '{{.Dir}}' github.com/alexaandru/go-sitter-forest/cobol` in `~/repos/mine/GoApps/gortex` resolves into this fork's `forest-shim/cobol` — the pipe was confirmed on before running the measurement.
- Ran `cobolprobe`'s exact documented invocation (`-corpus`/`-neut-corpus` both pointed at the DCC corpus, `-timeout 20m`). Exit 0, all four sub-tests (`TestErrorCascade`, `TestHypothesisIdentificationParagraphs`, `TestHypothesisIDMS`, `TestNeutralizedParseRate`, `TestCobolParseRate`) passed.
- Extracted all four measured cells with raw counts and percentages: `.cbl` grammar-alone 17,905 (14.7%), `.cbl` + `neutralize()` 32,360 (26.6%), `.cpy` grammar-alone 0 (0.0%), `.cpy` + `neutralize()` 22,800 (93.1%) — computed against the README's published, borrowed source-truth denominators (121,457 / 24,478), explicitly stated as borrowed rather than re-derived.
- Discovered and recorded, rather than reconciled, that this run's raw `dataItems` counts are numerically identical to the previously published forest v1.9.1 figures for this corpus — even though a genuine grammar-lineage difference exists (this fork's committed `src/parser.c` reports `SYMBOL_COUNT`/`TOKEN_COUNT` 1215/585 vs forest's cached 1153/523, per plan 01-03/01-04's findings). `docs/baseline.md` states this plainly: the symbols this fork gained beyond forest's cached revision (at minimum the comment-node exposure from `c7a36d7`) evidently don't touch the `data_description`-node counting logic this measurement uses, on this corpus.
- Sanity-checked the `.cpy` zero: the grammar-alone `dataItems` count is reported over the full `files` column value of 958, not a skipped subset — confirming the 0% figure is meaningful rather than an artifact of file selection.
- Recorded, as a genuine finding rather than smoothing it over, that the anticipated ~20-minute run duration (from the test's own `-timeout 20m`) did not materialize — the actual run completed in 18.4 seconds, confirmed by `probe_test.go`'s own log line reporting all 1,564 files were probed, not a subset.
- Completed `docs/baseline.md` into a 5-section, SPEC-001-house-style document: what the file is, the recall baseline, the SEQ-01 build order (IDMS DML 541/14,764, `EXEC CICS` 221/3,539, `EXEC SQL` 49/489, `EXEC DLI` 0/0 per locked decision D4) transcribed cell-for-cell from PROJECT.md, reproduction commands cross-referenced to `docs/vendoring.md` rather than duplicated, and a `> ⚠` callout that no numeric recall target exists until Phase 2.

## Task Commits

Each task was committed atomically:

1. **Task 1: Re-measure the recall baseline through the local vendoring path** - `2500fba` (docs)
2. **Task 2: Record the build order with the volumes that justify it** - `4c98c11` (docs)

**Plan metadata:** pending (this commit)

## Files Created/Modified

- `docs/baseline.md` - the VEND-05 recall baseline (four measured cells, denominator provenance, comparison against published figures) and the SEQ-01 build order with measured volumes; a complete, house-style record surviving milestone archival

## Decisions Made

- This run's numbers are the baseline of record for Phases 2-4, even though they are numerically identical to the previously published figures on this corpus — because they were measured through this fork's own grammar lineage, not inherited from a different parser build that happens to agree today.
- Percentage denominators are explicitly recorded as borrowed from `cobolprobe/README.md`'s published source-truth counts, never presented as re-derived in this run, since neither test file emits one.
- The 18.4-second actual run duration (vs. the anticipated ~20 minutes) is recorded plainly in `docs/baseline.md` as a genuine finding, not adjusted or omitted.

## Deviations from Plan

None — plan executed exactly as written. The corpus and pipe preconditions verified on the first check; the recall command exited 0 on the first run; no acceptance criterion required a fix.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None — this plan introduces no new network endpoint, auth path, or schema; the only new surface is `docs/baseline.md` itself, covered by the plan's own T-01-15/T-01-16/T-01-17 mitigations and verified clean (`grep -Ec` estate-path check returns 0 on both commits).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VEND-05 and SEQ-01 are both satisfied: `docs/baseline.md` records the same-method, same-corpus, same-grammar-lineage recall baseline and the measured-volume build order, outside `.planning/` so it survives milestone archival.
- Phase 1 is now fully executed (5/5 plans). The next step is `/gsd-verify-work 1`, which will harvest Task 1's embedded `<human-check>` (confirming `docs/baseline.md`'s recall table reads as an honest record) into the phase's consolidated UAT per `workflow.human_verify_mode=end-of-phase`.
- Phase 2 (IDMS DML Statement Nodes) can now cite `docs/baseline.md`'s recall baseline for its own recall-delta measurement and the build-order volumes for its own scope justification. No blockers identified.

## Self-Check: PASSED

- `docs/baseline.md` verified present on disk with `[ -f ]`
- Both commit hashes (`2500fba`, `4c98c11`) verified present via `git log --oneline --all`
- All task-level acceptance criteria re-run and confirmed PASS: corpus counts (606/958), `go list -m` resolution, recall command exit 0 with per-extension lines, four-cell table with raw counts + percentages, corpus-of-record naming, full `go test` invocation, denominator-provenance statement, published-figures comparison with baseline-of-record sentence, 1215/1153 grammar-lineage pair, `.cpy` 958-file denominator, zero estate-path matches (both commits); task 2: 5 numbered `##` headings starting at `1.`, all required volume numbers (541/14,764/221/3,539/49/489/1,369/634/1,757), `EXEC DLI` zero row, locked decision D4 named, `> ⚠` no-target-yet callout, `docs/vendoring.md` cross-referenced, `bash .githooks/estate-guard-selftest.sh` and `sh .githooks/commit-separability.sh` both exit 0, `git show --stat --name-only` for the task-2 commit lists only `docs/baseline.md`
- Plan-level `<verification>` re-run: corpus counts verify, `go list -m` resolves into this fork's shim, recall command exits 0 with per-extension lines for both extensions, `docs/baseline.md` carries all required content, both guard scripts exit 0

---
*Phase: 01-delivery-pipe-measurement-baseline*
*Completed: 2026-08-29*
