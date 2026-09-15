#!/bin/bash
# .githooks/estate-guard-selftest.sh
#
# Re-runnable fail-then-pass proof of .githooks/estate-guard.sh (D-18, FORK-02
# must_haves truth #1). Proves the guard FAILS on deliberately polluted input
# and PASSES on clean input, so the criterion stays proven rather than being
# true once.
#
# Isolation: all polluted/clean fixtures are built and committed inside a
# scratch repository under $(mktemp -d), never in this fork -- a branch here
# carrying an estate/ path would create exactly the git object the guard
# exists to prevent, and the blob survives branch deletion until `gc`. Every
# fixture below is hand-written synthetic COBOL, never copied from estate/ or
# from a real NIST file, per this project's data-handling constraint.
#
# House style (matches test/check_tests.sh): accumulate a return code across
# the whole run, exit with it at the end rather than exiting early. No
# `set -e` anywhere in this repo's shell scripts.

ORIG_DIR="$(pwd)"
# ESTATE_GUARD_PATH is a test-harness-only override, defaulting to the
# tracked guard. It exists so the CR-05 "zero-check stand-in" reproduction is
# a re-runnable assertion rather than a one-time manual demonstration.
# Neither pre-push nor estate-guard.sh honors this variable -- doing so would
# turn a test seam into a way to neuter the hook.
ORIG_GUARD="${ESTATE_GUARD_PATH:-$ORIG_DIR/.githooks/estate-guard.sh}"
echo "estate-guard-selftest: guard under test (ESTATE_GUARD_PATH override honored here only, default is the tracked guard): $ORIG_GUARD"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT INT TERM

RETURN_CODE=0

report_case() {
    # $1=case number  $2=description  $3=expected(PASS|FAIL)  $4=observed exit code
    NUM="$1"; DESC="$2"; EXPECT="$3"; CODE="$4"
    OBSERVED=FAIL
    [ "$CODE" -eq 0 ] && OBSERVED=PASS
    if [ "$OBSERVED" = "$EXPECT" ]; then
        echo "Case ${NUM} (${DESC}): PASS (expected-${EXPECT}-observed-${OBSERVED})"
    else
        echo "Case ${NUM} (${DESC}): FAIL (expected-${EXPECT}-observed-${OBSERVED}, exit=${CODE})"
        RETURN_CODE=1
    fi
}

require_check2_line() {
    # $1=case number  $2=description  $3=captured guard output
    if ! printf '%s\n' "$3" | grep -q 'CHECK 2'; then
        echo "Case ${1} (${2}): FAIL (missing CHECK 2 result line -- vacuous pass)"
        RETURN_CODE=1
    fi
}

require_check_fail() {
    # $1=case number  $2=description  $3=captured guard output  $4=check label
    # e.g. "CHECK 1". Asserts the SPECIFIC check reported a failure verdict,
    # not merely that the guard's exit code was non-zero (CR-05): a guard
    # replaced by a zero-check stand-in exits non-zero for the wrong reason
    # and must be caught here, not waved through by report_case alone.
    if ! printf '%s\n' "$3" | grep -q "^${4}.*: FAIL"; then
        echo "Case ${1} (${2}): FAIL (expected ${4} to report FAIL; guard may have exited non-zero for an unrelated reason, or the check never ran)"
        RETURN_CODE=1
    fi
}

require_not_shell_error() {
    # $1=case number  $2=description  $3=observed exit code
    # A guard that crashed (2/126/127) must not be counted as a rejection --
    # report_case's exit-code-only check cannot distinguish the two (CR-05).
    case "$3" in
        2|126|127)
            echo "Case ${1} (${2}): FAIL (guard exited with shell-error status ${3} -- crashed rather than rejected)"
            RETURN_CODE=1
            ;;
    esac
}

# Fixed-format line: 72-byte code area (padded) + an 8-byte sequence id.
make_seq_line() {
    printf '%-72s%s\n' "$1" "$2"
}

