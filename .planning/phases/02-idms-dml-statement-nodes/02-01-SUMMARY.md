---
phase: 02-idms-dml-statement-nodes
plan: 01
subsystem: parser
tags: [tree-sitter, grammar-dsl, cobol, idms-dml, lr-parsing]

# Dependency graph
requires:
  - phase: 01-delivery-pipe-measurement-baseline
    provides: the local vendoring path (forest-shim/refresh.sh, go.work), the pinned
      tree-sitter-cli 0.24.5, the NIST/corpus regression net, and the recall
      measurement baseline (17,905 grammar-alone / 32,360 neutralized)
provides:
  - "idms_navigation_statement, idms_record_name, idms_set_name, idms_unparsed_tail
    as named, exported node types — the cross-repo query contract 02-02..02-06 and
    gortex's graph builder both build on"
  - "queries/idms.scm — the extraction query shape (depth-independent named-node
    capture) later plans extend for idms_update_statement/idms_session_statement/
    idms_accept_statement rather than reinventing"
  - "the D-05 conflict-resolution precedent: static prec() on a single-token-wrapper
    rule resolves a reduce/reduce conflict against idms_unparsed_tail cleanly, before
    reaching for conflicts:/prec.dynamic() — directly reusable for the ACCEPT
    collision"
affects: [02-02, 02-03, 02-04, 02-05, 02-06]

# Actuals (#2632)
actuals:
  tokens: 4100
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Named-node operand extraction (idms_record_name/idms_set_name as their own
      rules, not field() labels) so a query matches under any of the four
      idms_*_statement types regardless of nesting depth (D-02)"
    - "Pure-grammar catch-all tail absorber (idms_unparsed_tail: repeat1 over
      existing atomic leaves, bounded at the literal '.') — new idiom for this
      grammar, no external-scanner extension"
    - "Static prec() on a single-token wrapper rule to resolve a reduce/reduce
      conflict against a catch-all absorber, tried before conflicts:/prec.dynamic()"

key-files:
  created:
    - queries/idms.scm
    - test/idms/query-sample.cbl
    - test/corpus/idms_navigation.txt
  modified:
    - grammar.js
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - src/tree_sitter/parser.h
    - src/tree_sitter/alloc.h
    - src/tree_sitter/array.h

key-decisions:
  - "idms_unparsed_tail admits exactly WORD, _LITERAL (number/string), '(', ')', ','
    — no bare $.integer arm, since $.integer is already reachable through
    _LITERAL -> number -> integer and adding it as a second, differently-shaped
    path to the same token would itself be a reduce/reduce ambiguity"
  - "CALC format's optional selector is CALC|ANY only, not CALC|ANY|DUPLICATE —
    Task 2's own enumerated terminal list (8 new _KEYWORD entries) does not
    include _DUPLICATE even though the <action> prose mentions it; a bare
    DUPLICATE selector falls through to idms_unparsed_tail (D-03) rather than
    ERROR, and can be added within-phase once 02-06's census shows volume"
  - "Static prec(1, ...) on idms_record_name/idms_set_name resolved the ACCEPT-
    adjacent-style reduce/reduce conflict (idms_record_name vs.
    _idms_operand_token, both bare-WORD wrappers) cleanly — tree-sitter generate
    exited 0 with no conflict error, so no conflicts: entry was needed"

requirements-completed: [IDMS-01, IDMS-02, IDMS-06, IDMS-07]

