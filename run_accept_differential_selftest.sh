#!/bin/bash
# run_accept_differential_selftest.sh
#
# Synthetic proof for run_accept_differential.sh. The original six compare
# cases remain stable; run-mode cases use scratch-only fixtures and override
# heavyweight parser compilation while exercising cmd_run orchestration.
#
# House style: no set -e/set -u; every failure contributes to RETURN_CODE.

ORIG_DIR="$(cd "$(dirname "$0")" && pwd)"
DIFFERENTIAL="$ORIG_DIR/run_accept_differential.sh"

SCRATCH="$(mktemp -d)"
if [ $? -ne 0 ] || [ -z "$SCRATCH" ]; then
    echo "accept-differential-selftest: FAIL - could not create scratch directory"
    exit 1
fi
REPO_PROBE_DIR="$ORIG_DIR/.accept-differential-selftest-$(basename "$SCRATCH")"
if ! mkdir "$REPO_PROBE_DIR"; then
    echo "accept-differential-selftest: FAIL - could not create repository-boundary probe"
    rm -rf "$SCRATCH"
    exit 1
fi
trap 'rm -rf "$SCRATCH" "$REPO_PROBE_DIR"' EXIT INT TERM

RETURN_CODE=0

FAKE_PARSER="$SCRATCH/fake-tree-sitter"
cat > "$FAKE_PARSER" <<'EOF'
#!/bin/sh
case " $* " in
    *" --timeout 5000000 "*) ;;
    *) exit 2 ;;
esac
printf '%s\n' '(accept_statement [0, 0] - [0, 6])'
EOF
chmod +x "$FAKE_PARSER"
mkdir "$SCRATCH/extensionless-corpus" "$SCRATCH/empty-corpus"
printf '%s\n' '       ACCEPT WS-FIELD.' > "$SCRATCH/extensionless-corpus/PROGRAM"
printf '%s\n' '       DISPLAY WS-FIELD.' > "$SCRATCH/extensionless-corpus/NOACCEPT"
SNAPSHOT_CHECK_OUT="$(TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$SCRATCH/extensionless-corpus" "$SCRATCH/extensionless.tsv" 2>&1)"
if [ $? -ne 0 ] || [ "$(wc -l < "$SCRATCH/extensionless.tsv" | tr -d ' ')" -ne 1 ]; then
    echo "accept-differential-selftest: FAIL - extensionless ACCEPT source was not inventoried"
    RETURN_CODE=1
fi
if ! printf '%s\n' "$SNAPSHOT_CHECK_OUT" | grep -qF 'discovered_files=2 selected_files=1 prefilter_failures=0'; then
    echo "accept-differential-selftest: FAIL - ACCEPT prefilter denominator was not reported"
    RETURN_CODE=1
fi
TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$SCRATCH/empty-corpus" "$SCRATCH/empty.tsv" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "accept-differential-selftest: FAIL - empty source denominator was accepted"
    RETURN_CODE=1
fi

# T-02-R01 adversarial path cases use only synthetic data. Each invocation
# reaches the public snapshot entry point and must fail before creating or
# changing any repository target.
PARENT_LINK="$SCRATCH/repo-parent-link"
ln -s "$REPO_PROBE_DIR" "$PARENT_LINK"
PARENT_LINK_OUT="$(TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$SCRATCH/extensionless-corpus" "$PARENT_LINK/parent-link.tsv" 2>&1)"
PARENT_LINK_CODE=$?
if [ "$PARENT_LINK_CODE" -eq 0 ] || [ -e "$REPO_PROBE_DIR/parent-link.tsv" ]; then
    echo "accept-differential-selftest: FAIL - parent symlink snapshot escaped containment"
    RETURN_CODE=1
else
    echo "Case 17 (parent symlink snapshot is refused): PASS"
fi