cd "$SCRATCH" || exit 1
git init -q .
git config user.email "estate-guard-selftest@local"
git config user.name "estate-guard-selftest"
git config commit.gpgsign false

# Base state (D-16 point 2's live posture, reproduced here so check 2 and
# check-exclude cases 3/4 below have something real to mutate):
printf '/estate/\n' >> .git/info/exclude
mkdir -p test/cobol85/src test/corpus

# Synthetic stand-in for a NIST fixture: 80-column fixed-format, populated
# sequence area. Hand-written, never copied from a real NIST file or estate/.
{
    make_seq_line "       IDENTIFICATION DIVISION." "PROBE01."
    make_seq_line "       PROGRAM-ID. PROBE01." "PROBE01."
    make_seq_line "       PROCEDURE DIVISION." "PROBE01."
    make_seq_line "       STOP RUN." "PROBE01."
} > test/cobol85/src/PROBE01.CBL

# Hand-written minimal fixture, short lines, no sequence area -- mirrors
# test/corpus/minimal-cobol.txt's 36-character maximum line length.
{
    echo "       identification division."
    echo "       program-id. probe."
    echo "       procedure division."
} > test/corpus/probe-existing.txt

echo "scratch repo for estate-guard-selftest.sh -- not real estate content" > README.md

git add -A
git commit -q -m "base state"
BASE="$(git rev-parse HEAD)"

cp "$ORIG_GUARD" ./estate-guard.sh
chmod +x ./estate-guard.sh
GUARD="$SCRATCH/estate-guard.sh"

# ===========================================================================
# Polluted cases (1-4): each must make the guard exit non-zero.
# ===========================================================================

# Case 1: a commit adds a file under an estate/ path.
git checkout -q -b case1 "$BASE"
mkdir -p estate
echo "synthetic proprietary-shaped placeholder, not real estate content" > estate/placeholder.txt
# The scratch repo's own .git/info/exclude (set above, matching D-16 point 2's
# live posture) makes git itself refuse to `git add` an estate/ path without
# -f -- this IS the pollution we are deliberately constructing to prove the
# guard's own check 1 catches it independently of that exclude entry.
git add -f estate/placeholder.txt >/dev/null
git commit -q -m "case1: estate/ path pollution"
OUT1="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"; CODE1=$?
report_case 1 "estate/ path pollution" FAIL "$CODE1"
require_check_fail 1 "estate/ path pollution" "$OUT1" "CHECK 1"
require_not_shell_error 1 "estate/ path pollution" "$CODE1"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case1 >/dev/null 2>&1

# Case 2: a commit adds a .cpy file whose lines carry a populated sequence
# area.
git checkout -q -b case2 "$BASE" >/dev/null 2>&1
make_seq_line "       01 WS-FIELD PIC X(5)." "PROBE01." > added.cpy
git add added.cpy
git commit -q -m "case2: populated sequence area in .cpy"
OUT2="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"; CODE2=$?
report_case 2 "populated columns 73-80 sequence area in added .cpy" FAIL "$CODE2"
require_check_fail 2 "populated columns 73-80 sequence area in added .cpy" "$OUT2" "CHECK 3"
require_not_shell_error 2 "populated columns 73-80 sequence area in added .cpy" "$CODE2"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case2 >/dev/null 2>&1

# Case 3: the exclusion line removed from .git/info/exclude, --check-exclude.
cp .git/info/exclude "$SCRATCH/.exclude.bak"
: > .git/info/exclude
OUT3="$("$GUARD" --check-exclude 2>&1)"; CODE3=$?
report_case 3 "exclusion line removed from .git/info/exclude" FAIL "$CODE3"
require_check_fail 3 "exclusion line removed from .git/info/exclude" "$OUT3" "CHECK 2"
require_not_shell_error 3 "exclusion line removed from .git/info/exclude" "$CODE3"
cp "$SCRATCH/.exclude.bak" .git/info/exclude
rm -f "$SCRATCH/.exclude.bak"

