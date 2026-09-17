---
phase: 02-idms-dml-statement-nodes
plan: 08
subsystem: parser
tags: [tree-sitter, cobol, idms, grammar, security]

requires:
  - phase: 02-07
    provides: Exact staged invalid-update query gate and hardened differential evidence
  - phase: 02-06
    provides: Measured ERASE member-option grammar extension
provides:
  - Verb-specific IDMS update alternatives under the stable public statement node
  - Synthetic negative matrix for bare, reversed, and cross-verb update forms
  - Regenerated parser artifacts with deterministic byte output
affects: [02-09, 02-10, 02-11]

actuals:
  tokens: 15409098
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - Verb-specific alternatives beneath one stable public syntax node
    - Private invalid-form recovery aliased to ERROR for deterministic rejection

key-files:
  created: []
  modified:
    - grammar.js
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - test/corpus/idms_update.txt

key-decisions:
  - "Keep idms_update_statement public while defining complete STORE/MODIFY, ERASE, CONNECT, DISCONNECT, and GET alternatives."
  - "Represent the enumerated invalid matrix through a private ERROR-aliased recovery rule so recovery cannot retain partial graph-bearing update operands."

patterns-established:
  - "Negative grammar cases assert ERROR nodes without exposing a public invalid-update node."
  - "Generated parser artifacts are checked for byte stability across two pinned-CLI runs."

requirements-completed: [IDMS-01, IDMS-02, IDMS-06, IDMS-07]

coverage:
  - id: D1
    description: "Update verbs accept only their syntax-grounded operand forms under idms_update_statement."
    requirement: IDMS-01
    verification:
      - kind: unit
        ref: "node_modules/.bin/tree-sitter test -i 'idms update'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Invalid update forms emit no record or set captures from the published query."
    requirement: IDMS-02
    verification:
      - kind: integration
        ref: "./run_idms_query_capture.sh --invalid-only"
        status: pass
    human_judgment: false
  - id: D3
    description: "All focused IDMS corpus tests pass with stable generated artifacts."
    requirement: IDMS-06
    verification:
      - kind: integration
        ref: "node_modules/.bin/tree-sitter test -i 'idms'"
        status: pass
      - kind: other
        ref: "two tree-sitter 0.24.5 generate runs with identical SHA-256 output"
        status: pass
    human_judgment: false
  - id: D4
    description: "Synthetic fixtures and implementation commits remain in the grammar family."
    requirement: IDMS-07
    verification:
      - kind: integration
        ref: "sh .githooks/commit-separability.sh --range 46e94f5..909ca09"
        status: pass
      - kind: integration
        ref: "sh .githooks/estate-guard.sh --range 46e94f5..909ca09"
        status: pass
    human_judgment: false

duration: 47min
completed: 2026-09-17
status: complete
---

# Phase 02 Plan 08: Verb-Specific IDMS Update Grammar Summary

**Verb-specific IDMS update parsing rejects prohibited operand combinations without exposing false record or set captures, while preserving the published update node contract.**

## Performance

- **Duration:** 47 min
- **Started:** 2026-09-17T14:46:22Z
- **Completed:** 2026-09-17T15:33:28Z
- **Tasks:** 2
- **Files modified:** 6, including this summary

## Accomplishments

- Added a synthetic RED matrix covering bare operand-required verbs, reversed CONNECT/DISCONNECT prepositions, set clauses on record-only verbs, and member options on non-ERASE verbs.
- Replaced the shared optional update body with complete verb-specific alternatives while retaining `idms_update_statement`, `idms_record_name`, and `idms_set_name`.
- Made all prohibited matrix forms produce explicit non-graph `ERROR` nodes and zero record/set query captures.
- Regenerated `src/parser.c`, `src/grammar.json`, and `src/node-types.json` twice with the pinned tree-sitter 0.24.5 CLI and confirmed byte stability.

## RED/GREEN Invalid-Shape Matrix