FINAL_TARGET="$REPO_PROBE_DIR/final-target.tsv"
printf '%s\n' 'sentinel-bytes' > "$FINAL_TARGET"
FINAL_LINK="$SCRATCH/final-link.tsv"
ln -s "$FINAL_TARGET" "$FINAL_LINK"
FINAL_BEFORE="$(shasum -a 256 "$FINAL_TARGET")"
FINAL_LINK_OUT="$(TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$SCRATCH/extensionless-corpus" "$FINAL_LINK" 2>&1)"
FINAL_LINK_CODE=$?
FINAL_AFTER="$(shasum -a 256 "$FINAL_TARGET")"
if [ "$FINAL_LINK_CODE" -eq 0 ] || [ ! -L "$FINAL_LINK" ] || [ "$FINAL_BEFORE" != "$FINAL_AFTER" ]; then
    echo "accept-differential-selftest: FAIL - existing final symlink snapshot changed repository target"
    RETURN_CODE=1
else
    echo "Case 18 (existing final symlink snapshot is refused unchanged): PASS"
fi

DANGLING_TARGET="$REPO_PROBE_DIR/missing-target.tsv"
DANGLING_LINK="$SCRATCH/dangling-link.tsv"
ln -s "$DANGLING_TARGET" "$DANGLING_LINK"
DANGLING_OUT="$(TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$SCRATCH/extensionless-corpus" "$DANGLING_LINK" 2>&1)"
DANGLING_CODE=$?
if [ "$DANGLING_CODE" -eq 0 ] || [ ! -L "$DANGLING_LINK" ] || [ -e "$DANGLING_TARGET" ]; then
    echo "accept-differential-selftest: FAIL - dangling final symlink snapshot was not fail-closed"
    RETURN_CODE=1
else
    echo "Case 19 (dangling final symlink snapshot is refused): PASS"
fi

MISSING_PARENT="$SCRATCH/missing-parent/out.tsv"
MISSING_PARENT_OUT="$(TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$SCRATCH/extensionless-corpus" "$MISSING_PARENT" 2>&1)"
MISSING_PARENT_CODE=$?
if [ "$MISSING_PARENT_CODE" -eq 0 ] || [ -e "$MISSING_PARENT" ]; then
    echo "accept-differential-selftest: FAIL - uncanonicalizable snapshot parent was accepted"
    RETURN_CODE=1
else
    echo "Case 20 (uncanonicalizable snapshot parent is refused): PASS"
fi

EXISTING_EXTERNAL_OUT="$SCRATCH/existing-external.tsv"
printf '%s\n' 'old-output' > "$EXISTING_EXTERNAL_OUT"
EXISTING_EXTERNAL_LOG="$(TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$SCRATCH/extensionless-corpus" "$EXISTING_EXTERNAL_OUT" 2>&1)"
EXISTING_EXTERNAL_CODE=$?
if [ "$EXISTING_EXTERNAL_CODE" -ne 0 ] || [ "$(wc -l < "$EXISTING_EXTERNAL_OUT" | tr -d ' ')" -ne 1 ]; then
    echo "accept-differential-selftest: FAIL - existing external output control was rejected"
    RETURN_CODE=1
else
    echo "Case 21 (existing external output remains usable): PASS"
fi

report_case() {
    NUM="$1"; DESC="$2"; EXPECT="$3"; CODE="$4"
    OBSERVED=FAIL
    [ "$CODE" -eq 0 ] && OBSERVED=PASS
    if [ "$OBSERVED" = "$EXPECT" ]; then
        CASE_RESULT="PASS"
    else
        CASE_RESULT="FAIL (expected-${EXPECT}-observed-${OBSERVED}, exit=${CODE})"
        RETURN_CODE=1
    fi
}

require_output_contains() {
    if ! printf '%s\n' "$3" | grep -qF "$4"; then
        CASE_RESULT="FAIL (missing expected output: ${4})"
        RETURN_CODE=1
    fi
}

finish_case() {
    if [ "$CASE_RESULT" = "PASS" ]; then
        echo "Case ${NUM} (${DESC}): PASS (expected-${EXPECT}-observed-${OBSERVED}, exit=${CODE})"
    else
        echo "Case ${NUM} (${DESC}): ${CASE_RESULT}"
    fi
}

# Run-mode tracer. Source production functions without dispatch, then replace
# only expensive external mechanics. cmd_run itself remains real.
DIFFERENTIAL_FUNCTIONS="$SCRATCH/run-accept-functions.sh"
sed '/^# Dispatch$/,$d' "$DIFFERENTIAL" > "$DIFFERENTIAL_FUNCTIONS"
if [ $? -ne 0 ]; then
    echo "accept-differential-selftest: FAIL - could not isolate production functions"
    exit 1
