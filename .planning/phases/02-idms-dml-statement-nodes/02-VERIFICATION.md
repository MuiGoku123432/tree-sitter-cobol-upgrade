---
phase: 02-idms-dml-statement-nodes
verified: 2026-09-16T14:15:31Z
status: gaps_found
score: 4/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "IDMS operands are semantically correct and the published query is complete enough for graph extraction."
    status: failed
    severity: blocker
    requirement_ids: [IDMS-01, IDMS-02]
    reason: "The query omits verb captures for update and session statements and captures the whole ACCEPT statement as @verb; READY areas are emitted as records; documented navigation alternatives are missing or mislabeled; and invalid update-verb shapes produce clean named nodes and false record/set captures."
    artifacts:
      - path: "grammar.js"
        issue: "idms_update_statement shares one optional, cross-verb body; non-GET bodies can be absent and incompatible TO/FROM/ERASE clauses are accepted. READY uses idms_record_name for an area, and navigation does not model DUPLICATE or distinguish an area from a set."
      - path: "queries/idms.scm"
        issue: "Only navigation verbs are token captures; update/session verbs are absent and ACCEPT's entire statement node is labeled @verb. The generic session record pattern also captures READY area names as records."
      - path: "test/corpus/idms_update.txt"
        issue: "No negative cases reject bare operand-required verbs or incompatible clauses."
      - path: "test/corpus/idms_navigation.txt"
        issue: "No coverage for DUPLICATE, FIRST/LAST/PRIOR/numeric selectors, PAGE-INFO, or distinct area semantics."
    missing:
      - "Make update syntax verb-specific: required records for STORE/MODIFY/ERASE/CONNECT/DISCONNECT, TO only for CONNECT, FROM only for DISCONNECT, and ERASE options only for ERASE."
      - "Represent area operands distinctly and prevent READY/area navigation forms from emitting @record or @set graph captures."
      - "Capture one verb token for every one of the 14 verbs, including ACCEPT, and add exact query-output assertions."
      - "Add positive coverage for documented navigation alternatives and negative coverage for invalid update forms."
  - truth: "The ACCEPT ambiguity is provably contained by a trustworthy differential and its proprietary-output boundary."
    status: failed
    severity: blocker
    requirement_ids: [IDMS-03, IDMS-07]
    reason: "The security claims are reproducibly false: symlinked output/scratch paths bypass repository containment, and duplicate inventory keys overwrite map entries so a real clean-to-IDMS reclassification can report RECLASSIFIED_COUNT: 0. The standalone snapshot path also accepts malformed node regexes as a clean empty census."
    artifacts:
      - path: "run_accept_differential.sh"
        issue: "path_is_under_repo uses logical pwd on candidate parents rather than a symlink-resolved physical path; cmd_compare neither validates four-column TSV nor rejects duplicate path+position keys; cmd_snapshot does not validate NODE_TYPE_REGEX or propagate the grep/sed failure."
      - path: "run_accept_differential_selftest.sh"
        issue: "No symlink-bypass, duplicate-key, or snapshot malformed-node-regex cases; the file is mode 100644 and the self-test is absent from CI."
    missing:
      - "Canonicalize existing parents/directories through symlinks and compare paths with path-aware containment before any output is created."
      - "Validate strict four-column inventories and reject duplicate keys before comparison."
      - "Validate snapshot node regexes and fail closed on extraction-pipeline errors."
      - "Add the adversarial cases to the self-test and run it in CI."
  - truth: "Regression and delivery gates continuously enforce the Phase 2 query, differential, and shim contracts."
    status: partial
    severity: warning
    requirement_ids: [IDMS-02, IDMS-03, IDMS-06, IDMS-07]
    reason: "Focused corpus and NIST tests are green, but fork CI runs only generation and the non-comment corpus suite. It does not run the differential self-test, assert exact IDMS query output, compare the shim query, or load the embedded query. refresh.sh also continues into copy/rewrite/build after generation or copy failure, allowing stale or mixed artifacts to appear validated before the final nonzero exit."
    artifacts:
      - path: ".github/workflows/fork-checks.yml"
        issue: "No differential self-test, query contract, shim parity, or embedded-query step."
      - path: "forest-shim/refresh.sh"
        issue: "Steps 3-6 are not skipped after Step 2 failure, and Steps 4-6 are not skipped after Step 3 failure."
    missing:
      - "Wire the differential adversarial self-test and exact 14-verb query assertions into CI."
      - "Check source/shim query identity and compile/load the embedded IDMS query in CI."
      - "Abort or stage atomically after generation/copy failure so stale or mixed shim output is never tested as current."
  - truth: "All Phase 2 completion records and plan gates accurately reflect executable verification."
    status: partial
    severity: warning
    requirement_ids: [IDMS-03, IDMS-06, IDMS-07]
    reason: "The phase validation contract remains draft and non-Nyquist-compliant, ROADMAP still reports 4/6 plans executed despite six summaries, and the documented self-test is not directly executable. These records overstate closure and leave the hard gate vulnerable to rot."
    artifacts:
      - path: ".planning/phases/02-idms-dml-statement-nodes/02-VALIDATION.md"
        issue: "status is draft, nyquist_compliant is false, and Wave 0 remains unchecked."
      - path: ".planning/ROADMAP.md"
        issue: "Phase 2 still says 4/6 plans executed and marks 02-05 unchecked."
      - path: "run_accept_differential_selftest.sh"
        issue: "Git mode is 100644, so direct invocation fails."
    missing:
      - "Close the validation map only after adversarial and exact query tests are wired."
      - "Reconcile roadmap plan/progress state with the actual six plan summaries."
      - "Make the self-test executable and continuously run it."
