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
#   6. smoke-tests the staged shim as the final pre-install gate
#
# Deliberately not an npm script and not a Makefile (D-07) — grouped here,
# beside the shim it maintains, so a fork-local tool never has to edit an
# upstream-owned file (package.json) or introduce a build system this repo
# does not otherwise use.
#
# House style, matching run_nist_cobol85.sh and test/check_tests.sh: no
# `set -e`/`set -u` anywhere in this repo's scripts — every command that can
# fail is followed by an explicit `$?` check. Every report line is dual-written
# to stdout and to $REFRESH_LOG via `tee -a`.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

TOP_DIR=${TOP_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}
SHIM_DIR=${SHIM_DIR:-$TOP_DIR/forest-shim/cobol}
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/.bin/tree-sitter}
FOREST_CACHE=${FOREST_CACHE:-$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1}
REFRESH_LOG=${REFRESH_LOG:-$TOP_DIR/forest-shim/refresh.log}
REFRESH_SKIP_INSTALL=${REFRESH_SKIP_INSTALL:-}
REFRESH_SKIP_GENERATE=${REFRESH_SKIP_GENERATE:-}
REFRESH_ALLOW_DRIFT=${REFRESH_ALLOW_DRIFT:-}
REFRESH_FORCE_COPY_FAILURE=${REFRESH_FORCE_COPY_FAILURE:-}

FAIL_COUNTER=0
STAGE_ROOT=""

cleanup() {
    if [ -n "$STAGE_ROOT" ] && [ -d "$STAGE_ROOT" ]; then
        rm -rf "$STAGE_ROOT"
    fi
}
trap cleanup EXIT INT TERM

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
        report "STEP 3 (copy-and-flatten): SKIPPED - generation failed"
        report "STEP 4 (include rewrite): SKIPPED - generation failed"
        report "STEP 5 (drift check): SKIPPED - generation failed"
        report "STEP 6 (smoke test): SKIPPED - generation failed"
        report "SUMMARY: step1=OK step2=FAIL step3=SKIPPED step4=SKIPPED step5=SKIPPED step6=SKIPPED (aborted after Step 2 - live shim unchanged)"
        exit 1
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

# --- Step 3: stage a complete copy-and-flatten set (D-04) ---
# Never mutate the live shim while assembling generated artifacts. A failed
# copy leaves the previously coherent live set byte-identical.
SHIM_PARENT=$(dirname "$SHIM_DIR")
SHIM_NAME=$(basename "$SHIM_DIR")
STAGE_ROOT=$(mktemp -d "$SHIM_PARENT/.${SHIM_NAME}.refresh.XXXXXX")
if [ $? != "0" ] || [ -z "$STAGE_ROOT" ]; then
    report "STEP 3 (copy-and-flatten): FAIL - could not create sibling staging directory"
    report "STEP 4 (include rewrite): SKIPPED - staging failed"
    report "STEP 5 (drift check): SKIPPED - staging failed"
    report "STEP 6 (smoke test): SKIPPED - staging failed"
    report "SUMMARY: step1=OK step2=OK step3=FAIL step4=SKIPPED step5=SKIPPED step6=SKIPPED (aborted after Step 3 - live shim unchanged)"
    exit 1
fi
STAGE_DIR="$STAGE_ROOT/$SHIM_NAME"
cp -R "$SHIM_DIR" "$STAGE_DIR"
if [ $? != "0" ]; then
    report "STEP 3 (copy-and-flatten): FAIL - could not clone the live shim into staging"
    report "STEP 4 (include rewrite): SKIPPED - staging failed"
    report "STEP 5 (drift check): SKIPPED - staging failed"
    report "STEP 6 (smoke test): SKIPPED - staging failed"
    report "SUMMARY: step1=OK step2=OK step3=FAIL step4=SKIPPED step5=SKIPPED step6=SKIPPED (aborted after Step 3 - live shim unchanged)"
    exit 1
fi
chmod -R u+w "$STAGE_DIR"

