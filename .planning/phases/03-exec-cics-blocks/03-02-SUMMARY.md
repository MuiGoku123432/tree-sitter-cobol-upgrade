---
phase: 03-exec-cics-blocks
plan: 02
subsystem: grammar
tags: [tree-sitter, cobol, cics, query, operands, forest-shim]

requires:
  - phase: 03-exec-cics-blocks
    provides: "03-01's proven exec_cics_statement node, the D-18 keyword-extraction result, queries/cics.scm, run_cics_query_capture.sh, and the 03-FINDINGS.md continuation-line answer that authorised leaving src/scanner.c alone"
provides:
  - Full option surface -- bare options, all measured argument forms, subscripted data names
  - cics_unparsed_tail with the terminator boundary settled by fixture
  - cics_transaction_name / cics_program_name / cics_map_name / cics_mapset_name as named nodes
  - queries/cics.scm with all five capture roles, vendored into forest-shim/cobol/
  - run_cics_query_capture.sh asserting all five captures
  - A measured EXEC SQL non-degradation result against a genuine pre-Phase-3 parser
affects: [03-03, 03-04, phase-4-exec-sql]

actuals:
  tokens: 88000
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "prec.right on an option rule to resolve both option-vs-tail and shift-vs-reduce statically"
    - "Baseline parser comparison must be ordered around the tree-sitter CLI's name-keyed parser cache"

key-files:
  created: []
  modified:
    - grammar.js
    - queries/cics.scm
    - test/corpus/exec_cics.txt
    - run_cics_query_capture.sh
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - forest-shim/cobol/parser.c
    - forest-shim/cobol/grammar.json
    - forest-shim/cobol/cics.scm

key-decisions:
  - "RESEARCH Pitfall 1 / A1 SETTLED BY FIXTURE: END-EXEC is consumed as the terminator and appears as a SIBLING of cics_unparsed_tail, never inside it. Neither a token precedence on the terminator nor a tail-vocabulary exclusion was needed -- keyword extraction arbitrates it."
  - "Added a subscripted-data-name argument arm on its own measured evidence (54 of 7,971 args, 0.68%), because without it those parse with a MISSING ')' recovery node rather than degrading into the tail."
  - "Left the comma-in-argument gap open deliberately (4 of 7,971, 0.05%), having verified the ERROR is contained and does not cascade, and that closing it would need a lexical precedence on the shared `integer` token whose regex wrongly matches a bare comma."
  - "EXEC SQL is NOT degraded, but its parse is NOT byte-identical either: the ERROR span and empty procedure_division are unchanged, while recovery now matches EXEC and inserts a MISSING _CICS. Recorded as changed-but-not-degraded rather than claimed identical."
  - "Operands are named rules, not field() labels, on two independently verified grounds: field() depth binding, and gortex's runQuery evaluating no predicates."

patterns-established:
  - "Parser-cache hazard: the tree-sitter CLI caches compiled parsers by grammar NAME, not path, so generating a second checkout's grammar silently repoints the shared parser. Any baseline-vs-current comparison must generate-then-measure in that order, per side."
  - "The .bin/tree-sitter shim resolves the grammar through node_modules and picks the wrong parser when multiple checkouts exist; invoke node_modules/tree-sitter-cli/tree-sitter directly."

requirements-completed: [CICS-01, CICS-02, CICS-05, CICS-06]

