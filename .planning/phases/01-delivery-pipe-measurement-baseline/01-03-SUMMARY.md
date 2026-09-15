---
phase: 01-delivery-pipe-measurement-baseline
plan: 03
subsystem: infra
tags: [tree-sitter, shell, vendoring, refresh-sequence, propagation-probe, gortex]

# Dependency graph
requires:
  - phase: 01-01
    provides: "forest-shim/cobol/ (the shim being maintained) and the go.work-based resolution path into gortex"
provides:
  - "forest-shim/refresh.sh - the VEND-04 regenerate-and-refresh sequence: npm ci, tree-sitter generate, copy-and-flatten, the two include rewrites, a drift check against the forest module cache, and a gating smoke build"
  - "forest-shim/pipe-probe.sh - the transient grammar.js-to-gortex propagation proof (ROADMAP criterion 1), with a trap-based failsafe proven by two deliberately aborted runs"
  - "A recorded finding: regenerating with the lockfile-pinned tree-sitter-cli 0.24.5 does NOT reproduce the committed src/parser.c byte-for-byte (SYMBOL_COUNT/TOKEN_COUNT differ), which the refresh sequence surfaces as an informational line rather than a failure"
affects: [01-04, 01-05]

# Actuals (#2632)
actuals:
  tokens: 4975
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "House shell-script exit discipline (explicit $? checks, no set -e/set -u, tee-style dual reporting, an aggregate failure-counter exit code) applied to two new fork-local scripts, matching run_nist_cobol85.sh and test/check_tests.sh"
    - "A shared EXIT/INT/TERM trap handler (one `trap handler EXIT INT TERM` registration) that distinguishes a deliberate success exit from a real interrupt via a NORMAL_COMPLETION flag set only immediately before the script's own final exit 0 - lets one handler serve both the failsafe and the normal cleanup path without forcing every exit to the same code"
    - "git checkout only restores tracked file content - a revert routine that runs `tree-sitter generate` must also explicitly remove any newly-created untracked files (src/tree_sitter/alloc.h, array.h) by name"

key-files:
  created:
    - forest-shim/refresh.sh
    - forest-shim/pipe-probe.sh
  modified: []

key-decisions:
  - "npm ci's own exit code is reported but does not gate refresh.sh's Step 1 - this package's top-level install script (node-gyp rebuild of the unrelated Node native binding) fails on this machine's Node/V8 version even though npm ci successfully installs the lockfile-pinned tree-sitter-cli; the actual gate is whether $TREE_SITTER exists and is executable afterward, which is what VEND-04 actually depends on"
  - "Chose K=start as the pipe-probe's rename target - the first kind (in gortex's alphabetically-sorted TestDumpGrammarKinds/cobol output) that is a top-level rule defined exactly once in grammar.js; ERROR and comment_entry were rejected first (zero grammar.js rule-definition matches)"
  - "pipe-probe.sh's revert() explicitly removes src/tree_sitter/alloc.h and array.h by name after git checkout, because git checkout cannot remove newly-created untracked files - discovered via the PROBE_ABORT_AFTER=4 test itself, before the formal Part C sequence"

patterns-established:
  - "A single shared EXIT/INT/TERM trap function, distinguishing real interrupts from deliberate completion via a completion flag, so the success path and the abort path use the exact same cleanup code and cannot drift apart"

requirements-completed: [VEND-04]

