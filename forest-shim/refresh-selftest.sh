#!/bin/bash
# Persistent synthetic regression test for forest-shim/refresh.sh.
# It operates only on an isolated temporary repository-shaped tree and proves
# generation and staged-copy failures cannot mutate the live shim artifact set.

SCRIPT_DIR=$(cd -P "$(dirname "$0")" && pwd)
TOP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REFRESH="$SCRIPT_DIR/refresh.sh"
REAL_TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/tree-sitter-cli/tree-sitter}
REAL_FOREST_CACHE=${FOREST_CACHE:-$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1}

RETURN_CODE=0
SCRATCH=$(mktemp -d)
if [ $? != "0" ] || [ -z "$SCRATCH" ]; then
    echo "refresh-selftest: FAIL - could not create scratch directory"
    exit 1
fi
trap 'rm -rf "$SCRATCH"' EXIT INT TERM

report_failure() {
    echo "refresh-selftest: FAIL - $1"
    RETURN_CODE=1
}

if [ ! -x "$REAL_TREE_SITTER" ]; then
    report_failure "lockfile-pinned tree-sitter CLI is unavailable"
fi
if [ ! -d "$REAL_FOREST_CACHE" ]; then
    report_failure "forest module cache is unavailable at $REAL_FOREST_CACHE"
fi
if [ "$RETURN_CODE" != "0" ]; then
    exit "$RETURN_CODE"
fi

ISOLATED_TOP="$SCRATCH/top"
ISOLATED_SHIM="$ISOLATED_TOP/forest-shim/cobol"
mkdir -p "$ISOLATED_TOP/forest-shim" "$ISOLATED_TOP/node_modules/tree-sitter-cli"
if [ $? != "0" ]; then
    report_failure "could not create isolated top-level directories"
    exit "$RETURN_CODE"
fi
cp -R "$TOP_DIR/forest-shim/cobol" "$ISOLATED_SHIM"
cp -R "$TOP_DIR/src" "$ISOLATED_TOP/src"
cp -R "$TOP_DIR/queries" "$ISOLATED_TOP/queries"
cp "$TOP_DIR/grammar.js" "$ISOLATED_TOP/grammar.js"
cp "$TOP_DIR/package.json" "$ISOLATED_TOP/package.json"
cp "$TOP_DIR/package-lock.json" "$ISOLATED_TOP/package-lock.json"
cp "$TOP_DIR/run_idms_query_capture.sh" "$ISOLATED_TOP/run_idms_query_capture.sh"
ln -s "$REAL_TREE_SITTER" "$ISOLATED_TOP/node_modules/tree-sitter-cli/tree-sitter"
if [ $? != "0" ]; then
    report_failure "could not construct isolated refresh tree"
    exit "$RETURN_CODE"
fi

ARTIFACTS="parser.c scanner.c grammar.json parser.h cics.scm idms.scm sample.scm sql.scm"
hash_artifacts() {
    HASH_DIR="$1"
    HASH_OUT="$2"
    : > "$HASH_OUT"
    for HASH_NAME in $ARTIFACTS; do
        if [ ! -f "$HASH_DIR/$HASH_NAME" ]; then
            return 1
        fi
        shasum -a 256 "$HASH_DIR/$HASH_NAME" >> "$HASH_OUT"
        if [ $? != "0" ]; then
            return 1
        fi
    done
}

assert_unchanged() {
    BEFORE_HASHES="$1"
    AFTER_HASHES="$2"
    CASE_NAME="$3"
    if ! cmp "$BEFORE_HASHES" "$AFTER_HASHES" >/dev/null 2>&1; then
        report_failure "$CASE_NAME changed the live shim artifact set"
        return 1
    fi
    return 0
}

BASELINE_HASHES="$SCRATCH/baseline.sha256"
AFTER_HASHES="$SCRATCH/after.sha256"
hash_artifacts "$ISOLATED_SHIM" "$BASELINE_HASHES"
if [ $? != "0" ]; then
    report_failure "could not hash the initial isolated shim"
    exit "$RETURN_CODE"
fi

FAIL_GENERATOR="$SCRATCH/fail-generate"
cat > "$FAIL_GENERATOR" <<'GENERATOR_EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
    exec "$REAL_TREE_SITTER" --version
fi
if [ "${1:-}" = "generate" ]; then
    echo "injected generation failure" >&2
    exit 73
fi
exec "$REAL_TREE_SITTER" "$@"
GENERATOR_EOF
chmod +x "$FAIL_GENERATOR"
GENERATION_LOG="$SCRATCH/generation.log"
REAL_TREE_SITTER="$REAL_TREE_SITTER" TOP_DIR="$ISOLATED_TOP" \
SHIM_DIR="$ISOLATED_SHIM" TREE_SITTER="$FAIL_GENERATOR" \
FOREST_CACHE="$REAL_FOREST_CACHE" REFRESH_LOG="$SCRATCH/generation.refresh.log" \
REFRESH_SKIP_INSTALL=1 bash "$REFRESH" > "$GENERATION_LOG" 2>&1
GENERATION_CODE=$?
hash_artifacts "$ISOLATED_SHIM" "$AFTER_HASHES"
if [ "$GENERATION_CODE" = "0" ]; then
    report_failure "forced generation failure returned success"
