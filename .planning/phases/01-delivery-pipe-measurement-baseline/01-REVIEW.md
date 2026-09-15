---
phase: 01-delivery-pipe-measurement-baseline
reviewed: 2026-08-29T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - .githooks/estate-guard.sh
  - .githooks/estate-guard-selftest.sh
  - .githooks/commit-separability.sh
  - .githooks/pre-push
  - forest-shim/refresh.sh
  - forest-shim/pipe-probe.sh
  - forest-shim/cobol/smoke_test.go
  - forest-shim/cobol/binding.go
  - forest-shim/cobol/plugin.go
  - forest-shim/cobol/go.mod
findings:
  critical: 6
  warning: 16
  info: 8
  total: 30
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-29
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The delivery pipe (`refresh.sh` -> shim -> `go.work` -> gortex) is structurally sound, and the
one step the brief flagged as most defect-prone — the two-pattern `#include` rewrite in
`refresh.sh` step 4 — is **correct**. Verified against the actual files: `src/parser.c:1` carries
`#include "tree_sitter/parser.h"` (quoted), `src/scanner.c:1` carries
`#include <tree_sitter/parser.h>` (angle-bracket), the two `sed` invocations use two genuinely
distinct patterns, both `$?` values are checked, and a post-rewrite `grep` independently confirms
the subdirectory path is gone. That step does what it claims.

The security control does not. **`estate-guard.sh` — the one thing standing between a 697MB
proprietary working copy and a public GitHub remote — can be made to report a full green PASS
while a proprietary blob rides along in the pushed object closure.** Four independent false
negatives were found and each was reproduced end-to-end against the real script, not inferred.
The most severe (CR-01) requires no adversary at all: an ordinary "added it, then thought better
of it" commit pair inside a single push defeats all three checks simultaneously. Because a false
negative here is a disclosure of proprietary source on a public repo, these are classified
Critical without hedging.

Compounding this: the fail-then-pass selftest that exists to prove the guard works (CR-05) asserts
only that the guard exited non-zero. A guard replaced with `#!/bin/sh` + `exit 3` — performing
zero checks — makes all four pollution cases report PASS. The proof does not constrain the thing
it claims to prove, and it is never run by `pre-push`, so a regression in the guard ships silently.

Secondary theme: the repo's documented house style is "no `set -e`/`set -u`; every command that
can fail is checked explicitly." As instructed, the absence of `set -euo pipefail` is **not**
raised. But the second half of that contract is broken in specific, load-bearing places —
`git diff`, `git rev-list`, `mktemp`, `git checkout`, and the failsafe's own shim rebuild all have
their exit status discarded, and in every one of those cases the resulting behavior is a silent
pass rather than a loud failure. Those are raised individually (CR-03, CR-06, WR-02, WR-03, WR-04).

The Go shim is faithful to the upstream surface it impersonates and is judged on that basis:
`binding.go`/`plugin.go` match forest's shape, `go vet` is clean, and the byte-identical
duplication between them is upstream's design and is deliberately **not** flagged. Findings there
are confined to test coverage.

---

## Critical Issues

### CR-01: Guard's two-dot endpoint diff is blind to every intermediate commit — proprietary blob pushed with all three checks reporting PASS

**File:** `.githooks/estate-guard.sh:103`, `:124`, `:216`, `:219`

**Issue:** Checks 1 and 3 both derive their input from `git diff <A>..<B>`. Two-dot syntax in
`git diff` compares the two **endpoint trees** — it is identical to `git diff A B` and does not
walk the commits between them. A push whose range adds a file under `estate/` in one commit and
removes it in a later commit produces an empty endpoint diff, so the changed set the guard
inspects is empty. Git nevertheless transmits the full object closure of every pushed commit,
including the intermediate tree and its blob.

Reproduced against the unmodified script. Range: commit 1 adds `estate/PGM.cbl` (synthetic
COBOL, populated sequence area — designed to trip check 1 *and* check 3); commit 2 `git rm`s it:

```
CHECK 2 (exclusion posture): PASS - /estate/ declared in .git/info/exclude, absent from .gitignore
CHECK 1 (estate/ path reject): PASS - no estate/ path in change
CHECK 3 (columns 73-80 sequence area, added lines only): PASS - no populated sequence area on added COBOL lines
estate-guard: PASS (3 check(s) run, 0 failed)
GUARD EXIT=0
```

while, over that same range:

```
$ git rev-list --objects BASE..TIP | grep -i pgm
c227c60de960e652a246df94b39c7fa8824063cb estate/PGM.cbl
```

and the blob's content is fully retrievable from the pushed range. This is not an exotic attack —
it is the shape of any ordinary "staged it by mistake, removed it in the next commit, pushed the
branch" sequence, which is precisely the accident the guard exists to catch.

**Fix:** Scan every commit in the range, not the endpoints. Replace the diff-based path
enumeration with a per-commit walk, and disable rename detection so a rename out of `estate/`
cannot hide the source path either:

```sh
# Check 1 -- enumerate paths touched by EVERY commit in the range.
# --no-renames: a rename out of estate/ must still surface the estate/ source path.
# -z + NUL read: see CR-02.
CHANGED_PATHS_FILE="$GUARD_TMP/paths"
: > "$CHANGED_PATHS_FILE"
if [ "$DIFF_SPEC" = "--cached" ]; then
    git diff --cached --name-only --no-renames -z > "$CHANGED_PATHS_FILE" || DIFF_FAILED=1
else
    git log --format=%H "$DIFF_SPEC" > "$GUARD_TMP/commits" || DIFF_FAILED=1
    while IFS= read -r c; do
        git diff-tree -r -m --no-commit-id --name-only --no-renames -z "$c" \
            >> "$CHANGED_PATHS_FILE" || DIFF_FAILED=1
    done < "$GUARD_TMP/commits"
fi
```