coverage:
  - id: D1
    description: "All measured argument forms parse: quoted literal, plain data name, LENGTH OF, numeric literal"
    requirement: CICS-01
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics option with plain data name argument / length of argument / numeric literal argument"
        status: pass
    human_judgment: false
  - id: D2
    description: "The four criterion operands emit named nodes wrapping the paren contents, whether literal or data name"
    requirement: CICS-01
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics transid operand / program operand as data name / program operand as quoted literal / map and mapset operands"
        status: pass
    human_judgment: false
  - id: D3
    description: "END-EXEC is consumed as the terminator and is not absorbed into cics_unparsed_tail"
    requirement: CICS-06
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics unparsed tail does not absorb the terminator"
        status: pass
    human_judgment: false
  - id: D4
    description: "Unmodelled content lands in a named cics_unparsed_tail rather than an ERROR"
    requirement: CICS-06
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics unmodelled content lands in unparsed tail / nested subscript argument"
        status: pass
    human_judgment: false
  - id: D5
    description: "Multi-line blocks parse to the same shape as their single-line equivalent, with no scanner change"
    requirement: CICS-05
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec cics multi-line block"
        status: pass
      - kind: unit
        ref: "git log --name-only HEAD~4..HEAD | grep -c src/scanner.c == 0"
        status: pass
    human_judgment: false
  - id: D6
    description: "EXEC SQL parses no worse than before the phase"
    requirement: CICS-05
    verification:
      - kind: unit
        ref: "test/corpus/exec_cics.txt#exec sql regression - error span unchanged from pre-phase-3 baseline 5a3a867"
        status: pass
    human_judgment: true
    rationale: "The parse is not byte-identical to baseline -- the ERROR gained a MISSING _CICS from recovery. Judging that as non-degradation rather than regression is a human call, and it is load-bearing for Phase 4 because the corpus of record contains zero EXEC SQL and the recall number cannot detect a degradation there."
  - id: D7
    description: "queries/cics.scm emits all five captures, with no predicates, and is byte-identical to the vendored copy"
    requirement: CICS-02
    verification:
      - kind: integration
        ref: "sh run_cics_query_capture.sh (5 captures: command 8, transaction 1, program 2, map 1, mapset 1)"
        status: pass
      - kind: integration
        ref: "diff queries/cics.scm forest-shim/cobol/cics.scm"
        status: pass
    human_judgment: true
    rationale: "Same D-22 disclosure as 03-01: mechanical capture success is not a claim that CICS edges are resolvable."
  - id: D8
    description: "The grammar still generates a length-0 conflicts array after all option and operand rules"
    verification:
      - kind: unit
        ref: "node -e 'process.exit(require(\"./src/grammar.json\").conflicts.length===0?0:1)'"
        status: pass
    human_judgment: false

duration: 70min
completed: 2026-09-10
status: complete
---

# Phase 3 Plan 02: Full Option and Operand Coverage Summary

**The phase's highest residual risk is retired: `END-EXEC` is consumed as the terminator and sits as a sibling of `cics_unparsed_tail`, never inside it — settled by a committed fixture rather than by the token-precedence or vocabulary-exclusion remedies the plan held in reserve.**

## Performance

- **Duration:** ~70 min
- **Tasks:** 3 of 3
- **Commits:** 4
- **Corpus cases:** 17 CICS cases, all green; full suite green

## Accomplishments

- **Pitfall 1 / A1 closed with no remedy needed.** The plan flagged the terminator boundary as the phase's highest residual risk and pre-authorised two fallbacks. Neither was required — keyword extraction arbitrates it, and the fixture proves the terminator is a sibling of the tail.
- **All five capture roles published and vendored.** `command`, `transaction`, `program`, `map`, `mapset` all fire against a fixture exercising both `PROGRAM` forms, and `queries/cics.scm` is byte-identical to `forest-shim/cobol/cics.scm`.
- **Two measured coverage decisions, opposite conclusions, both evidence-led.** Nested subscripts (54/7,971, 0.68%) were modelled because they produced a `MISSING ")"` defect. Comma arguments (4/7,971, 0.05%) were left open because the ERROR is provably contained and closing it needs a lexical precedence on a shared token.
- **`EXEC SQL` non-degradation established against a real baseline parser** — the one result in this phase that the recall number structurally cannot check, since the corpus of record has zero `EXEC SQL`.
- **`conflicts` array still length 0** after every option and operand rule, resolved entirely with static `prec` / `prec.right`.

## Task Commits

1. **Task 1: Option list, argument forms, unparsed tail** — `3f4ea43` (feat)
2. **Task 2: Four named operand nodes and mandatory fixtures** — `43c4e16` (feat)
3. **Task 3: Complete query, extend gate, refresh and vendor** — `aa4fa08` (feat), `36266d0` (test)

Task 3 spans two commits by design: the grammar/query series (b) and the fork-local gate (c) must not ride together (FORK-03). Verified — no commit spans two path constraints, and no commit touched `src/scanner.c`.

## Decisions Made