# Case 4: the exclusion present in .git/info/exclude but ALSO declared in
# .gitignore -- the split D-16 asserts is directional, both halves must have
# teeth.
printf '/estate/\n' > .gitignore
OUT4="$("$GUARD" --check-exclude 2>&1)"; CODE4=$?
report_case 4 "exclusion duplicated into .gitignore" FAIL "$CODE4"
require_check_fail 4 "exclusion duplicated into .gitignore" "$OUT4" "CHECK 2"
require_not_shell_error 4 "exclusion duplicated into .gitignore" "$CODE4"
rm -f .gitignore

# ===========================================================================
# Clean cases (5-9): each must make the guard exit zero.
# ===========================================================================

# Case 5: a hand-written minimal COBOL fixture with short lines (no line
# reaching 73 bytes), mirroring test/corpus/minimal-cobol.txt.
git checkout -q -b case5 "$BASE" >/dev/null 2>&1
echo "       stop run." >> test/corpus/probe-existing.txt
git add test/corpus/probe-existing.txt
git commit -q -m "case5: clean minimal fixture, short lines"
OUT5="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
report_case 5 "clean minimal fixture, short lines" PASS "$?"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case5 >/dev/null 2>&1

# Case 6: an empty range -- a branch with no new commits relative to its base.
git checkout -q -b case6 "$BASE" >/dev/null 2>&1
OUT6="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
report_case 6 "empty range, no new commits" PASS "$?"
require_check2_line 6 "empty range, no new commits" "$OUT6"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case6 >/dev/null 2>&1

# Case 7: an empty commit -- a push with zero added lines.
git checkout -q -b case7 "$BASE" >/dev/null 2>&1
git commit -q --allow-empty -m "case7: empty commit, zero added lines"
OUT7="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
report_case 7 "empty commit, zero added lines" PASS "$?"
require_check2_line 7 "empty commit, zero added lines" "$OUT7"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case7 >/dev/null 2>&1

# Case 8: the NIST false-positive regression case -- a commit that modifies an
# unrelated short-line file while test/cobol85/src/PROBE01.CBL (already
# committed in the base state, populated sequence area and all) sits
# untouched in the tree. This is the case that fails loudly if the
# sequence-area check is ever "simplified" from diff-added lines to a
# full-file scan.
git checkout -q -b case8 "$BASE" >/dev/null 2>&1
echo "       * unrelated short comment line" >> test/corpus/probe-existing.txt
git add test/corpus/probe-existing.txt
git commit -q -m "case8: modify unrelated short file, PROBE01.CBL untouched"
OUT8="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
report_case 8 "NIST false-positive regression: PROBE01.CBL untouched, full-file-scan guard" PASS "$?"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case8 >/dev/null 2>&1

# Case 9: encoding edge cases, all clean -- a line of exactly 72 bytes; a line
# with a tab in the code area under 73 bytes (must not expand to a tab stop
# and push content into the sequence area); a line with a UTF-8 multibyte
# character under 73 bytes (must count as its byte length). None may be
# flagged.
git checkout -q -b case9 "$BASE" >/dev/null 2>&1
awk 'BEGIN { s = ""; for (i = 0; i < 72; i++) s = s "A"; print s }' > case9-72byte.cpy
awk 'BEGIN { s = ""; for (i = 0; i < 65; i++) s = s "A"; print s "\tABCDEF" }' > case9-tab.cpy
printf 'caf\xc3\xa9 unaffected short utf8 test line\n' > case9-utf8.cpy
git add case9-72byte.cpy case9-tab.cpy case9-utf8.cpy
git commit -q -m "case9: encoding edge cases, all clean"
OUT9="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
report_case 9 "encoding edge cases (72-byte, tab, UTF-8 multibyte), all clean" PASS "$?"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case9 >/dev/null 2>&1