fi
. "$DIFFERENTIAL_FUNCTIONS"

# Task 2 selection proofs exercise the real production function before the
# run-mode tracer replaces heavyweight orchestration functions.
SELECTION_CORPUS="$SCRATCH/selection-corpus"
mkdir "$SELECTION_CORPUS"
printf '%s\n' '       EXEC SQL SELECT * FROM SAMPLE END-EXEC.' > "$SELECTION_CORPUS/sql.cbl"
printf '%s\n' '       ACCEPT WS-FIELD.' > "$SELECTION_CORPUS/accept.cbl"
printf '%s\n' '       DISPLAY WS-FIELD.' > "$SELECTION_CORPUS/plain.cbl"

CUSTOM_PATHS="$SCRATCH/custom-paths.bin"
CUSTOM_OUT="$(prepare_accept_paths "$SELECTION_CORPUS" "$CUSTOM_PATHS" '(^|[^A-Za-z0-9-])EXEC[[:space:]]+SQL([^A-Za-z0-9-]|$)' 1 2>&1)"
CUSTOM_CODE=$?
report_case 8 "real selector honors a custom collision prefilter" PASS "$CUSTOM_CODE"
if ! tr '\000' '\n' < "$CUSTOM_PATHS" | grep -qF "$SELECTION_CORPUS/sql.cbl"; then
    CASE_RESULT="FAIL (custom prefilter dropped ACCEPT-free collision file)"
    RETURN_CODE=1
fi
require_output_contains 8 "real selector honors a custom collision prefilter" "$CUSTOM_OUT" 'selected_files=1'
finish_case

FULL_PATHS="$SCRATCH/full-paths.bin"
FULL_OUT="$(prepare_accept_paths "$SELECTION_CORPUS" "$FULL_PATHS" --no-prefilter 1 2>&1)"
FULL_CODE=$?
report_case 9 "real selector no-prefilter mode selects every source file" PASS "$FULL_CODE"
if [ "$(tr -cd '\000' < "$FULL_PATHS" | wc -c | tr -d ' ')" -ne 3 ]; then
    CASE_RESULT="FAIL (--no-prefilter did not select all discovered source files)"
    RETURN_CODE=1
fi
require_output_contains 9 "real selector no-prefilter mode selects every source file" "$FULL_OUT" 'selected_files=3'
finish_case

DEFAULT_PATHS="$SCRATCH/default-paths.bin"
DEFAULT_OUT="$(prepare_accept_paths "$SELECTION_CORPUS" "$DEFAULT_PATHS" '' 0 2>&1)"
DEFAULT_CODE=$?
report_case 10 "real selector preserves the default ACCEPT prefilter" PASS "$DEFAULT_CODE"
if [ "$(tr -cd '\000' < "$DEFAULT_PATHS" | wc -c | tr -d ' ')" -ne 1 ] ||
   ! tr '\000' '\n' < "$DEFAULT_PATHS" | grep -qF "$SELECTION_CORPUS/accept.cbl"; then
    CASE_RESULT="FAIL (default selection did not retain only the ACCEPT-bearing file)"
    RETURN_CODE=1
fi
require_output_contains 10 "real selector preserves the default ACCEPT prefilter" "$DEFAULT_OUT" "text_prefilter='(^|[^A-Za-z0-9-])ACCEPT([^A-Za-z0-9-]|$)'"
finish_case

# The named estate branch keeps structural population checks but applies the
# historical 2391 ACCEPT-statement gate only to an uncustomized invocation.
SAVED_TOP_DIR="$TOP_DIR"
TOP_DIR="$SCRATCH/estate-root"
ESTATE_CORPUS="$TOP_DIR/estate"
mkdir -p "$ESTATE_CORPUS/endevor/SYSTEM/SUBSYSTEM/COBOL"
python3 - "$ESTATE_CORPUS/endevor/SYSTEM/SUBSYSTEM/COBOL" <<'PY'
import os
import sys