| Invalid shape | RED before grammar change | GREEN after grammar change |
|---------------|---------------------------|----------------------------|
| Bare STORE/MODIFY/ERASE/CONNECT/DISCONNECT | Each parsed as a clean `idms_update_statement` | Each parses as an `ERROR` node with no graph operands |
| CONNECT FROM / DISCONNECT TO | Clean update nodes with false record/set children | `ERROR` nodes with no record/set captures |
| STORE/MODIFY/GET with TO or FROM | Clean update nodes with false record/set children | `ERROR` nodes with no record/set captures |
| STORE/MODIFY/CONNECT/DISCONNECT/GET member options | Clean or partial update shapes before correction | `ERROR` nodes with no record/set captures |
| Bare GET | Legal positive control | Remains a clean `idms_update_statement` |

## Task Commits

1. **Task 1: Commit the complete invalid-update RED matrix** - `7256b32` (`test`)
2. **Task 2: Implement verb-specific update syntax and regenerate** - `c32f413` (`fix`)
   - Follow-up verification marker - `909ca09` (`fix`, empty commit; no file paths)

## Exact Commit Paths

| Commit | Paths |
|--------|-------|
| `7256b32` | `test/corpus/idms_update.txt` |
| `c32f413` | `grammar.js`, `src/grammar.json`, `src/node-types.json`, `src/parser.c`, `test/corpus/idms_update.txt` |
| `909ca09` | None; empty verification marker |

All commits pass `.githooks/commit-separability.sh`; neither grammar-family commit contains fork-local, shim, documentation, CI, or planning paths.

## Files Created/Modified

- `grammar.js` - Complete verb-specific update alternatives plus private ERROR-aliased recovery for the enumerated prohibited forms.
- `src/parser.c` - Regenerated parser implementation.
- `src/grammar.json` - Regenerated grammar representation.
- `src/node-types.json` - Regenerated node contract retaining the three published update/operand types.
- `test/corpus/idms_update.txt` - Positive controls and 19 named synthetic negative cases.
- `.planning/phases/02-idms-dml-statement-nodes/02-08-SUMMARY.md` - Execution, verification, and threat evidence.

## Generated-Artifact Status

- Generator: lockfile-pinned `tree-sitter 0.24.5`.
- Two consecutive generator runs produced identical SHA-256 values for all three generated artifacts.
- Final hashes:
  - `src/parser.c`: `d98855384931451f749a4d2cc8bae6375312eaf9832d559b09432d95a11e7964`
  - `src/grammar.json`: `cd2e0aa03f65eda15b3f7523c5bfcebd3b733f825bd3ef18da4f5432a2ae4404`
  - `src/node-types.json`: `bca6592bf5ffa02faebc6109fd2996619bef000369055cf6c4ed15ab2921996a`

## Verification Results

| Command | Result |
|---------|--------|
| `node_modules/tree-sitter-cli/tree-sitter generate` | PASS |
| `node_modules/.bin/tree-sitter test -i 'idms update'` | PASS, 27 focused cases |
| `node_modules/.bin/tree-sitter test -i 'idms'` | PASS, all focused IDMS cases |
| `./run_idms_query_capture.sh --invalid-only` | PASS, zero graph-bearing invalid captures |
| Two generate runs plus SHA-256 comparison | PASS, byte-stable artifacts |
| Public-node JSON assertions | PASS for update, record, and set node names |
| `node_modules/.bin/tree-sitter test -e '^comment$'` | PASS, all included corpus cases |
| `bash .githooks/estate-guard-selftest.sh` | PASS |
| Commit separability over `46e94f5..909ca09` | PASS, three commits and zero mixed families |
| Estate guard over `46e94f5..909ca09` | PASS |
| `npm test` | Expected pre-existing `comment` fixture failure only; all other 166 cases pass |

## Decisions Made

