---
phase: 02-idms-dml-statement-nodes
plan: 10
subsystem: delivery-and-ci
tags: [tree-sitter, cobol, idms, forest-shim, github-actions, security]

requires:
  - phase: 02-07
    provides: Fail-closed differential self-test and exact staged IDMS query gate
  - phase: 02-08
    provides: Verb-specific IDMS update grammar and invalid-update rejection
  - phase: 02-09
    provides: Exact 14-verb query contract and syntax-grounded operand roles
provides:
  - Fail-closed staged forest-shim refresh with portable include rewriting
  - Persistent generation and copy/staging failure-injection regression tests
  - Coherent generated parser, grammar JSON, and exact IDMS query delivery
  - Embedded IDMS query availability and source-byte identity tests
  - Blocking fork CI gates for differential, query, refresh, parity, and Go tests
affects: [02-11, forest-shim, fork-checks, idms-query-consumers]

actuals:
  tokens: 16349521
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - Sibling-directory staging followed by whole-directory atomic rename
    - Explicit skipped-step reporting after fail-closed generation or staging errors
    - Synthetic failure injection against an isolated repository-shaped tree
    - CI execution of exact source and delivered-shim query contracts

key-files:
  created:
    - forest-shim/refresh-selftest.sh
  modified:
    - forest-shim/refresh.sh
    - forest-shim/cobol/parser.c
    - forest-shim/cobol/grammar.json
    - forest-shim/cobol/idms.scm
    - forest-shim/cobol/smoke_test.go
    - run_accept_differential_selftest.sh
    - .github/workflows/fork-checks.yml

key-decisions:
  - "Build and test the complete shim in a sibling staging directory, then replace the live directory only after every gate passes."
  - "Use a temporary-file-plus-rename include transformation instead of platform-specific sed -i syntax."
  - "Keep full estate differential runs manual while running only neutral synthetic adversarial cases in public CI."
  - "Treat the 02-07/02-09 gate-hash mismatch as accepted plan-review history: the current unchanged gate matches 02-09 after its intentional semantic-oracle correction."

patterns-established:
  - "Failed generation or staged copy emits explicit SKIPPED reports and cannot reach drift, smoke, or install success."
  - "The shim package tests embedded query aliases, required contract fragments, and optional source-byte identity."

requirements-completed: [IDMS-02, IDMS-03, IDMS-06, IDMS-07]

coverage:
  - id: D1
    description: "The exact all-14 IDMS verb and syntax-grounded role contract passes twice deterministically."
    requirement: IDMS-02
    verification:
      - kind: integration
        ref: "./run_idms_query_capture.sh twice; normalized capture SHA-256 677af93f147b4fd70c80e3c06632a1577619d7d6c99561913da72721a6502b67"
        status: pass
    human_judgment: false
  - id: D2
    description: "Generation and copy/staging failures leave every live shim artifact byte-identical and skip all later stages."
    requirement: IDMS-07
    verification:
      - kind: integration
        ref: "./forest-shim/refresh-selftest.sh Cases 1-2"
        status: pass
    human_judgment: false
  - id: D3
    description: "A successful refresh installs one coherent generated/query set and the embedded IDMS query equals source bytes."
    requirement: IDMS-02
    verification:
      - kind: integration
        ref: "forest-shim/refresh-selftest.sh Cases 3-4; cmp; IDMS_QUERY_FILE gate; forest-shim/cobol go test ./..."
        status: pass
    human_judgment: false
  - id: D4
    description: "Fork CI continuously runs the synthetic differential, exact query, refresh failure, query parity, and embedded-query gates."
    requirement: IDMS-06
    verification:
      - kind: integration
        ref: "local execution of .github/workflows/fork-checks.yml commands in workflow order"
        status: pass
    human_judgment: false
  - id: D5
    description: "All delivery commits remain fork-local and contain no proprietary source."
    requirement: IDMS-07
    verification:
      - kind: integration
        ref: ".githooks/commit-separability.sh and .githooks/estate-guard.sh over 6298669 and a4f122d"
        status: pass
    human_judgment: false

