---
phase: 02-idms-dml-statement-nodes
plan: 09
subsystem: parser
tags: [tree-sitter, cobol, idms, grammar, queries, security]

requires:
  - phase: 02-08
    provides: Verb-specific update syntax and non-graph invalid recovery
  - phase: 02-07
    provides: Exact staged IDMS query gate and security-hardened differential
provides:
  - Exact token-valued verb captures for all 14 IDMS statements
  - Syntax-grounded READY area, known set, and neutral navigation scope nodes
  - Documented ANY, DUPLICATE, FIRST, LAST, PRIOR, numeric, and PAGE-INFO coverage
  - Deterministic generated artifacts and exact capture stream
  - Updated exact role oracle for the corrected graph contract
affects: [02-10, 02-11, idms-query-consumers]

actuals:
  tokens: 9000126
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - Direct visible verb fields on all four public IDMS statement classes
    - Named area and neutral scope nodes excluded from graph-bearing record/set captures
    - Syntax establishes roles; identifier spelling never does

key-files:
  created: []
  modified:
    - grammar.js
    - queries/idms.scm
    - run_idms_query_capture.sh
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - test/corpus/idms_accept.txt
    - test/corpus/idms_navigation.txt
    - test/corpus/idms_session.txt

key-decisions:
  - "Expose IDMS ACCEPT through field('verb', alias($._ACCEPT, $.ACCEPT)) so its capture is exactly the six-character token without changing standard accept_statement."
  - "Treat OWNER and CONNECT/DISCONNECT as syntactically known sets, but represent ordinary and CURRENT WITHIN operands as neutral idms_scope_name nodes because the source syntax cannot distinguish set from area."
  - "Update the gate-owned oracle when graph semantics change, while retaining its external synthetic fixture, exact ranges, deterministic output, and staged diagnostics."

patterns-established:
  - "A published query captures each direct verb field separately from descendant record/set operands."
  - "Semantic uncertainty is represented in the tree and omitted from graph edges rather than guessed from names."

requirements-completed: [IDMS-01, IDMS-02, IDMS-06, IDMS-07]

coverage:
  - id: D1
    description: "All 14 IDMS statement occurrences emit one exact token-valued verb capture, including ACCEPT."
    requirement: IDMS-02
    verification:
      - kind: integration
        ref: "./run_idms_query_capture.sh, exact ordered stream SHA-256 677af93f147b4fd70c80e3c06632a1577619d7d6c99561913da72721a6502b67"
        status: pass
    human_judgment: false
  - id: D2
    description: "READY areas and ambiguous navigation scopes cannot emit false record or set captures; known set contexts remain captured."
    requirement: IDMS-02
    verification:
      - kind: integration
        ref: "two byte-identical IDMS_CAPTURE_OUT runs plus role-negative assertions"
        status: pass
    human_judgment: false
  - id: D3
    description: "Documented navigation selectors and PAGE-INFO parse cleanly with exact operand roles."
    requirement: IDMS-01
    verification:
      - kind: unit
        ref: "tree-sitter test -i 'idms'"
        status: pass
    human_judgment: false
  - id: D4
    description: "Generated artifacts are stable and the grammar-family commit series remains estate-safe and separable."
    requirement: IDMS-07
    verification:
      - kind: integration
        ref: "two pinned generate runs; commit-separability and estate-guard over 844a487..39eea73"
        status: pass
    human_judgment: false
  - id: D5
    description: "Aggregate corpus and NIST COBOL-85 regression gates remain green."
    requirement: IDMS-06
    verification:
      - kind: integration
        ref: "tree-sitter test -e '^comment$'; run_nist_cobol85.sh: 371 success, 0 fail, 11 skip"
        status: pass
    human_judgment: false

duration: 14min
completed: 2026-09-17
status: complete
---

# Phase 02 Plan 09: Exact IDMS Verb and Operand Roles Summary

