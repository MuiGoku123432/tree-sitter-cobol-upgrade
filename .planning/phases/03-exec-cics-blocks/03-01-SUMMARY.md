---
phase: 03-exec-cics-blocks
plan: 01
subsystem: grammar
tags: [tree-sitter, cobol, cics, keyword-extraction, query, forest-shim]

requires:
  - phase: 02-idms-dml-statement-nodes
    provides: the queries/*.scm publication route, forest-shim/refresh.sh vendoring sequence, and run_accept_differential.sh as the reusable estate-scale differential harness
provides:
  - exec_cics_statement grammar node with a command field, integrated into the _statement choice()
  - EXEC / CICS / END-EXEC terminals following the repo's two-part private-regex + public-alias convention
  - queries/cics.scm publishing the command capture, vendored into forest-shim/cobol/
  - test/corpus/exec_cics.txt with the D-18/D-32 keyword-extraction proof
  - run_cics_query_capture.sh, the fork-local CICS-02 query-capture gate
  - 03-FINDINGS.md resolving OQ-1, OQ-2 and OQ-3 as citable constants
affects: [03-02, 03-03, 03-04, phase-4-exec-sql]

actuals:
  tokens: 62000
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Generic command-field statement node (D-17) coexisting with Phase 2's verb-class node shape"
    - "Fork-local gate scripts assert query reachability, not just tree shape"

key-files:
  created:
    - queries/cics.scm
    - test/corpus/exec_cics.txt
    - run_cics_query_capture.sh
    - forest-shim/cobol/cics.scm
    - .planning/phases/03-exec-cics-blocks/03-FINDINGS.md
  modified:
    - grammar.js
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - forest-shim/cobol/parser.c
    - forest-shim/cobol/grammar.json

key-decisions:
  - "D-18 confirmed by fixture, not argument: tree-sitter keyword extraction arbitrates READ/WRITE/DELETE/RETURN inside the block with no conflicts entry. The explicit choice() fallback was NOT needed."
  - "Rule anchors on the two-token EXEC CICS opening, never on EXEC alone, so the EXEC SQL and EXEC DLI parses Phase 4 inherits are not degraded (RESEARCH Pitfall 2)."
  - "Option list is repeat(), not repeat1() — the no-option shape is 43% of measured blocks (D-28b)."
  - "No terminating period embedded in the rule; the existing sentence machinery handles it, as in every sibling _statement rule (D-20)."
  - "Baseline SHA recorded as 5a3a867 (the literal parent), with the history-simplification alternative c7a36d7 proved byte-identical rather than assumed away."
  - "run_cics_query_capture.sh writes its fixture to an untracked scratch dir rather than adding a tracked test/cics/ fixture, keeping the commit inside the plan's declared path set."

patterns-established:
  - "Query-reachability gate: a grammar node that parses but is not extractable through the published .scm is worthless to gortex, and tree-sitter test cannot catch that. Assert the capture, not just the tree."
  - "Estate probes report counts only and never write a matched source line into a tracked file (D-32/T-03-01)."

requirements-completed: [CICS-01, CICS-02, CICS-05, CICS-06]

coverage:
  - id: D1
    description: "One EXEC CICS block parses as a named exec_cics_statement node with a bound command field, zero ERROR nodes"
    requirement: CICS-01
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics send map with literal - names invented and neutral"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-18 keyword extraction arbitrates the four colliding verbs; ordinary COBOL READ/WRITE are unaffected"
    requirement: CICS-05
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics d-18 keyword extraction proof - names invented and neutral"
        status: pass
      - kind: unit
        ref: "node -e 'process.exit(require(\"./src/grammar.json\").conflicts.length===0?0:1)'"
        status: pass
    human_judgment: false
  - id: D3
    description: "The no-option shape (43% of measured blocks) parses, proving the option list is repeat() not repeat1()"
    requirement: CICS-06
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics no-option shape"
        status: pass
    human_judgment: false
  - id: D4
    description: "Command and option keywords match case-insensitively — lowercase and uppercase spellings produce identical trees"
    requirement: CICS-06
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics lowercase spelling"
        status: pass
    human_judgment: false
  - id: D5
    description: "queries/cics.scm emits a command capture against an EXEC CICS block, and reaches the vendored shim"
    requirement: CICS-02
    verification:
      - kind: integration
        ref: "sh run_cics_query_capture.sh"
        status: pass
      - kind: integration
        ref: "forest-shim/refresh.sh (6/6 steps OK, forest-shim/cobol/cics.scm present)"
        status: pass
    human_judgment: true
    rationale: "CICS-02 cannot be reported satisfied on the automated capture alone — the D-22 finding (30 of 33 PROGRAM operands are data names, not resolvable edge targets) is a disclosure the plan requires a human to weigh against the requirement's intent."
  - id: D6
    description: "The three open research questions resolved with reproducible commands and recorded as citable constants for 03-02 and 03-04"
    verification:
      - kind: unit
        ref: "test -f .planning/phases/03-exec-cics-blocks/03-FINDINGS.md && grep -qi 'pre-phase-2' ... && grep -q 'NODE_TYPE_REGEX' ..."
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-09-09
status: complete
---

# Phase 3 Plan 01: EXEC CICS Tracer Summary

**The D-18 keyword-extraction assumption is settled by a committed fixture — tree-sitter arbitrates `READ`/`WRITE`/`DELETE`/`RETURN` inside `EXEC CICS` blocks with zero grammar conflicts, so the whole phase proceeds on the cheap path and the explicit `choice()` fallback is never needed.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2 of 2
- **Files created:** 5
- **Files modified:** 6
- **Commits:** 3

## Accomplishments

- **D-18 proven, not argued.** All four colliding command words parse as `exec_cics_statement` while ordinary COBOL `READ`/`WRITE` in the same fixture still parse as `read_statement`/`write_statement`, with zero ERROR nodes and `src/grammar.json` `conflicts` still length 0. This was the phase's single load-bearing assumption and the reason this plan was sequenced first.
- **One `EXEC CICS` block is queryable end-to-end** — grammar rule → regenerated parser → vendored shim → published query → asserted capture. `forest-shim/refresh.sh` completes all 6 steps including the Go smoke build and the forest drop-in drift check.
- **The continuation-line risk is closed at zero cost.** 3,726 blocks across 267 estate files, 2,837 of them multi-line, contain exactly **0** column-7 continuation indicators. `src/scanner.c` stays untouched and plan 03-02 needs no scope escalation — this was the phase's largest latent scope risk.
- **Plan 03-04 has both constants it was blocked on**: the baseline SHA `5a3a867` and the `NODE_TYPE_REGEX` for the D-31 differential.

## Task Commits

1. **Task 1: End-to-end "one EXEC CICS block is a queryable named node"** — `77b1fea` (feat), `5c4dbb6` (test)
2. **Task 2: Resolve and record the three open research questions** — `b6f5190` (docs)

Task 1 spans two commits by design, per the plan's `<commit_path_constraints>`: the grammar series (b) and the fork-local gate (c) must not ride together (FORK-03). Verified — no commit spans two path constraints.

## Files Created/Modified

**Created**
- `queries/cics.scm` — the command capture, no predicates (gortex's `runQuery` evaluates none, so a predicate would compile and be silently ignored)
- `test/corpus/exec_cics.txt` — 4 cases: the map/literal shape, the D-18 four-verb proof, the no-option shape, the lowercase spelling
- `run_cics_query_capture.sh` — CICS-02 fork-local gate; asserts the query emits its contracted captures
- `forest-shim/cobol/cics.scm` — vendored by `refresh.sh` Step 3 so gortex's `//go:embed *.scm` can see it
- `.planning/phases/03-exec-cics-blocks/03-FINDINGS.md` — OQ-1/OQ-2/OQ-3 resolutions

**Modified**
- `grammar.js` — `exec_cics_statement`, `_cics_option`, `_cics_argument`, the three terminal pairs, and one line in the `_statement` `choice()`
- `src/{parser.c,grammar.json,node-types.json}`, `forest-shim/cobol/{parser.c,grammar.json}` — regenerated/vendored, never hand-edited

## Decisions Made

- **D-18 fallback not triggered.** The plan instructed STOP-and-fallback if the proof case failed. It passed; no `choice()` arms were added and no `conflicts:` entry exists.
- **Baseline SHA ambiguity discharged by proof.** RESEARCH A6 warned an ambiguous commit boundary would make the reconstructed baseline non-comparable. `git log -- grammar.js` (history-simplified) points at `c7a36d7` while the literal parent is `5a3a867`. Rather than pick one, the two were shown byte-identical on `grammar.js`; `5a3a867` is recorded because it follows the plan's stated derivation rule without a caveat.
- **Query-gate fixture kept untracked.** The plan's path constraint (c) admits `run_cics_query_capture.sh` and `.git/info/exclude` only. Adding `test/cics/query-sample.cbl` would have been an undeclared tracked file, so the script writes its fixture into `.cics-query-scratch/`, excluded via `.git/info/exclude` per FORK-02.

## Deviations from Plan

**1. [Minor - scope] Fixture location for the query gate**
- **Found during:** Task 1
- **Issue:** The plan's route (a) implies a fixture program for `tree-sitter query`, but `files_modified` and path constraint (c) declare no tracked fixture path.
- **Fix:** The gate generates its fixture at runtime into an untracked scratch directory, declared via `.git/info/exclude`.
- **Verification:** `sh run_cics_query_capture.sh` exits 0; `git status` shows no untracked fixture.
- **Committed in:** `5c4dbb6`

**2. [Minor - convention] D-32 disclaimer placement**
- **Found during:** Task 1
- **Issue:** The plan asks for the invented-and-neutral disclaimer inline, mirroring `cascade_test.go:79-80` — but the tree-sitter corpus format has no comment channel outside the COBOL source, and a COBOL comment line would add `(comment)` nodes to every expected tree.
- **Fix:** Carried the disclaimer in the test-name headers (`... - names invented and neutral`), which are free-form. The full disclaimer also appears in `run_cics_query_capture.sh`'s header block and in `03-FINDINGS.md`.
- **Verification:** `tree-sitter test -e '^comment$'` exits 0, 0 failures.
- **Committed in:** `77b1fea`, `5c4dbb6`

**Total deviations:** 2 minor, both auto-fixed. No behavioral or contract deviation.

## Prohibition Disclosures

**REQUIRED disclosure (plan prohibition, CICS-02).** Criterion 1 is reported satisfied on the mechanical evidence — `queries/cics.scm` emits a `command` capture and it reaches the vendored shim. It is **not** a claim that CICS edges are resolvable. The D-22 finding stands: **30 of 33 `PROGRAM` operands are data names rather than resolvable edge targets.** Any consumer treating a `PROGRAM(...)` capture as a program-name edge will be wrong ~91% of the time on the measured sample. This is unchanged by this plan and is inherited by 03-02's operand work.

**Estate hygiene.** No estate source excerpt, identifier, program name, map name or transaction id was copied into any tracked file. The continuation probe read the estate and wrote counts only. All fixture names are invented and neutral.

## Flagged Assumption (carried forward, not dismissed)

Edge probe row **CICS-01/unclassified** remains unresolved — the probe could not classify the requirement onto a shape category. The planner's assumption is that CICS-01's edges are covered by the empty/encoding/adjacency rows resolved under CICS-02 and CICS-03. Nothing in this plan tested that assumption; it is surfaced again here for 03-04's measurement to settle.

## Verification

| Gate | Result |
|------|--------|
| `tree-sitter test -e '^comment$'` | exit 0, 0 failures, 4 new cases green |
| `src/grammar.json` conflicts length 0 | exit 0 |
| `sh run_cics_query_capture.sh` | exit 0, 5 command captures |
| `forest-shim/refresh.sh` | exit 0, 6/6 steps, `forest-shim/cobol/cics.scm` present |
| `grep -c exec_cics_statement queries/cics.scm` | 1 |
| Per-commit path constraints | 3/3 clean, no commit spans two constraints |
