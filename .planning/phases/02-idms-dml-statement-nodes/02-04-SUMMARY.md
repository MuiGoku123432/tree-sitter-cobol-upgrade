---
phase: 02-idms-dml-statement-nodes
plan: 04
subsystem: parser
status: complete
tags: [tree-sitter, grammar-dsl, cobol, idms-dml, regression, differential]

requires:
  - phase: 02-idms-dml-statement-nodes
    provides: idms_navigation_statement, idms_update_statement, idms_session_statement, shared record/set nodes, tail absorber
  - phase: 02-idms-dml-statement-nodes
    provides: run_accept_differential.sh fail-proven ACCEPT differ
provides:
  - idms_accept_statement anchored on a required CURRENCY keyword with optional relative selector
  - completed queries/idms.scm contract across all four IDMS statement classes
  - differential evidence on DCC and the authoritative estate population
  - corrected IDMS ACCEPT syntax model replacing the disproved DB-KEY anchor assumption
affects: [02-05-gortex-delivery, 02-06-measurement]

actuals:
  tasks: 3
  commits: 13

tech-stack:
  added: []
  patterns:
    - TDD standard-form fixtures written before the IDMS rule so reclassification is visible
    - Required trailing anchor keyword as the sole containment mechanism
    - Direct C tree-walker for corpus-scale differential inventories
    - Isolated single-statement census to measure rule coverage independent of parse cascade

key-files:
  created:
    - run_accept_differential_helper.c
  modified:
    - grammar.js
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - test/corpus/idms_accept.txt
    - test/idms/query-sample.cbl
    - queries/idms.scm
    - run_accept_differential.sh

key-decisions:
  - "The DB-KEY trailing anchor from SPEC-001 and 02-RESEARCH assumption A2 was disproved by an estate census and removed. Zero of 2,391 statement-start ACCEPTs anchor on DB-KEY; it appears only as a target identifier."
  - "CURRENCY is the single required anchor, optionally preceded by a NEXT, PRIOR or OWNER relative selector, matching the vendor manual's simple and relative forms."
  - "tree-sitter generate resolved the collision statically. No conflicts: entry and no prec.dynamic were added, so the grammar's structure is itself evidence of containment, not only the differential."
  - "The 12 qualifier-omitted reclassifications are accepted as corrections rather than regressions, on two independent verifications. The literal zero-tolerance gate reading is recorded as a deviation."
  - "The estate acceptance claim rests on the isolated statement census, not the full-file run. Full-file reach is bounded by unrelated upstream parse failures and is not claimed as ACCEPT coverage."

patterns-established:
  - "Where a planning figure and the corpus disagree, the corpus census is reproduced first and the figure is restated, rather than tuning the grammar toward the figure."
  - "A classification gate is evaluated against its intent (do not degrade valid standard COBOL) with deviations evidenced, not against a literal count."

requirements-completed: [IDMS-01, IDMS-03, IDMS-06, IDMS-07]

coverage:
  - id: D1
    description: IDMS ACCEPT forms anchored on CURRENCY parse into idms_accept_statement with the record name captured and no ERROR node.
    requirement: IDMS-01
    verification:
      - kind: unit
        ref: "test/corpus/idms_accept.txt (7 cases); node_modules/.bin/tree-sitter test -i 'idms accept'"
        status: pass
    human_judgment: false
  - id: D2
    description: Standard ACCEPT forms are untouched. accept_statement and _accept_body are byte-identical to their 02-03 state.
    requirement: IDMS-03
    verification:
      - kind: unit
        ref: "three standard-form corpus cases pass; git diff shows no removed line in accept_statement or _accept_body"
        status: pass
      - kind: integration
        ref: "run_accept_differential.sh run 39886c7 DCC: RECLASSIFIED_COUNT 0"
        status: pass
      - kind: integration
        ref: "run_accept_differential.sh run 39886c7 estate: RECLASSIFIED_COUNT 0"
        status: pass
    human_judgment: false
  - id: D3
    description: All four IDMS statement classes expose record and set captures through queries/idms.scm.
    requirement: IDMS-01
    verification:
      - kind: integration
        ref: "node_modules/.bin/tree-sitter query queries/idms.scm test/idms/query-sample.cbl"
        status: pass
    human_judgment: false
  - id: D4
    description: Every documented estate IDMS ACCEPT form is recognised when reachable by the parser.
    requirement: IDMS-01
    verification:
      - kind: integration
        ref: "isolated statement census over all 631 estate CURRENCY forms: 631 idms_accept_statement, 0 accept_statement, 0 parse errors, 0 trailing-error tails"
        status: pass
    human_judgment: false
  - id: D5
    description: Full grammar and NIST suites gain no regression and every commit stays within the grammar family.
    requirement: IDMS-06
    verification:
      - kind: integration
        ref: "node_modules/.bin/tree-sitter test -e '^comment$' (114 pass, 0 fail)"
        status: pass
      - kind: integration
        ref: "sh run_nist_cobol85.sh (371 success, 0 fail, 11 skip)"
        status: pass
      - kind: integration
        ref: "commit-separability and estate-guard over e879646..a489989"
        status: pass
    human_judgment: false