**Exact one-token verbs for all 14 IDMS statements with syntax-grounded READY areas, known sets, and neutral navigation scopes that cannot create guessed graph edges.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-09-17T15:37:35Z
- **Completed:** 2026-09-17T15:51:00Z
- **Tasks:** 2
- **Implementation files modified:** 9
- **Implementation commits:** 3

## Accomplishments

- Added a direct visible `verb` field to IDMS ACCEPT using a named alias while leaving standard COBOL `accept_statement` unchanged.
- Published exact direct-verb query patterns for navigation, update, session, and ACCEPT classes; all 14 required source statements emit one exact verb token.
- Introduced `idms_area_name` for READY and `idms_scope_name` for syntactically ambiguous navigation WITHIN/CURRENT WITHIN operands.
- Kept `idms_set_name` only in known set contexts, including OWNER and CONNECT/DISCONNECT, and structurally restricted session record capture to BIND.
- Added named corpus cases for ANY, DUPLICATE, FIRST, LAST, PRIOR, numeric selectors, and PAGE-INFO.
- Regenerated all parser artifacts twice with pinned tree-sitter 0.24.5 and proved byte stability.

## Exact Verb Rows

| Source line | Capture | Value |
|-------------|---------|-------|
| 3 | `@verb` | `BIND` |
| 4 | `@verb` | `OBTAIN` |
| 5 | `@verb` | `FIND` |
| 6 | `@verb` | `READY` |
| 7 | `@verb` | `ERASE` |
| 8 | `@verb` | `ACCEPT` |
| 9 | `@verb` | `GET` |
| 10 | `@verb` | `STORE` |
| 11 | `@verb` | `FINISH` |
| 12 | `@verb` | `MODIFY` |
| 13 | `@verb` | `CONNECT` |
| 14 | `@verb` | `ROLLBACK` |
| 15 | `@verb` | `COMMIT` |
| 16 | `@verb` | `DISCONNECT` |

All ranges equal the captured token width. ACCEPT is `(8,7)..(8,13)`, exactly six characters.

## Operand Role Matrix

| Syntax context | AST operand | Published graph capture | Evidence |
|----------------|-------------|-------------------------|----------|
| `READY CUSTOMER-AREA` | `idms_area_name` | none | Exact gate has no record/set row on line 6 |
| `OWNER WITHIN CUST-ORDER-SET` | `idms_set_name` | `@set` | Corpus preserves syntax-known set role |
| `CONNECT ... TO CUST-ORDER-SET` | `idms_set_name` | `@set` | Exact gate line 13 |
| `DISCONNECT ... FROM CUST-ORDER-SET` | `idms_set_name` | `@set` | Exact gate line 16 |
| `FIRST/LAST/NEXT/PRIOR/n WITHIN scope` | `idms_scope_name` | none for scope | Exact gate lines 19-22 omit all prior false set rows |
| `CURRENT WITHIN scope` | `idms_scope_name` | none for scope | Navigation corpus pins neutral node |
| `CALC/ANY/DUPLICATE record` | `idms_record_name` | `@record` | Exact gate lines 4, 17, 18 and named corpus cases |
| `record DB-KEY ... PAGE-INFO ...` | `idms_record_name` only | record only | Exact gate line 23; DB-key/page-info operands are not graph captures |
| `FIND NEXT AREA-REC WITHIN CONTROL-AREA` | record plus neutral scope | record only | Exact gate line 24 omits `CONTROL-AREA` as a guessed set |
| `BIND record` | `idms_record_name` | `@record` | Session query requires direct `verb: (BIND)` |

No suffix or identifier-spelling classifier was added. Role assignment is grammar-position only.

## Task Commits

1. **Task 1: Make every IDMS verb a visible exact field** - `8f5f0a9` (`fix`)
2. **Task 2: Encode syntax-grounded area, set, and neutral scope roles** - `3adaba8` (`fix`)
   - Exact gate/oracle alignment kept in a separate fork-local-family commit - `39eea73` (`test`)

## Exact Commit Paths