warnings:
  - id: WR-01
    requirement_ids: [IDMS-02]
    summary: "READY area names are emitted as @record."
  - id: WR-02
    requirement_ids: [IDMS-03, IDMS-05]
    summary: "Malformed snapshot node regexes return success with an empty census."
  - id: WR-03
    requirement_ids: [IDMS-03, IDMS-06]
    summary: "The differential self-test is mode 100644 and cannot be invoked directly."
  - id: WR-04
    requirement_ids: [IDMS-02, IDMS-03, IDMS-06]
    summary: "CI omits exact query and differential safety gates."
  - id: WR-05
    requirement_ids: [IDMS-07]
    summary: "Shim refresh continues after generation or copy failure and can test stale/mixed output."
  - id: WR-06
    requirement_ids: [IDMS-01, IDMS-02]
    summary: "Navigation syntax and role coverage omit documented alternatives and conflate area with set."
---

# Phase 2: IDMS DML Statement Nodes Verification Report

**Phase Goal:** IDMS DML statements are walkable AST nodes whose record and set operands can be queried, the `ACCEPT` ambiguity is contained, and recall impact is measured.
**Verified:** 2026-09-16T14:15:31Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Verdict

The goal is not achieved. The parser exposes named IDMS nodes and focused positive fixtures pass, but the graph extraction contract is semantically unsafe and incomplete. The four high-severity findings in `02-SECURITY.md` were independently confirmed against the shipped code. They are blockers, not speculative review comments.

No proprietary source was read or quoted during this verification. Synthetic, hand-written inputs were used for adversarial probes.

## Goal Achievement

### Observable Truths and Requirement Coverage