duration: 21h 20m
completed: 2026-09-01
---

# Phase 2 Plan 4: IDMS ACCEPT Containment Summary

**The ACCEPT collision is contained by a required `CURRENCY` anchor resolved statically by the generator, with zero reclassification on both corpora and complete recognition of all 631 documented estate forms. The plan's `DB-KEY` anchor assumption was disproved by the estate itself and removed.**

## Performance

- **Duration:** 21h 20m elapsed
- **Started:** 2026-08-31T10:56:18-05:00
- **Completed:** 2026-09-01T08:16:47-05:00
- **Tasks:** 3
- **Commits:** 13 (3 grammar-family, 9 fork-local harness, 1 correction)

## Accomplishments

- Added `idms_accept_statement` as a separate rule alongside `accept_statement`. Neither `accept_statement` nor `_accept_body` was modified.
- `tree-sitter generate` resolved the collision with static LALR. No `conflicts:` entry and no `prec.dynamic` were introduced, so GLR runtime forking is not paid on any of the 2,391 estate `ACCEPT` occurrences.
- Completed `queries/idms.scm` across all four IDMS statement classes with record and set captures.
- Corrected the IDMS ACCEPT syntax model against the vendor manual and an estate census after the planned `DB-KEY` anchor was disproved.
- Ran the differential on both corpora with zero reclassifications, and established an isolated statement census showing complete coverage of the documented forms.

## Task Commits

1. **Task 1 RED: failing IDMS ACCEPT fixtures** - `32e234e` (`test`)
2. **Task 1 GREEN: anchored IDMS ACCEPT statements** - `b40ece6` (`feat`)
3. **Task 2: complete IDMS query contract** - `64f1339` (`feat`)
4. **Task 3 correction: corrected ACCEPT syntax** - `a489989` (`fix`)

Fork-local harness commits `fcca21c`, `67dec59`, `663d18f`, `602b36b`, `2c78637`, `71f8cf3`, `a7610bc`, `e6d4b33`, `b09dc1d` made the differential runnable at estate scale. They touch only `run_accept_differential*.{sh,c}` and never the grammar family.

## Deviations from Plan

### 1. The DB-KEY anchor was disproved and removed

The plan required exactly two anchors, `CURRENCY` and `DB-KEY`, and forbade changing the anchor set without "a differential result naming the shortfall that justifies it". That evidence arrived.

An estate census over all 2,391 statement-start ACCEPTs in the 1,369-program authoritative population found:

| Signature | Count |
|---|---|
| `ACCEPT W FROM W CURRENCY` | 611 |
| `ACCEPT W FROM CURRENCY` (qualifier omitted) | 12 |
| `ACCEPT W FROM W OWNER CURRENCY` | 6 |
| `ACCEPT W FROM W NEXT CURRENCY` | 1 |
| `ACCEPT DB-KEY FROM W CURRENCY` | 1 |
| **Anchored on a trailing `DB-KEY`** | **0** |
| `DB-KEY` present without `CURRENCY` | **0** |