coverage:
  - id: D1
    description: "OBTAIN NEXT CUSTOMER-REC WITHIN CUST-ORDER-SET parses into idms_navigation_statement with idms_record_name/idms_set_name, zero ERROR nodes"
    requirement: "IDMS-01"
    verification:
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation obtain next within set"
        status: pass
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation lowercase"
        status: pass
    human_judgment: false
  - id: D2
    description: "tree-sitter query queries/idms.scm test/idms/query-sample.cbl returns record and set names as named captures"
    requirement: "IDMS-02"
    verification:
      - kind: e2e
        ref: "node_modules/.bin/tree-sitter query queries/idms.scm test/idms/query-sample.cbl"
        status: pass
    human_judgment: false
  - id: D3
    description: "All six manual-documented FIND/OBTAIN formats (DB-KEY, CALC, OWNER, WITHIN set/area, CURRENT, KEEP [EXCLUSIVE] prefix) parse into idms_navigation_statement"
    requirement: "IDMS-01"
    verification:
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation db-key"
        status: pass
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation calc"
        status: pass
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation owner"
        status: pass
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation current"
        status: pass
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation keep exclusive"
        status: pass
    human_judgment: false
  - id: D4
    description: "An unmodelled operand tail is absorbed into idms_unparsed_tail, never ERROR, never silently dropped"
    verification:
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation unparsed tail"
        status: pass
    human_judgment: false
  - id: D5
    description: "Two IDMS statements chained in one sentence parse as two sibling idms_navigation_statement nodes, not one absorbing the other's tail"
    requirement: "IDMS-02"
    verification:
      - kind: unit
        ref: "test/corpus/idms_navigation.txt#idms navigation two statements one sentence"
        status: pass
    human_judgment: false
  - id: D6
    description: "tree-sitter generate is idempotent (byte-identical src/ across two consecutive runs) and the pure-grammar tail absorber leaves src/scanner.c untouched"
    requirement: "IDMS-01"
    verification:
      - kind: other
        ref: "shasum src/parser.c src/grammar.json src/node-types.json before/after a second tree-sitter generate — identical; git diff --quiet src/scanner.c"
        status: pass
    human_judgment: false
  - id: D7
    description: "Full regression net stays green: tree-sitter test -e '^comment$' exits 0, NIST gains no failure beyond the 11 in skip_tests.txt, and every commit touches only upstream-owned grammar paths (FORK-03)"
    requirement: "IDMS-06"
    verification:
      - kind: integration
        ref: "node_modules/.bin/tree-sitter test -e '^comment$'"
        status: pass
      - kind: integration
        ref: "sh run_nist_cobol85.sh (Fail: 0, matching the 39886c7 pre-change baseline)"
        status: pass
      - kind: other
        ref: "git show --name-only --format= <sha> for 5a3a867, 44ce5df, 6c930d1"
        status: pass
    human_judgment: false
  - id: D8
    description: "Estate-leak guard (FORK-02) passes over this plan's own commit range and fixtures stay under the 72-byte line limit"
    requirement: "IDMS-07"
    verification:
      - kind: integration
        ref: "bash .githooks/estate-guard-selftest.sh"
        status: pass
      - kind: integration
        ref: "sh .githooks/estate-guard.sh --range 39886c7..HEAD (CHECK 1 PASS, CHECK 3 PASS)"
        status: pass
      - kind: other
        ref: "awk 'length($0) > 72' test/corpus/idms_navigation.txt test/idms/query-sample.cbl"
        status: pass
    human_judgment: false

duration: 38min
completed: 2026-08-30
status: complete
---

# Phase 2 Plan 1: IDMS DML Statement Nodes — Navigation Tracer Summary

**All six CA IDMS FIND/OBTAIN manual formats parse into a new `idms_navigation_statement` node with depth-independent `idms_record_name`/`idms_set_name` captures and a pure-grammar `idms_unparsed_tail` absorber, proven end-to-end through `queries/idms.scm` with zero NIST/corpus regressions.**

## Performance

- **Duration:** 38 min
- **Started:** 2026-08-30T04:14:00Z (approx, from STATE.md session marker)
- **Completed:** 2026-08-30T04:51:49Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments
- Tracer slice (Task 1): `OBTAIN NEXT CUSTOMER-REC WITHIN CUST-ORDER-SET.` travels from a new `grammar.js` rule through a regenerated, committed `src/parser.c` into a passing corpus fixture and out through a `queries/idms.scm` capture returning both the record and set name — proving the four-node model (D-01), named-operand model (D-02), and query-delivery path end-to-end on one path before expanding.
- Full navigation class (Task 2): `idms_navigation_statement` restructured to `seq(field('verb', choice($.FIND, $.OBTAIN)), $._idms_navigation_body)` covering all six manual-documented formats (DB-KEY, CALC, OWNER, WITHIN set/area, CURRENT), each preceded by a shared optional `KEEP [EXCLUSIVE]` prefix.
- `idms_unparsed_tail` (D-03) implemented as a pure-grammar `repeat1` over `$.WORD`, `$._LITERAL`, and punctuation, bounded at the literal `.` — absorbs an unmodelled operand into a named node rather than producing an ERROR, and a genuine `FIND CURRENT WORD .` reduce/reduce conflict against it was resolved with static `prec(1, ...)` on `idms_record_name`/`idms_set_name`, with no `conflicts:` entry needed.
- Verified two chained navigation statements in one sentence parse as two sibling `idms_navigation_statement` nodes — `idms_unparsed_tail`'s leaf set excludes keyword tokens (like a second `OBTAIN`), so it never swallows a following statement.
- Full regression gate (Task 3): `tree-sitter test -e '^comment$'` exits 0, NIST `run_nist_cobol85.sh` reports `Fail: 0` against a freshly-captured pre-change baseline (also `Fail: 0` at commit `39886c7`), `skip_tests.txt` unchanged at 11 entries, and every one of this plan's 3 commits touches only `grammar.js`, `src/`, `test/corpus/`, `test/idms/`, `queries/` — none touch `docs/`, `.planning/`, `.githooks/`, `forest-shim/`, or `.github/` (FORK-03 verified via `git show --name-only`).
- Estate-leak guard (FORK-02) re-run over this plan's own commit range: `estate-guard-selftest.sh` exits 0, and `estate-guard.sh --range 39886c7..HEAD` reports CHECK 1 PASS and CHECK 3 PASS.