| Commit | Family | Paths |
|--------|--------|-------|
| `8f5f0a9` | grammar | `grammar.js`, `queries/idms.scm`, generated `src/`, `test/corpus/idms_accept.txt` |
| `3adaba8` | grammar | `grammar.js`, `queries/idms.scm`, generated `src/`, navigation/session corpus |
| `39eea73` | fork-local test gate | `run_idms_query_capture.sh` only |

`commit-separability.sh --range 844a487..39eea73` reports three commits checked and zero mixed families. `estate-guard.sh` passes all three checks.

## Generated-Artifact Status

- Generator: lockfile-pinned `tree-sitter 0.24.5`.
- Two consecutive runs produced byte-identical artifacts.
- `src/parser.c`: `89532d1acd81cb76720e95b35df395dcdbb2760c98220dd2f331274595bbad71`
- `src/grammar.json`: `11085371e3e0a62be477330f189105e99949594f3d036689d215c94d4256c4ea`
- `src/node-types.json`: `946a9ebea784ffb2f5df9548cc4f832623d2b865124b7cf5bead5d7c631dcbd5`
- Generated node types retain all four statement classes and expose `verb` on each, plus named `idms_area_name` and `idms_scope_name`.

## Deterministic Exact-Gate Evidence

- Gate script SHA-256 after semantic-oracle update: `5219024654ac8af08619dbf9948b9f0d1a91980fbf32872b30581166e101b940`.
- Two normal `IDMS_CAPTURE_OUT` runs were byte-identical.
- Ordered capture SHA-256 for both runs: `677af93f147b4fd70c80e3c06632a1577619d7d6c99561913da72721a6502b67`.
- The positive synthetic subject parses without `ERROR` or `MISSING` markers.
- The staged `--expect-red=verbs` and `--expect-red=roles` modes now return nonzero because their exact historical defects are resolved; normal mode returns `QUERY_CONTRACT_GREEN`.
- `--invalid-only` remains GREEN with zero graph-bearing invalid-update captures.

## Verification Results

| Command | Result |
|---------|--------|
| `tree-sitter generate` twice plus SHA comparison | PASS, byte-identical generated artifacts |
| `tree-sitter test -i 'idms navigation|idms session|idms accept'` | PASS, all focused cases |
| `tree-sitter test -i 'idms'` | PASS, all IDMS corpus cases |
| `tree-sitter test -e '^comment$'` | PASS, all included corpus cases |
| `./run_idms_query_capture.sh` twice with external outputs plus `cmp` | PASS, exact deterministic stream |
| `./run_idms_query_capture.sh --invalid-only` | PASS, no graph-bearing invalid captures |
| Staged verb/role modes after GREEN | PASS, both reject because historical defect sets no longer exist |
| Gate-owned positive subject parse scan | PASS, no error or missing marker |
| `sh run_nist_cobol85.sh` | PASS, 371 success, 0 fail, 11 skip |
| Commit separability and estate guard over plan range | PASS |

## Decisions Made

- Used a named alias only for the hidden ACCEPT token. Existing visible keyword nodes remain direct verb children, and ordinary COBOL ACCEPT remains byte-stable at the grammar rule level.
- Chose neutral `idms_scope_name` for every ambiguous navigation WITHIN operand. Names such as `ORDER-SET` or `CONTROL-AREA` do not determine semantics.
- Kept OWNER as `idms_set_name` because its syntax specifically establishes a set context.
- Limited session record extraction structurally to `verb: (BIND)`, rather than relying only on current descendants.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated the exact gate oracle for neutral scope semantics**
- **Found during:** Task 2 normal exact-gate verification
- **Issue:** The immutable 02-07 future-GREEN oracle still required `@set` rows for four ordinary WITHIN operands, contradicting 02-09's binding neutral-scope semantics. Leaving the script unchanged made correct output fail normal mode.
- **Fix:** Removed ambiguous scope rows from the GREEN oracle, expanded staged role diagnostics to enumerate all former false-set rows, and retained exact range/count/multiplicity checking.
- **Files modified:** `run_idms_query_capture.sh`
- **Verification:** Normal mode passes twice byte-identically; both staged defect modes reject the resolved implementation; gate fixture remains external and synthetic.
- **Committed in:** `39eea73`