`DB-KEY` never terminates an IDMS ACCEPT in this estate. It appears only as a target identifier. The vendor manual agrees: both the simple and relative forms end in `CURRENCY`, with `NEXT`, `PRIOR` or `OWNER` preceding it in the relative form. This directly resolves 02-RESEARCH assumption A2, which flagged the `RELATIVE TO` variant's operand tail as unverified. The real relative form is `FROM <set> NEXT|PRIOR|OWNER CURRENCY`, not a `DB-KEY` anchor.

The rule was corrected to require `CURRENCY` with an optional relative selector, and the unreachable `db-key` corpus case was replaced by the two shapes the estate actually contains.

### 2. The 634 acceptance figure was restated as 631

The plan expected CONVERTED to land "near 634" on the estate. That figure was derived from the same disproved `DB-KEY` split. The reproducible census is **631** same-line `CURRENCY` forms. The 634 target was not pursued, because hitting it would have meant tuning the grammar toward a number already shown to rest on a bad assumption.

### 3. Twelve reclassifications accepted against a zero-tolerance gate

In the isolated census, 12 statements moved from a clean `accept_statement` to `idms_accept_statement`. All 12 are exactly one signature, `ACCEPT <target> FROM CURRENCY`, with the qualifier omitted. Under the literal gate this is a failure. Two independent verifications establish that no valid standard COBOL was affected:

- **`CURRENCY` cannot be a mnemonic.** Standard `ACCEPT x FROM <mnemonic>` requires a user-defined word declared in `SPECIAL-NAMES`. `CURRENCY` is a COBOL reserved word and cannot be user-defined. Across 1,369 programs and 177 with a `SPECIAL-NAMES` paragraph, `CURRENCY` is declared as a mnemonic **0** times and the `CURRENCY SIGN` clause appears **0** times. There is no valid standard reading being destroyed, in theory or in this estate.
- **Every affected file is unambiguously IDMS.** The 12 statements live in 5 files. All 5 carry all 7 independent IDMS markers checked: `SCHEMA SECTION`, `SUB-SCHEMA`, `IDMS-STATUS`, `COPY IDMS`, `DB ... WITHIN`, other DML verbs, and `FIND`. **0** files rely on the `CURRENCY` keyword alone for their dialect classification.

These 12 are corrections of a pre-existing misparse. The gate's intent, that no valid standard COBOL degrades, is preserved. Recorded as a deviation rather than silently absorbed.

Note that in the full-file differential run the gate passes literally: `RECLASSIFIED_COUNT` is 0 on both corpora, because those statements are not cleanly parsed in the baseline full-file context either.

## Caveat: what the estate evidence does and does not prove

**The estate acceptance claim rests on the isolated statement census, not on the full-file run.** This is stated plainly because the distinction matters for anyone reading the numbers later.

In full-file mode the estate run recognises **141** `idms_accept_statement` nodes, not 631. This is unchanged by the syntax correction. The cause is upstream parse cascade, not anchor failure: **792 of 836** selected files carry parse errors from unrelated constructs, so most `ACCEPT` statements sit inside error regions and are never reached by any statement rule.

To measure the rule itself, each of the 631 documented forms was extracted into a minimal standalone program and parsed. That census is the D4 evidence.

The honest claim is therefore: **631 of 631 documented forms are recognised when reachable**, with full-file reach bounded by pre-existing parse failures outside this plan's scope. It is **not** a claim that 631 conversions are realised across the estate today. Raising full-file reach is a separate concern and does not belong to ACCEPT containment.

The residual from 02-02 also still stands: the differ inventories node type, position and a cleanliness qualifier, not subtrees. A standard `accept_statement` whose node type is unchanged but whose children changed would pass the gate silently. Static LALR resolution and the byte-identical `_accept_body` partially compensate, but the gate is not claimed to prove more than it proves.

## Verification Evidence

### Differential, DCC corpus of record
- `sh run_accept_differential.sh run 39886c7 <DCC>` - 606 discovered, 451 selected, 0 failed to emit a tree, 0 timed out.
- `RECLASSIFIED_COUNT: 0`, `CONVERTED_COUNT: 2`, `NEW_COUNT: 276`. Records 587 before, 863 after.
- Bit-identical to the pre-correction run, confirming the syntax correction caused no drift.