Note `-m` on `diff-tree`, so merge commits are decomposed rather than silently listing nothing
(same root cause as WR-01). Check 3's per-file diff must be sourced the same way. Add a selftest
case that commits an `estate/` path and then removes it in a second commit, asserting FAIL.

---

### CR-02: `git diff --name-only` C-quotes special paths, so `grep -E '^estate/'` never matches them

**File:** `.githooks/estate-guard.sh:103-104` (and the same data feeds `:120`, `:124`)

**Issue:** With default `core.quotePath=true`, git wraps any path containing a non-ASCII byte in
double quotes with octal escapes; paths containing `"`, a tab, or a newline are quoted
**regardless** of that setting. The resulting line begins with `"`, not `e`, so the anchored
pattern `^estate/` cannot match, and check 1 reports PASS.

Reproduced — two files committed under `estate/`, one with a non-ASCII name, one containing a
double quote:

```
$ git diff --name-only BASE..HEAD | grep -E '^estate/'
grep exit=1        # NO MATCH -- guard reports "no estate/ path in change"

$ git diff --name-only -z BASE..HEAD | tr '\0' '\n' | grep -E '^estate/'
estate/café.txt
estate/quo"te.txt  # both caught
```

`core.quotePath=false` alone is **not** sufficient — it recovered the non-ASCII path but the
embedded-quote path was still quoted and still evaded. Only `-z` is reliable.

This also silently disables check 3 for the same paths: line 124 passes the quoted string
(literal `"` characters and all) to `git diff -- "$f"` as a pathspec, which matches nothing, and
the error is swallowed by `2>/dev/null` — so the file is never scanned and no hit is recorded.

**Fix:** Use NUL-delimited output and NUL-delimited reads throughout, and never re-derive a
pathspec from human-readable diff output:

```sh
git diff --name-only --no-renames -z $DIFF_SPEC > "$GUARD_TMP/paths"
# check 1
if LC_ALL=C tr '\0' '\n' < "$GUARD_TMP/paths" | grep -q -E '^estate/'; then ...

# check 3 -- read NUL-delimited so paths with spaces/newlines survive intact
while IFS= read -r -d '' f; do
    case "$f" in *.cbl|*.CBL|*.cpy|*.CPY|*.cob|*.COB|test/corpus/*|test/cobol85/*) ;; *) continue ;; esac
    ...
done < "$GUARD_TMP/paths"
```

(`read -d ''` is a bashism; either switch the shebang to `#!/bin/bash` as `pre-push` already
uses, or drive the loop with `xargs -0`.) Add selftest cases for a non-ASCII `estate/` path and
one containing a double quote.

---

### CR-03: A `git diff` that fails is reported as "PASS - no estate/ path in change"

**File:** `.githooks/estate-guard.sh:103`, `:124`

**Issue:** `CHANGED_PATHS="$(git diff --name-only $DIFF_SPEC 2>/dev/null)"` discards both stderr
and the exit status. When the range cannot be resolved, `CHANGED_PATHS` is empty and the guard
proceeds to affirmatively report that nothing bad was found. There is no "could not evaluate"
state — the failure mode is indistinguishable from a clean change.

Reproduced against the unmodified script with a range naming a nonexistent commit:

```
$ sh estate-guard.sh --range "deadbeef...deadbeef..HEAD"
CHECK 2 (exclusion posture): PASS - ...
CHECK 1 (estate/ path reject): PASS - no estate/ path in change
CHECK 3 (columns 73-80 sequence area, added lines only): PASS - ...
estate-guard: PASS (3 check(s) run, 0 failed)
EXIT=0
```

This is reachable in normal operation, not just under a synthetic bad argument: in stdin mode
line 219 builds `${REMOTE_SHA}..${LOCAL_SHA}` from git's ref-update protocol, and `REMOTE_SHA` is
not guaranteed to exist in the local object store — after the remote branch has been force-pushed
or advanced by another party, in a shallow clone, or when the remote-tracking ref is stale. Every
one of those turns the leak guard off silently.

It also directly contradicts the script's own header (lines 27-31): *"every command that can fail
is checked explicitly."*

**Fix:** Check the status and fail closed. A guard that cannot evaluate must block the push:

```sh
CHANGED_PATHS="$(git diff --name-only --no-renames -z $DIFF_SPEC 2>"$GUARD_TMP/diff.err")"
if [ $? -ne 0 ]; then
    report "CHECK 1 (estate/ path reject): FAIL - cannot evaluate range '$DIFF_SPEC': $(cat "$GUARD_TMP/diff.err")"
    FAIL_COUNTER=$((FAIL_COUNTER + 1))
    return
fi
```

Apply the same treatment to the `git diff` at line 124 and to `git rev-list` at line 207.

---

### CR-04: `--not --remotes` excludes commits already on *another* remote, so a new-branch push to the public remote skips scanning them

**File:** `.githooks/estate-guard.sh:207-216`; enabling cause in `.githooks/pre-push:29-31`