root = sys.argv[1]
for number in range(3781):
    path = os.path.join(root, f"MEMBER{number:04d}")
    if number < 1369:
        lines = [
            "       IDENTIFICATION DIVISION.",
            f"       PROGRAM-ID. PROGRAM{number:04d}.",
            "       PROCEDURE DIVISION.",
            "       DISPLAY WS-FIELD.",
        ]
        if number == 0:
            lines[-1] = "       EXEC SQL SELECT * FROM SAMPLE END-EXEC."
    else:
        lines = ["       COPYBOOK DATA."]
    with open(path, "w", encoding="ascii") as member:
        member.write("\n".join(lines) + "\n")
PY
if [ $? -ne 0 ]; then
    echo "accept-differential-selftest: FAIL - could not create estate selector fixture"
    exit 1
fi
ESTATE_PATHS="$SCRATCH/estate-paths.bin"
ESTATE_OUT="$(prepare_accept_paths "$ESTATE_CORPUS" "$ESTATE_PATHS" '(^|[^A-Za-z0-9-])EXEC[[:space:]]+SQL([^A-Za-z0-9-]|$)' 1 2>&1)"
ESTATE_CODE=$?
TOP_DIR="$SAVED_TOP_DIR"
report_case 11 "estate branch reports measured custom-selection denominator" PASS "$ESTATE_CODE"
require_output_contains 11 "estate branch reports measured custom-selection denominator" "$ESTATE_OUT" 'estate selector: custom selection recorded denominator'
require_output_contains 11 "estate branch reports measured custom-selection denominator" "$ESTATE_OUT" 'selected_files=1 statements=1'
finish_case

ESTATE_DEFAULT_PATHS="$SCRATCH/estate-default-paths.bin"
TOP_DIR="$SCRATCH/estate-root"
ESTATE_DEFAULT_OUT="$(prepare_accept_paths "$ESTATE_CORPUS" "$ESTATE_DEFAULT_PATHS" '' 0 2>&1)"
ESTATE_DEFAULT_CODE=$?
TOP_DIR="$SAVED_TOP_DIR"
report_case 16 "estate branch retains default ACCEPT denominator gate" FAIL "$ESTATE_DEFAULT_CODE"
require_output_contains 16 "estate branch retains default ACCEPT denominator gate" "$ESTATE_DEFAULT_OUT" 'recorded 3781/1369/2391 population'
finish_case

# A lexical estate symlink must activate the same authoritative selector. This
# pins cmd_run's physical corpus-root canonicalization without reading any real
# corpus content.
SYMLINK_REPO="$SCRATCH/symlink-repo"
mkdir "$SYMLINK_REPO"
ln -s "$ESTATE_CORPUS" "$SYMLINK_REPO/estate"
TOP_DIR="$SYMLINK_REPO"
SYMLINK_ESTATE_ABS=$(cd -P "$SYMLINK_REPO/estate" && pwd)
SYMLINK_ESTATE_PATHS="$SCRATCH/symlink-estate-paths.bin"
SYMLINK_ESTATE_OUT="$(prepare_accept_paths "$SYMLINK_ESTATE_ABS" "$SYMLINK_ESTATE_PATHS" '(^|[^A-Za-z0-9-])EXEC[[:space:]]+SQL([^A-Za-z0-9-]|$)' 1 2>&1)"
SYMLINK_ESTATE_CODE=$?
TOP_DIR="$SAVED_TOP_DIR"
report_case 34 "physical estate symlink activates authoritative selector" PASS "$SYMLINK_ESTATE_CODE"
require_output_contains 34 "physical estate symlink activates authoritative selector" "$SYMLINK_ESTATE_OUT" 'estate selector: custom selection recorded denominator'
require_output_contains 34 "physical estate symlink activates authoritative selector" "$SYMLINK_ESTATE_OUT" 'declared_cobol_members=3781 compilable_programs=1369'
finish_case

TRACER_CORPUS="$SCRATCH/tracer-corpus"
TRACER_TMP="$SCRATCH/tracer-run"
mkdir "$TRACER_CORPUS" "$TRACER_TMP"
printf '%s\n' '       EXEC SQL SELECT * FROM SAMPLE END-EXEC.' '       ACCEPT WS-FIELD.' > "$TRACER_CORPUS/sql.cbl"