coverage:
  - id: D1
    description: "forest-shim/refresh.sh performs the six required steps (deps, generate, copy-and-flatten, the two include rewrites, drift check, gating smoke build), is idempotent across two consecutive runs, and proves its own fault-injection failure mode leaves the shim untouched"
    requirement: VEND-04
    verification:
      - kind: other
        ref: "bash forest-shim/refresh.sh (twice consecutively, REFRESH_SKIP_GENERATE=1 on the settled run) - shasums of parser.c/scanner.c/parser.h/grammar.json identical across both runs"
        status: pass
      - kind: other
        ref: "REFRESH_SKIP_INSTALL=1 TREE_SITTER=/nonexistent/tree-sitter bash forest-shim/refresh.sh"
        status: pass
      - kind: other
        ref: "cd forest-shim/cobol && go build ./... && go test ./..."
        status: pass
      - kind: other
        ref: "sh run_nist_cobol85.sh (382 tests, 371 success, 0 fail, 11 skip)"
        status: pass
    human_judgment: false
  - id: D2
    description: "forest-shim/pipe-probe.sh proves a grammar.js edit reaches gortex's TestDumpGrammarKinds/cobol output through refresh.sh and go.work alone, then reverts; the revert is registered as a trap before the first write to grammar.js and is proven (not merely present) by two deliberately aborted runs that both restore the tree without manual cleanup"
    requirement: VEND-04
    verification:
      - kind: other
        ref: "PROBE_ABORT_AFTER=3 bash forest-shim/pipe-probe.sh - exits non-zero, git diff --quiet -- grammar.js src/ and git status --porcelain forest-shim/cobol both clean afterward"
        status: pass
      - kind: other
        ref: "PROBE_ABORT_AFTER=4 bash forest-shim/pipe-probe.sh - same clean-afterward assertions, exercising the handler's shim-rebuild branch"
        status: pass
      - kind: other
        ref: "bash forest-shim/pipe-probe.sh (real run, no flags) - exit 0, kinds-after.txt lists start_pipe_probe and not start, post-revert capture byte-identical to the step-1 baseline"
        status: pass
      - kind: integration
        ref: "go test ./internal/parser/forest/cobolprobe/ -run 'TestErrorCascade|TestHypothesis' -v (in ~/repos/mine/GoApps/gortex)"
        status: pass
    human_judgment: false

duration: 32min
completed: 2026-08-29
status: complete
---

# Phase 1 Plan 3: Delivery Pipe Refresh Sequence and Propagation Proof Summary

**forest-shim/refresh.sh scripts the six-step regenerate-and-refresh sequence and forest-shim/pipe-probe.sh proves, with a trap-guarded transient edit, that a grammar.js change reaches gortex's parse output through it alone - both proven idempotent and proven to fail safely under fault injection and interruption.**

## Performance

- **Duration:** 32 min
- **Started:** 2026-08-29T15:12:00Z (approx, first tool call)
- **Completed:** 2026-08-29T15:44:00Z
- **Tasks:** 3
- **Files created:** 2 (forest-shim/refresh.sh, forest-shim/pipe-probe.sh)