**Issue:** For a new branch (`REMOTE_SHA` all zeros), line 207 bounds the scan with
`git rev-list "$LOCAL_SHA" --not --remotes`. `--remotes` with no argument means *every*
remote-tracking ref in the repository, not the remote being pushed to. Any commit reachable from
any other remote is treated as "not new" and excluded; `tail -1` then picks a later commit as
`OLDEST_NEW` and the scanned range begins after the excluded commits.

This repo has two remotes configured today (`origin`, `upstream`), and the failure generalizes to
any additional (e.g. private) remote. Reproduced with a second remote holding the estate-bearing
commit:

```
$ git rev-list $LOCAL --not --remotes
b284eca...   = "clean commit"        # the estate commit is excluded

$ git diff --name-only "${OLD}^..${LOCAL}"
clean.txt                            # the guard scans only this
```

Pushing that branch to the public remote transmits the estate-bearing commit, which the guard
never looked at.

Line 208-210 makes it worse: if *every* commit is reachable from some remote, `OLDEST_NEW` is
empty and the code `continue`s — skipping checks 1 and 3 entirely for that ref update, with no
report line emitted and no counter incremented.

The information needed to fix this is available and being thrown away: git invokes `pre-push`
with the remote name as `$1` and its URL as `$2`. `pre-push` never reads them and never forwards
them to the guard.

**Fix:** Scope the exclusion to the remote actually being pushed to, and never skip silently:

```sh
# pre-push: forward git's remote name/URL to the guard
printf '%s\n' "$STDIN_DATA" | "$ESTATE_GUARD" --remote "$1"

# estate-guard.sh, new-branch branch:
OLDEST_NEW="$(git rev-list "$LOCAL_SHA" --not --remotes="$PUSH_REMOTE" 2>/dev/null | tail -1)"
if [ -z "$OLDEST_NEW" ]; then
    report "CHECK 1/3: SKIPPED - no commits new to remote '$PUSH_REMOTE' for $LOCAL_REF"
    # still emit a result line; do not vanish
    continue
fi
```

If `--remote` is absent, fail closed rather than defaulting to `--remotes`.

---

### CR-05: Selftest's pollution cases assert only a non-zero exit — a guard that performs no checks at all passes all four

**File:** `.githooks/estate-guard-selftest.sh:106-135`, helper at `:28-39`

**Issue:** Cases 1-4 exist to prove the guard *detects* specific pollution, but `report_case`
inspects nothing except the exit code (`OBSERVED=FAIL` whenever `$? != 0`). Any non-zero exit
satisfies them — a crash, a syntax error, a missing interpreter, an unrelated check failing, or a
guard that was never wired up. The `require_check2_line` helper that *would* catch this exists at
lines 41-47 but is applied only to cases 6 and 7, the two clean cases.

Reproduced by replacing the guard with a two-line script that performs zero checks
(`#!/bin/sh` / `exit 3`):

```
Case 1 (estate/ path pollution): PASS (expected-FAIL-observed-FAIL)
Case 2 (populated columns 73-80 sequence area in added .cpy): PASS (expected-FAIL-observed-FAIL)
Case 3 (exclusion line removed from .git/info/exclude): PASS (expected-FAIL-observed-FAIL)
Case 4 (exclusion duplicated into .gitignore): PASS (expected-FAIL-observed-FAIL)
```

This is why CR-01 through CR-04 could all be present while the D-18 proof reported success: the
proof cannot distinguish "the guard caught the right thing" from "the guard exited non-zero."
Given the selftest is the phase's stated evidence that the leak control works, its inability to
constrain the control is itself Critical.

**Fix:** Assert on the specific check that must have failed, not merely on the exit code. The
captured output (`OUT1`..`OUT4`) is already in hand and currently unused:

```sh
require_check_fail() {
    # $1=case  $2=desc  $3=output  $4=check label e.g. "CHECK 1"
    if ! printf '%s\n' "$3" | grep -q "^${4}.*: FAIL"; then
        echo "Case ${1} (${2}): FAIL (expected ${4} to report FAIL; guard may have exited non-zero for an unrelated reason)"
        RETURN_CODE=1
    fi
}
require_check_fail 1 "estate/ path pollution"        "$OUT1" "CHECK 1"
require_check_fail 2 "populated sequence area"       "$OUT2" "CHECK 3"
require_check_fail 3 "exclusion line removed"        "$OUT3" "CHECK 2"
require_check_fail 4 "exclusion duplicated"          "$OUT4" "CHECK 2"
```

Additionally assert cases 1-4 did **not** exit with a shell-error code (126/127/2) that would
indicate a crash rather than a rejection.

---

### CR-06: `pipe-probe.sh`'s failsafe reports success without verifying it restored anything, and guarantees an interrupted revert is never retried

**File:** `forest-shim/pipe-probe.sh:46-65`

**Issue:** Three compounding defects in the one function the whole probe's safety rests on:

1. **The restore is unchecked.** Line 52,
   `( cd "$TOP_DIR" && git checkout -- grammar.js src/ ) > /dev/null 2>&1` — stdout, stderr and
   `$?` are all discarded. If the checkout fails (index lock held by a concurrent git process,
   permissions, detached/conflicted state), line 60 still prints
   `"FAILSAFE: restored grammar.js and src/ from git"`. The report is emitted on the basis of the
   *pre*-revert status captured at line 51, never on the post-revert state.