| # | Requirement | Truth | Status | Actual evidence |
|---|-------------|-------|--------|-----------------|
| 1 | IDMS-01 | All 14 verbs are named, walkable statement nodes with accurate, semantically valid shapes rather than ERROR nodes | FAILED -- BLOCKER | A synthetic 14-verb parse produced a named node and no ERROR for every verb, and the 36 focused IDMS corpus cases pass. However, `grammar.js:2696-2723` accepts invalid bare STORE/MODIFY/ERASE and incompatible cross-verb clauses as clean `idms_update_statement` nodes. The implementation therefore creates valid-looking ASTs for invalid shapes and cannot satisfy the semantic part of the goal. |
| 2 | IDMS-02 | Record and set operands can be queried as correct named captures | FAILED -- BLOCKER | `queries/idms.scm` returns real record/set captures and is byte-identical in the shim, but READY areas are `idms_record_name`/`@record`, navigation areas are `idms_set_name`/`@set`, and invalid update clauses emit false set captures. The query also omits update/session verb captures and labels the full ACCEPT statement as `@verb`. |
| 3 | IDMS-03 | Standard COBOL ACCEPT is provably unaffected and the ambiguity is contained | FAILED -- BLOCKER | Standard/IDMS ACCEPT corpus cases pass and the rule requires `CURRENCY`, but the proof mechanism is unsound. A duplicate-key after inventory containing an IDMS row followed by a standard row returned exit 0 and `RECLASSIFIED_COUNT: 0`. The symlink boundary also permits proprietary inventories under the public repo. |
| 4 | IDMS-04 | A valid procedural IDMS statement no longer cascades into following paragraphs/data items | VERIFIED | External gortex `TestErrorCascade` contains hard assertions against an immutable 20/20 control. `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -count=2 -args -enhanced-parser` passed. The DATA DIVISION placement is correctly retained as a negative control because procedural DML is invalid there. |
| 5 | IDMS-05 | Recall impact rises on the corrected grammar-alone axis and tail coverage is measured | VERIFIED | The later corrected requirement uses `paragraph_header`: Phase 1 9,187 to Phase 2 15,323, a measured +6,136; `idms_unparsed_tail` fell 119 to 9. Evidence is recorded in `docs/baseline.md` §§5-6 and the Phase 3 verification. The original `dataItems` axis remained flat and was explicitly retired as mis-specified. |
| 6 | IDMS-06 | Corpus and NIST regressions remain green | VERIFIED | `tree-sitter test -e '^comment$'` passed with all included fixtures; independent NIST run completed `382 tests. (Success: 371, Fail: 0, Skip: 11)`. CI nevertheless has warning-level coverage gaps noted below. |
| 7 | IDMS-07 | Delivery is separable and proprietary data cannot cross into tracked/public output | FAILED -- BLOCKER | Commit-history inspection found no mixed grammar/fork-local Phase 2 commit, fixtures are synthetic, and the estate guard self-test passes. However, the Phase 2 differential's explicit proprietary-output boundary is bypassable through an external symlink targeting the repo. Synthetic snapshot probe exited 0 and created the repository file. |
| 8 | IDMS-08 | Recall impact is converted into a concrete, auditable target | VERIFIED | OQ-3 was measured, then re-scoped with evidence onto `paragraph_header`. The record now carries Phase 1 9,187, Phase 2 15,323, residual 1,409, terminal target 16,732, and the later Phase 3 result 18,234. The earlier `dataItems >= 18,772` target is explicitly withdrawn. |

**Score:** 4/8 requirements verified

### Roadmap Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Query returns record/set and all 14 verbs are valid named statements | FAILED | Positive parsing exists, but operand semantics and update grammar are unsound; the query's verb contract is incomplete/incorrect. |
| Standard COBOL ACCEPT is exactly preserved and proved by differential | FAILED | Positive fixtures pass, but the comparator can return false clean on duplicate keys. The roadmap's stale `DB-KEY` tail wording was corrected by measured evidence to a required `CURRENCY` anchor. |
| IDMS cascade parity | VERIFIED | Focused enhanced-parser cascade test passes twice with hard assertions. |
| Recall rises and yields a concrete target | VERIFIED on corrected contract | `paragraph_header` increased 9,187 to 15,323 during IDMS; tail 119 to 9; corrected target is on file. |
| Separable, regression-safe, estate-safe delivery | FAILED | Commit boundaries and test suites pass, but the proprietary-output symlink bypass violates the hard estate-safety constraint. |

## Required Artifacts