**2. [Rule 3 - Blocking] Added the singular DUPLICATE keyword terminal**
- **Found during:** Task 2 generation
- **Issue:** The documented selector required `DUPLICATE`, but the existing grammar exported only plural `DUPLICATES`; generation failed on an undefined symbol.
- **Fix:** Added case-insensitive private `_DUPLICATE` and visible `DUPLICATE` terminals beside their plural counterparts.
- **Files modified:** `grammar.js`, generated `src/`
- **Verification:** Generation and named DUPLICATE corpus/exact-gate cases pass.
- **Committed in:** `3adaba8`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking issue)
**Impact on plan:** Both fixes were necessary to implement the accepted semantic contract. The gate change was isolated from grammar-family commits, and no proprietary source or new dependency was introduced.

## Issues Encountered

- Regenerating after the additional terminals and named operand rules rewrote the large generated parser substantially. Two consecutive pinned-CLI runs were byte-identical, and a final generate left no diff.
- The plan simultaneously called `run_idms_query_capture.sh` immutable and required a GREEN semantic contract incompatible with its old set rows. The semantic requirement controls correctness; the oracle update is explicitly isolated and documented rather than hidden.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: T-02-R01 resolved in 02-07 | `run_accept_differential.sh` | Plan 02-07's physical path containment and synthetic symlink-refusal evidence remains intact; this plan did not modify the differential. |
| threat_flag: T-02-R03 resolved in 02-07 | `run_accept_differential.sh` | Plan 02-07's strict four-column TSV and duplicate-key rejection remains intact; this plan did not modify the comparator. |
| threat_flag: T-02-R05 resolved in 02-08 | `grammar.js`, `test/corpus/idms_update.txt` | Plan 02-08's verb-specific update alternatives and non-graph invalid recovery remain green under focused, aggregate, and invalid-only gates. |
| threat_flag: T-02-R06 resolved | `grammar.js`, `queries/idms.scm`, `run_idms_query_capture.sh` | All 14 required statements emit exactly one token-valued verb; ACCEPT spans exactly `ACCEPT`; two exact outputs are byte-identical. |
| threat_flag: T-02-R07 resolved | `grammar.js`, `queries/idms.scm` | READY area and ambiguous navigation scopes use distinct named nodes excluded from record/set captures; known set contexts remain captured without spelling heuristics. |
| threat_flag: T-02-02 mitigated | `test/corpus/idms_accept.txt`, `test/corpus/idms_navigation.txt`, `test/corpus/idms_session.txt`, `run_idms_query_capture.sh` | Every added fixture is hand-written and synthetic; no proprietary source was read, copied, or committed. |
| threat_flag: none | -- | No additional security-relevant surface was introduced. |

## Known Stubs

None. Empty Python lists in the gate are local accumulator initialization, not placeholder behavior; no TODO, FIXME, skipped test, mock source, or unrun verification remains.

## User Setup Required

None.

## Next Phase Readiness

- Plan 02-10 can refresh the corrected parser/query into the shim and wire the exact GREEN contract into fork-local delivery gates.
- Plan 02-11 can perform final closeout against stable grammar-family commits `8f5f0a9` and `3adaba8` plus isolated gate commit `39eea73`.
- ROADMAP.md and STATE.md remain untouched exactly as requested.

## Self-Check: PASSED

- All nine implementation artifacts and this summary exist in the target worktree.
- Commits `8f5f0a9`, `3adaba8`, and `39eea73` exist on `agent-02-closeout`.
- Exact, focused, aggregate corpus, generated-artifact, NIST, separability, and estate-safety gates pass.
- No untracked or unstaged implementation file remains before summary creation.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-09-17*
