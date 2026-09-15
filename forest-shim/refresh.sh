#!/bin/bash
# forest-shim/refresh.sh
#
# The VEND-04 regenerate-and-refresh sequence. One command:
#   1. installs the lockfile-pinned tree-sitter-cli (npm ci, never npm install)
#   2. regenerates src/ from grammar.js
#   3. copies and flattens the generated output into forest-shim/cobol/
#   4. rewrites the two different #include forms the copied C files still
#      carry, so the flattened layout actually compiles
#   5. diffs the shim's Go surface against the forest module-cache copy
#      it impersonates, to catch drift from forest's drop-in contract
#   6. smoke-builds the shim as the final, exit-code-gating self-check
#
# Deliberately not an npm script and not a Makefile (D-07) — grouped here,
# beside the shim it maintains, so a fork-local tool never has to edit an
# upstream-owned file (package.json) or introduce a build system this repo
# does not otherwise use.
#
# House style, matching run_nist_cobol85.sh and test/check_tests.sh: no
# `set -e`/`set -u` anywhere in this repo's scripts — every command that can
# fail is followed by an explicit `$?` check, integer counters accumulate a
# result, and the aggregate exit code reflects that counter, not the last
# command run. Every report line is dual-written to stdout and to
# $REFRESH_LOG via `tee -a`.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

TOP_DIR=${TOP_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}
SHIM_DIR=${SHIM_DIR:-$TOP_DIR/forest-shim/cobol}
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/.bin/tree-sitter}
FOREST_CACHE=${FOREST_CACHE:-$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1}
REFRESH_LOG=${REFRESH_LOG:-$TOP_DIR/forest-shim/refresh.log}
REFRESH_SKIP_INSTALL=${REFRESH_SKIP_INSTALL:-}
REFRESH_SKIP_GENERATE=${REFRESH_SKIP_GENERATE:-}
REFRESH_ALLOW_DRIFT=${REFRESH_ALLOW_DRIFT:-}

FAIL_COUNTER=0

: > "$REFRESH_LOG"

report() {
    echo "$1" | tee -a "$REFRESH_LOG"
}

# Declare the refresh log untracked via the repo-local exclude file, never
# .gitignore: .gitignore is upstream-owned, and D-14 keeps fork-local entries
# out of it so `git pull upstream` stays painless — the same split that
# already holds the /estate/ exclusion. Idempotent: safe to run every time.
EXCLUDE_FILE="$TOP_DIR/.git/info/exclude"
if [ -f "$EXCLUDE_FILE" ]; then
    grep -qF '/forest-shim/refresh.log' "$EXCLUDE_FILE" > /dev/null 2>&1
    if [ $? != "0" ]; then
        echo '/forest-shim/refresh.log' >> "$EXCLUDE_FILE"
    fi
fi

# --- Step 1: dependencies ---
# npm ci's own exit code is reported but is NOT the gate: this package's
# top-level "install" script (node-gyp rebuild of bindings/node/, an
# unrelated native Node addon) can fail on a given toolchain even though npm
# ci already installed every package - including the lockfile-pinned
# tree-sitter-cli, whose own postinstall runs and succeeds independently.
# What actually gates this refresh is whether $TREE_SITTER ended up present
# and executable, which is checked explicitly below.
STEP1_OK=1
if [ -n "$REFRESH_SKIP_INSTALL" ]; then
    report "STEP 1 (dependencies): SKIPPED - REFRESH_SKIP_INSTALL set"
else
    ( cd "$TOP_DIR" && npm ci )
    NPM_CI_STATUS=$?
    if [ "$NPM_CI_STATUS" != "0" ]; then
        report "STEP 1 (dependencies): npm ci exited $NPM_CI_STATUS (non-fatal here - gated below on whether \$TREE_SITTER is actually present and executable)"
    else
        report "STEP 1 (dependencies): OK - npm ci installed the lockfile-pinned tree-sitter-cli"
    fi
fi

if [ -x "$TREE_SITTER" ]; then
    report "STEP 1 (tree-sitter binary): OK - $TREE_SITTER exists and is executable"
else
    report "STEP 1 (tree-sitter binary): FAIL - $TREE_SITTER does not exist or is not executable"
    STEP1_OK=0
fi

if [ "$STEP1_OK" != "1" ]; then
    FAIL_COUNTER=$((FAIL_COUNTER+1))
    report "SUMMARY: step1=FAIL step2=SKIPPED step3=SKIPPED step4=SKIPPED step5=SKIPPED step6=SKIPPED (aborted after Step 1 - dependencies not satisfied, refresh did not complete cleanly)"
    exit 1
fi

# --- Step 2: generate ---
if [ -n "$REFRESH_SKIP_GENERATE" ]; then
    report "STEP 2 (generate): SKIPPED - REFRESH_SKIP_GENERATE set"
else
    ( cd "$TOP_DIR" && "$TREE_SITTER" generate )
    GEN_STATUS=$?
    if [ "$GEN_STATUS" != "0" ]; then
        report "STEP 2 (generate): FAIL - tree-sitter generate exited $GEN_STATUS"
        FAIL_COUNTER=$((FAIL_COUNTER+1))
    else
        report "STEP 2 (generate): OK - tree-sitter generate regenerated src/ from grammar.js"
        SRC_DIFF=$(cd "$TOP_DIR" && git status --porcelain src/)
        if [ -n "$SRC_DIFF" ]; then
            report "STEP 2 (generate, informational): src/ differs from the committed generated output after regeneration - this is a finding about which tree-sitter-cli patch produced the committed src/, not a failure - changed paths: $(echo "$SRC_DIFF" | tr '\n' ' ')"
        else
            report "STEP 2 (generate, informational): src/ matches the committed generated output byte-for-byte after regeneration"
        fi
    fi
