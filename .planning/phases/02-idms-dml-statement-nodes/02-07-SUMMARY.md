---
phase: 02-idms-dml-statement-nodes
plan: 07
subsystem: testing
tags: [shell, tree-sitter, idms, differential, security]

requires:
  - phase: 02-02
    provides: ACCEPT differential and synthetic self-test framework
  - phase: 02-06
    provides: completed Phase 2 grammar and query baseline
provides:
  - Symlink-safe physical containment for differential output and scratch paths
  - Strict duplicate-free four-column inventory validation and regex failure handling
  - Executable exact-output staged IDMS query gate using synthetic fixtures
affects: [02-08, 02-09, 02-10, 02-11]

actuals:
  tokens: 10181
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns: [strict pathlib resolution, pre-verdict TSV validation, staged exact-output query oracle]

key-files:
  created: [run_idms_query_capture.sh]
  modified: [run_accept_differential.sh, run_accept_differential_selftest.sh]

key-decisions:
  - "Path guards distinguish safe external paths, repository-contained paths, and uncanonicalizable paths, with uncertainty failing closed."
  - "The query gate models expected verb, role, and invalid-update defects as separate staged contracts so setup failures cannot count as expected RED."

patterns-established:
  - "Validate complete differential inputs before emitting any summary or verdict."
  - "Use external temporary synthetic fixtures and exact normalized capture streams for query contracts."

requirements-completed: [IDMS-03, IDMS-07]

coverage:
  - id: D1
    description: "Differential output and scratch paths are physically resolved and symlink escapes are refused before artifacts are created."
    requirement: IDMS-07
    verification:
      - kind: integration
        ref: "bash run_accept_differential_selftest.sh -- Cases 17-22"
        status: pass
    human_judgment: false
  - id: D2
    description: "Differential inventories are strict four-column TSV with unique path-position keys, and invalid regex or extraction failures fail closed."
    requirement: IDMS-03
    verification:
      - kind: integration
        ref: "bash run_accept_differential_selftest.sh -- Cases 23-33"
        status: pass
    human_judgment: false
  - id: D3
    description: "Executable query gate exactly reproduces the current 14-verb contract defect while separating later role and invalid-update work."
    verification:
      - kind: integration
        ref: "./run_idms_query_capture.sh --expect-red=verbs"
        status: pass
    human_judgment: false

duration: 23min
completed: 2026-09-17
status: complete
---

# Phase 02 Plan 07: Differential and IDMS Query Gate Summary

**Fail-closed differential path and inventory validation with a synthetic, executable exact-capture gate for all 14 IDMS verbs**

## Performance

- **Duration:** 23 min
- **Started:** 2026-09-17T14:09:14Z
- **Completed:** 2026-09-17T14:31:21Z
- **Tasks:** 3
- **Files modified:** 4, including this summary

## Accomplishments

- Closed the reproduced output and `DIFF_TMP` symlink escapes using strict physical resolution before output or run artifacts are created.
- Rejected malformed four-column inventories and duplicate path-position keys before differential maps, counters, or verdicts are produced.
- Made malformed node regexes and extraction failures fail closed without leaving partial inventories.
- Added an executable synthetic query gate that distinguishes exact verb-contract RED, semantic-role RED, invalid-update RED, and harness failure.

## Task Commits

Each implementation task was committed atomically:

1. **Task 1: Reproduce and close the symlink containment bypass through snapshot and run** - `6bbdd47` (`fix`)
2. **Task 2: Reject malformed and duplicate inventory keys before differential verdicts** - `e281264` (`fix`)
3. **Task 3: Commit the exact 14-verb and semantic-role RED query gate** - `fc7f826` (`test`)
   - Exact whole-stream strengthening - `13713f3` (`fix`)
   - Invalid-subject staged-output validation - `8ef8c1b` (`fix`)

## Files Created/Modified

- `run_accept_differential.sh` - Physical path containment, node-regex validation, extraction status propagation, and strict inventory ingestion.
- `run_accept_differential_selftest.sh` - Synthetic symlink, malformed regex/pipeline, duplicate-key, and malformed-TSV adversarial cases.
- `run_idms_query_capture.sh` - Exact staged query contract with external temporary fixtures and optional atomic caller-owned capture output.
- `.planning/phases/02-idms-dml-statement-nodes/02-07-SUMMARY.md` - Execution and threat evidence.

## T-02-R01 / T-02-R03 Evidence

All inputs were synthetic and neutral. No proprietary corpus source or excerpt was read, copied, quoted, or committed.

