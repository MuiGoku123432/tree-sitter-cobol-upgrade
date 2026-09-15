---
phase: 02-idms-dml-statement-nodes
plan: 03
subsystem: parser
status: complete
tags: [tree-sitter, grammar-dsl, cobol, idms-dml, regression]

requires:
  - phase: 02-idms-dml-statement-nodes
    provides: idms_navigation_statement, shared record/set nodes, tail absorber, and fork-local gates
provides:
  - idms_update_statement for STORE, MODIFY, ERASE, CONNECT, DISCONNECT, and GET
  - idms_session_statement for BIND, READY, FINISH, COMMIT, and ROLLBACK
  - record/set query captures for update statements and record capture for BIND
  - zero-regression evidence across corpus, IDMS, NIST, separability, and estate guards
affects: [02-04-accept-containment, 02-05-gortex-delivery, 02-06-measurement]

actuals:
  tokens: 15257031
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - TDD corpus fixtures before each IDMS verb-class implementation
    - Shared idms_record_name, idms_set_name, and idms_unparsed_tail query contract
    - Static prec.right choices without GLR conflicts

key-files:
  created:
    - test/corpus/idms_update.txt
    - test/corpus/idms_session.txt
  modified:
    - grammar.js
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - test/idms/query-sample.cbl
    - queries/idms.scm

key-decisions:
  - "Both BIND RUN-UNIT and BIND record-name are modeled; the record operand remains optional rather than assuming one estate shape."
  - "Update and session statements reuse the exact idms_record_name, idms_set_name, and idms_unparsed_tail nodes established by 02-01."
  - "Static prec.right choices generated successfully; no conflicts entry or dynamic precedence was introduced."

patterns-established:
  - "Operand-free forms remain explicit green cases: GET, READY, FINISH, and COMMIT parse without synthetic record children or ERROR nodes."
  - "CONNECT and DISCONNECT expose record and set as siblings under one idms_update_statement."

requirements-completed: [IDMS-01, IDMS-02, IDMS-06, IDMS-07]

coverage:
  - id: D1
    description: Six update verbs parse into idms_update_statement, including operand-free GET and tail absorption.
    requirement: IDMS-01
    verification:
      - kind: unit
        ref: "test/corpus/idms_update.txt (8 cases); node_modules/.bin/tree-sitter test -i 'idms update'"
        status: pass
    human_judgment: false
  - id: D2
    description: Five session verbs parse into idms_session_statement, including both BIND forms and operand-free forms.
    requirement: IDMS-01
    verification:
      - kind: unit
        ref: "test/corpus/idms_session.txt (10 cases); node_modules/.bin/tree-sitter test -i 'idms session'"
        status: pass
    human_judgment: false
  - id: D3
    description: Update statements expose record and set captures, while BIND record form exposes a record capture.
    requirement: IDMS-02
    verification:
      - kind: integration
        ref: "node_modules/.bin/tree-sitter query queries/idms.scm test/idms/query-sample.cbl"
        status: pass
    human_judgment: false
  - id: D4
    description: Full grammar and NIST suites gain no regression and every implementation commit remains grammar-family-only.
    requirement: IDMS-06
    verification:
      - kind: integration
        ref: "node_modules/.bin/tree-sitter test -e '^comment$' (108 pass)"
        status: pass
      - kind: integration
        ref: "sh run_nist_cobol85.sh (371 success, 0 fail, 11 skip)"
        status: pass
      - kind: integration
        ref: "commit-separability and estate-guard checks over 138bd6c..1084811"
        status: pass
    human_judgment: false

duration: 14h 34m
completed: 2026-08-31
---

# Phase 2 Plan 3: IDMS Update and Session Statements Summary

**Thirteen non-ACCEPT IDMS verbs now parse into deterministic update, session, and navigation nodes with shared record/set captures and no regression across the corpus or NIST suites.**

## Performance