2. **The shim rebuild is unchecked and can leave `forest-shim/cobol/` dirty.** `revert()` restores
   only `grammar.js` and `src/`. `forest-shim/cobol/{parser.c,scanner.c,grammar.json,parser.h}`
   were overwritten by step 4's `refresh.sh` run with the probe-renamed grammar, and are brought
   back only by the line 61 re-run — whose exit status is also discarded. That re-run fails
   routinely under conditions that are *more* likely mid-abort, e.g. `refresh.sh` step 5's drift
   check failing, or the Go toolchain being unavailable. Step 6 (line 204-210) does verify
   `forest-shim/cobol` is clean, but **only on the success path**; the trap-driven abort path —
   the one the failsafe exists for — verifies nothing. A killed probe can therefore leave a
   probe-renamed 30MB generated `parser.c` in the working tree while the log says the failsafe
   restored everything.

3. **`REVERT_DONE=1` is set before the work, not after** (line 50, before lines 51-61). The
   header comment (lines 41-43) argues this makes the handler idempotent; what it actually
   guarantees is that a revert interrupted partway — which is likely, since line 61 runs a
   multi-minute `npm ci` plus a cgo rebuild (see WR-09) — can never be completed. The EXIT trap's
   second pass hits the `return` at line 48 and the tree stays dirty.

The brief states fork hygiene depends on always returning level with upstream. All three paths
here break that while reporting that they upheld it.

**Fix:** Set the flag after completion, check both operations, and verify the post-state:

```sh
revert() {
    if [ "$REVERT_DONE" = "1" ]; then return; fi
    RESTORED=$(cd "$TOP_DIR" && git status --porcelain -- grammar.js src/)
    ( cd "$TOP_DIR" && git checkout -- grammar.js src/ ); CO_STATUS=$?
    rm -f "$TOP_DIR/src/tree_sitter/alloc.h" "$TOP_DIR/src/tree_sitter/array.h"
    if [ "$CO_STATUS" != "0" ]; then
        report "FAILSAFE: FAIL - git checkout -- grammar.js src/ exited $CO_STATUS; TREE IS DIRTY, restore by hand"
        return   # leave REVERT_DONE=0 so a later pass retries
    fi
    if [ -n "$RESTORED" ]; then
        ( cd "$TOP_DIR" && REFRESH_SKIP_INSTALL=1 REFRESH_SKIP_GENERATE=1 \
            bash "$TOP_DIR/forest-shim/refresh.sh" ) > "$PROBE_LOG.failsafe-refresh" 2>&1
        if [ $? != "0" ]; then
            report "FAILSAFE: FAIL - shim rebuild exited nonzero; forest-shim/cobol/ MAY BE DIRTY (see $PROBE_LOG.failsafe-refresh)"
            return
        fi
    fi
    # verify the post-state, on the abort path too -- not just in step 6
    LEFTOVER=$(cd "$TOP_DIR" && git status --porcelain -- grammar.js src/ forest-shim/cobol)
    if [ -n "$LEFTOVER" ]; then
        report "FAILSAFE: FAIL - still dirty after revert: $LEFTOVER"
        return
    fi
    REVERT_DONE=1
    report "FAILSAFE: OK - grammar.js, src/ and forest-shim/cobol/ verified clean"
}
```

---

## Warnings

### WR-01: Merge commits list no paths, so a merge mixing both families passes the separability check

**File:** `.githooks/commit-separability.sh:58`

**Issue:** `git show --stat --name-only --pretty=format: "$sha"` produces **empty output** for a
merge commit — git suppresses the combined diff by default. `PATHS` is empty, neither family
matches, and the commit is reported `PASS - single-family or no matching paths`. Verified: a merge
of a `grammar.js`-only branch into a `forest-shim/`-only branch yields empty output, while a
normal commit on the same repo correctly lists `forest-shim/x.sh`.

Since the check's whole purpose is preserving a reconstructible upstream PR branch, and merges are
exactly where two families converge, this is the highest-value blind spot in the file.

**Fix:** Use `git diff-tree` with `-m` so merges are decomposed against each parent, and skip the
`git show` porcelain entirely:

```sh
PATHS="$(git diff-tree -r -m --no-commit-id --name-only --no-renames "$sha" 2>/dev/null)"
```

### WR-02: An unresolvable range is reported as "PASS ... nothing to check", contradicting the file's own comment

**File:** `.githooks/commit-separability.sh:44-48`; fallback at `:36-41`

**Issue:** `git rev-list $RANGE 2>/dev/null` discards its status; an empty result is treated as
"0 commits, nothing to check" and exits 0. Verified:

```
$ sh commit-separability.sh --range "deadbeef...deadbeef..HEAD"
commit-separability: PASS (0 commits in range deadbeef...deadbeef..HEAD -- nothing to check)
EXIT=0
```

The `HEAD~20..HEAD` fallback at line 40 has the same defect from a different direction: in a
repository with fewer than 20 commits (a fresh clone, or a shallow one) `git rev-list HEAD~20..HEAD`
fails, and the run reports a green PASS. The comment at lines 26-27 explicitly promises
*"never silently check nothing"* — both paths do exactly that.

**Fix:** Check the status and distinguish "empty range" from "range could not be resolved":

```sh
COMMIT_LIST="$(git rev-list $RANGE 2>&1)"
if [ $? -ne 0 ]; then
    report "commit-separability: FAIL - cannot resolve range ${RANGE}: ${COMMIT_LIST}"
    exit 1
fi
```