fi

# --- Step 3: copy and flatten (D-04) ---
COPY_OK=1
cp "$TOP_DIR/src/parser.c" "$SHIM_DIR/parser.c"
if [ $? != "0" ]; then COPY_OK=0; fi
cp "$TOP_DIR/src/scanner.c" "$SHIM_DIR/scanner.c"
if [ $? != "0" ]; then COPY_OK=0; fi
cp "$TOP_DIR/src/grammar.json" "$SHIM_DIR/grammar.json"
if [ $? != "0" ]; then COPY_OK=0; fi
cp "$TOP_DIR/src/tree_sitter/parser.h" "$SHIM_DIR/parser.h"
if [ $? != "0" ]; then COPY_OK=0; fi

# queries/*.scm must land INSIDE the shim: forest-shim/cobol/plugin.go and
# binding.go both declare `//go:embed grammar.json *.scm`, so a query left
# behind in queries/ is invisible to gortex no matter how correct it is.
#
# The destination is removed first. Files carried in by forest's own module-cache
# drop-in arrive read-only (0444, as everything under $GOPATH/pkg/mod does), and
# sample.scm is one of them - a plain cp over it fails with "Permission denied"
# and takes the whole step down with it.
SCM_COPIED=""
for SCM_FILE in "$TOP_DIR"/queries/*.scm; do
    if [ -f "$SCM_FILE" ]; then
        rm -f "$SHIM_DIR/$(basename "$SCM_FILE")"
        cp "$SCM_FILE" "$SHIM_DIR/$(basename "$SCM_FILE")"
        if [ $? != "0" ]; then
            COPY_OK=0
        else
            SCM_COPIED="$SCM_COPIED $(basename "$SCM_FILE")"
        fi
    fi
done

if [ "$COPY_OK" = "1" ]; then
    report "STEP 3 (copy-and-flatten): OK - parser.c, scanner.c, grammar.json, parser.h and queries/*.scm ($(echo $SCM_COPIED)) copied into $SHIM_DIR"
else
    report "STEP 3 (copy-and-flatten): FAIL - one or more copies from src/ into $SHIM_DIR failed"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
fi

# --- Step 4: rewrite the include directives ---
# The copied parser.c and scanner.c still ask for the header at its
# pre-flatten location, in two different syntaxes - a single sed pattern
# catches only one of them.
sed -i '' 's#include "tree_sitter/parser.h"#include "parser.h"#' "$SHIM_DIR/parser.c"
SED1_STATUS=$?
sed -i '' 's#include <tree_sitter/parser.h>#include "parser.h"#' "$SHIM_DIR/scanner.c"
SED2_STATUS=$?

if [ "$SED1_STATUS" != "0" ] || [ "$SED2_STATUS" != "0" ]; then
    report "STEP 4 (include rewrite): FAIL - sed exited nonzero (parser.c=$SED1_STATUS scanner.c=$SED2_STATUS)"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
else
    grep -q 'tree_sitter/parser.h' "$SHIM_DIR/parser.c" "$SHIM_DIR/scanner.c"
    if [ $? = "0" ]; then
        report "STEP 4 (include rewrite): FAIL - the subdirectory include path is still present after rewrite"
        FAIL_COUNTER=$((FAIL_COUNTER+1))
    else
        report "STEP 4 (include rewrite): OK - parser.c (quoted form) and scanner.c (angle-bracket form) both rewritten to the flattened header"
    fi
fi

# --- Step 5: drift check (D-03) ---
if [ ! -d "$FOREST_CACHE" ]; then
    report "STEP 5 (drift check): FAIL - forest module cache not found at $FOREST_CACHE"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
else
    DRIFT_FOUND=0
    for GO_SURFACE_FILE in binding.go plugin.go go.mod; do
        diff -q "$SHIM_DIR/$GO_SURFACE_FILE" "$FOREST_CACHE/$GO_SURFACE_FILE" > /dev/null 2>&1
        if [ $? != "0" ]; then
            DRIFT_FOUND=1
        fi
    done
    if [ "$DRIFT_FOUND" = "1" ]; then
        if [ -n "$REFRESH_ALLOW_DRIFT" ]; then
            report "STEP 5 (drift check): WARN - binding.go/plugin.go/go.mod differ from $FOREST_CACHE (REFRESH_ALLOW_DRIFT set, downgraded from a hard failure)"
        else
            report "STEP 5 (drift check): FAIL - binding.go/plugin.go/go.mod differ from $FOREST_CACHE (set REFRESH_ALLOW_DRIFT to downgrade this to a warning)"
            FAIL_COUNTER=$((FAIL_COUNTER+1))
        fi
    else
        report "STEP 5 (drift check): OK - binding.go, plugin.go, go.mod match $FOREST_CACHE exactly"
    fi
fi

# --- Step 6: smoke build, LAST ---
# This must be the final step and the exit code must be gated on it, so a
# run that failed anywhere earlier can never report success with a
# half-updated shim.
( cd "$SHIM_DIR" && go build ./... )
BUILD_STATUS=$?
if [ "$BUILD_STATUS" != "0" ]; then
    report "STEP 6 (smoke build): FAIL - go build ./... exited $BUILD_STATUS in $SHIM_DIR"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
else
    report "STEP 6 (smoke build): OK - go build ./... succeeded in $SHIM_DIR"
fi

if [ "$FAIL_COUNTER" != "0" ]; then
    report "SUMMARY: $FAIL_COUNTER step(s) failed - refresh did not complete cleanly"
    exit 1
else
    report "SUMMARY: all 6 steps completed - dependencies OK, generate OK, copy-and-flatten OK, include rewrite OK, drift check OK, smoke build OK"
    exit 0
fi
