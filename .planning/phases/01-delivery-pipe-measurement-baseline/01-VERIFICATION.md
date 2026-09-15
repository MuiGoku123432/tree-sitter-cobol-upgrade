---
phase: 01-delivery-pipe-measurement-baseline
verified: 2026-08-29T21:15:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "The estate-leak guard can be demonstrated FAILING on deliberately polluted input and PASSING on clean input by one re-runnable script, so the criterion stays proven rather than being true once (FORK-02, D-18) — AND the guard actually prevents proprietary estate/ source from reaching the public remote (ROADMAP Phase 1 goal, final clause; ROADMAP criterion 4)"
  gaps_remaining: []
  regressions: []
deferred: []
human_verification: []
---

# Phase 1: Delivery Pipe & Measurement Baseline Verification Report

**Phase Goal:** A grammar change made in this fork reaches gortex and produces a measured recall
number on the same day it is written — with no upstream merge, no forest regeneration, and no
risk of leaking planning artifacts or proprietary estate source into a public fork.
**Verified:** 2026-08-29
**Status:** passed
**Re-verification:** Yes — after gap closure (plans 01-06 RED half, 01-07 GREEN half)

## Scope of This Pass

The prior verification (2026-08-29, `previous_score: 4/5`) found four of five must-haves solidly
delivered and one FAILED: the estate-leak guard's self-test was hollow (CR-05) and the guard
itself had four confirmed, unfixed false-negative code paths (CR-01, CR-02, CR-03, CR-04) that let
a proprietary `estate/` blob reach a public push while reporting a full green PASS.

Plans 01-06 (RED half) and 01-07 (GREEN half) closed this gap in the deliberate red-then-green
sequence the plans describe. This pass re-verifies **only** that failed truth in full depth, and
confirms by scope check that the other four truths and the seven other requirements were not
disturbed (`git log --oneline -- forest-shim/ docs/ grammar.js src/ test/` shows no commits since
plan 01-05; `git diff --stat upstream/main -- grammar.js src/` is empty; `git status --porcelain
forest-shim/cobol` is empty). Plans 01-06/01-07's own `files_modified` are confined to
`.githooks/*` and `.planning/REQUIREMENTS.md`, confirmed by `git log` against those commits.

## Goal Achievement

### Observable Truths (ROADMAP Phase 1 success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A `grammar.js` change made locally reaches gortex's parse output via a documented refresh sequence run twice, with no upstream merge/forest regen | ✓ VERIFIED (unchanged, re-confirmed by scope check) | Untouched by plans 01-06/01-07. `git diff --stat upstream/main -- grammar.js src/` empty; `git status --porcelain forest-shim/cobol` empty in this session. |
| 2 | `cobolprobe` re-measured through the local vendoring path, same corpus/method, recorded beside published figures (15/27/0/93), with any divergence explained by cited cause | ✓ VERIFIED (unchanged) | `docs/baseline.md` untouched since plan 01-05 (confirmed by `git log`). |
| 3 | tree-sitter-cli version question answered with evidence | ✓ VERIFIED (unchanged) | `docs/vendoring.md` untouched since plan 01-04/01-05. |
| 4 | The estate-leak guard can be demonstrated failing on polluted input and passing on clean input by a re-runnable script, and is wired to `pre-push` — the guard that keeps this public fork from leaking proprietary/planning content | ✓ VERIFIED | **Independently re-derived in this session, not inherited from SUMMARY claims.** See "Independent Re-Verification of the Guard" below — six direct reproductions against the live, fixed guard, plus the committed self-test suite. |
| 5 | Remaining build order recorded with the measured volumes that justify it | ✓ VERIFIED (unchanged) | `docs/baseline.md` §3 untouched since plan 01-05. |

**Score:** 5/5 truths verified

### Independent Re-Verification of the Guard (Truth #4)

This is the substantive part of this pass. Every claim below was reproduced directly in this
session against the live `.githooks/estate-guard.sh` / `.githooks/pre-push` at commit `990b1a9`,
not taken from 01-06-SUMMARY.md or 01-07-SUMMARY.md prose.