prepare_accept_paths() {
    printf '%s\0' "$1/sql.cbl" > "$2"
    report "snapshot: discovered_files=1 selected_files=1 prefilter_failures=0 text_prefilter='$3' custom_selection=$4"
}
compile_inventory_helper() {
    printf '%s\n' '#!/bin/sh' 'exit 0' > "$2"
    chmod +x "$2"
}
run_helper_snapshot() {
    HELPER_NODE_TYPE_REGEX="$5"
    report "snapshot: helper_invocation node_type_regex='$HELPER_NODE_TYPE_REGEX'"
    report "snapshot: corpus=$2 node_type_regex='$HELPER_NODE_TYPE_REGEX' out=$4"
    if [ "$HELPER_NODE_TYPE_REGEX" = "^(${DEFAULT_NODE_TYPE_REGEX})$" ]; then
        printf '%b\n' 'sql.cbl\t0,7\taccept_statement\tclean' > "$4"
    else
        case "$1" in
            *baseline*) printf '%b\n' 'sql.cbl\t0,7\texec_sql_statement\tclean' > "$4" ;;
            *) printf '%b\n' 'sql.cbl\t0,7\tread_statement\tclean' > "$4" ;;
        esac
    fi
}

MALFORMED_NODE_SNAPSHOT="$SCRATCH/malformed-node-snapshot.tsv"
MALFORMED_NODE_SNAPSHOT_OUT="$(TREE_SITTER="$FAKE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$TRACER_CORPUS" "$MALFORMED_NODE_SNAPSHOT" '[' 2>&1)"
MALFORMED_NODE_SNAPSHOT_CODE=$?
report_case 23 "malformed snapshot node regex fails before output" FAIL "$MALFORMED_NODE_SNAPSHOT_CODE"
require_output_contains 23 "malformed snapshot node regex fails before output" "$MALFORMED_NODE_SNAPSHOT_OUT" 'snapshot: FAIL - invalid node type regex'
if [ -e "$MALFORMED_NODE_SNAPSHOT" ]; then
    CASE_RESULT="FAIL (malformed snapshot left a partial inventory)"
    RETURN_CODE=1
fi
finish_case

MALFORMED_NODE_RUN_TMP="$SCRATCH/malformed-node-run"
mkdir "$MALFORMED_NODE_RUN_TMP"
MALFORMED_NODE_RUN_OUT="$(DIFF_TMP="$MALFORMED_NODE_RUN_TMP" TREE_SITTER=true cmd_run HEAD "$TRACER_CORPUS" '[' --no-prefilter 2>&1)"
MALFORMED_NODE_RUN_CODE=$?
report_case 24 "malformed run node regex fails before scratch artifacts" FAIL "$MALFORMED_NODE_RUN_CODE"
require_output_contains 24 "malformed run node regex fails before scratch artifacts" "$MALFORMED_NODE_RUN_OUT" 'run: FAIL - invalid node type regex'
if [ -n "$(ls -A "$MALFORMED_NODE_RUN_TMP")" ]; then
    CASE_RESULT="FAIL (malformed run node regex left scratch artifacts)"
    RETURN_CODE=1
fi
finish_case

PIPELINE_PARSER="$SCRATCH/failing-extraction-parser"
cat > "$PIPELINE_PARSER" <<'EOF'
#!/bin/sh
printf '%s\n' '(accept_statement [0, 0] - [0, 6])'
exit 2
EOF
chmod +x "$PIPELINE_PARSER"
PIPELINE_OUT="$SCRATCH/pipeline-error.tsv"
PIPELINE_LOG="$(TREE_SITTER="$PIPELINE_PARSER" bash "$DIFFERENTIAL" snapshot \
    "$TRACER_CORPUS" "$PIPELINE_OUT" 2>&1)"
PIPELINE_CODE=$?
report_case 25 "snapshot extraction pipeline error propagates" FAIL "$PIPELINE_CODE"
require_output_contains 25 "snapshot extraction pipeline error propagates" "$PIPELINE_LOG" 'snapshot: FAIL - parser extraction pipeline failed'
if [ -e "$PIPELINE_OUT" ]; then
    CASE_RESULT="FAIL (pipeline error left a partial inventory)"
    RETURN_CODE=1