- **Subscripted data name added as a fifth argument arm.** Not one of D-29's four measured forms, so it needed its own justification: a precise census of the 7,971 parenthesised arguments in the estate's 3,726 blocks found 54 (0.68%) with a nested paren, and without the arm they parse with a `MISSING ")"` recovery node — a defect, not the graceful degradation D-19 intends. COBOL subscripting is generic syntax, so this is not the site-specific hack D-21 forbids.
- **Comma-in-argument gap deliberately left open.** 4 of 7,971 (0.05%). Verified contained: a fixture with the comma form followed by two more paragraphs still yields all 3 `paragraph_header` nodes, so it does not cascade and CICS-03 is not at risk. Closing it would mean a lexical precedence on `integer`, whose regex `/[+-]?[0-9,]+/` wrongly matches a bare comma — an upstream-owned blast radius out of all proportion to 0.05%.
- **`EXEC SQL` reported as changed-but-not-degraded, not as identical.** Baseline `(ERROR (comment_entry))`; now `(ERROR (EXEC) (CICS (MISSING _CICS)) (WORD)×4 (comment_entry))`. Same span, same empty `procedure_division`, still exactly one ERROR, and no node that previously parsed is lost. The fixture records the `MISSING` node explicitly rather than hiding it.

## Deviations from Plan

**1. [Minor - scope] Fifth argument arm not in D-29's four forms**
- **Found during:** Task 1
- **Issue:** Nested subscripts produced a `MISSING ")"` node, which the plan's must-have ("never an ERROR node, never silently dropped") does not admit.
- **Fix:** Added a subscripted-data-name arm, justified by its own census rather than by D-29.
- **Verification:** `exec cics nested subscript argument` fixture green; conflicts still 0.
- **Committed in:** `3f4ea43`

**2. [Minor - tooling] Gate repointed off the `.bin` shim**
- **Found during:** Task 3
- **Issue:** `node_modules/.bin/tree-sitter` resolves the grammar through `node_modules`, so it selects the wrong parser when a second checkout of this grammar exists — which it did, for the baseline comparison.
- **Fix:** `run_cics_query_capture.sh` now defaults `TREE_SITTER` to `node_modules/tree-sitter-cli/tree-sitter`.
- **Verification:** gate exits 0 with all five captures.
- **Committed in:** `36266d0`

**Total deviations:** 2 minor, both evidence-led. No contract or node-name deviation.

## Method Error Found and Corrected

An initial `EXEC SQL` baseline comparison returned "IDENTICAL" and was **wrong**. Two compounding causes:

1. The baseline worktree had `node_modules` symlinked to the main repo, so the CLI resolved the main repo's grammar.
2. More seriously, **the tree-sitter CLI caches compiled parsers by grammar NAME, not by path.** Running `tree-sitter generate` in the baseline worktree silently repointed the shared `cobol` parser, so every subsequent parse in the main repo used the *baseline* parser. The symptom was alarming and misleading: all 11 existing CICS fixtures suddenly reported `EXEC CICS` failing to parse entirely.

The comparison was redone in the correct order (generate-then-measure, per side). This is recorded because any future baseline differential — including plan 03-04's D-31 run — is exposed to the same trap.

## Prohibition Compliance

- **D-30 (must not widen the tail until the census reports zero):** the tail vocabulary is unchanged from the `_idms_operand_token` structure it copies. The two coverage changes were to the *argument* rule, not the tail, and each carries its own census.
- **D-21 (must not hard-code the 25-name option vocabulary):** only the four criterion operands have named nodes. Every other option keyword is plain `$.WORD`.
- **D-22 disclosure carried:** recorded in `queries/cics.scm`'s leading comment and repeated here — 30 of 33 measured `PROGRAM` operands are data names, so `@program` is a variable, not a resolvable edge target, ~91% of the time.
- **D-32:** every fixture name invented and neutral; no estate source text in any tracked file. Censuses report counts only.

## Verification

| Gate | Result |
|------|--------|
| `tree-sitter test -e '^comment$'` | exit 0, 0 failures, 17 CICS cases green |
| `src/grammar.json` conflicts length 0 | 0 |
| `sh run_cics_query_capture.sh` | exit 0, 5 captures |
| no predicates in `queries/cics.scm` | 0 |
| `diff queries/cics.scm forest-shim/cobol/cics.scm` | identical |
| shim Go surface unmodified | clean |
| `forest-shim/refresh.sh` | exit 0, 6/6 steps |
| `src/scanner.c` in any plan commit | 0 |