# ===========================================================================
# Regression cases (10-15): one per confirmed guard defect from 01-REVIEW.md.
# Each asserts require_check_fail against the SPECIFIC check the defect
# defeats, not just an exit code, per CR-05. These are expected to FAIL
# against the guard as currently shipped -- that is the point of 01-06; only
# 01-07's guard fix is permitted to turn them green.
# ===========================================================================

# Case 10: CR-01 -- a commit adds an estate/ path (with a populated sequence
# area, so it would also trip check 3), a second commit git rm's it. The
# guard's two-dot endpoint diff over the range sees no net change, so check 1
# never sees the path even though the blob is fully present in the pushed
# object closure.
git checkout -q -b case10 "$BASE" >/dev/null 2>&1
mkdir -p estate
make_seq_line "       01 WS-FIELD-CR01 PIC X(5)." "PROBE02." > estate/PROBE02.cbl
git add -f estate/PROBE02.cbl >/dev/null
git commit -q -m "case10a: CR-01 add estate/ path (to be removed next commit)"
git rm -q estate/PROBE02.cbl >/dev/null
git commit -q -m "case10b: CR-01 remove estate/ path -- endpoint diff now empty"
# Sanity: the blob must genuinely be present in the range's object closure,
# or this case would not be testing what it claims to test.
BLOB_HITS="$(git rev-list --objects "${BASE}..HEAD" 2>/dev/null | grep -c 'estate/PROBE02.cbl')"
if [ "$BLOB_HITS" -lt 1 ]; then
    echo "Case 10 (CR-01 add-then-remove): FAIL (sanity check failed -- estate/PROBE02.cbl not found in range's object closure, case is not testing CR-01)"
    RETURN_CODE=1
fi
OUT10="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
require_check_fail 10 "CR-01 add-then-remove, endpoint diff blind to intermediate commit" "$OUT10" "CHECK 1"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case10 >/dev/null 2>&1

# Case 11: CR-02a -- a single commit adding an estate/ path whose basename
# carries a non-ASCII UTF-8 byte sequence. Built with a printf byte escape so
# the fixture is stable across editors/locales. Default core.quotePath=true
# C-quotes the path, so `grep -E '^estate/'` on `git diff --name-only` never
# matches it.
git checkout -q -b case11 "$BASE" >/dev/null 2>&1
mkdir -p estate
NONASCII_FILE="$(printf 'estate/caf\xc3\xa9.txt')"
printf 'synthetic proprietary-shaped placeholder, non-ASCII filename test\n' > "$NONASCII_FILE"
git add -f "$NONASCII_FILE" >/dev/null
git commit -q -m "case11: CR-02a non-ASCII estate/ path pollution"
OUT11="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
require_check_fail 11 "CR-02a non-ASCII estate/ path evades the anchored path match" "$OUT11" "CHECK 1"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case11 >/dev/null 2>&1

# Case 12: CR-02b -- a single commit adding an estate/ path whose basename
# contains an embedded double-quote character. Proves core.quotePath=false is
# NOT a sufficient fix: git C-quotes an embedded-quote path regardless of
# that setting, so this must still evade with it explicitly set false.
git checkout -q -b case12 "$BASE" >/dev/null 2>&1
mkdir -p estate
QUOTE_FILE='estate/quo"te.txt'
printf 'synthetic proprietary-shaped placeholder, embedded double-quote filename test\n' > "$QUOTE_FILE"
git add -f "$QUOTE_FILE" >/dev/null
git commit -q -m "case12: CR-02b embedded-double-quote estate/ path pollution"
git config core.quotePath false
OUT12="$("$GUARD" --range "${BASE}..HEAD" 2>&1)"
git config core.quotePath true
require_check_fail 12 "CR-02b embedded-quote estate/ path evades check 1 even with core.quotePath=false" "$OUT12" "CHECK 1"
git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case12 >/dev/null 2>&1

