---
phase: 03-exec-cics-blocks
status: passed
score: 15/15
verified: 2026-09-11
human_needed: false
gaps_found: false
---

# Phase 3 Verification: EXEC CICS Blocks

## Verdict

**PASSED.** The phase goal is achieved: `EXEC CICS ... END-EXEC` is a named, queryable grammar surface exposing command, transaction, program, map and mapset operands; parse recovery reaches paragraph/data parity; recall exceeds the terminal target; and standard COBOL regressions are zero on both measured populations.

## Goal Verification

| Goal condition | Evidence | Result |
|----------------|----------|--------|
| Named EXEC CICS statement node | `grammar.js` `exec_cics_statement`; 17 green corpus cases | PASS |
| Accurate named operands | `cics_transaction_name`, `cics_program_name`, `cics_map_name`, `cics_mapset_name` | PASS |
| Query extraction | `run_cics_query_capture.sh`: command 8, transaction 1, program 2, map 1, mapset 1 | PASS |
| No grammar conflicts | `src/grammar.json` conflicts length 0 | PASS |
| Local recovery | gortex `TestErrorCascade -count=2`: four shapes at 20/20 paragraphs and 20/20 data items | PASS |
| Recall target | grammar-alone `paragraph_header` 18,234 >= 16,732 | PASS |
| Standard COBOL unchanged | DCC and estate `CLEAN_RECLASSIFIED_COUNT: 0` | PASS |
| Regression suite | corpus exit 0; NIST 371 success, 0 fail, 11 known skips | PASS |
| Graceful-tail coverage | `cics_unparsed_tail` census = 0 on DCC and estate | PASS |
| Separable delivery | docs/planning, grammar, fork-local gate, and cross-repo changes in separate commits | PASS |

## Requirement Traceability

| Requirement | Evidence | Status |
|-------------|----------|--------|
| CICS-01 | `test/corpus/exec_cics.txt`; named `exec_cics_statement`, all measured forms, no ERROR in fixtures | VERIFIED |
| CICS-02 | `queries/cics.scm`; `run_cics_query_capture.sh`; vendored query identical | VERIFIED |
| CICS-03 | gortex commits `99231882`, `bdb98dd1`; RED 1/20, GREEN 20/20 | VERIFIED |
| CICS-04 | `docs/baseline.md` §§5-6; 18,234 >= 16,732, 206.6% residual closure | VERIFIED |
| CICS-05 | corpus green; NIST 371/0/11; DCC and estate zero clean reclassifications | VERIFIED |
| CICS-06 | path-separated commits; invented-neutral fixtures; estate guard remains active | VERIFIED |
| IDMS-05 | reconstructed Phase 1 9,187 -> Phase 2 15,323 -> Phase 3 18,234; tail previously 119 -> 9 | VERIFIED |

All requirement IDs declared by the four PLAN frontmatter blocks are accounted for in `.planning/REQUIREMENTS.md`.

## Must-Have Verification

### Plan 03-01

- D-18 keyword extraction proven for READ, WRITE, DELETE and RETURN without a conflicts entry.
- Ordinary COBOL READ/WRITE remain their original statement nodes in the same fixture.
- One block reaches query, vendored shim and capture gate.
- OQ-1/OQ-2/OQ-3 resolved in `03-FINDINGS.md`.

### Plan 03-02

- All measured argument forms and four named operand nodes are present.
- END-EXEC is a sibling of `cics_unparsed_tail`, never absorbed.
- Bare, zero-option, multi-line and EXEC SQL regression fixtures are green.
- Published and vendored query files are byte-identical; all five captures fire.

### Plan 03-03

- Four representative CICS shapes are independently compared to one immutable clean control.
- Eight hard parity assertions exist.
- SCHEMA SECTION remains logged-only; WORKING-STORAGE remains a negative control.
- Fail-first proof confirms all four paragraph assertions fail at 1/20 on the prior parser.

### Plan 03-04

- Missing Phase 1 baseline reconstructed at 9,187 through an isolated historical parser.
- User confirmed D-16d with explicit IDMS/CICS partition qualifier.
- Phase 3 measured 18,234; no post-measurement grammar tuning occurred.
- DCC and estate differentials report zero clean reclassifications.
- NIST and tail-census gates are green.

## Disclosures and Residual Risks

- **D-22:** 30 of 33 measured PROGRAM operands are data names. The `@program` capture usually identifies a variable, not a resolvable program edge, until DATA DIVISION resolution exists.
- **D-24:** `queries/cics.scm` is a published contract with no gortex production reader today; the fork-local capture gate is its current consumer.
- Four comma-bearing arguments out of 7,971 measured arguments (0.05%) still produce a contained ERROR because the upstream `integer` token matches a bare comma. The error does not cascade; all following paragraphs survive. This is recorded debt, not a phase-goal gap.
- EXEC SQL remains an error before and after Phase 3 with the same span and empty procedure division; recovery now inserts a missing CICS token. Phase 4 owns EXEC SQL parsing.
- Differential clean/trailing-error qualification is a same-row heuristic and is not evidence for multi-line blocks; only clean reclassification counts are used as the hard gate.

## Automated Checks

- `node_modules/tree-sitter-cli/tree-sitter test -e '^comment$'` — PASS.
- `sh run_cics_query_capture.sh` — PASS, all five captures.
- `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -count=2` — PASS.
- `node -e '... conflicts.length ...'` — PASS, zero.
- `diff queries/cics.scm forest-shim/cobol/cics.scm` — PASS.
- `sh run_nist_cobol85.sh` — PASS, 371/0/11.
- DCC/estate compiled-helper differential — PASS, 0 clean reclassifications each.
- DCC/estate `cics_unparsed_tail` census — PASS, 0 each.

## Human Verification

None required. The one-way target decision was handled during execution and the user selected `confirm-with-note`; every delivered behavior has deterministic automated evidence.