| Artifact | Exists | Substantive | Wired | Status | Details |
|----------|--------|-------------|-------|--------|---------|
| `grammar.js` IDMS rules | yes | yes | yes, through `_statement` | FAILED | Four named classes are integrated, but update syntax is over-permissive and operand roles are semantically conflated. |
| `src/parser.c`, `src/grammar.json`, `src/node-types.json` | yes | yes | yes | VERIFIED | Regeneration completed; a post-generate diff check found no drift, and all seven public IDMS node names are present. |
| `test/corpus/idms_*.txt` | yes | yes | yes, collected by tree-sitter | PARTIAL | 36 positive cases pass. Missing negative update cases and documented navigation/role alternatives. |
| `queries/idms.scm` | yes | yes | yes, CLI and shim | FAILED | Record/set patterns execute, but verb captures and semantic roles are wrong/incomplete. |
| `run_accept_differential.sh` | yes, executable | yes | used manually | FAILED | Comparator and path-boundary blockers reproduced; malformed snapshot regex also returns false success. |
| `run_accept_differential_selftest.sh` | yes | yes | not in CI; not executable | WARNING | Existing synthetic cases do not cover the reproduced blockers. |
| `.github/workflows/fork-checks.yml` | yes | yes | push-to-main | WARNING | Runs generation and corpus only; hard query/differential/shim contracts are absent. |
| `forest-shim/cobol/idms.scm` and embed surface | yes | yes | yes | VERIFIED | Source and shim query files compare byte-identically; `go test ./...` in the shim module passes; `plugin.go` embeds `*.scm`. |
| gortex `cascade_test.go` | yes, cross-repo | yes | yes, enhanced parser | VERIFIED | Hard IDMS parity assertions pass with `-enhanced-parser`; invalid DATA DIVISION placement remains a negative control. |
| `docs/baseline.md` | yes | yes | linked from requirements/project | VERIFIED | Contains raw measurements, tail census, corrected axis, and target history. |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `grammar.js` | generated parser artifacts | `tree-sitter generate` | WIRED | Generation succeeds and leaves no generated diff. |
| IDMS grammar classes | statement parser | `_statement` choice at `grammar.js:1380-1402` | WIRED | All four classes are reachable wherever procedural statements are legal. |
| Operand nodes | `queries/idms.scm` | named `idms_record_name` / `idms_set_name` patterns | PARTIAL | Mechanically wired, semantically wrong for areas and invalid cross-verb clauses. |
| `queries/idms.scm` | gortex shim | `refresh.sh` copy plus `//go:embed grammar.json *.scm` | WIRED | Byte-identical file and shim module tests pass. |
| ACCEPT parser change | differential verdict | snapshot inventories and `cmd_compare` | NOT TRUSTWORTHY | Duplicate keys overwrite prior values and can hide the exact regression the link is meant to detect. |
| corpus-derived output | public-repo boundary | `path_is_under_repo` | NOT WIRED SAFELY | Symlink target is not physically resolved; boundary bypass reproduced. |
| IDMS parser | cascade gate | local shim selected by gortex workspace | WIRED | Enhanced-parser test passes with hard assertions. |
| measurement | requirements/roadmap | `docs/baseline.md` §§4-6 | WIRED | Corrected recall axis and target are traceable. |

## Data-Flow Trace

| Source | Flow | Consumer | Status |
|--------|------|----------|--------|
| COBOL source spans | parser emits named record/set nodes | `queries/idms.scm` | FAILED SEMANTICS | Real data flows, but areas and invalid clauses can become false graph operands. |
| Query source | refresh copy | shim embedded files | FLOWING | Source and embedded copy are identical. |
| Baseline/current AST nodes | helper/snapshot TSV | `cmd_compare` maps and verdict | FAILED INTEGRITY | Duplicate keys silently overwrite earlier records. |
| Corpus paths | snapshot output | caller-selected output/scratch | FAILED BOUNDARY | Symlinked parent/directory can redirect proprietary inventory into the repo. |
| cobolprobe counters | baseline record | requirements and target | FLOWING | Raw values and corrected interpretation are on file. |

## Focused Behavioral Checks