fi
assert_unchanged "$BASELINE_HASHES" "$AFTER_HASHES" "forced generation failure"
for EXPECTED in \
    "STEP 2 (generate): FAIL" \
    "STEP 3 (copy-and-flatten): SKIPPED - generation failed" \
    "STEP 4 (include rewrite): SKIPPED - generation failed" \
    "STEP 5 (drift check): SKIPPED - generation failed" \
    "STEP 6 (smoke test): SKIPPED - generation failed"
do
    if ! grep -qF "$EXPECTED" "$GENERATION_LOG"; then
        report_failure "generation case omitted: $EXPECTED"
    fi
done
if grep -qF "INSTALL: OK" "$GENERATION_LOG"; then
    report_failure "generation failure reached installation"
fi
if [ "$RETURN_CODE" = "0" ]; then
    echo "Case 1 (generation failure skips steps 3-6 and preserves live hashes): PASS"
fi

COPY_LOG="$SCRATCH/copy.log"
TOP_DIR="$ISOLATED_TOP" SHIM_DIR="$ISOLATED_SHIM" TREE_SITTER="$REAL_TREE_SITTER" \
FOREST_CACHE="$REAL_FOREST_CACHE" REFRESH_LOG="$SCRATCH/copy.refresh.log" \
REFRESH_SKIP_INSTALL=1 REFRESH_SKIP_GENERATE=1 REFRESH_FORCE_COPY_FAILURE=1 \
bash "$REFRESH" > "$COPY_LOG" 2>&1
COPY_CODE=$?
hash_artifacts "$ISOLATED_SHIM" "$AFTER_HASHES"
if [ "$COPY_CODE" = "0" ]; then
    report_failure "forced copy/staging failure returned success"
fi
assert_unchanged "$BASELINE_HASHES" "$AFTER_HASHES" "forced copy/staging failure"
for EXPECTED in \
    "STEP 3 (copy-and-flatten): injected copy/staging failure" \
    "STEP 4 (include rewrite): SKIPPED - staging failed" \
    "STEP 5 (drift check): SKIPPED - staging failed" \
    "STEP 6 (smoke test): SKIPPED - staging failed"
do
    if ! grep -qF "$EXPECTED" "$COPY_LOG"; then
        report_failure "copy/staging case omitted: $EXPECTED"
    fi
done
if grep -Eq "STEP 4 .*: OK|STEP 5 .*: OK|STEP 6 .*: OK|INSTALL: OK" "$COPY_LOG"; then
    report_failure "copy/staging failure reported a later success"
fi
if [ "$RETURN_CODE" = "0" ]; then
    echo "Case 2 (copy/staging failure skips steps 4-6 and preserves live hashes): PASS"
fi

SUCCESS_LOG="$SCRATCH/success.log"
TOP_DIR="$ISOLATED_TOP" SHIM_DIR="$ISOLATED_SHIM" TREE_SITTER="$REAL_TREE_SITTER" \
FOREST_CACHE="$REAL_FOREST_CACHE" REFRESH_LOG="$SCRATCH/success.refresh.log" \
REFRESH_SKIP_INSTALL=1 bash "$REFRESH" > "$SUCCESS_LOG" 2>&1
SUCCESS_CODE=$?
if [ "$SUCCESS_CODE" != "0" ]; then
    report_failure "isolated successful refresh exited $SUCCESS_CODE"
fi
for EXPECTED in \
    "STEP 3 (copy-and-flatten): OK" \
    "STEP 4 (include rewrite): OK" \
    "STEP 5 (drift check): OK" \
    "STEP 6 (smoke test): OK" \
    "INSTALL: OK"
do
    if ! grep -qF "$EXPECTED" "$SUCCESS_LOG"; then
        report_failure "success case omitted: $EXPECTED"
    fi
done
if ! cmp "$ISOLATED_TOP/queries/idms.scm" "$ISOLATED_SHIM/idms.scm"; then
    report_failure "successful refresh did not install the source IDMS query"
fi
if grep -q 'tree_sitter/parser.h' "$ISOLATED_SHIM/parser.c" "$ISOLATED_SHIM/scanner.c"; then
    report_failure "successful refresh left unflattened include paths"
fi
if [ "$RETURN_CODE" = "0" ]; then
    echo "Case 3 (successful portable staged refresh installs a coherent set): PASS"
fi

QUERY_LOG="$SCRATCH/query.log"
TOP_DIR="$ISOLATED_TOP" TREE_SITTER="$REAL_TREE_SITTER" \
IDMS_QUERY_FILE="$ISOLATED_SHIM/idms.scm" IDMS_SKIP_INSTALL=1 \
bash "$ISOLATED_TOP/run_idms_query_capture.sh" > "$QUERY_LOG" 2>&1
QUERY_CODE=$?
if [ "$QUERY_CODE" != "0" ]; then
    report_failure "shim IDMS query execution exited $QUERY_CODE"
fi
if ! grep -qF "QUERY_CONTRACT_GREEN" "$QUERY_LOG"; then
    report_failure "shim IDMS query did not match the exact synthetic contract"
fi
if [ "$RETURN_CODE" = "0" ]; then
    echo "Case 4 (shim IDMS query compiles and matches the exact synthetic subject): PASS"
fi

echo "refresh-selftest: $([ "$RETURN_CODE" = "0" ] && echo PASS || echo FAIL)"
exit "$RETURN_CODE"
