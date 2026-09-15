#!/bin/bash
# run_cics_query_capture.sh
#
# The CICS-02 fork-local gate: assert that queries/cics.scm actually extracts
# a command capture from a parsed EXEC CICS block. A grammar rule that parses
# but is not reachable through the published query is worthless to gortex,
# and `tree-sitter test` alone cannot catch that -- it validates the tree, not
# the query.
#
# PATTERNS.md route (a). Route (b) -- a Go query test inside forest-shim/cobol
# -- is rejected deliberately: forest-shim/cobol/go.mod has zero dependencies
# and refresh.sh Step 5 hard-fails on any change to it, so a Go test there
# cannot add a tree-sitter binding.
#
# Fork-local tooling (FORK-03): kept out of the separable grammar commit
# series, and its scratch fixture is declared untracked via .git/info/exclude
# rather than .gitignore, because .gitignore is upstream-owned (D-14/FORK-02).
#
# House style, matching forest-shim/refresh.sh and run_nist_cobol85.sh: no
# `set -e`/`set -u` -- every command that can fail is followed by an explicit
# `$?` check, integer counters accumulate the result, and the aggregate exit
# code reflects that counter, not the last command run.
#
# All names in the fixture below are invented and neutral (D-32). Nothing is
# derived from any real estate source.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

TOP_DIR=${TOP_DIR:-$SCRIPT_DIR}
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/tree-sitter-cli/tree-sitter}
QUERY_FILE=${QUERY_FILE:-$TOP_DIR/queries/cics.scm}
SCRATCH_DIR=${SCRATCH_DIR:-$TOP_DIR/.cics-query-scratch}
FIXTURE=$SCRATCH_DIR/query-sample.cbl
CAPTURE_LOG=$SCRATCH_DIR/capture.log

# The capture names queries/cics.scm is contracted to emit.
EXPECTED_CAPTURES="command transaction program map mapset"

FAIL_COUNTER=0

report() {
    echo "$1"
}

# Idempotent: keep the scratch directory out of git via the repo-local
# exclude file, never .gitignore (FORK-02).
EXCLUDE_FILE="$TOP_DIR/.git/info/exclude"
if [ -f "$EXCLUDE_FILE" ]; then
    grep -qF '/.cics-query-scratch/' "$EXCLUDE_FILE" > /dev/null 2>&1
    if [ $? != "0" ]; then
        echo '/.cics-query-scratch/' >> "$EXCLUDE_FILE"
    fi
fi

# --- Step 1: preconditions ---
STEP1_OK=1
if [ -x "$TREE_SITTER" ]; then
    report "STEP 1 (tree-sitter binary): OK - $TREE_SITTER exists and is executable"
else
    report "STEP 1 (tree-sitter binary): FAIL - $TREE_SITTER does not exist or is not executable"
    STEP1_OK=0
fi

if [ -f "$QUERY_FILE" ]; then
    report "STEP 1 (query file): OK - $QUERY_FILE present"
else
    report "STEP 1 (query file): FAIL - $QUERY_FILE not found"
    STEP1_OK=0
fi

if [ "$STEP1_OK" != "1" ]; then
    report "SUMMARY: step1=FAIL step2=SKIPPED step3=SKIPPED (aborted - preconditions not satisfied)"
    exit 1
fi

# --- Step 2: write the scratch fixture ---
mkdir -p "$SCRATCH_DIR"
if [ $? != "0" ]; then
    report "STEP 2 (fixture): FAIL - could not create $SCRATCH_DIR"
    report "SUMMARY: step2=FAIL step3=SKIPPED (aborted)"
    exit 1
fi

cat > "$FIXTURE" <<'FIXTURE_EOF'
       identification division.
       program-id. cics-query-sample.
       procedure division.
       EXEC CICS SEND MAP('MENU01') MAPSET('MENUSET') END-EXEC.
       EXEC CICS START TRANSID('TRN1') END-EXEC.
       EXEC CICS LINK PROGRAM(WS-PROG-NAME) END-EXEC.
       EXEC CICS LINK PROGRAM('SUBPROG1') END-EXEC.
       EXEC CICS RETURN END-EXEC.
       EXEC CICS READ END-EXEC.
       EXEC CICS WRITE END-EXEC.
       EXEC CICS DELETE END-EXEC.
       stop run.
FIXTURE_EOF
if [ $? != "0" ]; then
    report "STEP 2 (fixture): FAIL - could not write $FIXTURE"
    report "SUMMARY: step2=FAIL step3=SKIPPED (aborted)"
    exit 1
fi
report "STEP 2 (fixture): OK - wrote $FIXTURE (all names invented and neutral, D-32)"

# --- Step 3: run the query and assert each expected capture appears ---
( cd "$TOP_DIR" && "$TREE_SITTER" query "$QUERY_FILE" "$FIXTURE" ) > "$CAPTURE_LOG" 2>&1
QUERY_STATUS=$?
if [ "$QUERY_STATUS" != "0" ]; then
    report "STEP 3 (query): FAIL - tree-sitter query exited $QUERY_STATUS"
    cat "$CAPTURE_LOG"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
else
    report "STEP 3 (query): OK - tree-sitter query exited 0"
fi

for CAPTURE_NAME in $EXPECTED_CAPTURES; do
    grep -q "capture: .* - $CAPTURE_NAME," "$CAPTURE_LOG"
    if [ $? != "0" ]; then
        report "STEP 3 (capture '$CAPTURE_NAME'): FAIL - not present in query output"
        FAIL_COUNTER=$((FAIL_COUNTER+1))
    else
        CAPTURE_COUNT=$(grep -c "capture: .* - $CAPTURE_NAME," "$CAPTURE_LOG")
        report "STEP 3 (capture '$CAPTURE_NAME'): OK - $CAPTURE_COUNT occurrence(s) in query output"
    fi
done

if [ "$FAIL_COUNTER" != "0" ]; then
    report "SUMMARY: $FAIL_COUNTER check(s) failed - queries/cics.scm did not emit the contracted captures"
    exit 1
else
    report "SUMMARY: all checks passed - queries/cics.scm emits [$EXPECTED_CAPTURES] against an EXEC CICS block"
    exit 0
fi