| Check | Result | Status |
|-------|--------|--------|
| `tree-sitter test -i 'idms'` | 36 focused corpus assertions pass; query sample has 0 assertions | PASS with gap |
| 14 synthetic verb forms parse | Each emitted an IDMS statement node with no ERROR | PASS for positive path |
| Invalid update forms | Bare STORE/MODIFY/ERASE and incompatible CONNECT/DISCONNECT/STORE/MODIFY clauses all emitted clean `idms_update_statement` nodes | FAIL -- BLOCKER |
| IDMS query sample | Navigation verbs captured; update/session verbs absent; ACCEPT `@verb` is the full statement text | FAIL -- BLOCKER |
| Duplicate-key differential | Exit 0, `RECLASSIFIED_COUNT: 0` despite a clean baseline row and an IDMS after-row at the same key | FAIL -- BLOCKER |
| Symlinked snapshot output | Exit 0 and repository target file created | FAIL -- BLOCKER |
| Malformed snapshot node regex | Exit 0 with zero-row output while grep reported an invalid regex | FAIL -- WARNING |
| gortex cascade `-count=2 -enhanced-parser` | Pass | PASS |
| full non-comment corpus | Pass | PASS |
| NIST COBOL-85 | 371 success, 0 fail, 11 skip | PASS |
| shim query identity and module tests | Pass | PASS |
| estate guard self-test | Pass | PASS |

## Blocking Gaps

1. **CR-01 / T-02-R01 -- proprietary-output symlink bypass** (`IDMS-07`, affects `IDMS-03` evidence).
2. **CR-02 / T-02-R03 -- duplicate-key false-clean differential verdict** (`IDMS-03`).
3. **CR-03 / T-02-R06 -- incomplete and incorrect IDMS verb capture contract** (`IDMS-02`, `IDMS-01`).
4. **CR-04 / T-02-R05 -- invalid update-verb shapes accepted as clean graph-bearing ASTs** (`IDMS-01`, `IDMS-02`).

These four findings directly prevent the phase goal: a walkable node that emits the wrong edge is not a successful graph contract, and an ACCEPT gate that can return a false clean verdict does not prove containment.

## Non-Blocking Warnings and Residual Debt

| ID | Requirement IDs | Residual gap/debt |
|----|-----------------|-------------------|
| WR-01 | IDMS-02 | READY area names become record captures. |
| WR-02 | IDMS-03, IDMS-05 | Standalone snapshot accepts malformed node regexes as a successful empty census. |
| WR-03 | IDMS-03, IDMS-06 | Differential self-test is mode 100644 and direct invocation fails. |
| WR-04 | IDMS-02, IDMS-03, IDMS-06 | CI does not run differential safety, exact query output, shim identity, or embedded-query checks. |
| WR-05 | IDMS-07 | Refresh continues after generation/copy failure and may test stale or mixed output. |
| WR-06 | IDMS-01, IDMS-02 | Navigation coverage omits documented alternatives and conflates area/set roles. |
| Planning debt | IDMS-03, IDMS-06, IDMS-07 | `02-VALIDATION.md` is still draft/non-Nyquist-compliant; ROADMAP claims 4/6 plans despite six summaries and leaves 02-05 unchecked. |

## Anti-Patterns

- No unresolved `TBD`, `FIXME`, or `XXX` markers were found in the implementation files reviewed.
- The green positive corpus suite is misleading as completeness evidence because it contains no negative update-shape cases and `test/idms/query-sample.cbl` contributes zero assertions.
- The query and differential hard gates are not in CI, so exact failures already present in the shipped artifacts can coexist with a green workflow.

## Deferred-Item Check

No blocking gap is deferred. Phases 3 and 4 address CICS and SQL, not Phase 2's IDMS semantic correctness or differential safety. Later work measured and re-scoped recall, but it did not fix the four Phase 2 blockers.

## Human Verification

None required for the verdict. All blocking findings were reproduced deterministically with synthetic inputs. Judgment-tier fixture provenance was reviewed without reading proprietary source; no evidence disproved the existing manual finding that the fixtures use invented neutral names.

## Gaps Summary

Four high-severity blockers remain open and reproduced. Four of eight Phase 2 requirements are verified. IDMS-04, IDMS-05, IDMS-06, and IDMS-08 have adequate behavioral or measurement evidence. IDMS-01, IDMS-02, IDMS-03, and IDMS-07 fail because the graph contract can emit false operands, the query omits/mislabels verbs, the ACCEPT differential can return a false clean verdict, and proprietary inventory can be redirected into the public repository through symlinks. Six review warnings and planning/validation drift remain as non-blocking debt.

---

_Verified: 2026-09-16T14:15:31Z_
_Verifier: the agent (gsd-verifier)_