For the fallback, prefer a root-safe bound such as `git rev-list --max-count=20 HEAD` over
`HEAD~20..HEAD`.

### WR-03: `pre-push` discards separability failures if `mktemp` fails, allowing the push

**File:** `.githooks/pre-push:40`, `:57`, `:60`, `:66`

**Issue:** `SEP_FAIL_FILE="$(mktemp)"` is unchecked. On failure the variable is empty, the
`echo fail >> ""` at lines 57/60 fails silently inside the subshell, `[ -s "" ]` at line 66 is
false, `FAIL` stays 0, and the push proceeds despite one or more separability violations. The
sentinel-file pattern is the right way to escape the `while`-in-a-pipe subshell, but it needs the
file to actually exist.

**Fix:**

```sh
SEP_FAIL_FILE="$(mktemp)"
if [ $? -ne 0 ] || [ -z "$SEP_FAIL_FILE" ]; then
    echo "pre-push: FAIL - cannot create temp file for separability results"
    exit 1
fi
```

### WR-04: `mktemp -d` unchecked in the guard; check 3 can be skipped without a result line

**File:** `.githooks/estate-guard.sh:51`

**Issue:** `GUARD_TMP="$(mktemp -d)"` has no status check. With `GUARD_TMP` empty, check 3's
scratch file resolves to `/seq-hits`. Observed behavior when simulated: the guard emitted CHECK 2
and CHECK 1 and then stopped — check 3's result line and the final `estate-guard: PASS/FAIL`
summary were never printed, so the operator sees two green lines and no verdict. On a host where
that path is writable rather than erroring, `[ -s "$GUARD_TMP/seq-hits" ]` would simply be false
and check 3 would report a clean PASS having scanned nothing. Which of the two happens is decided
by filesystem layout, not by the script.

**Fix:**

```sh
GUARD_TMP="$(mktemp -d)"
if [ $? -ne 0 ] || [ ! -d "$GUARD_TMP" ]; then
    printf '%s\n' "estate-guard: FAIL - cannot create temp dir"
    exit 1
fi
```

### WR-05: Check 2 tests for a literal line, not for the effective ignore status

**File:** `.githooks/estate-guard.sh:75-77`

**Issue:** `grep -qx '/estate/' "$EXCLUDE_FILE"` asserts a string is present, which is not the
same as asserting git ignores `estate/`. A later `!/estate/` negation line, or a preceding pattern
interaction, re-includes the directory while the asserted line remains — check 2 passes while the
exclusion is functionally absent. This is exactly the "can it pass while the exclusion is actually
absent" case flagged in the review priorities.

**Fix:** Keep the literal-line assertion (it defends the D-16 exclude/`.gitignore` split) and add
an authoritative behavioral test:

```sh
if ! git check-ignore -q estate/ 2>/dev/null; then
    report "CHECK 2 (exclusion posture): FAIL - git does not actually ignore estate/ despite the exclude entry"
    FAIL_COUNTER=$((FAIL_COUNTER + 1))
fi
```

Add a selftest case appending `!/estate/` after the exclusion and asserting FAIL.

### WR-06: Unquoted `$DIFF_SPEC` / `$RANGE` / `$COMMIT_LIST` expansions in command position

**File:** `.githooks/estate-guard.sh:103`, `:124`; `.githooks/commit-separability.sh:44`

**Issue:** `git diff --name-only $DIFF_SPEC` and `git rev-list $RANGE` expand unquoted, so the
value is subject to word splitting and pathname expansion. Values reaching them today are
internally constructed and benign, but both are also reachable from `argv` (`--range "$2"`), which
makes this an input-validation gap under ASVS V5 and the organization's secure-coding standard
rather than a style point. `commit-separability.sh:54`'s `set -- $COMMIT_LIST` is deliberate and
correctly justified by its comment (SHAs are whitespace- and glob-free) — that one is fine.

**Fix:** Quote them. Where a spec token must remain splittable, validate its shape first:

```sh
case "$RANGE_ARG" in
    *..*) ;;
    *) report "estate-guard: --range must be <A>..<B>"; exit 1 ;;
esac
```

### WR-07: The stdin mode — the only mode `pre-push` uses — is never exercised by the selftest

**File:** `.githooks/estate-guard-selftest.sh:92-199`

**Issue:** All nine cases invoke `--range` or `--check-exclude`. The stdin ref-update parser
(`estate-guard.sh:190-223`) — containing the zero-SHA deletion handling, the `--not --remotes`
bounding of CR-04, the empty-tree fallback, and the loop that consumes the script's own stdin — is
the code that actually runs on every push and has zero coverage. CR-04 lives entirely in untested
code.

**Fix:** Add cases that pipe synthetic ref-update lines to the guard: a normal update, a branch
deletion (`LOCAL_SHA` all zeros, expect PASS), a new branch (`REMOTE_SHA` all zeros), a new branch
whose first commit is a root commit (exercising the `git hash-object -t tree /dev/null` fallback),
and a new branch carrying an `estate/` path (expect FAIL).

### WR-08: Selftest's `cp` of the guard is unchecked and its paths assume invocation from the repo root

**File:** `.githooks/estate-guard-selftest.sh:20-21`, `:88-90`

**Issue:** `ORIG_DIR="$(pwd)"` and `ORIG_GUARD="$ORIG_DIR/.githooks/estate-guard.sh"` silently
resolve to a nonexistent path when the script is run from anywhere but the repo root — including
from `.githooks/` itself, the most natural place to run it. The `cp` at line 88 is unchecked, so
`$GUARD` then names a missing file, every case exits 127, and per CR-05 cases 1-4 report PASS.

