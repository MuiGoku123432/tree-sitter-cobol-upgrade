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
trap 'rm -rf "$SCRATCH"' EXIT INT TERM

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

exit "$RETURN_CODE"