COPY_OK=1
SCM_COPIED=""
for COPY_SPEC in \
    "$TOP_DIR/src/parser.c:parser.c" \
    "$TOP_DIR/src/scanner.c:scanner.c" \
    "$TOP_DIR/src/grammar.json:grammar.json" \
    "$TOP_DIR/src/tree_sitter/parser.h:parser.h"
do
    COPY_SOURCE=${COPY_SPEC%:*}
    COPY_NAME=${COPY_SPEC##*:}
    cp "$COPY_SOURCE" "$STAGE_DIR/$COPY_NAME"
    if [ $? != "0" ]; then COPY_OK=0; fi
done

# queries/*.scm must land INSIDE the shim: forest-shim/cobol/plugin.go and
# binding.go both declare `//go:embed grammar.json *.scm`, so a query left
# behind in queries/ is invisible to gortex no matter how correct it is.
# Remove staged query files first so a source deletion cannot leave a stale,
# embedded query in the installed set. Keep forest's empty structural marker.
for STAGED_SCM in "$STAGE_DIR"/*.scm; do
    if [ -f "$STAGED_SCM" ] && [ "$(basename "$STAGED_SCM")" != "_keep.scm" ]; then
        rm -f "$STAGED_SCM"
        if [ $? != "0" ]; then COPY_OK=0; fi
    fi
done
for SCM_FILE in "$TOP_DIR"/queries/*.scm; do
    if [ -f "$SCM_FILE" ]; then
        cp "$SCM_FILE" "$STAGE_DIR/$(basename "$SCM_FILE")"
        if [ $? != "0" ]; then
            COPY_OK=0
        else
            SCM_COPIED="$SCM_COPIED $(basename "$SCM_FILE")"
        fi
    fi
done

if [ -n "$REFRESH_FORCE_COPY_FAILURE" ]; then
    report "STEP 3 (copy-and-flatten): injected copy/staging failure"
    COPY_OK=0
fi

if [ "$COPY_OK" != "1" ]; then
    report "STEP 3 (copy-and-flatten): FAIL - one or more copies into staging failed"
    report "STEP 4 (include rewrite): SKIPPED - staging failed"
    report "STEP 5 (drift check): SKIPPED - staging failed"
    report "STEP 6 (smoke test): SKIPPED - staging failed"
    report "SUMMARY: step1=OK step2=OK step3=FAIL step4=SKIPPED step5=SKIPPED step6=SKIPPED (aborted after Step 3 - live shim unchanged)"
    exit 1
fi
report "STEP 3 (copy-and-flatten): OK - parser.c, scanner.c, grammar.json, parser.h and queries/*.scm ($(echo $SCM_COPIED)) staged for $SHIM_DIR"

# --- Step 4: portably rewrite and validate the staged include directives ---
# Write transformed temporary files and rename them; BSD and GNU sed differ on
# in-place syntax, so no sed -i form is portable across supported CI hosts.
rewrite_include() {
    REWRITE_FILE="$1"
    REWRITE_PATTERN="$2"
    REWRITE_TEMP="$REWRITE_FILE.refresh-tmp"
    sed "$REWRITE_PATTERN" "$REWRITE_FILE" > "$REWRITE_TEMP"
    if [ $? != "0" ]; then
        rm -f "$REWRITE_TEMP"
        return 1
    fi
    mv "$REWRITE_TEMP" "$REWRITE_FILE"
}

rewrite_include "$STAGE_DIR/parser.c" 's#include "tree_sitter/parser.h"#include "parser.h"#'
SED1_STATUS=$?
rewrite_include "$STAGE_DIR/scanner.c" 's#include <tree_sitter/parser.h>#include "parser.h"#'
SED2_STATUS=$?

if [ "$SED1_STATUS" != "0" ] || [ "$SED2_STATUS" != "0" ]; then
    report "STEP 4 (include rewrite): FAIL - portable rewrite exited nonzero (parser.c=$SED1_STATUS scanner.c=$SED2_STATUS)"
    report "STEP 5 (drift check): SKIPPED - include rewrite failed"
    report "STEP 6 (smoke test): SKIPPED - include rewrite failed"
    report "SUMMARY: step1=OK step2=OK step3=OK step4=FAIL step5=SKIPPED step6=SKIPPED (live shim unchanged)"
    exit 1
fi
grep -q 'tree_sitter/parser.h' "$STAGE_DIR/parser.c" "$STAGE_DIR/scanner.c"
if [ $? = "0" ]; then
    report "STEP 4 (include rewrite): FAIL - the subdirectory include path remains in staging"
    report "STEP 5 (drift check): SKIPPED - include rewrite failed"
    report "STEP 6 (smoke test): SKIPPED - include rewrite failed"
    report "SUMMARY: step1=OK step2=OK step3=OK step4=FAIL step5=SKIPPED step6=SKIPPED (live shim unchanged)"
    exit 1
fi
report "STEP 4 (include rewrite): OK - staged parser.c and scanner.c use the flattened header"

# --- Step 5: drift check (D-03) ---
if [ ! -d "$FOREST_CACHE" ]; then
    report "STEP 5 (drift check): FAIL - forest module cache not found at $FOREST_CACHE"
    FAIL_COUNTER=$((FAIL_COUNTER+1))
else
    DRIFT_FOUND=0
    for GO_SURFACE_FILE in binding.go plugin.go go.mod; do
        diff -q "$STAGE_DIR/$GO_SURFACE_FILE" "$FOREST_CACHE/$GO_SURFACE_FILE" > /dev/null 2>&1
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

if [ "$FAIL_COUNTER" != "0" ]; then
    report "STEP 6 (smoke test): SKIPPED - drift check failed"
    report "SUMMARY: step1=OK step2=OK step3=OK step4=OK step5=FAIL step6=SKIPPED (live shim unchanged)"
    exit 1
fi

# --- Step 6: smoke test the complete staged package, LAST ---
# No generated artifact reaches the live shim until the staged Go tests pass.
( cd "$STAGE_DIR" && IDMS_SOURCE_QUERY="$TOP_DIR/queries/idms.scm" go test ./... )
BUILD_STATUS=$?
if [ "$BUILD_STATUS" != "0" ]; then
    report "STEP 6 (smoke test): FAIL - go test ./... exited $BUILD_STATUS in staging"
    report "SUMMARY: step1=OK step2=OK step3=OK step4=OK step5=OK step6=FAIL (live shim unchanged)"
    exit 1
fi
report "STEP 6 (smoke test): OK - go test ./... succeeded against the staged coherent artifact set"

BACKUP_DIR="$STAGE_ROOT/${SHIM_NAME}.previous"
mv "$SHIM_DIR" "$BACKUP_DIR"
if [ $? != "0" ]; then
    report "INSTALL: FAIL - could not move the live shim aside; staged set not installed"
    exit 1
fi
mv "$STAGE_DIR" "$SHIM_DIR"
if [ $? != "0" ]; then
    if [ -e "$SHIM_DIR" ] || [ -L "$SHIM_DIR" ]; then
        rm -rf "$SHIM_DIR"
    fi
    mv "$BACKUP_DIR" "$SHIM_DIR"
    RESTORE_STATUS=$?
    if [ "$RESTORE_STATUS" != "0" ]; then
        report "INSTALL: FAIL - could not install staged shim or restore the previous live shim"
    else
        report "INSTALL: FAIL - could not install staged shim; previous live shim restored"
    fi
    exit 1
fi
rm -rf "$BACKUP_DIR"
if [ $? != "0" ]; then
    report "INSTALL: FAIL - coherent shim installed but previous sibling cleanup failed"
    exit 1
fi
STAGE_ROOT=""
report "INSTALL: OK - complete staged parser, grammar, header, scanner, and query set atomically installed"
report "SUMMARY: all 6 steps completed - dependencies OK, generate OK, staged copy OK, portable include rewrite OK, drift check OK, staged tests OK"
exit 0
