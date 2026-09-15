#!/bin/bash
# forest-shim/pipe-probe.sh
#
# The transient grammar-to-gortex propagation probe (ROADMAP criterion 1).
# Proves the whole chain - grammar.js -> tree-sitter generate -> src/ ->
# refresh.sh -> forest-shim/cobol/ -> go.work -> gortex's parse output - with
# a probe edit that is applied, observed, then reverted before this script
# exits. Nothing from the probe is ever committed: the phase's committed
# grammar stays unchanged and the fork stays level with upstream/main.
#
# The revert is registered as a trap on EXIT, INT and TERM BEFORE the first
# write to grammar.js - not after; the ordering is the whole point. This
# reuses the failsafe shape .githooks/estate-guard-selftest.sh already uses
# in this repo for its own scratch directory: an owning process whose revert
# survives a build failure, a timeout, or a killed agent.
#
# House style, matching refresh.sh: no `set -e`/`set -u`, explicit `$?`
# checks, tee-style dual reporting to stdout and to a log, one result line
# per numbered step, a single aggregate exit code from a failure counter.
# Because each step depends on the one before it, a failing step exits
# immediately (relying on the trap for cleanup) rather than accumulating
# across independent checks the way refresh.sh's six steps do.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

TOP_DIR=${TOP_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}
GORTEX_DIR=${GORTEX_DIR:-$HOME/repos/mine/GoApps/gortex}
PROBE_CAPTURE_DIR=${PROBE_CAPTURE_DIR:-$(mktemp -d)}
PROBE_ABORT_AFTER=${PROBE_ABORT_AFTER:-}

FAIL_COUNTER=0
PROBE_LOG="$PROBE_CAPTURE_DIR/pipe-probe.log"
: > "$PROBE_LOG"

report() {
    echo "$1" | tee -a "$PROBE_LOG"
}

# --- The failsafe: armed BEFORE anything touches grammar.js ---
#
# Idempotent by design: an interrupt fires it once for the signal and again
# on exit (EXIT always fires, even after an explicit `exit` from a signal
# handler), and calling it when the tree is already clean is harmless.
REVERT_DONE=0

revert() {
    if [ "$REVERT_DONE" = "1" ]; then
        return
    fi
    REVERT_DONE=1
    RESTORED=$(cd "$TOP_DIR" && git status --porcelain -- grammar.js src/)
    ( cd "$TOP_DIR" && git checkout -- grammar.js src/ ) > /dev/null 2>&1
    # `git checkout` only restores tracked file content - it cannot remove
    # new untracked files. Regenerating with the lockfile-pinned CLI creates
    # src/tree_sitter/alloc.h and src/tree_sitter/array.h as new untracked
    # files not present in the committed tree (confirmed this session);
    # remove them explicitly by name so the revert is actually complete.
    rm -f "$TOP_DIR/src/tree_sitter/alloc.h" "$TOP_DIR/src/tree_sitter/array.h"
    if [ -n "$RESTORED" ]; then
        report "FAILSAFE: restored grammar.js and src/ from git (this is the failsafe path, not the script's own step 6) - rebuilding the shim from the restored committed src/"
        ( cd "$TOP_DIR" && REFRESH_SKIP_GENERATE=1 bash "$TOP_DIR/forest-shim/refresh.sh" ) > /dev/null 2>&1
    else
        report "FAILSAFE: grammar.js and src/ were already clean - nothing to restore"
    fi
}

# One shared handler for EXIT, INT and TERM (a single trap registration
# naming all three) so the success path and the abort path can never drift
# apart. NORMAL_COMPLETION is set to 1 only immediately before this script's
# own final `exit 0` - every other route to this handler (a real INT/TERM,
# or any of this script's own early `exit 1` calls) leaves it at 0, and the
# handler forces a non-zero exit in that case. A signal's first pass through
# this handler calls `exit 1` itself, which triggers the EXIT disposition of
# the very same trap; bash fires the EXIT trap exactly once at actual
# process termination, so this second pass just finalizes the same code.
NORMAL_COMPLETION=0

handle_exit() {
    revert
    if [ "$NORMAL_COMPLETION" != "1" ]; then
        exit 1
    fi
}

trap handle_exit EXIT INT TERM