fi
finish_case

TRACER_REGEX='exec_sql_statement|read_statement'
TRACER_OUT="$(DIFF_TMP="$TRACER_TMP" TREE_SITTER=true cmd_run HEAD "$TRACER_CORPUS" "$TRACER_REGEX" 2>&1)"
TRACER_CODE=$?
report_case 7 "custom run regex reaches isolated helpers and detects reclassification" FAIL "$TRACER_CODE"
require_output_contains 7 "custom run regex reaches isolated helpers and detects reclassification" "$TRACER_OUT" "node_type_regex='^(${TRACER_REGEX})$'"
require_output_contains 7 "custom run regex reaches isolated helpers and detects reclassification" "$TRACER_OUT" 'sql.cbl:0,7'
require_output_contains 7 "custom run regex reaches isolated helpers and detects reclassification" "$TRACER_OUT" 'RECLASSIFIED_COUNT: 1'
finish_case

DEFAULT_RUN_TMP="$SCRATCH/default-run"
mkdir "$DEFAULT_RUN_TMP"
DEFAULT_RUN_OUT="$(DIFF_TMP="$DEFAULT_RUN_TMP" TREE_SITTER=true cmd_run HEAD "$TRACER_CORPUS" 2>&1)"
DEFAULT_RUN_CODE=$?
report_case 12 "omitted run arguments preserve ACCEPT defaults" PASS "$DEFAULT_RUN_CODE"
require_output_contains 12 "omitted run arguments preserve ACCEPT defaults" "$DEFAULT_RUN_OUT" "node_type_regex='^(${DEFAULT_NODE_TYPE_REGEX})$'"
require_output_contains 12 "omitted run arguments preserve ACCEPT defaults" "$DEFAULT_RUN_OUT" "text_prefilter='${DEFAULT_TEXT_PREFILTER_RE}' custom_selection=0"
finish_case

INVALID_TMP="$SCRATCH/invalid-run"
mkdir "$INVALID_TMP"
INVALID_OUT="$(DIFF_TMP="$INVALID_TMP" TREE_SITTER=true cmd_run HEAD "$TRACER_CORPUS" '' --no-prefilter 2>&1)"
INVALID_CODE=$?
report_case 13 "empty node regex fails closed" FAIL "$INVALID_CODE"
require_output_contains 13 "empty node regex fails closed" "$INVALID_OUT" 'run: usage:'
finish_case

EMPTY_PREFILTER_TMP="$SCRATCH/empty-prefilter-run"
mkdir "$EMPTY_PREFILTER_TMP"
EMPTY_PREFILTER_OUT="$(DIFF_TMP="$EMPTY_PREFILTER_TMP" TREE_SITTER=true cmd_run HEAD "$TRACER_CORPUS" "$TRACER_REGEX" '' 2>&1)"
EMPTY_PREFILTER_CODE=$?
report_case 14 "empty text prefilter fails closed" FAIL "$EMPTY_PREFILTER_CODE"
require_output_contains 14 "empty text prefilter fails closed" "$EMPTY_PREFILTER_OUT" 'run: usage:'
finish_case

MALFORMED_TMP="$SCRATCH/malformed-run"
mkdir "$MALFORMED_TMP"
MALFORMED_OUT="$(DIFF_TMP="$MALFORMED_TMP" TREE_SITTER=true cmd_run HEAD "$TRACER_CORPUS" "$TRACER_REGEX" '[' 2>&1)"
MALFORMED_CODE=$?
report_case 15 "malformed text prefilter fails closed" FAIL "$MALFORMED_CODE"
require_output_contains 15 "malformed text prefilter fails closed" "$MALFORMED_OUT" 'run: FAIL - invalid text prefilter regex'
finish_case