duration: 23min
completed: 2026-09-17
status: complete
---

# Phase 02 Plan 10: Fail-Closed Shim and Continuous Gates Summary

**Atomic forest-shim delivery now rejects partial refreshes, embeds the corrected IDMS query, and continuously enforces exact query and synthetic differential contracts in read-only fork CI.**

## Performance

- **Duration:** 23 min
- **Started:** 2026-09-17T15:54:28Z
- **Completed:** 2026-09-17T16:17:28Z
- **Tasks:** 3
- **Implementation files modified:** 8
- **Implementation commits:** 2
- **Metadata commits:** 1

## Accomplishments

- Reconfirmed the current exact query gate twice without modifying it; both normalized capture streams were byte-identical and had SHA-256 `677af93f147b4fd70c80e3c06632a1577619d7d6c99561913da72721a6502b67`.
- Reworked `forest-shim/refresh.sh` to stage an entire parser/grammar/header/scanner/query set, apply portable include rewrites, run drift and Go tests against staging, and install only the coherent validated directory.
- Added a persistent isolated self-test proving generation and copy/staging failures preserve live shim hashes and skip later stages, while the success path compiles and exercises the delivered query.
- Refreshed `parser.c`, `grammar.json`, and `idms.scm` from the corrected source artifacts and added Go-level embedded-query assertions.
- Made the hardened differential self-test directly executable and added all blocker gates to the least-privileged fork workflow.

## Task Commits

1. **Task 1: Reconfirm the committed exact 14-verb RED-to-GREEN contract** - verification-only; no file change or task commit
2. **Task 2: Refresh a coherent shim and prove the embedded IDMS query** - `6298669` (`fix`)
3. **Task 3: Run blocker gates continuously in fork CI** - `a4f122d` (`ci`)

## Files Created/Modified

- `forest-shim/refresh.sh` - Fail-closed staged refresh, portable include rewriting, staged tests, and coherent directory installation.
- `forest-shim/refresh-selftest.sh` - Persistent synthetic generation-failure, copy/staging-failure, success, and shim-query cases.
- `forest-shim/cobol/parser.c` - Refreshed corrected generated parser with flattened include path.
- `forest-shim/cobol/grammar.json` - Refreshed grammar metadata, byte-identical to `src/grammar.json`.
- `forest-shim/cobol/idms.scm` - Correct exact-verb and syntax-grounded role query, byte-identical to `queries/idms.scm`.
- `forest-shim/cobol/smoke_test.go` - Embedded IDMS query aliases, contract fragments, and optional source-byte identity assertions.
- `run_accept_differential_selftest.sh` - Mode changed from 100644 to 100755; content unchanged.
- `.github/workflows/fork-checks.yml` - Blocking differential, exact-query, refresh, parity, shim-query, and Go-test steps.

## Exact Query Evidence

- Current gate SHA-256: `5219024654ac8af08619dbf9948b9f0d1a91980fbf32872b30581166e101b940`.
- This equals the Plan 02-09 post-role-correction hash and the script stayed byte-unchanged in Plan 02-10.
- Plan 02-07 records the earlier pre-correction hash `598ba240326cab2243613488c62590e1c043db4e1a8d63fcc9784bae098944c0`; the user accepted this known plan-review inconsistency. No historical replay or gate weakening was introduced.
- Two current outputs were byte-identical at SHA-256 `677af93f147b4fd70c80e3c06632a1577619d7d6c99561913da72721a6502b67`.
- Normal mode exercises both the zero-capture invalid-update subject and the all-14 verb/role subject and reports `QUERY_CONTRACT_GREEN`.

## Refresh Failure-Injection Evidence

| Case | Expected result | Observed result |
|------|-----------------|-----------------|
| Forced Step 2 generation failure | Nonzero; Steps 3-6 skipped; live artifact hashes unchanged | PASS |
| Forced Step 3 copy/staging failure | Nonzero; Steps 4-6 skipped; no later success; live artifact hashes unchanged | PASS |
| Isolated successful refresh | Generate, stage, portable rewrite, drift check, Go tests, atomic install | PASS |
| Delivered shim query execution | Query compiles and matches exact synthetic subject | PASS |