- Kept the six legal update alternatives inside one public `idms_update_statement`; no consumer-facing node was renamed.
- Attached `idms_unparsed_tail` only to ERASE after its legal option slot. Record-only and record-plus-set alternatives cannot use a tail to legalize incompatible clauses.
- Added a private invalid-form recovery rule aliased to `ERROR`. Tree-sitter recovery otherwise retained a valid STORE/MODIFY/GET prefix before the illegal suffix, allowing the descendant-only query to emit a false record capture.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added deterministic invalid-form recovery**
- **Found during:** Task 2 query-gate verification
- **Issue:** Verb-specific legal alternatives alone let tree-sitter recover a valid STORE, MODIFY, or GET prefix before an illegal suffix, so the existing descendant query still emitted a record capture.
- **Fix:** Added a private `_idms_invalid_update_statement` rule, exposed only as `ERROR`, for the enumerated prohibited forms. This keeps the invalid text inside the procedure division without emitting `idms_update_statement`, `idms_record_name`, or `idms_set_name`.
- **Files modified:** `grammar.js`, generated `src/`, `test/corpus/idms_update.txt`
- **Verification:** Focused and aggregate IDMS corpus pass; `--invalid-only` reports `INVALID_CONTRACT_GREEN`.
- **Committed in:** `c32f413`

**2. [Rule 2 - Missing Critical] Expanded the negative matrix to every stated cross-verb category**
- **Found during:** Task 2 acceptance review
- **Issue:** The initial RED examples covered representative categories but did not independently pin both TO/FROM variants or every non-ERASE member-option verb.
- **Fix:** Added synthetic STORE FROM, MODIFY TO, GET FROM, and per-verb member-option cases before final verification.
- **Files modified:** `test/corpus/idms_update.txt`, `grammar.js`, generated `src/`
- **Verification:** All 27 update cases and the exact invalid-only gate pass.
- **Committed in:** `c32f413`; follow-up verification recorded by `909ca09`

---

**Total deviations:** 2 auto-fixed (2 missing critical)
**Impact on plan:** Both additions enforce the plan's stated security invariant. No query, shim, CI, dependency, ROADMAP, STATE, or unrelated source change was introduced.

## Issues Encountered

- Tree-sitter's normal error recovery initially retained valid-looking update prefixes when an illegal suffix followed. The private ERROR-aliased recovery rule closed that graph-extraction hole.
- The pinned generator rewrote the large generated parser artifact substantially but deterministically; two consecutive runs were byte-identical.
- Gortex indexed the source symbol but does not map tree-sitter corpus fixtures as test relationships. Its contract check allowed the public-node change at low graph risk; executable corpus and query gates supply the behavioral evidence.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: T-02-R01 resolved in 02-07 | `run_accept_differential.sh` | Plan 02-07's symlink-safe physical containment evidence remains intact; this plan did not modify the differential. |
| threat_flag: T-02-R03 resolved in 02-07 | `run_accept_differential.sh` | Plan 02-07's strict TSV and duplicate-key rejection evidence remains intact; this plan did not modify the comparator. |
| threat_flag: T-02-R05 resolved | `grammar.js`, `test/corpus/idms_update.txt` | Verb-specific legal alternatives plus ERROR-aliased invalid recovery make all matrix cases non-graph-bearing; focused corpus and `--invalid-only` pass. |
| threat_flag: T-02-R06 staged for 02-09 | `queries/idms.scm`, `run_idms_query_capture.sh` | Update invalid-shape semantics are green, but all-verb and operand-role query corrections remain explicitly assigned to plan 02-09. |
| threat_flag: none | -- | No additional security-relevant surface was introduced. |

## Known Stubs

None. No placeholder implementation, empty runtime data source, skipped test, or unrun plan verification remains.

## User Setup Required

None.

## Next Phase Readiness

- Plan 02-09 can update verb and operand-role query semantics on the corrected parser.
- `run_idms_query_capture.sh --invalid-only` is GREEN; normal and role stages remain intentionally owned by 02-09.
- ROADMAP.md and STATE.md were intentionally left unchanged for shared-phase orchestration.

## Self-Check: PASSED

- All five implementation artifacts exist.
- Commits `7256b32`, `c32f413`, and `909ca09` exist on `agent-02-closeout`.
- Every plan verification command passed, generated artifacts are byte-stable, and the worktree was clean before summary creation.
- Commit-family and estate guards pass for the full plan range.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-09-17*