# Case 13: CR-03 -- a range naming a forty-hex-digit commit that does not
# exist in this repo. `git diff` fails, stderr and the exit status are both
# discarded, and the guard affirmatively reports "no estate/ path in change"
# instead of failing closed on an unresolvable range.
UNRESOLVABLE_SHA="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
OUT13="$("$GUARD" --range "${UNRESOLVABLE_SHA}..${BASE}" 2>&1)"
require_check_fail 13 "CR-03 unresolvable range must fail closed, not silently report PASS" "$OUT13" "CHECK 1"

# Cases 14 & 15: CR-04 / CR-04b -- a two-remote new-branch push. Set up two
# bare repositories inside the scratch dir (cleaned up by the existing trap)
# and add both as remotes of the scratch repo: "origin" (the hypothetical
# public push target) and "other" (a second, non-target remote). Commit an
# estate/-path fixture on a branch and push it to "other" only, then fetch so
# its remote-tracking ref exists.
mkdir -p "$SCRATCH/remotes/origin.git" "$SCRATCH/remotes/other.git"
git init -q --bare "$SCRATCH/remotes/origin.git"
git init -q --bare "$SCRATCH/remotes/other.git"
git remote add origin "$SCRATCH/remotes/origin.git"
git remote add other "$SCRATCH/remotes/other.git"
git checkout -q -b case1415 "$BASE" >/dev/null 2>&1
mkdir -p estate
make_seq_line "       01 WS-FIELD-CR04 PIC X(5)." "PROBE03." > estate/PROBE03.cbl
git add -f estate/PROBE03.cbl >/dev/null
git commit -q -m "case14/15: CR-04/CR-04b estate/ path on a branch pushed only to 'other'"
CASE1415_TIP="$(git rev-parse HEAD)"
git push -q other "case1415:refs/heads/case1415" >/dev/null 2>&1
git fetch -q other >/dev/null 2>&1
REFLINE="refs/heads/case1415 ${CASE1415_TIP} refs/heads/case1415 0000000000000000000000000000000000000000"

# Case 14: CR-04 -- forwarding --remote origin is not recognized by the guard
# as currently shipped (the fix for CR-04 does not exist yet), so the
# invocation is rejected before any check runs at all.
OUT14="$(printf '%s\n' "$REFLINE" | "$GUARD" --remote origin 2>&1)"
require_check_fail 14 "CR-04 two-remote new-branch push, --remote forwarded but unsupported by the guard" "$OUT14" "CHECK 1"

# Case 15: CR-04b -- same stdin new-branch shape, no --remote forwarded at
# all. The guard's own bare `--not --remotes` bound excludes the commit
# because it is reachable from "other", which is not the remote being pushed
# to -- the commit is silently skipped rather than scanned.
OUT15="$(printf '%s\n' "$REFLINE" | "$GUARD" 2>&1)"
require_check_fail 15 "CR-04b missing --remote falls back to excluding commits reachable from any configured remote" "$OUT15" "CHECK 1"

git checkout -q "$BASE" >/dev/null 2>&1
git branch -q -D case1415 >/dev/null 2>&1

# ===========================================================================
# Cover the real repository too, not just the synthetic scratch one.
# ===========================================================================
cd "$ORIG_DIR" || exit 1

REAL_OUT_1="$(bash -- "$ORIG_GUARD" --check-exclude 2>&1)"
REAL_CODE_1=$?
if [ "$REAL_CODE_1" -eq 0 ]; then
    echo "Real-repo check (--check-exclude): PASS"
else
    echo "Real-repo check (--check-exclude): FAIL"
    echo "$REAL_OUT_1"
    RETURN_CODE=1
fi

REAL_OUT_2="$(bash -- "$ORIG_GUARD" --range HEAD~1..HEAD 2>&1)"
REAL_CODE_2=$?
if [ "$REAL_CODE_2" -eq 0 ]; then
    echo "Real-repo check (--range HEAD~1..HEAD): PASS"
else
    echo "Real-repo check (--range HEAD~1..HEAD): FAIL"
    echo "$REAL_OUT_2"
    RETURN_CODE=1
fi

exit "$RETURN_CODE"