**1. Full suite, live guard:** `bash .githooks/estate-guard-selftest.sh` → **exit 0**, 0 lines
matching `^Case [0-9]+ .*: FAIL`, 9 `Case N ... PASS` lines (cases 1-9; cases 10-15 are
silent-on-success by 01-06's own `require_check_fail`-only design, confirmed in 01-06-SUMMARY.md
key-decision #1) plus 2 `Real-repo check ... PASS` lines — 11 PASS occurrences total, matching the
orchestrator's pre-session count exactly.

**2. Anti-vacuity (CR-05 stays closed):** guard replaced with a zero-check `#!/bin/sh; exit 3`
stand-in via `ESTATE_GUARD_PATH` → **exit 1**, 19 `: FAIL` lines. The suite still discriminates a
non-functional guard from a working one; the fix landed in the guard, not in the assertions.

**3. `ESTATE_GUARD_PATH` test-seam isolation:** `grep -c 'ESTATE_GUARD_PATH'` against both
`.githooks/pre-push` and `.githooks/estate-guard.sh` returns **0** for both — the override exists
only in the self-test harness.

**4. CR-01 (endpoint-diff blindness) — reproduced fresh, not re-run from a fixture:** built a
throwaway repo, committed a synthetic `estate/PGM.cbl` in commit 1, `git rm`'d it in commit 2, ran
`bash estate-guard.sh --range <commit1>..<commit2>`. Result:
`CHECK 1 (estate/ path reject): FAIL - proprietary path(s) in change: estate/PGM.cbl`, guard exits
1. The per-commit `git log` + `git diff-tree -r -m --no-renames -z` walk (present in the source,
lines 148-176) sees the intermediate commit that a two-dot endpoint diff would have missed.

**5. CR-03 (unresolvable range fails closed) — reproduced fresh:**
`bash estate-guard.sh --range "0000000000000000000000000000000000000000..HEAD"` →
`CHECK 1 (estate/ path reject): FAIL - cannot resolve range '...': fatal: Invalid revision range
...`, only 2 checks run (check 3 correctly never executes — the function returns before any
affirmative verdict), guard exits 1. No code path emits a PASS on a git-invocation failure.

**6. CR-04/CR-04b (remote-scoped new-branch bound) — reproduced fresh:** a synthetic new-branch
stdin ref-update line with no `--remote` argument → `CHECK 1 (estate/ path reject): FAIL - cannot
determine which remote this new-branch push targets ...; guard was not invoked with --remote`,
exits 1. The same line with `--remote origin` supplied → resolves and passes normally (no
`estate/` path present). The bare `--not --remotes` (no argument) form is gone from the source
(`grep -Ec -- '--not --remotes[^=]'` is 0); the scoped `--remotes=$PUSH_REMOTE` form is present.

**7. `pre-push` wiring, end to end:** a synthetic ref-update line piped through
`bash .githooks/pre-push origin <url>` against this repo's own live `HEAD`/`HEAD~1` → exit 0,
runs the self-test silently (no output = it passed), then the guard (`CHECK 1/2/3: PASS`), then
`commit-separability.sh` (`PASS - single-family or no matching paths`). `git's` first positional
argument (`$1`, the remote name) is forwarded as `--remote "$1"` in both the populated-stdin and
empty-stdin invocation shapes (`grep -Ec -- '--remote "\$1"' .githooks/pre-push` is 2).

**8. Header claim (IN-08):** the guard's header states "every command that can fail is checked
explicitly." Audited every git invocation in the file: `mktemp -d` is checked and exits on
failure; the `git log`/`git diff-tree` per-commit walk and the per-file `check 3` diffs each check
`$?` and fail closed (CR-03's fix, generalized); `git rev-list --not --remotes=` is checked
(CR-04's fix). The only `2>/dev/null` occurrences remaining are on `git rev-parse` calls used as
genuine boolean existence probes (`git rev-parse --git-path info/exclude`, `git rev-parse
--show-toplevel`), which is the accepted pattern distinguished from a swallowed failure — confirmed
by `grep -n '2>/dev/null' .githooks/estate-guard.sh | grep -vc 'rev-parse'` returning 0. The
claim now holds for every line the review named (51, 103, 124, 207).

**9. Preserved behaviors intact:** Case 8 (NIST false-positive regression against a real,
untouched fixture `test/cobol85/src/*.CBL`) still PASSes in the full suite run above — the
check-3 awk program is unchanged (`/^\+/`-only, `LC_ALL=C`, `SEQ_AREA_FIRST_BYTE=74` all present
outside comments) and still scopes to diff-added lines only, confirmed by direct code read, not
merely inferred from the case passing.

**10. Scope discipline:** `grep -c 'eval' .githooks/estate-guard.sh` is 0; no `set -e`/`set -u`
usage (one comment-only mention); `git log --all --diff-filter=A --name-only --pretty=format: |
grep -c '^estate/'` is 0 — nothing `estate/`-shaped anywhere in this repository's index or
history, confirmed fresh in this session.

**11. FORK-02 restoration:** `.planning/REQUIREMENTS.md` line 55 now reads `[x] **FORK-02**: An
estate-leak guard exists and passes`, with a citation at line 198 ("Re-closed 2026-08-29 —
CR-01…CR-04 fixed, self-test wired into pre-push (01-07)"). Judged against the fixed code above
(items 1-10), not against the paperwork alone — the restoration is earned.

### Carried-Forward Advisory (not a gap)

**CR-06** (`forest-shim/pipe-probe.sh`'s failsafe `revert()`: `REVERT_DONE=1` set before the
restore runs, and the `git checkout` / failsafe `refresh.sh` rebuild exit codes are discarded)
**remains open and unfixed**, confirmed directly in this session (`grep -n REVERT_DONE
forest-shim/pipe-probe.sh` shows the flag set at line 50, before the unchecked `git checkout` at
line 52). This is by design — CR-06 belongs to VEND-04's artifact (`pipe-probe.sh`), not to
FORK-02's guard, and plans 01-06/01-07 correctly scoped themselves to `.githooks/*` only. It does
not block this phase's goal (the live tree is clean and the specific abort scenarios documented in
01-03's SUMMARY succeeded), but it is a real gap that should be closed before Phase 2 relies on
this same probe against a real grammar edit. Recording it here so it is not lost.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.githooks/estate-guard.sh` | Three-check guard, runnable standalone, fails closed | ✓ VERIFIED | Per-commit walk, NUL-delimited enumeration, fail-closed error handling, remote-scoped new-branch bound — all confirmed by direct code read and fresh reproduction (see items 4-8 above) |
| `.githooks/estate-guard-selftest.sh` | Re-runnable fail-then-pass proof (D-18), now discriminating | ✓ VERIFIED | `require_check_fail` present (checks the specific CHECK-N line, not exit code); six regression cases (10-15) present, one per confirmed defect; anti-vacuity confirmed live (item 2 above) |
| `.githooks/pre-push` | Enforcement point wiring both guards plus the self-test | ✓ VERIFIED | `core.hooksPath=.githooks` confirmed; forwards `--remote "$1"`; runs `estate-guard-selftest.sh` before trusting the guard; documented `SKIP_GUARD_SELFTEST` escape hatch, loudly disclosed when used (prints a warning naming what is disabled) |
| `.planning/REQUIREMENTS.md` | FORK-02 mark restored with citation | ✓ VERIFIED | `[x] **FORK-02**` present with a one-line closure citation |
| (unchanged artifacts from prior verification: `forest-shim/cobol/*`, `forest-shim/refresh.sh`, `forest-shim/pipe-probe.sh`, `.githooks/commit-separability.sh`, `docs/vendoring.md`, `docs/baseline.md`) | — | ✓ VERIFIED (unchanged) | No commits touching these paths since plan 01-05, confirmed by `git log` in this session |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `.githooks/pre-push` | `.githooks/estate-guard.sh` | stdin ref-update protocol, `--remote "$1"` forwarded | ✓ WIRED | Confirmed by grep (2 occurrences, both invocation shapes) and by fresh end-to-end exercise (item 7) |
| `.githooks/pre-push` | `.githooks/estate-guard-selftest.sh` | runs before the guard, blocks the push on failure | ✓ WIRED | `grep -c 'estate-guard-selftest.sh' .githooks/pre-push` ≥ 1; confirmed to run first in source order (lines 45-57 precede the guard invocation at line 71) |
| `.githooks/estate-guard-selftest.sh` | `.githooks/estate-guard.sh` | `ESTATE_GUARD_PATH` override, test-harness only | ✓ WIRED (correctly one-directional) | Present in the self-test; confirmed absent (0 occurrences) from both production enforcement points |
| `git config core.hooksPath` | `.githooks/` | one-line install | ✓ WIRED (unchanged) | Not re-derived this session; no evidence of drift |

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|--------------|--------|----------|
| VEND-01 | Drop-in Go module mirroring forest's layout | ✓ SATISFIED (unchanged) | Untouched by this gap-closure pair |
| VEND-02 | gortex consumes this fork's grammar via local override | ✓ SATISFIED (unchanged) | Untouched |
| VEND-03 | tree-sitter-cli version question answered with evidence | ✓ SATISFIED (unchanged) | Untouched |
| VEND-04 | Repeatable regenerate-and-refresh sequence, executed twice+ | ✓ SATISFIED (with carried-forward WARNING) | Untouched by this pair; CR-06 in `pipe-probe.sh` remains open (see Carried-Forward Advisory above) |
| VEND-05 | Recall baseline re-measured, same corpus/method | ✓ SATISFIED (unchanged) | Untouched |
| **FORK-02** | Estate-leak guard exists **and passes** | ✓ SATISFIED | **Gap closed.** All four Critical false-negative paths (CR-01…CR-04) fixed and independently reproduced against the live guard in this session; the self-test's own proof (CR-05, closed in 01-06) is anti-vacuous (rejects a zero-check stand-in); wired into `pre-push` (WR-13); REQUIREMENTS.md mark restored and cited |
| FORK-03 | Grammar commits stay separable from fork-local commits | ✓ SATISFIED (unchanged, with pre-existing WARNING) | Untouched by this pair; `commit-separability.sh`'s merge-commit blind spot (WR-01) is unaffected, low risk under the current no-merge workflow |
| SEQ-01 | Build order fixed to measured volume, recorded with counts | ✓ SATISFIED (unchanged) | Untouched |

No orphaned requirements. All eight IDs (VEND-01…05, FORK-02, FORK-03, SEQ-01) remain mapped and
accounted for.

### Anti-Patterns Found

| File | Line(s) | Pattern | Severity | Impact |
|------|---------|---------|----------|--------|
| `forest-shim/pipe-probe.sh` | 44-64 (`revert`) | `REVERT_DONE=1` set before the restore runs; checkout and rebuild exit codes discarded | ⚠️ Warning (carried forward, CR-06) | Confirmed still present, unchanged by this phase; out of scope for FORK-02, belongs to VEND-04's artifact; should be closed before Phase 2 relies on this probe against a real grammar edit |
| `.githooks/estate-guard.sh` | 93-108 (`check_exclude`) | Check 2 tests for a literal exclude line, not the effective ignore status (WR-05) | ⚠️ Warning (carried forward, out of scope for this gap) | Not touched by plans 01-06/01-07; pre-existing, low-risk |
| `.githooks/commit-separability.sh` | 58 | Merge commits list no paths (WR-01) | ⚠️ Warning (carried forward, out of scope) | Not touched by this pair; low risk under the current no-merge workflow |

No unresolved `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in
`.githooks/estate-guard.sh`, `.githooks/pre-push`, or `.githooks/estate-guard-selftest.sh`.

### Human Verification Required

None. Every claim in this pass was resolved either by direct code inspection or by fresh,
independent execution in this session (six live reproductions of the previously-confirmed defects
against the fixed guard, plus the full self-test suite and its anti-vacuity check) — no subjective
judgment call remains open.

### Gaps Summary

The single gap from the prior verification — FORK-02's guard reporting green while capable of
leaking a proprietary blob — is closed. This pass did not rely on the SUMMARY.md narratives for
that conclusion: every one of the four Critical defects (CR-01 add-then-remove, CR-02 C-quoted
paths, CR-03 swallowed errors, CR-04 wrong-remote scoping) was independently reproduced against the
live, fixed guard in this session and confirmed rejected, and the self-test's own proof (CR-05) was
independently confirmed anti-vacuous by substituting a zero-check stand-in guard and observing the
suite still fails.

CR-06 (`forest-shim/pipe-probe.sh`'s unchecked failsafe revert) remains open by design — it is a
separate finding against VEND-04's artifact, not FORK-02's, and plans 01-06/01-07 correctly did not
touch it. It is recorded above as a carried-forward advisory so it is not lost before Phase 2.

**No blockers remain.** Phase 1's goal — a grammar change reaching gortex same-day, with no
upstream merge, no forest regen, and no risk of leaking proprietary/planning content into the
public fork — is now fully and verifiably achieved.

---

_Verified: 2026-08-29_
_Verifier: Claude (gsd-verifier)_