### Differential, authoritative estate population
- `sh run_accept_differential.sh run 39886c7 estate` - selection asserts 3,781 declared members, 1,369 compilable programs, 836 selected files, 2,391 ACCEPT statements, 0 selection failures.
- 836 walked, **0 failed to emit a tree, 0 timed out**, 792 with parse errors from unrelated constructs.
- `RECLASSIFIED_COUNT: 0`, `CONVERTED_COUNT: 2`, `NEW_COUNT: 328`. Records 1,065 before, 1,393 after.

### Isolated statement census, all 631 documented forms
- 631 cases walked, 0 failed, 0 timed out, 0 parse errors, 0 trailing-error tails.
- After: 631 `idms_accept_statement`, 0 `accept_statement`.
- Before at `39886c7`: 631 `accept_statement`, 619 carrying a trailing error.

| Outcome | Count | Signature |
|---|---|---|
| Converted (trailing error to clean IDMS) | 611 | `ACCEPT W FROM W CURRENCY .` |
| Converted | 6 | `ACCEPT W FROM W OWNER CURRENCY .` |
| Converted | 1 | `ACCEPT W FROM W NEXT CURRENCY .` |
| Converted | 1 | `ACCEPT DB-KEY FROM W CURRENCY .` |
| Reclassified (clean to IDMS) | 12 | `ACCEPT W FROM CURRENCY .` |
| Unchanged or other | 0 | |

619 converted plus 12 reclassified equals 631, complete coverage. The relative `NEXT` and `OWNER` forms now parse fully rather than being absorbed into `idms_unparsed_tail`, and the single `ACCEPT DB-KEY FROM ... CURRENCY` case confirms `DB-KEY` is a target rather than an anchor.

### Suites and guards
- `node_modules/.bin/tree-sitter generate` - exit 0, no conflict reported.
- `node_modules/.bin/tree-sitter test -i 'idms accept'` - 7/7 pass.
- `node_modules/.bin/tree-sitter test -e '^comment$'` - 114 pass, 0 fail, exit 0.
- `sh run_nist_cobol85.sh` - 382 total, 371 success, **0 fail**, 11 skip. Matches the 02-01 and 02-03 baseline.
- `node_modules/.bin/tree-sitter query queries/idms.scm test/idms/query-sample.cbl` - exit 0, captures under all four `idms_*_statement` types including the ACCEPT record capture.
- `sh .githooks/commit-separability.sh --range e879646..a489989` - 13 commits checked, 0 mixed.
- `sh .githooks/estate-guard.sh --range e879646..a489989` - 3 checks pass, 0 failed.
- `grep -cE '^  conflicts:' grammar.js` - 0.
- `skip_tests.txt` unchanged at exactly 11 entries.
- `awk 'length($0) > 72'` over the fixtures and query sample prints nothing.

## Issues Encountered

- **Harness performance at estate scale.** The Tree-sitter CLI reloads a 13 MB parser per file, and its external scanner can ignore `--timeout`. Batch mode renders full ASTs and exceeded a 30-minute budget. Resolved by a direct C tree-walker (`run_accept_differential_helper.c`) emitting only matched nodes, plus a per-file GNU `timeout` wrapper. The stale CLI branch remains in `cmd_snapshot` and is still selected when `snapshot` is invoked directly, which cost a 40-minute timeout during this plan. Calling `run` uses the fast path. Worth removing in a later cleanup.
- **The `snapshot` sub-command is a performance trap.** Documented here so the next reader uses `run`, or drives the helper directly, rather than `snapshot`.
- Tree-sitter CLI continued to print its pre-existing package and config warnings. Commands still exited successfully.

## Next Phase Readiness

- All 14 estate IDMS verbs now parse into named statement nodes. The ACCEPT collision, the phase's named regression gate, is closed with static resolution rather than a runtime heuristic.
- `queries/idms.scm` is complete across all four classes and is the stable contract 02-05 delivers to gortex.
- 02-06 measurement should use the isolated-census figure of 631 documented forms and must not reuse the 634 figure, which this plan disproved.
- Full-file estate reach at 141 is a known, documented ceiling caused by unrelated upstream parse failures. If 02-06 needs realised estate coverage rather than rule coverage, that ceiling is the thing to address, and it is not an ACCEPT problem.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-09-01*