- **Duration:** 14h 34m elapsed across interrupted executor sessions
- **Started:** 2026-08-30T20:13:46-05:00
- **Completed:** 2026-08-31T15:49:26Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Added `idms_update_statement` for STORE, MODIFY, ERASE, CONNECT, DISCONNECT, and GET, including record-plus-set siblings for CONNECT/DISCONNECT and operand-free GET.
- Added `idms_session_statement` for BIND, READY, FINISH, COMMIT, and ROLLBACK, including both documented BIND shapes and operand-free session forms.
- Extended `queries/idms.scm` and the hand-written query sample without splitting the shared record/set node contract.
- Passed 28 aggregate IDMS cases, 108 non-comment corpus cases, NIST at 371 success / 0 fail / 11 skip, and all fork-separability and estate guards.

## Task Commits

1. **Task 1 RED: IDMS update fixtures** - `672b948` (`test`)
2. **Task 1 GREEN: IDMS update statements** - `571a1c0` (`feat`)
3. **Task 2 RED: IDMS session fixtures** - `0fcaaf1` (`test`)
4. **Task 2 GREEN: IDMS session statements** - `1084811` (`feat`)

## Files Created/Modified

- `test/corpus/idms_update.txt` - Eight hand-written update-statement cases.
- `test/corpus/idms_session.txt` - Ten hand-written session-statement cases.
- `grammar.js` - Update/session statement rules, keyword terminals, and exports.
- `src/parser.c` - Regenerated parser implementation.
- `src/grammar.json` - Regenerated grammar representation.
- `src/node-types.json` - Regenerated public node contract.
- `test/idms/query-sample.cbl` - CONNECT, DISCONNECT, and BIND query inputs.
- `queries/idms.scm` - Update record/set and session record captures.

## Decisions Made

- Reused the exact 02-01 operand node names and tail absorber so downstream queries have one stable contract.
- Modeled both `BIND RUN-UNIT` and `BIND record-name`; no estate-frequency assumption narrowed the grammar.
- Used `prec.right` within the verb-class bodies. Generation succeeded without a top-level `conflicts:` entry or `prec.dynamic`.

## Deviations from Plan

None in product scope. The planned implementation and validation were completed as specified.

## Issues Encountered

- Two executor dispatches lost their completion signal after making progress. The first left Task 1 RED plus an unstaged GREEN implementation; the second committed Task 1 GREEN and Task 2 RED, then left Task 2 GREEN unstaged. Recovery inspected every commit and unstaged diff, confirmed no executor process remained, reran generation and focused tests, committed only the coherent remaining implementation, and ran Task 3 inline. No work was reset or discarded.
- Gortex correctly rated the broad grammar diff as critical reach, then returned a low-risk contract verdict for the new session-node signature. Its test-edge analysis reports the grammar symbol uncovered because Tree-sitter corpus fixtures are not indexed as test relationships; the concrete corpus, query, NIST, and guard commands above are the verification evidence.
- Tree-sitter CLI repeatedly printed its pre-existing package/config warnings. Commands still exited successfully and produced the expected parser/tests.

## Verification Evidence

- `node_modules/.bin/tree-sitter generate` - exit 0; repeated regeneration left a coherent generated diff before commit.
- `node_modules/.bin/tree-sitter test -i 'idms update'` - 8/8 pass.
- `node_modules/.bin/tree-sitter test -i 'idms session'` - 10/10 pass.
- `node_modules/.bin/tree-sitter test -i 'idms'` - 28/28 IDMS corpus cases pass; query sample parses.
- `node_modules/.bin/tree-sitter test -e '^comment$'` - 108/108 included cases pass.
- `sh run_nist_cobol85.sh` - 382 total, 371 success, 0 fail, 11 skip; matches the 02-01 `Fail: 0` baseline.
- `sh .githooks/commit-separability.sh --range 138bd6c..1084811` - 4 commits checked, 0 mixed.
- `sh .githooks/estate-guard.sh --range 138bd6c..1084811` - all 3 checks pass.
- `bash .githooks/estate-guard-selftest.sh` - all 9 synthetic cases and both real-repo checks pass.
- `skip_tests.txt` remains unchanged with exactly 11 non-empty entries.
- All added fixture/query-sample COBOL lines are at most 72 bytes.

## Next Phase Readiness

- Thirteen non-ACCEPT verbs are complete; only the intentionally isolated ACCEPT collision remains for plan 02-04.
- The fail-proven ACCEPT differ from 02-02 is ready to measure standard-COBOL containment.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-08-31*