## Accomplishments
- `forest-shim/refresh.sh`: six explicit, individually-reported steps - `npm ci` (never `npm install`), `tree-sitter generate`, copy-and-flatten `src/` into the shim, the two different `#include` rewrites (quoted form in `parser.c`, angle-bracket form in `scanner.c`), a drift check against the forest module-cache copy, and a gating smoke build as the last word on success. Run twice consecutively with `REFRESH_SKIP_GENERATE=1` after settling: shasums of all four shim files identical across both runs, `git status --porcelain forest-shim/cobol` empty. A third, fault-injected run (`TREE_SITTER=/nonexistent/tree-sitter`) exits non-zero, prints a FAIL line naming the missing binary, and leaves the shim byte-identical to its committed state.
- `forest-shim/pipe-probe.sh`: renames one deterministically-chosen top-level grammar.js rule (`start` -> `start_pipe_probe`), runs `refresh.sh`, observes the renamed node appear in gortex's `TestDumpGrammarKinds/cobol` output (and the old name disappear), then reverts - the whole `grammar.js -> tree-sitter generate -> src/ -> refresh.sh -> forest-shim/cobol/ -> go.work -> gortex parse output` chain, proven with the unmodified-otherwise grammar. The revert is registered as a `trap handle_exit EXIT INT TERM` before the first write to `grammar.js`; two deliberately aborted runs (`PROBE_ABORT_AFTER=3` and `=4`) both exit non-zero and both leave `grammar.js`, `src/` and `forest-shim/cobol/` at their exact committed content with no manual cleanup step before the next run.
- Discovered and fixed a real gap in the failsafe before it was ever exercised for real: `git checkout` cannot remove newly-created untracked files, so regenerating with the pinned CLI left `src/tree_sitter/alloc.h`/`array.h` behind after a `PROBE_ABORT_AFTER=4` abort. Fixed by removing both files by name inside `revert()`.
- Recorded a genuine, unplanned finding (Task 2's "genuine finding, not a failure" clause): regenerating with the lockfile-pinned tree-sitter-cli 0.24.5 produces a `src/parser.c` whose `SYMBOL_COUNT`/`TOKEN_COUNT` (1153/523) do **not** match the currently committed `src/parser.c` (1215/585) - they instead match forest's cached `cobol@v1.9.1` copy's values exactly. `LANGUAGE_VERSION`/`STATE_COUNT`/`LARGE_STATE_COUNT` still match in all three. This means the currently-committed `src/parser.c` was generated by a *different* tree-sitter-cli version than the one pinned in `package-lock.json` - not a regression this plan introduces, but a fact `docs/vendoring.md` (plan 04) should state precisely.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the regenerate-and-refresh sequence** - `543f17f` (feat)
2. **Task 2: Execute the sequence twice and prove its failure mode** - no commit (no-op refresh: `forest-shim/cobol/` was restored to committed content after both runs, exactly as the plan anticipates - "commit only if forest-shim/cobol/ actually changed")
3. **Task 3: Prove a grammar.js edit reaches gortex's parse output, then revert it** - `49bc74a` (feat, script committed before the probe ran) and `5ad0986` (fix, the untracked-header cleanup gap found while exercising `PROBE_ABORT_AFTER=4`)

**Plan metadata:** pending (this commit)

## Files Created/Modified
- `forest-shim/refresh.sh` - the VEND-04 six-step regenerate-and-refresh sequence
- `forest-shim/pipe-probe.sh` - the transient grammar-to-gortex propagation probe with a trap-guarded revert

## Decisions Made
- `npm ci`'s own exit code is reported but does not gate Step 1 of `refresh.sh` - this package's top-level `install` script (`node-gyp rebuild` of the unrelated Node native binding under `bindings/node/`) fails on this machine's Node 24 / V8 combination (a `nan`-vs-modern-V8-API incompatibility, unrelated to `tree-sitter-cli`) even though `npm ci` successfully installs the lockfile-pinned `tree-sitter-cli` first. The actual, literal gate - whether `$TREE_SITTER` exists and is executable afterward - is what VEND-04 depends on, and is checked explicitly and independently.
- Chose `K=start` as the pipe-probe's rename target: the first kind, in the order gortex's `TestDumpGrammarKinds/cobol` printed them (alphabetical), that is a top-level rule defined exactly once in `grammar.js`. `ERROR` and `comment_entry` were tried first and rejected (zero `grammar.js` rule-definition matches each - both are produced by the grammar but not defined as named top-level rules of that exact name).
- `pipe-probe.sh`'s `revert()` explicitly `rm -f`s `src/tree_sitter/alloc.h` and `array.h` by name after `git checkout -- grammar.js src/`, because `git checkout` restores tracked content only and cannot remove newly-created untracked files that `tree-sitter generate` produces on this CLI version.
- Used a single shared `trap handle_exit EXIT INT TERM` registration (one line naming all three, per the plan's acceptance criteria) with a `NORMAL_COMPLETION` flag set only immediately before the script's own final `exit 0`, so a real interrupt and a deliberate completion share one implementation but still produce the correct exit code in each case - verified in isolation with two minimal reproductions before wiring it into the real script.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] npm ci's own top-level install script fails on this machine, independent of tree-sitter-cli**
- **Found during:** Task 1, first execution of `forest-shim/refresh.sh`
- **Issue:** `npm ci` exits 1 because this repo's own `package.json` runs `node-gyp rebuild` for `bindings/node/` (a native Node addon using the `nan` package), which fails to compile against this machine's Node 24 / V8 headers (`no matching constructor for initialization of 'v8::ScriptOrigin'`). This is unrelated to `tree-sitter-cli`, whose own postinstall step (downloading/building the CLI binary) completes successfully before the top-level script fails.
- **Fix:** `refresh.sh` reports `npm ci`'s exit code informationally but gates Step 1 solely on whether `$TREE_SITTER` exists and is executable afterward - the fact VEND-04 actually needs. Verified: `node_modules/.bin/tree-sitter --version` reports `0.24.5`, matching `package-lock.json`'s pin exactly.
- **Files modified:** `forest-shim/refresh.sh`
- **Verification:** `bash forest-shim/refresh.sh` completes all 6 steps and exits 0 on this machine.
- **Committed in:** `543f17f` (Task 1 commit)

**2. [Rule 1 - Bug] pipe-probe.sh's revert left untracked generated headers behind**
- **Found during:** Task 3, while exercising `PROBE_ABORT_AFTER=4` before the formal Part C sequence
- **Issue:** `git checkout -- grammar.js src/` only restores tracked file content. Regenerating with the pinned CLI creates `src/tree_sitter/alloc.h` and `array.h` as new, untracked files (see the SYMBOL_COUNT finding above) - `git checkout` cannot remove them, so they were left behind after an abort that reached Step 4.
- **Fix:** `revert()` now also `rm -f`s both files by name, explicitly, immediately after the `git checkout`.
- **Files modified:** `forest-shim/pipe-probe.sh`
- **Verification:** Re-ran `PROBE_ABORT_AFTER=4 bash forest-shim/pipe-probe.sh` after the fix - `git status --porcelain` afterward matched the pre-test baseline exactly, with no stray files.
- **Committed in:** `5ad0986` (separate fix commit, since the buggy version had already been committed once)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes were necessary for the refresh sequence and the probe to actually work on this machine and to actually prove full cleanup under fault injection. No scope creep - neither fix touches `grammar.js`, `test/corpus/*`, or any file outside the two new fork-local scripts.

## Known Issues (pre-existing, out of scope)

**`node_modules/.bin/tree-sitter test` reports 1 failure out of 13 fixtures (`comment`), not 0.** This is a genuine, pre-existing defect in the currently-committed `grammar.js`/`test/corpus/comment.txt` pairing, **not** caused by this plan's refresh sequence or propagation probe:
- The identical failure reproduces against the **committed** `src/parser.c` (untouched, `git status --porcelain` clean) with no involvement from `refresh.sh` or `pipe-probe.sh` at all.
- The fixture (`test/corpus/comment.txt`) was last touched in upstream commit `4bc6ff5`, long before this session.
- `.github/workflows/test.yml` has the `tree-sitter test` CI step commented out, and `test/check_tests.sh` requires GnuCOBOL (`cobc`, not installed on this machine) - meaning this specific check has, as far as can be determined, **never actually run** in this fork's history until this session's `npm ci` first created `node_modules/`.
- The fixture's expected S-expression shows no `comment` node at all for a trailing fixed-format comment line, while the actual (both committed-src and freshly-regenerated) parse places a `comment` node (via the `_LINE_COMMENT_ALIAS` extras rule) as a sibling of `program_definition` - a discrepancy that looks like the fixture predates that alias being wired into `extras`.
- Fixing this would require editing `test/corpus/comment.txt`, a "grammar family" path this phase's domain boundary (CONTEXT.md: "no grammar changes in this phase", D-13) explicitly puts out of scope, and which FORK-03's commit-separability guard treats as a distinct family from this plan's fork-local scripts.
- **Recorded in `.planning/WINDOWS.md`** as an open `deviation` entry so it stays visible at ship time. `run_nist_cobol85.sh` (382 tests, 371 success, 0 fail, 11 skip) and the gortex `cobolprobe` tests both pass cleanly, and VEND-04's own requirement (a reproducible refresh mechanism) is fully proven independent of this fixture.

**`git status --porcelain` is not literally empty repo-wide at plan end** - it lists four untracked entries: `.gsd/`, `.planning/config.json`, `.planning/milestone.lock` (pre-existing GSD-harness scaffolding, present before this plan's Task 1 ever ran, confirmed via a baseline snapshot taken before both `PROBE_ABORT_AFTER` test runs and diffed against afterward - byte-for-byte unchanged by the probe), and `.planning/WINDOWS.md` (this plan's own legitimate new fork-local ledger entry from the Known Issues item above, to be committed with this plan's final metadata commit). **None of these four are probe residue** - `grammar.js`, `src/`, and `forest-shim/cobol/` are all confirmed byte-for-byte clean against `HEAD` (`git diff --quiet` and scoped `git status --porcelain` checks both pass), which is what the underlying criterion actually protects against.

## Issues Encountered

None beyond the two auto-fixed deviations and the pre-existing corpus-fixture defect documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VEND-04 is fully satisfied: the refresh sequence is a single documented script, proven reproducible across two consecutive runs and safe under fault injection.
- ROADMAP Phase 1 criterion 1 is fully satisfied: a `grammar.js` edit demonstrably reaches gortex's parse output through `refresh.sh` and `go.work` alone, with the edit fully reverted and no residue.
- Plan 04 (`docs/vendoring.md`) should transcribe: the six refresh steps, the twice-executed reproducibility proof, the `SYMBOL_COUNT`/`TOKEN_COUNT` finding (state it precisely - "ABI-version compatible, not table-identical", per RESEARCH.md Pitfall 5), and the before/after kind lines from the propagation probe (`start` -> `start_pipe_probe`).
- Plan 04/05 should also be aware of the pre-existing `comment` corpus-fixture failure recorded in `.planning/WINDOWS.md` - out of scope for this phase, but worth a mention in `docs/vendoring.md`'s known-limitations section since it affects the truthfulness of "13/13 corpus fixtures pass" as a blanket claim.
- No blockers identified for subsequent plans in this phase.

## Self-Check: PASSED

- Both key files verified present on disk with `[ -f ]` and executable with `[ -x ]`
- All 3 commit hashes (`543f17f`, `49bc74a`, `5ad0986`) verified present via `git log --oneline --all`
- All task-level acceptance criteria re-run and confirmed PASS: `bash -n` on both scripts, all required grep-based structural checks (npm ci present/npm install absent, TREE_SITTER/REFRESH_SKIP_GENERATE/REFRESH_ALLOW_DRIFT/PROBE_ABORT_AFTER presence, sed-count and go-build-after-sed line-order checks, trap-before-grammar.js-write line-order check, the single `trap handle_exit EXIT INT TERM` line naming all three signals, no `set -e`/`set -u` anywhere in either script), the two-consecutive-run shasum-identity proof, the fault-injection proof, and both `PROBE_ABORT_AFTER` proofs (post-fix)
- Plan-level `<verification>` re-run: `git diff --stat upstream/main -- grammar.js src/` empty; `sh run_nist_cobol85.sh` exits 0 with an 11-skip summary line; `cd ~/repos/mine/GoApps/gortex && go test ./internal/parser/forest/cobolprobe/ -run 'TestErrorCascade|TestHypothesis' -v` exits 0; `node_modules/.bin/tree-sitter test` exits 1 due to the pre-existing, out-of-scope `comment` fixture defect documented above (12/13 pass) - the one plan-level verification item not fully green, explicitly not silently skipped

---
*Phase: 01-delivery-pipe-measurement-baseline*
*Completed: 2026-08-29*