## Task Commits

1. **Task 1 (RED): Tracer fixture** - `5a3a867` (test) — two failing corpus cases for the OBTAIN/WITHIN tracer path
2. **Task 1 (GREEN): Tracer implementation** - `44ce5df` (feat) — grammar rule, regenerated `src/`, `queries/idms.scm`, `test/idms/query-sample.cbl`
3. **Task 2: Full navigation class + idms_unparsed_tail** - `6c930d1` (feat) — all six manual formats, tail absorber, 7 new corpus cases, extended query-sample
4. **Task 3: Full regression gate** - no commit (verification-only; no file changes produced)

_Task 1 was `type="tracer" tdd="true"` and followed the full RED→GREEN cycle as two separate commits. Task 2 was `type="auto" tdd="true"`; see "TDD Gate Compliance" below._

## Files Created/Modified
- `grammar.js` - 8 new `_KEYWORD` terminals + exports (`_CALC`, `_CURRENT`, `_DB_KEY`, `_FIND`, `_KEEP`, `_OWNER`, `_PAGE_INFO`, `_PRIOR`, plus Task 1's `_OBTAIN`/`_WITHIN`); uncommented pre-existing `IS`/`LAST` markers; `idms_navigation_statement`, `_idms_navigation_body`, `idms_record_name`, `idms_set_name`, `_idms_operand_token`, `idms_unparsed_tail` rules; registered in `_statement`'s `choice()`
- `src/parser.c`, `src/grammar.json`, `src/node-types.json` - regenerated via pinned `tree-sitter 0.24.5`; `SYMBOL_COUNT`/`TOKEN_COUNT` now 1184/535 (up from the Phase-1-regenerated 1153/523 baseline; docs/vendoring.md's committed-file figure of 1215/585 remains the open, unrelated vendoring question — not touched by this plan)
- `src/tree_sitter/alloc.h`, `src/tree_sitter/array.h` - newly emitted by this generate, absent from the previously-committed tree; committed alongside per the plan's own note
- `queries/idms.scm` - new extraction query: `verb`/`@record`/`@set` captures, depth-independent (matches under any format without format-specific patterns)
- `test/idms/query-sample.cbl` - minimal subject program exercising WITHIN, DB-KEY, CALC, and OWNER formats
- `test/corpus/idms_navigation.txt` - 9 fixture cases covering all six manual formats, lowercase, unparsed tail, and statement adjacency

## Decisions Made
- **`idms_unparsed_tail`'s admitted leaf set is `$.WORD`, `$._LITERAL`, `'('`, `')'`, `','` — no bare `$.integer`.** Research flagged `$.integer` as a candidate arm, but since `$._LITERAL` already resolves to `$.number` → `$.integer` for numeric leaves, adding a second, differently-shaped path to the same terminal would itself be a reduce/reduce ambiguity. This is the empirically-validated leaf set for 02-06's later census, pending whatever new leaf types future plans' fixtures surface as genuinely unabsorbed.
- **CALC format models `CALC|ANY` only, not `CALC|ANY|DUPLICATE`.** Task 2's own enumerated new-terminal list (8 entries) omits `_DUPLICATE`even though the `<action>` prose's format description mentions it as a third selector option. Treated the enumerated terminal list as authoritative (smallest diff, D-09's "minimal-to-edges, extend on evidence") — a bare `DUPLICATE` selector currently falls into `idms_unparsed_tail` rather than ERROR (D-03's own safety net), and can be added within-phase if 02-06's coverage census shows it occurs.
- **Static `prec(1, ...)` on `idms_record_name`/`idms_set_name` resolved the `FIND CURRENT WORD .` reduce/reduce conflict cleanly.** Per the plan's mandated resolution order (attempt static `prec()` before `conflicts:`/`prec.dynamic()`), this was tried first, `tree-sitter generate` exited 0 with no conflict error, so no `conflicts:` entry exists in `grammar.js` (`grep -cE '^  conflicts:' grammar.js` returns 0) — the safer, deterministic resolution won.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stale native-binding build cache after the ad hoc NIST-baseline worktree**
- **Found during:** Task 3 (NIST regression gate)
- **Issue:** Task 3's action required capturing a pre-change NIST baseline via `git worktree add` at commit `39886c7` (the plan's base) since no baseline was captured before Task 1. After removing that worktree, `tree-sitter test -i 'idms navigation'` in the main tree started failing with all 9 IDMS cases reverting to `(ERROR (comment_entry))` — the built native parser binding was apparently keyed by grammar name rather than working-tree path and had been left pointing at the worktree's pre-Task-1 build.
- **Fix:** Re-ran `node_modules/.bin/tree-sitter generate` in the main tree, which forced a fresh native-binding rebuild; all 9 IDMS cases and the full 90-case non-comment suite passed immediately after, and `git status --short src/` showed the regenerated files byte-identical to what was already committed (no drift).
- **Files modified:** none (no committed file changed; this was a local build-cache artifact, not a source change)
- **Verification:** `node_modules/.bin/tree-sitter test -i 'idms navigation'` (9/9 pass) and `node_modules/.bin/tree-sitter test -e '^comment$'` (full 90-case suite, exit 0) both re-run clean; `git status --short` confirmed no working-tree drift
- **Committed in:** n/a (no source change; documented here for anyone reproducing the NIST-baseline worktree technique)

---

**Total deviations:** 1 auto-fixed (1 bug, local build-cache artifact, no source impact)
**Impact on plan:** No effect on shipped grammar or fixtures. Documented so a future plan reusing the "worktree for a pre-change baseline" technique in Task 3-shaped steps knows to re-run `tree-sitter generate` in the main tree afterward before trusting `tree-sitter test` output.

## TDD Gate Compliance

Task 1 (`type="tracer" tdd="true"`) followed the full RED → GREEN cycle as two separate commits (`5a3a867` test, `44ce5df` feat), matching the gate sequence exactly.

Task 2 (`type="auto" tdd="true"`) does **not** have a separate `test(02-01): ...` commit preceding its `feat(02-01): ...` commit — all 7 new corpus cases and the grammar restructuring were authored together in one commit (`6c930d1`). A genuine failing state was still observed and resolved before reaching green: the first `tree-sitter generate` attempt (with all 9 fixtures already written) reported an unresolved reduce/reduce conflict at `FIND CURRENT WORD .`, which was diagnosed and fixed with static `prec()` before any fixture was run — satisfying the spirit of RED→GREEN (see a real failure, fix it, confirm green) but not the letter of two atomic commits. Recorded here per the executor's gate-enforcement rule; not re-split retroactively since doing so now would require reverting working history rather than reflecting how the work actually happened.

## Issues Encountered
None beyond the build-cache artifact documented above under Deviations.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `idms_record_name`, `idms_set_name`, `idms_unparsed_tail` exist as the stable cross-repo query contract; 02-02 (idms_update_statement / idms_session_statement) and later plans in this phase reuse them verbatim rather than re-deriving.
- The D-05 conflict-resolution precedent (static `prec()` on a single-token-wrapper rule, tried before `conflicts:`) is directly reusable for the ACCEPT collision task in a later plan in this phase.
- `queries/idms.scm`'s depth-independent capture pattern needs no format-specific duplication as later plans add `idms_update_statement`/`idms_session_statement`/`idms_accept_statement` — only new `(idms_*_statement (idms_record_name) @record)`-shaped entries, following the same shape already established here.
- No blockers. IDMS-04 (`TestErrorCascade` cross-repo gate) and IDMS-05/08 (recall measurement) remain out of this plan's scope per its `requirements:` frontmatter (`[IDMS-01, IDMS-02, IDMS-06, IDMS-07]`) — tracked for later plans/phase-end gates per 02-RESEARCH.md.

## Self-Check: PASSED

All key files confirmed on disk (`queries/idms.scm`, `test/idms/query-sample.cbl`,
`test/corpus/idms_navigation.txt`, `.planning/phases/02-idms-dml-statement-nodes/02-01-SUMMARY.md`)
and all three commit hashes (`5a3a867`, `44ce5df`, `6c930d1`) confirmed present in `git log`.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-08-30*
