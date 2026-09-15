---
phase: 01-delivery-pipe-measurement-baseline
plan: 06
kind: RED-evidence
date: 2026-08-29
guard_revision: de02b67
guard_status: unfixed (unchanged by this plan)
suite_exit: non-zero
cases_failed: [10, 11, 12, 13, 14, 15]
cases_failed_count: 6
findings_covered: [CR-01, CR-02, CR-03, CR-04, CR-05]
---

# 01-06 RED Evidence: Estate-Leak Guard Self-Test Discriminates

**This file is the evidence that the strengthened self-test now discriminates a working guard
from a broken one.** Plan 01-06 hardened `.githooks/estate-guard-selftest.sh` so it asserts
*which specific check* the guard must report as failed (CR-05's fix), and added one regression
case per confirmed guard defect (CR-01, CR-02a, CR-02b, CR-03, CR-04, CR-04b). Both transcripts
below were captured against the guard exactly as it shipped at commit `de02b67` — **plan 01-06
does not touch `.githooks/estate-guard.sh` or `.githooks/pre-push`.**

**Plan 01-07 is the only thing permitted to turn these cases green — by fixing the guard, never
by relaxing an assertion in the self-test.** If a future run of this suite reports all cases
passing without a corresponding guard fix landing in `.githooks/estate-guard.sh`, that is a
regression in the self-test itself, not progress.

## Guard revision under test

```
$ git log -1 --format='%h %ad %s' --date=short -- .githooks/estate-guard.sh
de02b67 2026-08-29 feat(01-02): wire estate-leak and separability guards to pre-push (FORK-02, FORK-03)
```

## Transcript 1 — full suite against the shipped (unfixed) guard

Command: `bash .githooks/estate-guard-selftest.sh`
Result: **exit 1** (non-zero — the suite correctly rejects the current guard)
Wall-clock runtime: ~2s

```
estate-guard-selftest: guard under test (ESTATE_GUARD_PATH override honored here only, default is the tracked guard): /Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-upgrade/.githooks/estate-guard.sh
Case 1 (estate/ path pollution): PASS (expected-FAIL-observed-FAIL)
Case 2 (populated columns 73-80 sequence area in added .cpy): PASS (expected-FAIL-observed-FAIL)
Case 3 (exclusion line removed from .git/info/exclude): PASS (expected-FAIL-observed-FAIL)
Case 4 (exclusion duplicated into .gitignore): PASS (expected-FAIL-observed-FAIL)
Case 5 (clean minimal fixture, short lines): PASS (expected-PASS-observed-PASS)
Case 6 (empty range, no new commits): PASS (expected-PASS-observed-PASS)
Case 7 (empty commit, zero added lines): PASS (expected-PASS-observed-PASS)
Case 8 (NIST false-positive regression: PROBE01.CBL untouched, full-file-scan guard): PASS (expected-PASS-observed-PASS)
Case 9 (encoding edge cases (72-byte, tab, UTF-8 multibyte), all clean): PASS (expected-PASS-observed-PASS)
Case 10 (CR-01 add-then-remove, endpoint diff blind to intermediate commit): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 11 (CR-02a non-ASCII estate/ path evades the anchored path match): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 12 (CR-02b embedded-quote estate/ path evades check 1 even with core.quotePath=false): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 13 (CR-03 unresolvable range must fail closed, not silently report PASS): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 14 (CR-04 two-remote new-branch push, --remote forwarded but unsupported by the guard): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 15 (CR-04b missing --remote falls back to excluding commits reachable from any configured remote): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Real-repo check (--check-exclude): PASS
Real-repo check (--range HEAD~1..HEAD): PASS
```

### Which cases failed and what they prove

| Case | Finding | Check label expected but not reported | What it proves |
|------|---------|----------------------------------------|----------------|
| 10 | CR-01 | `CHECK 1` (estate/ path reject) | Add-then-remove within one range: the guard's two-dot endpoint diff nets to empty even though `git rev-list --objects` over the same range confirms the blob is fully present in the pushed object closure. |
| 11 | CR-02a | `CHECK 1` (estate/ path reject) | A non-ASCII `estate/` basename is C-quoted by default `core.quotePath=true`, so `grep -E '^estate/'` never matches the quoted line. |
| 12 | CR-02b | `CHECK 1` (estate/ path reject) | An embedded-double-quote `estate/` basename evades check 1 even with `core.quotePath=false` explicitly set — that setting only recovers non-ASCII names, not embedded quotes. |
| 13 | CR-03 | `CHECK 1` (estate/ path reject) | A range naming a nonexistent 40-hex-digit commit: `git diff`'s failure and exit status are both swallowed, and the guard affirmatively reports "no estate/ path in change" instead of failing closed. |
| 14 | CR-04 | `CHECK 1` (estate/ path reject) | Forwarding `--remote origin` (the shape CR-04's fix requires) is rejected outright by the guard's argument dispatch — it has no `--remote` support at all yet, so the invocation errors out before any check runs. |
| 15 | CR-04b | `CHECK 1` (estate/ path reject) | The same two-remote new-branch push with no `--remote` forwarded: the guard's bare `--not --remotes` bound excludes the commit because it is reachable from the non-target remote ("other"), silently skipping the scan. |

Cases 5-9 (clean minimal fixture, empty range, empty commit, the NIST false-positive regression,
and the encoding edge cases) all still report PASS, unchanged. Cases 1-4 (the original polluted
cases) also still report PASS — CR-01 through CR-04 are blind spots in specific range/path/remote
shapes, not regressions in the guard's basic single-commit detection, so cases 1-4 continue to
demonstrate that the guard's straightforward checks work correctly.

## Transcript 2 — CR-05 stand-in reproduction (zero-check guard)

This is a separate demonstration from the six defect cases above: it proves the self-test rejects
a guard that performs *no checks at all*, which is the specific CR-05 finding (the original
`report_case`-only assertion could not distinguish "the guard caught the right thing" from "the
guard exited non-zero for any reason").

Command:
```
printf '#!/bin/sh\nexit 3\n' > /tmp/gsd-stub-guard.sh && chmod +x /tmp/gsd-stub-guard.sh
ESTATE_GUARD_PATH=/tmp/gsd-stub-guard.sh bash .githooks/estate-guard-selftest.sh
```
Result: **exit 1** (non-zero — the suite correctly rejects the zero-check stand-in)

```
estate-guard-selftest: guard under test (ESTATE_GUARD_PATH override honored here only, default is the tracked guard): /tmp/gsd-stub-guard.sh
Case 1 (estate/ path pollution): PASS (expected-FAIL-observed-FAIL)
Case 1 (estate/ path pollution): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 2 (populated columns 73-80 sequence area in added .cpy): PASS (expected-FAIL-observed-FAIL)
Case 2 (populated columns 73-80 sequence area in added .cpy): FAIL (expected CHECK 3 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 3 (exclusion line removed from .git/info/exclude): PASS (expected-FAIL-observed-FAIL)
Case 3 (exclusion line removed from .git/info/exclude): FAIL (expected CHECK 2 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 4 (exclusion duplicated into .gitignore): PASS (expected-FAIL-observed-FAIL)
Case 4 (exclusion duplicated into .gitignore): FAIL (expected CHECK 2 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 5 (clean minimal fixture, short lines): FAIL (expected-PASS-observed-FAIL, exit=3)
Case 6 (empty range, no new commits): FAIL (expected-PASS-observed-FAIL, exit=3)
Case 6 (empty range, no new commits): FAIL (missing CHECK 2 result line -- vacuous pass)
Case 7 (empty commit, zero added lines): FAIL (expected-PASS-observed-FAIL, exit=3)
Case 7 (empty commit, zero added lines): FAIL (missing CHECK 2 result line -- vacuous pass)
Case 8 (NIST false-positive regression: PROBE01.CBL untouched, full-file-scan guard): FAIL (expected-PASS-observed-FAIL, exit=3)
Case 9 (encoding edge cases (72-byte, tab, UTF-8 multibyte), all clean): FAIL (expected-PASS-observed-FAIL, exit=3)
Case 10 (CR-01 add-then-remove, endpoint diff blind to intermediate commit): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 11 (CR-02a non-ASCII estate/ path evades the anchored path match): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 12 (CR-02b embedded-quote estate/ path evades check 1 even with core.quotePath=false): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 13 (CR-03 unresolvable range must fail closed, not silently report PASS): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 14 (CR-04 two-remote new-branch push, --remote forwarded but unsupported by the guard): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Case 15 (CR-04b missing --remote falls back to excluding commits reachable from any configured remote): FAIL (expected CHECK 1 to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)
Real-repo check (--check-exclude): FAIL
Real-repo check (--range HEAD~1..HEAD): FAIL
```

Every one of the 15 cases (plus both real-repo checks) rejects the zero-check stand-in — before
this plan, `report_case`'s exit-code-only assertion would have reported cases 1-4 as a clean PASS
against this exact same stand-in (per `01-REVIEW.md` CR-05's original reproduction). The
`require_check_fail` assertions this plan added are what makes the difference visible.

## Scratch-directory teardown check

Recorded per Task 2's acceptance criterion — `$TMPDIR/tmp.*` entry count before and after two
consecutive suite runs (this machine's `mktemp -d` resolves under `$TMPDIR`, not literal
`/tmp/tmp.*`):

```
before=6 after_run1=6 after_run2=6
```

No growth — the existing `EXIT`/`INT`/`TERM` trap on `$SCRATCH` correctly tears down the scratch
repo and its nested bare "origin"/"other" remotes (added for cases 14/15) on every run.

## Suite wall-clock runtime

~2 seconds per full run (15 cases + 2 real-repo checks). Recorded for plan 01-07's WR-13
per-push cost tradeoff (wiring the selftest into `pre-push` itself) — at this cost, running it on
every push is cheap relative to the risk it closes.

## What this evidence does NOT claim

This transcript does not claim the guard is now safe to rely on — the opposite: it is the
documented proof that it is not, yet, and that the self-test can finally say so precisely. Plan
01-07 must land the CR-01/CR-02/CR-03/CR-04 fixes in `.githooks/estate-guard.sh` (and, per WR-13,
wire the self-test into `.githooks/pre-push`) before any of cases 10-15 above are permitted to
turn green.
