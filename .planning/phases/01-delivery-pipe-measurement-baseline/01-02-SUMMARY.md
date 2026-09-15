---
phase: 01-delivery-pipe-measurement-baseline
plan: 02
subsystem: infra
tags: [git-hooks, shell, estate-leak-guard, commit-separability, pre-push]

# Dependency graph
requires: []
provides:
  - ".githooks/estate-guard.sh — three-check estate-leak guard (FORK-02, D-16): estate/ path rejection, .git/info/exclude vs .gitignore posture assertion, columns 73-80 sequence-area heuristic scoped to diff-added lines"
  - ".githooks/estate-guard-selftest.sh — re-runnable fail-then-pass proof of the guard (D-18), isolated in a scratch repo under mktemp -d"
  - ".githooks/commit-separability.sh — FORK-03 enforcement: no commit mixes grammar-family and fork-local-family paths"
  - ".githooks/pre-push — the enforcement point wiring both guards, installed via `git config core.hooksPath .githooks`"
affects: [01-03, 01-04, 01-05]

# Actuals (#2632)
actuals:
  tokens: 6159
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "core.hooksPath pointed at a tracked .githooks/ directory instead of an untracked .git/hooks/ copy, so the hook is committed, diffable, and reviewable"
    - "git-diff-scoped content heuristics: scan only diff-added (+) lines restricted to a path allowlist, never a whole-file scan, to avoid false-positiving on pre-existing upstream fixtures"
    - "file-based accumulation across a piped `while read` loop to sidestep the POSIX-sh subshell variable-scope trap when a shell variable must survive past the loop"

key-files:
  created:
    - .githooks/estate-guard.sh
    - .githooks/estate-guard-selftest.sh
    - .githooks/commit-separability.sh
    - .githooks/pre-push
  modified: []

key-decisions:
  - "Followed the plan's decision-fidelity note on D-18 exactly: the self-test's throwaway branches live in a scratch repo under mktemp -d, never in this fork, because a branch here carrying an estate/ path would create exactly the git object the guard exists to prevent"
  - "Discovered and worked around a real interaction not called out in the plan: the scratch repo's own .git/info/exclude (deliberately set to /estate/ to match this fork's live posture) makes `git add estate/...` fail without -f — the self-test's case 1 now uses `git add -f` to force the pollution fixture into being, which is the correct way to construct a deliberately-bad commit for testing, not a guard weakness"
  - "SEQ_AREA_FIRST_BYTE=74 pins the raw-diff-line offset (content byte 73 = raw +-prefixed line byte 74) in one variable so the +-stripping arithmetic and the column-73 semantics can never silently drift apart"

patterns-established:
  - "Byte-column heuristics over fixed-format source always run under LC_ALL=C so awk's length/substr are byte-indexed, never character-indexed — required for correct UTF-8 and tab handling per D-16"

requirements-completed: [FORK-02, FORK-03]

coverage:
  - id: D1
    description: "The estate-leak guard performs all three D-16 checks (estate/ path rejection, .git/info/exclude vs .gitignore posture, columns 73-80 sequence-area heuristic on diff-added lines) and is demonstrably failing on polluted input and passing on clean input by a re-runnable script"
    requirement: FORK-02
    verification:
      - kind: other
        ref: "bash .githooks/estate-guard-selftest.sh (run twice consecutively)"
        status: pass
      - kind: other
        ref: "sh .githooks/estate-guard.sh --check-exclude (against this fork's live state)"
        status: pass
      - kind: other
        ref: "sh .githooks/estate-guard.sh --range HEAD~1..HEAD"
        status: pass
      - kind: other
        ref: "sh .githooks/estate-guard.sh --staged (nothing staged) — exclusion-check line present, not vacuous"
        status: pass
      - kind: other
        ref: "printf '' | sh .githooks/estate-guard.sh (zero ref-update lines)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both guards are wired to pre-push via a tracked, diffable .githooks/ directory installed by one git config command, and grammar commits stay separable from fork-local commits"
    requirement: FORK-03
    verification:
      - kind: other
        ref: "git config --get core.hooksPath == .githooks"
        status: pass
      - kind: other
        ref: "sh .githooks/commit-separability.sh (17 commits on main, all single-family or no-match)"
        status: pass
      - kind: other
        ref: "printf '' | bash .githooks/pre-push origin https://example.invalid/x.git (empty ref-update list)"
        status: pass
      - kind: other
        ref: "git show --stat --name-only --pretty=format: HEAD lists only .githooks/ paths (the wiring commit is itself separable)"
        status: pass
    human_judgment: false