RUN_LINK="$SCRATCH/repo-run-link"
ln -s "$REPO_PROBE_DIR" "$RUN_LINK"
RUN_LINK_OUT="$(DIFF_TMP="$RUN_LINK" TREE_SITTER=true cmd_run HEAD "$TRACER_CORPUS" 2>&1)"
RUN_LINK_CODE=$?
report_case 22 "DIFF_TMP symlink into repository is refused" FAIL "$RUN_LINK_CODE"
require_output_contains 22 "DIFF_TMP symlink into repository is refused" "$RUN_LINK_OUT" 'run: REFUSED - DIFF_TMP resolves under the repository root'
if [ -e "$REPO_PROBE_DIR/accept-differential-worktree" ] ||
   [ -e "$REPO_PROBE_DIR/before-inventory.txt" ] ||
   [ -e "$REPO_PROBE_DIR/after-inventory.txt" ] ||
   [ -e "$REPO_PROBE_DIR/selected-paths.bin" ] ||
   [ -e "$REPO_PROBE_DIR/baseline-inventory-helper" ] ||
   [ -e "$REPO_PROBE_DIR/current-inventory-helper" ]; then
    CASE_RESULT="FAIL (run created repository artifacts before refusal)"
    RETURN_CODE=1
fi
finish_case

B1="$SCRATCH/before1.txt"; A1="$SCRATCH/after1.txt"
printf '%b\n' 'sample.cbl\t10,5\taccept_statement\tclean' > "$B1"; cp "$B1" "$A1"
OUT1="$(bash "$DIFFERENTIAL" compare "$B1" "$A1")"; CODE1=$?
report_case 1 "identical before/after inventories" PASS "$CODE1"
require_output_contains 1 "identical before/after inventories" "$OUT1" "RECLASSIFIED_COUNT: 0"
finish_case

B2="$SCRATCH/before2.txt"; A2="$SCRATCH/after2.txt"
printf '%b\n' 'sample.cbl\t10,5\taccept_statement\tclean' > "$B2"
printf '%b\n' 'sample.cbl\t10,5\tidms_accept_statement\tclean' > "$A2"
OUT2="$(bash "$DIFFERENTIAL" compare "$B2" "$A2")"; CODE2=$?
report_case 2 "clean accept_statement reclassified to idms_accept_statement" FAIL "$CODE2"
require_output_contains 2 "clean accept_statement reclassified to idms_accept_statement" "$OUT2" "sample.cbl:10,5"
require_output_contains 2 "clean accept_statement reclassified to idms_accept_statement" "$OUT2" "RECLASSIFIED_COUNT: 1"
finish_case

B3="$SCRATCH/before3.txt"; A3="$SCRATCH/after3.txt"
printf '%b\n' 'sample.cbl\t20,5\taccept_statement\ttrailing_error' > "$B3"
printf '%b\n' 'sample.cbl\t20,5\tidms_accept_statement\tclean' > "$A3"
OUT3="$(bash "$DIFFERENTIAL" compare "$B3" "$A3")"; CODE3=$?
report_case 3 "trailing_error accept_statement converted to idms_accept_statement" PASS "$CODE3"
require_output_contains 3 "trailing_error accept_statement converted to idms_accept_statement" "$OUT3" "CONVERTED_COUNT: 1"
require_output_contains 3 "trailing_error accept_statement converted to idms_accept_statement" "$OUT3" "RECLASSIFIED_COUNT: 0"
finish_case

B4="$SCRATCH/before4.txt"; A4="$SCRATCH/after4.txt"
printf '%b\n' 'sample.cbl\t30,5\taccept_statement\tclean' > "$B4"; : > "$A4"
OUT4="$(bash "$DIFFERENTIAL" compare "$B4" "$A4")"; CODE4=$?
report_case 4 "clean accept_statement present before, absent after" FAIL "$CODE4"
require_output_contains 4 "clean accept_statement present before, absent after" "$OUT4" "sample.cbl:30,5"
require_output_contains 4 "clean accept_statement present before, absent after" "$OUT4" "RECLASSIFIED_COUNT: 1"
finish_case

B5="$SCRATCH/before5.txt"; A5="$SCRATCH/after5.txt"
: > "$B5"; printf '%b\n' 'sample.cbl\t40,5\tidms_accept_statement\tclean' > "$A5"
OUT5="$(bash "$DIFFERENTIAL" compare "$B5" "$A5")"; CODE5=$?
report_case 5 "new-only-in-after record is not a reclassification" PASS "$CODE5"
require_output_contains 5 "new-only-in-after record is not a reclassification" "$OUT5" "NEW_COUNT: 1"
require_output_contains 5 "new-only-in-after record is not a reclassification" "$OUT5" "RECLASSIFIED_COUNT: 0"
finish_case