**Fix:** Derive the path from the script's own location and check the copy:

```sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIG_GUARD="$SCRIPT_DIR/estate-guard.sh"
cp "$ORIG_GUARD" ./estate-guard.sh || { echo "selftest: cannot copy guard"; exit 1; }
```

### WR-09: The failsafe path runs a full `npm ci` and cgo rebuild, making interrupt handling slow and re-interruptible

**File:** `forest-shim/pipe-probe.sh:61`

**Issue:** The revert calls `refresh.sh` with `REFRESH_SKIP_GENERATE=1` but **not**
`REFRESH_SKIP_INSTALL=1`, so `refresh.sh` step 1 executes `npm ci` (network fetch, minutes) before
the shim is rebuilt via a cgo compile of the 30MB `parser.c`. All output is discarded. A user who
presses Ctrl-C sees the probe hang with no explanation; a second Ctrl-C during that window is
delivered to the in-flight `npm ci`/`go build` child, aborting the rebuild and leaving
`forest-shim/cobol/` half-updated — which, combined with CR-06 item 3, is then never retried. A
failsafe should be the fastest and most robust code in the script; here it is the slowest.

**Fix:** Set `REFRESH_SKIP_INSTALL=1` on the failsafe invocation (dependencies are already
installed by definition — step 4 ran), and keep its log for diagnosis rather than sending it to
`/dev/null`. See the CR-06 fix snippet, which incorporates both.

### WR-10: `$CHOSEN_KIND` is interpolated unescaped into a `grep` ERE and into a `sed -i` program that rewrites `grammar.js`

**File:** `forest-shim/pipe-probe.sh:132`, `:153`

**Issue:** `CHOSEN_KIND` is derived by `awk`/`sed` from the **stdout of a downstream Go test**
(`kinds-before.txt`) and then substituted, unescaped and unvalidated, into:

- line 132: `grep -cE "^    ${CANDIDATE}: "` — an extended regex. tree-sitter node kinds routinely
  include regex metacharacters (`+`, `*`, `(`, `.`, `[`, `?`), which either error out or match the
  wrong thing. A candidate rejected because its name broke the regex is silently misattributed to
  "not defined exactly once."
- line 153: `sed -i '' -E "s/[[:<:]]${CHOSEN_KIND}[[:>:]]/${CHOSEN_KIND}_pipe_probe/g"` — an
  in-place rewrite of `grammar.js`. A `/` or a metacharacter in the value corrupts the `s///`
  program; in the worst case a global substitution matches far more than the intended identifier.

The `MATCH_COUNT = 1` filter constrains the value in practice, but nothing enforces that
constraint, and the data crosses a process boundary from a different repository. Under ASVS V5
this is untrusted input reaching a program text.

**Fix:** Validate the shape before use and fail loudly otherwise:

```sh
case "$CANDIDATE" in
    *[!A-Za-z0-9_]*|"") continue ;;   # identifier-shaped only
esac
```

Prefer a fixed-string match for the count (`grep -cF "    ${CANDIDATE}: "` with an explicit
line-shape check) so no metacharacter is ever interpreted.

### WR-11: `sed -i ''` and `[[:<:]]`/`[[:>:]]` are BSD/macOS-only — the pipe cannot run on Linux or CI

**File:** `forest-shim/refresh.sh:133`, `:135`; `forest-shim/pipe-probe.sh:153`

**Issue:** `sed -i ''` (separate empty suffix argument) is BSD syntax. GNU sed parses the `''` as
the *script* and the real script as a *filename*, so the invocation fails. The word-boundary
classes `[[:<:]]` / `[[:>:]]` are likewise BSD-only; GNU sed spells them `\<` / `\>` or `\b`.

Both call sites do check `$?`, so this fails loudly rather than silently corrupting the shim —
which is why this is a Warning and not a Blocker. But it means `refresh.sh` step 4 and the entire
probe are macOS-only, and the phase's reproducibility claim ("one command regenerates the shim")
does not hold off this developer's machine.

**Fix:** Use a portable temp-file rewrite instead of in-place editing:

```sh
sed 's#include "tree_sitter/parser.h"#include "parser.h"#' "$SHIM_DIR/parser.c" > "$SHIM_DIR/parser.c.tmp" \
    && mv "$SHIM_DIR/parser.c.tmp" "$SHIM_DIR/parser.c"
```

For the probe's word boundaries, either detect the sed flavor or use a `perl -pe 's/\b.../'`
one-liner, which is consistent across platforms.

### WR-12: Step 4's post-rewrite verification only greps for `parser.h`, narrower than the failure class it guards

**File:** `forest-shim/refresh.sh:142`

**Issue:** The rewrite verification is `grep -q 'tree_sitter/parser.h'`. Today's `src/scanner.c`
includes only `<tree_sitter/parser.h>` and `<wctype.h>`, so this is sufficient *at this commit* —
but the check exists precisely to catch the flattening going stale, and it is pinned to the one
include that happens to be present now. tree-sitter scanners commonly also carry
`<tree_sitter/alloc.h>` and `<tree_sitter/array.h>`; if a regenerated scanner introduces either,
step 4 reports OK and only step 6's `go build` catches it, with a compiler error rather than the
diagnostic the step was written to give.