duration: 40min
completed: 2026-08-29
status: complete
---

# Phase 1 Plan 2: Estate-Leak Guard and Commit-Separability Check Summary

**A three-check pre-push guard (estate/ path rejection, exclusion-posture assertion, byte-scoped columns 73-80 sequence-area heuristic on diff-added lines) proven fail-then-pass by a re-runnable scratch-repo self-test, plus a commit-separability check, both wired to `pre-push` via a tracked `.githooks/` directory.**

## Performance

- **Duration:** 40 min
- **Started:** 2026-08-29T10:06:00Z (approx, first shell command)
- **Completed:** 2026-08-29T10:46:00Z
- **Tasks:** 3
- **Files created:** 4 (603 lines total)

## Accomplishments
- `.githooks/estate-guard.sh`: implements all three D-16 checks with modes `--check-exclude`, `--range <A>..<B>`, `--staged`, and a default stdin mode that parses git's pre-push ref-update protocol (handling new-branch, deletion, and zero-line cases). Byte-column semantics (`LC_ALL=C`, tabs not tab-stop-expanded, UTF-8 counted as bytes) and diff-added-only scoping are pinned in code (`COBOL_PATH_RE`, `SEQ_AREA_FIRST_BYTE`) and commented at the check site so a later editor cannot silently "simplify" the scoping into a full-file scan.
- `.githooks/estate-guard-selftest.sh`: builds a scratch repo under `mktemp -d`, proves the guard fails on four polluted inputs (estate/ path, populated `.cpy` sequence area, exclude removed, exclude duplicated into `.gitignore`) and passes on five clean inputs (minimal fixture, empty range, empty commit, the NIST full-file-scan regression case, and three byte-encoding edge cases), then re-checks the real fork's live state. Verified re-runnable (ran twice consecutively, both green) with zero residue (`git status --porcelain` and `git branch --list` unchanged).
- `.githooks/commit-separability.sh`: FORK-03 enforcement — fails a commit only when its changed-path set intersects both the grammar family (`grammar.js`, `test/corpus/*`, `src/*`) and the fork-local family (`forest-shim/*`, `docs/*`, `.planning/*`, `.githooks/*`). Defaults to `upstream/main..HEAD`, falls back to `HEAD~20..HEAD` with an explicit message if `upstream/main` is unresolvable.
- `.githooks/pre-push`: reads git's stdin ref-update protocol once, runs both guards over the correct ranges, resolves sibling scripts relative to its own directory, and records the `git push --no-verify` bypass limitation as a comment. Installed via `git config core.hooksPath .githooks` (verified with `git config --get`).

## Task Commits

Each task was committed atomically:

1. **Task 1: The three-check estate-leak guard** - `10119d5` (feat)
2. **Task 2: Re-runnable fail-then-pass proof of the guard** - `df41d82` (test)
3. **Task 3: Wire both guards to pre-push and add the commit-separability check** - `de02b67` (feat)

**Plan metadata:** pending (this commit)

## Files Created/Modified
- `.githooks/estate-guard.sh` - the three-check guard, all modes, byte-column semantics pinned
- `.githooks/estate-guard-selftest.sh` - scratch-repo fail-then-pass proof (D-18)
- `.githooks/commit-separability.sh` - FORK-03 enforcement over a commit range
- `.githooks/pre-push` - the hook wiring both guards, sourced relative to its own directory