The successful live refresh was run twice. Both runs completed all six gates and installed the same coherent output. `npm ci` still reports the documented unrelated Node 24/NAN native-addon failure, but the exact lockfile-installed tree-sitter 0.24.5 binary exists and gates generation as designed.

## Delivered Artifact Evidence

- `forest-shim/cobol/grammar.json` equals `src/grammar.json`, SHA-256 `11085371e3e0a62be477330f189105e99949594f3d036689d215c94d4256c4ea`.
- `forest-shim/cobol/idms.scm` equals `queries/idms.scm`, SHA-256 `98a79ca9f90c0dd0981f9aadcf29892de84b8af85541168fc36f336753351160`.
- The shim parser is the source parser with only the required flattened include transformation; shim SHA-256 is `25d72d9aaf38b4919b728cfd6db6d3ed8f46d76001de20f5dd4799203f75c70e`.
- `go test ./...` executes `TestShimEmbedsIDMSQuery`, proving both `GetQuery("idms")` and `GetQuery("idms.scm")` return identical nonempty bytes, contain every corrected statement/capture contract fragment, and equal the source query when `IDMS_SOURCE_QUERY` is set.
- `IDMS_QUERY_FILE="$PWD/forest-shim/cobol/idms.scm" ./run_idms_query_capture.sh` compiles and matches the shim query against the exact neutral synthetic subject.

## CI Gates

The fork workflow retains `push` to `main` plus `workflow_dispatch`, `permissions: contents: read`, lockfile-pinned `npm ci`, and the documented comment-fixture exclusion. It now runs, in order:

1. Parser generation and non-comment corpus fixtures.
2. Direct executable differential adversarial self-test.
3. Exact source IDMS query contract, including invalid-update and all-14 verb/role subjects.
4. Persistent fail-closed refresh self-test, including successful and forced-failure paths on Ubuntu.
5. Source/shim `idms.scm` byte comparison.
6. Exact gate against the shim query.
7. Shim Go tests with source-query byte identity enabled.

All workflow commands passed locally in order. `actionlint` was unavailable locally; Ruby YAML parsing passed, and the unchanged repository `check-workflows.yml` continues to install and run actionlint in GitHub Actions.

## Commit Separability and Estate Safety

| Commit | Family | Paths | Guards |
|--------|--------|-------|--------|
| `6298669` | forest shim | `forest-shim/` only | separability PASS; estate guard 3/3 PASS |
| `a4f122d` | fork-local/CI | `run_accept_differential_selftest.sh`, `.github/workflows/fork-checks.yml` | separability PASS; estate guard 3/3 PASS |

No grammar-family source path was included in either commit. No proprietary corpus was read, copied, quoted, or introduced; every new test uses hand-written neutral data under temporary directories.

## Decisions Made

- Staging and whole-directory replacement were selected over in-place live-file updates so any pre-install failure leaves one coherent prior shim.
- Include rewriting uses ordinary `sed` output into a temporary file followed by `mv`; no BSD-only `sed -i ''` remains in `refresh.sh`.
- Step 6 runs `go test ./...`, not merely `go build`, so embedded-query assertions gate installation.
- The full DCC/estate differential remains manual per D-08; only fast neutral synthetic adversarial cases enter public CI.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Synchronize staged query files before copying source queries**
- **Found during:** Task 2 review of coherent artifact-set semantics
- **Issue:** Copying current queries over a cloned shim could leave a removed source query embedded as stale output.
- **Fix:** Delete staged `.scm` files except the structural `_keep.scm` marker before copying the complete source query set.
- **Files modified:** `forest-shim/refresh.sh`
- **Verification:** Isolated success and both failure cases pass; source/shim IDMS parity passes.
- **Committed in:** `6298669`