| Threat | Synthetic case | RED result before production fix | GREEN result | Command |
|--------|----------------|----------------------------------|--------------|---------|
| T-02-R01 | Parent symlink targets a repository directory | Snapshot succeeded and created the target | Refused; target absent | `bash run_accept_differential_selftest.sh` Case 17 |
| T-02-R01 | Existing final output symlink targets a repository file | Snapshot succeeded and changed target bytes | Refused; link and target unchanged | `bash run_accept_differential_selftest.sh` Case 18 |
| T-02-R01 | Dangling final output symlink | Snapshot replaced/created through the link | Refused; link retained and target absent | `bash run_accept_differential_selftest.sh` Case 19 |
| T-02-R01 | Uncanonicalizable output parent | Refused before output | Refused before output | `bash run_accept_differential_selftest.sh` Case 20 |
| T-02-R01 | Existing ordinary external output | Control remained writable | Accepted and replaced with one-row inventory | `bash run_accept_differential_selftest.sh` Case 21 |
| T-02-R01 | `DIFF_TMP` symlink targets a repository directory | Run created repository scratch artifacts | Refused before any child artifact | `bash run_accept_differential_selftest.sh` Case 22 |
| T-02-R03 | Duplicate before key | Comparator emitted a success-looking verdict | Rejected with side, line, and key before verdict | `bash run_accept_differential_selftest.sh` Case 26 |
| T-02-R03 | After duplicate, IDMS then standard | Comparator could report false clean | Rejected before verdict | `bash run_accept_differential_selftest.sh` Case 27 |
| T-02-R03 | After duplicate, standard then IDMS | Result depended on overwrite order | Rejected before verdict | `bash run_accept_differential_selftest.sh` Case 28 |
| T-02-R03 | Short and long TSV rows | Malformed rows entered comparison | Both rejected with side and line | `bash run_accept_differential_selftest.sh` Cases 29-30 |
| T-02-R03 | Invalid position, node spelling, or qualifier | Malformed values entered comparison | Each rejected before verdict | `bash run_accept_differential_selftest.sh` Cases 31-33 |
| T-02-R04 | Malformed snapshot/run node regex and forced parser failure | Invalid regex could produce false empty output | Rejected before output; parser status greater than one propagates | `bash run_accept_differential_selftest.sh` Cases 23-25 |

## Staged Query Evidence

- `./run_idms_query_capture.sh --expect-red=verbs` exits 0 only after both query invocations and normalization succeed and the exact current verb defects match the staged oracle.
- Normal mode exits 1 against current source, as required before plans 02-08 and 02-09.
- `--expect-red=roles` exits 1 before verb repair, proving it cannot pass at the wrong stage.
- `--invalid-only` exits 1 while the CR-04 negative subject still emits graph-bearing captures; plan 02-08 owns that GREEN transition.
- A deliberately unavailable CLI and a forced normalizer failure each exit 2 with `HARNESS_ERROR`, so infrastructure failure cannot masquerade as expected RED.
- Gate SHA-256: `598ba240326cab2243613488c62590e1c043db4e1a8d63fcc9784bae098944c0`.

## Verification Results

| Command | Result |
|---------|--------|
| `bash -n run_accept_differential.sh run_accept_differential_selftest.sh` | PASS |
| `bash run_accept_differential_selftest.sh` | PASS, all legacy and adversarial cases |
| `bash -n run_idms_query_capture.sh` | PASS |
| `test -x run_idms_query_capture.sh` | PASS, Git mode 100755 |
| `./run_idms_query_capture.sh --expect-red=verbs` | PASS, exact staged RED reproduced |
| `./run_idms_query_capture.sh` | Expected exit 1 on current contract |
| `./run_idms_query_capture.sh --expect-red=roles` | Expected exit 1 before verb repair |
| `./run_idms_query_capture.sh --invalid-only` | Expected exit 1 before plan 02-08 |
| Missing-CLI and forced-normalizer probes | PASS, each exits 2 with `HARNESS_ERROR` |
| `.githooks/commit-separability.sh 6bbdd47^ fc7f826` | PASS, no mixed path families |

## Decisions Made

- Used Python `Path.resolve(strict=True)` plus `os.path.commonpath` because textual path prefixes cannot enforce a physical repository boundary.
- Kept the four-column public inventory contract. Node types remain generic identifier-shaped values so the reusable custom differential works across ACCEPT, CICS, and SQL families.
- Made the exact gate's expected RED modes strict subsets of one full future-GREEN oracle rather than accepting arbitrary nonzero results.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Preserved custom differential node types during TSV hardening**
- **Found during:** Task 2 verification
- **Issue:** Restricting node type values to the two ACCEPT defaults broke the existing custom-regex tracer used by later phases.
- **Fix:** Validate node types as nonempty tree-sitter identifier spellings while retaining exact four-column and duplicate constraints.
- **Files modified:** `run_accept_differential.sh`, `run_accept_differential_selftest.sh`
- **Verification:** Full synthetic self-test passes, including the custom SQL collision case.
- **Committed in:** `e281264`