## Decisions Made
- Followed the plan's D-18 decision-fidelity note exactly: throwaway branches for the self-test live in a `mktemp -d` scratch repo, never in this fork
- `SEQ_AREA_FIRST_BYTE=74` pins the raw-diff-line-to-content-byte offset arithmetic in one variable, per the plan's explicit instruction, so the two can never silently drift apart
- Used file-based accumulation (a temp file under a `mktemp -d` guard-scoped directory) instead of shell variables to cross a piped `while read` loop boundary, avoiding the POSIX-sh subshell variable-scope trap for `FAIL_COUNTER`/`CHECKS_RUN` — an implementation detail not specified by the plan but necessary for correctness

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Self-test's estate/ path pollution fixture needed `git add -f`**
- **Found during:** Task 2 (writing the self-test's case 1), confirmed while manually verifying the guard against a hand-built scratch repo before trusting the self-test script
- **Issue:** The scratch repo's base state deliberately sets `/estate/` in its own `.git/info/exclude` (to mirror this fork's live posture, matching D-16 point 2's assertion target). That means `git add estate/placeholder.txt` is refused by git itself ("ignored by one of your .gitignore files") — the polluted commit for case 1 was silently never created, and the guard's PASS result was actually testing an empty diff, not the estate/-path scenario it claimed to test.
- **Fix:** Added `-f` to the `git add` call for the case 1 fixture in `.githooks/estate-guard-selftest.sh`. This is the correct way to force a deliberately-polluted commit into existence for testing purposes inside a disposable scratch repo — it does not touch or weaken any exclusion posture in this fork itself.
- **Files modified:** `.githooks/estate-guard-selftest.sh` (case 1 block only)
- **Verification:** Re-ran the self-test after the fix; case 1 correctly reports `expected-FAIL-observed-FAIL` (guard's own CHECK 1 catches the estate/ path independently of the exclude entry). Manually confirmed with a standalone scratch-repo reproduction before and after the fix.
- **Committed in:** `df41d82` (Task 2 commit — the fix was made before the task's first commit, so no separate follow-up commit was needed)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for the self-test to actually exercise the scenario it claims to test rather than silently passing on an empty diff. No scope creep — the fix is confined to the polluted-fixture construction inside the disposable scratch repo.

## Issues Encountered

None beyond the deviation above.

## User Setup Required

None - no external service configuration required. `git config core.hooksPath .githooks` was run in this clone as part of Task 3's verification; a future clone of this fork needs the same one-line command, which is documented as this phase's Part C install step and will be restated in `docs/vendoring.md` (plan 04).

## Next Phase Readiness

- FORK-02 and FORK-03 are both fully implemented, wired to `pre-push`, and proven — the guard fires on every future `git push` from this clone (barring `--no-verify`, an accepted, documented limitation)
- Plan 04 (`docs/vendoring.md`) should carry forward the `--no-verify` bypass statement verbatim, per D-17/Part D of this plan
- No blockers identified for subsequent plans in this phase

## Self-Check: PASSED

- All 4 key files verified present on disk with `[ -f ]` and executable with `[ -x ]`
- All 3 commit hashes (`10119d5`, `df41d82`, `de02b67`) verified present via `git log --oneline --all`
- All acceptance criteria for all three tasks re-run and confirmed PASS (parse checks, grep-based pins, exit codes, self-test run twice consecutively both exit 0, `git status --porcelain`/`git branch --list` unchanged after the self-test, `core.hooksPath` correctly set)
- Plan-level `<verification>` re-run: `bash .githooks/estate-guard-selftest.sh` exits 0 twice in a row and reports all 9 numbered cases plus both real-repo checks; `sh .githooks/estate-guard.sh --check-exclude` exits 0 against the live repo; `sh .githooks/commit-separability.sh` exits 0 against the current 17-commit history; `git config --get core.hooksPath` prints `.githooks`; `git status --porcelain` and `git branch --list` unchanged

---
*Phase: 01-delivery-pipe-measurement-baseline*
*Completed: 2026-08-29*