**2. [Rule 2 - Missing Critical] Compare embedded query bytes to source during staged tests**
- **Found during:** Task 2 embedded-query test implementation
- **Issue:** Nonempty fragment checks alone could pass a stale query that retained the expected names.
- **Fix:** Added optional `IDMS_SOURCE_QUERY` byte comparison and supplied it from refresh and CI.
- **Files modified:** `forest-shim/cobol/smoke_test.go`, `forest-shim/refresh.sh`, `.github/workflows/fork-checks.yml`
- **Verification:** Staged refresh, live Go tests, and local CI command sequence pass.
- **Committed in:** `6298669`, `a4f122d`

---

**Total deviations:** 2 auto-fixed (2 missing critical functionality)
**Impact on plan:** Both strengthened coherent delivery and stale-query detection without adding dependencies, changing the grammar family, or weakening a gate.

## Issues Encountered

- Task 1's plan text required identical hashes in the 02-07 and 02-09 summaries, but Plan 02-09 intentionally changed the gate oracle and documented the new hash. The accepted review risk was recorded transparently; current byte identity and deterministic GREEN evidence use the 02-09 hash.
- Local `actionlint` was absent. The workflow parsed as YAML locally, all commands ran in workflow order, and the unchanged upstream workflow still installs/runs actionlint in CI.
- Gortex's active graph remained rooted at the main checkout, so review output could not reliably inspect this worktree diff. Deterministic tests, Git path guards, and direct diff checks were used instead.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: T-02-R01 continuously mitigated | `run_accept_differential_selftest.sh`, `.github/workflows/fork-checks.yml` | Executable CI self-test continuously rejects parent, final, dangling, and run-scratch symlink escapes using neutral temporary fixtures. |
| threat_flag: T-02-R03 continuously mitigated | `run_accept_differential_selftest.sh`, `.github/workflows/fork-checks.yml` | CI continuously rejects malformed TSV and duplicate keys in both orderings before any false-clean verdict. |
| threat_flag: T-02-R05 continuously mitigated | `run_idms_query_capture.sh`, `.github/workflows/fork-checks.yml` | Full normal exact gate runs its synthetic invalid-update matrix and requires zero graph-bearing captures. |
| threat_flag: T-02-R06 continuously mitigated | `run_idms_query_capture.sh`, `forest-shim/cobol/idms.scm`, `.github/workflows/fork-checks.yml` | Source and delivered-shim gates require exact ranges, values, count, multiplicity, and roles for all 14 verbs. |
| threat_flag: T-02-R09 mitigated | `forest-shim/refresh.sh`, `forest-shim/refresh-selftest.sh` | Generation and staging failures skip all later validation/install steps and preserve live artifact hashes; successful sets install only after staged Go tests. |
| threat_flag: T-02-R10 preserved | `.github/workflows/fork-checks.yml` | Main-only/workflow-dispatch triggers and read-only contents permission remain unchanged; no privileged pull-request trigger or secret was added. |
| threat_flag: T-02-R15 mitigated | `.github/workflows/fork-checks.yml` | Every blocker regression has an explicit named blocking step. |
| threat_flag: none | -- | No additional security-relevant surface was introduced. |

## Known Stubs

None. `STAGE_ROOT=""` and `SCM_COPIED=""` are shell state initialization, not placeholder behavior. The pre-existing forest placeholder comparison in `smoke_test.go` is an active anti-regression assertion. No TODO, FIXME, skipped test, mock data source, or unrun plan verification remains.

## User Setup Required

None.

## Next Phase Readiness

- Plan 02-11 can consume literal commits `6298669` and `a4f122d` for fork-local closeout evidence.
- The corrected parser/query is coherently delivered, and all fast blocker gates are executable locally and wired into fork CI.
- ROADMAP.md and STATE.md remain untouched exactly as requested.

## Self-Check: PASSED

- All eight implementation artifacts exist; both self-test scripts are mode 100755.
- Commits `6298669` and `a4f122d` exist on `agent-02-closeout` and contain only permitted fork-local/shim/CI path families.
- Every plan verification command ran and passed; local actionlint absence is explicitly recorded rather than silently treated as a pass.
- Source `grammar.js`, generated `src/`, corpus files, source queries, `ROADMAP.md`, and `STATE.md` are unchanged by this plan.

---
*Phase: 02-idms-dml-statement-nodes*
*Completed: 2026-09-17*