B6="$SCRATCH/before6.txt"; A6="$SCRATCH/after6.txt"
: > "$B6"; : > "$A6"
OUT6="$(bash "$DIFFERENTIAL" compare "$B6" "$A6")"; CODE6=$?
report_case 6 "both inventories empty, zero records compared" PASS "$CODE6"
require_output_contains 6 "both inventories empty, zero records compared" "$OUT6" "zero records compared"
finish_case

run_invalid_inventory_case() {
    CASE_NUMBER="$1"
    CASE_DESCRIPTION="$2"
    CASE_SIDE="$3"
    CASE_ROWS="$4"
    CASE_EXPECTED="$5"
    CASE_BEFORE="$SCRATCH/invalid-before-${CASE_NUMBER}.txt"
    CASE_AFTER="$SCRATCH/invalid-after-${CASE_NUMBER}.txt"
    : > "$CASE_BEFORE"
    : > "$CASE_AFTER"
    if [ "$CASE_SIDE" = "before" ]; then
        printf '%b' "$CASE_ROWS" > "$CASE_BEFORE"
    else
        printf '%b' "$CASE_ROWS" > "$CASE_AFTER"
    fi
    CASE_OUTPUT="$(bash "$DIFFERENTIAL" compare "$CASE_BEFORE" "$CASE_AFTER" 2>&1)"
    CASE_CODE=$?
    report_case "$CASE_NUMBER" "$CASE_DESCRIPTION" FAIL "$CASE_CODE"
    require_output_contains "$CASE_NUMBER" "$CASE_DESCRIPTION" "$CASE_OUTPUT" "$CASE_EXPECTED"
    if printf '%s\n' "$CASE_OUTPUT" | grep -Eq '^(RECLASSIFIED_COUNT|CONVERTED_COUNT|NEW_COUNT):'; then
        CASE_RESULT="FAIL (invalid inventory emitted a differential verdict)"
        RETURN_CODE=1
    fi
    finish_case
}

run_invalid_inventory_case 26 "duplicate before key is rejected" before \
    'sample.cbl\t1,2\taccept_statement\tclean\nsample.cbl\t1,2\taccept_statement\tclean\n' \
    'before-inventory line 2: duplicate key sample.cbl:1,2'
run_invalid_inventory_case 27 "duplicate after key IDMS then standard is rejected" after \
    'sample.cbl\t1,2\tidms_accept_statement\tclean\nsample.cbl\t1,2\taccept_statement\tclean\n' \
    'after-inventory line 2: duplicate key sample.cbl:1,2'
run_invalid_inventory_case 28 "duplicate after key standard then IDMS is rejected" after \
    'sample.cbl\t1,2\taccept_statement\tclean\nsample.cbl\t1,2\tidms_accept_statement\tclean\n' \
    'after-inventory line 2: duplicate key sample.cbl:1,2'
run_invalid_inventory_case 29 "short TSV row is rejected" before \
    'sample.cbl\t1,2\taccept_statement\n' 'before-inventory line 1: expected exactly four TSV fields'
run_invalid_inventory_case 30 "long TSV row is rejected" after \
    'sample.cbl\t1,2\taccept_statement\tclean\textra\n' 'after-inventory line 1: expected exactly four TSV fields'
run_invalid_inventory_case 31 "invalid position is rejected" before \
    'sample.cbl\trow,2\taccept_statement\tclean\n' 'before-inventory line 1: invalid position'
run_invalid_inventory_case 32 "unsupported node type is rejected" after \
    'sample.cbl\t1,2\tnot-a-node\tclean\n' 'after-inventory line 1: unsupported node type'
run_invalid_inventory_case 33 "unsupported qualifier is rejected" before \
    'sample.cbl\t1,2\taccept_statement\tunknown\n' 'before-inventory line 1: unsupported qualifier'

exit "$RETURN_CODE"