# --- Part B: the abort knob, so the failsafe is testable rather than merely
# present. Terminates the script abnormally immediately after the named
# step's result line, via a self-delivered SIGINT, without ever reaching the
# script's own step 6. ---
abort_after() {
    STEP_NUM="$1"
    if [ "$PROBE_ABORT_AFTER" = "$STEP_NUM" ]; then
        report "ABORT (PROBE_ABORT_AFTER=$STEP_NUM): terminating abnormally via kill -INT \$\$, without reaching step 6"
        kill -INT $$
        exit 1
    fi
}

# --- Step 1: capture the baseline ---
( cd "$GORTEX_DIR" && go test -run 'TestDumpGrammarKinds/cobol' -v ./internal/parser/forest/ ) \
    > "$PROBE_CAPTURE_DIR/kinds-before.txt" 2>&1
STEP1_STATUS=$?
if [ "$STEP1_STATUS" != "0" ]; then
    report "STEP 1 (capture baseline): FAIL - go test exited $STEP1_STATUS"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 1"
    exit 1
fi
report "STEP 1 (capture baseline): OK - captured kinds-before.txt from gortex's TestDumpGrammarKinds/cobol"
abort_after 1

# --- Step 2: choose the probe target deterministically ---
# Walk the kind names from the === cobol === section in the order printed
# and take the first name K for which K is a top-level rule defined exactly
# once in grammar.js.
KIND_SECTION=$(awk '
/^=== cobol ===$/ { flag=1 }
/^--- (PASS|FAIL)/ { if (flag) exit }
flag { print }
' "$PROBE_CAPTURE_DIR/kinds-before.txt")

CANDIDATES=$(echo "$KIND_SECTION" | grep -E '^  [^ ]' | \
    sed -E 's/^  //; s/[[:space:]]*× [0-9]+$//; s/[[:space:]]+$//')

CHOSEN_KIND=""
REJECTED=""
while IFS= read -r CANDIDATE; do
    if [ -z "$CANDIDATE" ]; then
        continue
    fi
    MATCH_COUNT=$(grep -cE "^    ${CANDIDATE}: " "$TOP_DIR/grammar.js")
    if [ "$MATCH_COUNT" = "1" ]; then
        CHOSEN_KIND="$CANDIDATE"
        break
    else
        REJECTED="$REJECTED ${CANDIDATE}(matches=${MATCH_COUNT})"
    fi
done < <(printf '%s\n' "$CANDIDATES")

if [ -z "$CHOSEN_KIND" ]; then
    report "STEP 2 (choose probe target): FAIL - no kind in the === cobol === section is a top-level rule defined exactly once in grammar.js (rejected:$REJECTED)"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 2"
    exit 1
fi
report "STEP 2 (choose probe target): OK - chose K=$CHOSEN_KIND (first candidate, in the order gortex printed them, that is a top-level rule defined exactly once in grammar.js; rejected:${REJECTED:- none})"
abort_after 2

# --- Step 3: arm the failsafe (already armed above), then apply the probe
# edit --- a consistent global rename of one identifier, semantics-preserving
# for tree-sitter: it changes the node's name, not the language.
LC_ALL=C sed -i '' -E "s/[[:<:]]${CHOSEN_KIND}[[:>:]]/${CHOSEN_KIND}_pipe_probe/g" "$TOP_DIR/grammar.js"
SED_STATUS=$?
if [ "$SED_STATUS" != "0" ]; then
    report "STEP 3 (apply probe edit): FAIL - sed rename exited $SED_STATUS"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 3"
    exit 1
fi
report "STEP 3 (apply probe edit): OK - renamed $CHOSEN_KIND to ${CHOSEN_KIND}_pipe_probe everywhere in grammar.js"
abort_after 3

# --- Step 4: run the documented sequence ---
( cd "$TOP_DIR" && bash "$TOP_DIR/forest-shim/refresh.sh" ) > "$PROBE_CAPTURE_DIR/refresh-during-probe.log" 2>&1
REFRESH_STATUS=$?
if [ "$REFRESH_STATUS" != "0" ]; then
    report "STEP 4 (run refresh.sh): FAIL - refresh.sh exited $REFRESH_STATUS (see $PROBE_CAPTURE_DIR/refresh-during-probe.log)"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 4"
    exit 1
fi
report "STEP 4 (run refresh.sh): OK - refresh.sh regenerated and rebuilt the shim from the probe-edited grammar.js"
abort_after 4

# --- Step 5: observe the change in gortex's parse output ---
( cd "$GORTEX_DIR" && go test -run 'TestDumpGrammarKinds/cobol' -v ./internal/parser/forest/ ) \
    > "$PROBE_CAPTURE_DIR/kinds-after.txt" 2>&1
STEP5_STATUS=$?
if [ "$STEP5_STATUS" != "0" ]; then
    report "STEP 5 (observe change): FAIL - go test exited $STEP5_STATUS"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 5"
    exit 1
fi
HAS_NEW=$(grep -c "^  ${CHOSEN_KIND}_pipe_probe " "$PROBE_CAPTURE_DIR/kinds-after.txt")
HAS_OLD=$(grep -c "^  ${CHOSEN_KIND} " "$PROBE_CAPTURE_DIR/kinds-after.txt")
if [ "$HAS_NEW" -lt 1 ] || [ "$HAS_OLD" != "0" ]; then
    report "STEP 5 (observe change): FAIL - expected ${CHOSEN_KIND}_pipe_probe present and ${CHOSEN_KIND} absent in gortex's parse output (found new=$HAS_NEW old=$HAS_OLD)"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 5"
    exit 1
fi
report "STEP 5 (observe change): OK - gortex's parse output now lists ${CHOSEN_KIND}_pipe_probe and no longer lists ${CHOSEN_KIND}"
report "STEP 5 (before): $(grep "^  ${CHOSEN_KIND} " "$PROBE_CAPTURE_DIR/kinds-before.txt")"
report "STEP 5 (after):  $(grep "^  ${CHOSEN_KIND}_pipe_probe " "$PROBE_CAPTURE_DIR/kinds-after.txt")"
abort_after 5

# --- Step 6: revert on the success path ---
# Invoke the same handler the trap uses, so the normal path and the abort
# path share one implementation and cannot drift apart.
revert
REPO_STATUS=$(cd "$TOP_DIR" && git status --porcelain)
PROBE_PATHS_STATUS=$(cd "$TOP_DIR" && git status --porcelain -- grammar.js src/ forest-shim/cobol)
if [ -n "$PROBE_PATHS_STATUS" ]; then
    report "STEP 6 (revert): FAIL - grammar.js/src//forest-shim/cobol are not clean after revert: $PROBE_PATHS_STATUS"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 6"
    exit 1
fi
report "STEP 6 (revert): OK - grammar.js, src/ and forest-shim/cobol/ are clean after revert (full repo status: ${REPO_STATUS:-<empty>})"
abort_after 6

# --- Step 7: confirm restoration ---
( cd "$GORTEX_DIR" && go test -run 'TestDumpGrammarKinds/cobol' -v ./internal/parser/forest/ ) \
    > "$PROBE_CAPTURE_DIR/kinds-restored.txt" 2>&1
STEP7_STATUS=$?
if [ "$STEP7_STATUS" != "0" ]; then
    report "STEP 7 (confirm restoration): FAIL - go test exited $STEP7_STATUS"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 7"
    exit 1
fi
awk '
/^=== cobol ===$/ { flag=1 }
/^--- (PASS|FAIL)/ { if (flag) exit }
flag { print }
' "$PROBE_CAPTURE_DIR/kinds-before.txt" > "$PROBE_CAPTURE_DIR/section-before.txt"
awk '
/^=== cobol ===$/ { flag=1 }
/^--- (PASS|FAIL)/ { if (flag) exit }
flag { print }
' "$PROBE_CAPTURE_DIR/kinds-restored.txt" > "$PROBE_CAPTURE_DIR/section-restored.txt"
diff -q "$PROBE_CAPTURE_DIR/section-before.txt" "$PROBE_CAPTURE_DIR/section-restored.txt" > /dev/null 2>&1
DIFF_STATUS=$?
if [ "$DIFF_STATUS" != "0" ]; then
    report "STEP 7 (confirm restoration): FAIL - post-revert === cobol === section differs from the step-1 baseline"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: $FAIL_COUNTER step(s) failed - aborted after Step 7"
    exit 1
fi
report "STEP 7 (confirm restoration): OK - post-revert === cobol === section is byte-identical to the step-1 baseline"

report "SUMMARY: all 7 steps completed - chose K=$CHOSEN_KIND, observed ${CHOSEN_KIND}_pipe_probe in gortex's parse output, reverted, and confirmed byte-identical restoration"
NORMAL_COMPLETION=1
exit 0