Related: `alloc.h` and `array.h` **are** vendored in `forest-shim/cobol/` (from the forest module
cache) but step 3 never copies or refreshes them, so the vendored set and the set `refresh.sh`
maintains have already diverged.

**Fix:** Verify the general shape rather than one filename, and state which file failed:

```sh
LEFTOVER="$(grep -n 'include[[:space:]]*[<"]tree_sitter/' "$SHIM_DIR/parser.c" "$SHIM_DIR/scanner.c")"
if [ -n "$LEFTOVER" ]; then
    report "STEP 4 (include rewrite): FAIL - subdirectory include path still present: $LEFTOVER"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
fi
```

Also assert the positive: that `#include "parser.h"` is now present in both files.

### WR-13: `pre-push` never runs the selftest, so a regression in the guard ships silently

**File:** `.githooks/pre-push:20-35`

**Issue:** Confirmed by inspection — `pre-push` contains no reference to
`estate-guard-selftest.sh`. The fail-then-pass proof that the guard has teeth runs only when a
human remembers to run it. Combined with CR-05 (the proof does not constrain the guard) and CR-01
through CR-04 (four live false negatives that shipped with the proof reporting green), nothing in
the pipeline would surface a future regression in the leak control.

**Fix:** Run the selftest from `pre-push` (it is self-isolating — all fixtures are built in a
`mktemp -d` scratch repo, so it is safe to invoke), gated to keep the common path fast:

```sh
if [ -z "$SKIP_GUARD_SELFTEST" ]; then
    bash "$HOOK_DIR/estate-guard-selftest.sh" > /tmp/guard-selftest.$$ 2>&1
    if [ $? -ne 0 ]; then
        echo "pre-push: FAIL - estate-guard selftest did not pass; the leak guard is not trustworthy"
        cat /tmp/guard-selftest.$$
        FAIL=1
    fi
    rm -f /tmp/guard-selftest.$$
fi
```

The `--no-verify` bypass noted at lines 11-14 is honestly documented, but with no server-side
backstop the selftest is the only remaining integrity signal — worth wiring up.

### WR-14: Check 3's file filter misses common COBOL spellings, so a rename evades the sequence-area heuristic

**File:** `.githooks/estate-guard.sh:33`

**Issue:** `COBOL_PATH_RE` enumerates only all-lower and all-upper `cbl|cpy|cob` plus two fixed
directories. Mixed-case (`.Cbl`), other conventional COBOL/mainframe extensions (`.cbl.txt`,
`.pco`, `.jcl`, `.cblle`), and extensionless files are not scanned at all. Since check 3 is the
only content-based control — check 1 matches on path prefix alone — copying proprietary COBOL to
`notes/PGM.Cbl` defeats both. The header calls check 3 a heuristic, which is fair, but the gap is
wide enough to note.

**Fix:** Make the extension match case-insensitively and widen the set:

```sh
COBOL_PATH_RE='[.](cbl|cpy|cob|cobol|pco|jcl)$|^test/corpus/|^test/cobol85/'
# and match with: grep -Ei "$COBOL_PATH_RE"
```

Consider additionally scanning *all* added lines (not just COBOL-named files) for the sequence-area
signature, which costs little and closes the rename path.

### WR-15: `GetQuery`'s `opts` parameter and three of its four branches are untested; one assertion is tautological

**File:** `forest-shim/cobol/smoke_test.go:24-27`, `:58-63`

**Issue:** The suite's stated purpose is pinning the drop-in contract so a consumer cannot hit an
undefined or misbehaving symbol. Two gaps against that purpose:

- Lines 24-27 compare `GetQuery("sample.scm")` to `GetQuery("sample")`. Both arguments pass
  through the same `strings.TrimSuffix(kind, ".scm") + ".scm"` normalization at `binding.go:33`
  and produce an identical lookup key, so the assertion is true by construction and cannot fail.
  It reads as coverage of the suffix logic while testing nothing.
- The `opts ...byte` parameter is never supplied. `NativeFirst`, `NvimOnly` and `NativeOnly`
  (`binding.go:52-66`) are all unexercised, as is the fall-through at `binding.go:69` where an
  out-of-range preference (`GetQuery("sample", 0)` or `GetQuery("sample", 99)`) silently returns
  `nil` with no error. A consumer passing a preference byte is the most likely way to hit
  divergent behavior at this boundary, and it is exactly what is untested.

**Fix:** Test the branches that can actually differ:

```go
func TestGetQueryPreferences(t *testing.T) {
    native := GetQuery("sample", NativeOnly)
    if len(native) == 0 {
        t.Fatal("GetQuery(sample, NativeOnly) empty, want sample.scm contents")
    }
    if got := GetQuery("sample", NvimOnly); len(got) != 0 {
        t.Fatalf("GetQuery(sample, NvimOnly) = %q, want empty (no nvimts__sample.scm embedded)", got)
    }
    if got := GetQuery("sample", NativeFirst); string(got) != string(native) {
        t.Fatalf("NativeFirst = %q, want %q", got, native)
    }
    if got := GetQuery("sample", 99); len(got) != 0 {
        t.Fatalf("out-of-range pref = %q, want empty", got)
    }
}
```

For the suffix behavior, assert against the embedded file directly rather than against another
`GetQuery` call.

### WR-16: `refresh.sh` resolves the exclude file by hardcoding `.git/`, which breaks in a linked worktree

**File:** `forest-shim/refresh.sh:49`