**2. [Rule 3 - Blocking] Accepted lockfile restore despite unrelated native-addon failure**
- **Found during:** Task 3 CLI preflight
- **Issue:** `npm ci` restored tree-sitter-cli 0.24.5 but exited nonzero because the existing `nan` binding is incompatible with Node 24.
- **Fix:** The gate follows the established Phase 1 contract: after `npm ci`, require and version-check the exact CLI binary rather than treating an unrelated addon failure as missing CLI.
- **Files modified:** `run_idms_query_capture.sh`
- **Verification:** Exact version check passes and staged query execution succeeds.
- **Committed in:** `fc7f826`

**3. [Rule 2 - Missing Critical] Added complete staged-stream comparison**
- **Found during:** Post-task review of Task 3 against the plan's exact-output requirement
- **Issue:** Diagnostic-set equality alone pinned every mismatch but did not itself compare the full mode-specific capture stream.
- **Fix:** Derive a complete staged oracle from the future-GREEN TSV and compare every normalized row, range, value, count, and multiplicity.
- **Files modified:** `run_idms_query_capture.sh`
- **Verification:** Verb RED passes exactly; normal, premature roles, and invalid modes remain expected failures.
- **Committed in:** `13713f3`

**4. [Rule 2 - Missing Critical] Validated invalid-subject output during verb staging**
- **Found during:** Post-task review of Task 3's staged handoff contract
- **Issue:** Verb mode isolated the plan 02-08 failure but did not reject malformed or non-record/set rows from the invalid subject.
- **Fix:** Require the staged invalid output to be nonempty, structurally valid six-column TSV, and graph-bearing only until plan 02-08 turns it GREEN.
- **Files modified:** `run_idms_query_capture.sh`
- **Verification:** Verb RED still passes; invalid-only remains RED; harness errors remain exit 2.
- **Committed in:** `8ef8c1b`

---

**Total deviations:** 4 auto-fixed (2 blocking, 2 missing critical)
**Impact on plan:** Both fixes preserve existing contracts and were required to execute the planned tests. No grammar-family path or dependency file changed.

## Issues Encountered

- The Gortex primary graph remained rooted at the main checkout after the branch switch. Reads and impact analysis were used where exact; post-edit verification relied on the target worktree's deterministic scripts and Git diff.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: T-02-R01 resolved | `run_accept_differential.sh` | Strict physical containment now rejects parent, existing-final, dangling-final, and `DIFF_TMP` symlink routes before output or run artifacts. |
| threat_flag: T-02-R03 resolved | `run_accept_differential.sh` | Both inventories are fully schema- and uniqueness-validated before maps, counters, or verdicts. |
| threat_flag: T-02-R04 resolved | `run_accept_differential.sh` | Snapshot and run reject malformed node regexes before output, and extraction failures propagate without partial inventory. |
| threat_flag: T-02-R06 staged RED | `run_idms_query_capture.sh` | Exact missing update/session verb captures and oversized ACCEPT capture are reproduced and handed to plan 02-09. |
| threat_flag: T-02-R05 staged invalid-subject RED | `run_idms_query_capture.sh` | Complete synthetic invalid-update matrix currently fails and is handed to plan 02-08. |
| threat_flag: none | -- | No additional security-relevant surface was introduced. |

## Known Stubs

None. The empty `SNAPSHOT_TREE_SITTER_LIBDIR` default is an intentional runtime mode selector, not UI or production-data stub behavior.

## User Setup Required

None. The existing lockfile-pinned CLI is restored automatically when absent.

## Next Phase Readiness

- Plan 02-08 can use `--invalid-only` as its executable RED-to-GREEN update-grammar gate.
- Plan 02-09 can first turn `--expect-red=verbs` into a failure, then satisfy `--expect-red=roles` and normal mode.
- No blocker remains for the dependent plans.

## Self-Check: PASSED

- All three implementation files exist, and `run_idms_query_capture.sh` is executable mode 100755.
- Commits `6bbdd47`, `e281264`, `fc7f826`, `13713f3`, and `8ef8c1b` exist on `agent-02-closeout`.
- Every plan verification command and staged failure-mode assertion produced the expected status.
- Only fork-local scripts and this summary were changed; no grammar, generated parser, corpus, query, shim, ROADMAP, or STATE file was modified.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-09-17*