**Issue:** `EXCLUDE_FILE="$TOP_DIR/.git/info/exclude"` assumes `.git` is a directory. In a linked
worktree or a submodule, `.git` is a *file* containing a `gitdir:` pointer, so `[ -f "$EXCLUDE_FILE" ]`
at line 50 is false, the block is skipped silently, and `forest-shim/refresh.log` is never
excluded — leaving a generated log as an untracked file in a repo whose entire hygiene story is
about not committing the wrong thing. `estate-guard.sh:67` already does this correctly with
`git rev-parse --git-path info/exclude`; the two files disagree.

**Fix:**

```sh
EXCLUDE_FILE="$(cd "$TOP_DIR" && git rev-parse --git-path info/exclude 2>/dev/null)"
```

---

## Info

### IN-01: `--stat` is redundant with `--name-only`

**File:** `.githooks/commit-separability.sh:58`
**Issue:** `git show --stat --name-only --pretty=format:` produces output byte-identical to the
same command without `--stat` (verified). The flag is dead and implies a stat block is being
parsed when it is not.
**Fix:** Drop `--stat`. (Superseded if WR-01's `diff-tree` fix is applied.)

### IN-02: `report()` here does not do the `tee` dual-write the house style specifies

**File:** `.githooks/commit-separability.sh:19-21`
**Issue:** `estate-guard.sh:54-60` and `refresh.sh:41-43` both support a log file; this `report()`
is a bare `printf`. Its output exists only in the terminal, so a failed push leaves no artifact.
**Fix:** Add the same optional `$SEPARABILITY_LOG` + `tee -a` shape for consistency.

### IN-03: Hardcoded forest version in the drift-check default

**File:** `forest-shim/refresh.sh:31`
**Issue:** `@v1.9.1` is embedded in the `FOREST_CACHE` default. When the consumer bumps the forest
dependency, the cache directory will not exist and step 5 reports "forest module cache not found"
rather than a version mismatch — correct outcome, confusing message.
**Fix:** Derive it, e.g. `go list -m -f '{{.Dir}}' github.com/alexaandru/go-sitter-forest/cobol`
run from the consumer module, falling back to the pin.

### IN-04: `$REFRESH_LOG` is truncated before any validation and the truncation is unchecked

**File:** `forest-shim/refresh.sh:39`
**Issue:** `: > "$REFRESH_LOG"` runs at line 39, before any argument or environment validation, on
a fully caller-overridable path (line 32). If the redirect fails, every subsequent `tee -a` fails
per-line while stdout still looks correct.
**Fix:** Check the redirect and abort with a message if the log path is unwritable.

### IN-05: A failed step 3 does not gate steps 4-6, producing misleading per-step OK lines

**File:** `forest-shim/refresh.sh:112-149`
**Issue:** If a `cp` at lines 113-120 fails, `COPY_OK=0` correctly increments `FAIL_COUNTER`, but
step 4 proceeds to `sed` the *stale* shim files and reports `STEP 4 ... OK`. The aggregate exit
code is still 1, so this is cosmetic — but the log reads as though the rewrite succeeded against
fresh output.
**Fix:** Guard steps 4-6 with `if [ "$COPY_OK" = "1" ]` and emit `SKIPPED` lines otherwise.

### IN-06: `PROBE_CAPTURE_DIR` is created by `mktemp -d` and never cleaned up

**File:** `forest-shim/pipe-probe.sh:28`
**Issue:** Every run leaves a temp directory containing four multi-KB capture files. Retention is
plausibly intentional (they are the probe's evidence), but nothing says so and nothing prunes them.
**Fix:** Print the capture directory path in the final SUMMARY line so it is discoverable, and note
in the header comment that retention is deliberate.

### IN-07: Magic threshold and hardcoded byte counts in the grammar-size assertion

**File:** `forest-shim/cobol/smoke_test.go:51-52`
**Issue:** `100000` is an unnamed literal, and the failure message hardcodes both `327` and
`428,580`, which will drift the moment the grammar changes in phase 2.
**Fix:** Name the threshold (`const minGrammarBytes = 100_000`) and drop the exact current size
from the message, keeping only the forest-placeholder comparison that gives the number meaning.

### IN-08: Guard header claims an invariant the code does not hold

**File:** `.githooks/estate-guard.sh:27-31`
**Issue:** *"every command that can fail is checked explicitly"* is contradicted by lines 51, 103,
124 and 207 (CR-03, CR-04, WR-04). Because the comment is the stated justification for omitting
`set -e`, a reader has no signal that these paths are unguarded.
**Fix:** Once CR-03/CR-04/WR-04 are fixed the comment becomes true; until then it should not assert
an invariant the file does not maintain.

---

## Verification Notes

Findings CR-01 through CR-05, WR-01, WR-02 and IN-01 were reproduced against the unmodified
scripts in throwaway git repositories under the session scratchpad, not inferred from reading. No
`estate/` content and no content from the private corpus was read, quoted, or reproduced at any
point — every COBOL fixture used in the reproductions was synthesized (`01 WS-ACCT PIC X(10).`
padded to an 80-column line with the sequence id `SEQ00001`). No source file was modified by this
review.

The `#include` rewrite (review priority 3) and the trap-arming order in `pipe-probe.sh` (review
priority 4, first half — the trap at line 85 genuinely precedes the first write to `grammar.js` at
line 153) were both checked and are **correct as written**. The defects found in `pipe-probe.sh`
are in the handler's body, not its registration.

---

_Reviewed: 2026-08-29_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
