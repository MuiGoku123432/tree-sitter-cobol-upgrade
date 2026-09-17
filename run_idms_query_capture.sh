#!/bin/bash
# Exact staged IDMS query contract gate. Every fixture name and statement is
# hand-written and synthetic. No repository corpus is read by this script.
#
# Exit 0: requested GREEN contract or exact staged RED matched.
# Exit 1: contract mismatch.
# Exit 2: HARNESS_ERROR (tool, path, fixture, query, or normalizer failure).

SCRIPT_DIR=$(cd -P "$(dirname "$0")" && pwd)
TOP_DIR=${TOP_DIR:-$SCRIPT_DIR}
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/tree-sitter-cli/tree-sitter}
IDMS_QUERY_FILE=${IDMS_QUERY_FILE:-$TOP_DIR/queries/idms.scm}
IDMS_CAPTURE_OUT=${IDMS_CAPTURE_OUT:-}
EXPECTED_VERBS="BIND OBTAIN FIND READY ERASE ACCEPT GET STORE FINISH MODIFY CONNECT ROLLBACK COMMIT DISCONNECT"
MODE=green
FORCE_NORMALIZER_FAILURE=${IDMS_FORCE_NORMALIZER_FAILURE:-0}

report() { printf '%s\n' "$1"; }
harness_error() { report "HARNESS_ERROR: $1"; exit 2; }

case "${1:-}" in
    "") ;;
    --invalid-only) MODE=invalid ;;
    --expect-red=verbs) MODE=verbs ;;
    --expect-red=roles) MODE=roles ;;
    *) harness_error "unsupported argument: $1" ;;
esac
if [ "$#" -gt 1 ]; then
    harness_error "expected at most one mode argument"
fi

if [ "${IDMS_SKIP_INSTALL:-0}" != "1" ] && [ ! -x "$TREE_SITTER" ]; then
    (cd "$TOP_DIR" && npm ci)
    INSTALL_STATUS=$?
    if [ "$INSTALL_STATUS" -ne 0 ] && [ ! -x "$TREE_SITTER" ]; then
        harness_error "npm ci failed and the lockfile-pinned CLI is unavailable"
    fi
fi
if [ ! -x "$TREE_SITTER" ]; then
    harness_error "lockfile-pinned tree-sitter CLI is unavailable"
fi
CLI_VERSION="$($TREE_SITTER --version 2>&1)"
CLI_STATUS=$?
if [ "$CLI_STATUS" -ne 0 ]; then
    harness_error "tree-sitter --version exited $CLI_STATUS"
fi
case "$CLI_VERSION" in
    "tree-sitter 0.24.5"|"tree-sitter 0.24.5 "*) ;;
    *) harness_error "expected tree-sitter 0.24.5, got: $CLI_VERSION" ;;
esac

if [ ! -f "$IDMS_QUERY_FILE" ] || [ ! -r "$IDMS_QUERY_FILE" ] || [ -L "$IDMS_QUERY_FILE" ]; then
    harness_error "IDMS_QUERY_FILE must be a readable regular non-symlink file"
fi
QUERY_CANONICAL="$(python3 - "$IDMS_QUERY_FILE" <<'PY'
import pathlib
import sys
try:
    path = pathlib.Path(sys.argv[1]).resolve(strict=True)
except (OSError, RuntimeError):
    sys.exit(1)
if not path.is_file():
    sys.exit(1)
print(path)
PY
)"
if [ $? -ne 0 ] || [ -z "$QUERY_CANONICAL" ]; then
    harness_error "IDMS_QUERY_FILE could not be resolved strictly"
fi

SCRATCH_DIR="$(mktemp -d)"
if [ $? -ne 0 ] || [ -z "$SCRATCH_DIR" ]; then
    harness_error "could not create gate-owned external scratch"
fi
cleanup() { rm -rf "$SCRATCH_DIR"; }
trap cleanup EXIT INT TERM

FULL_FIXTURE="$SCRATCH_DIR/idms-query-gate.cbl"
INVALID_FIXTURE="$SCRATCH_DIR/idms-invalid-gate.cbl"
FULL_RAW="$SCRATCH_DIR/full.raw"
INVALID_RAW="$SCRATCH_DIR/invalid.raw"
FULL_TSV="$SCRATCH_DIR/full.tsv"
INVALID_TSV="$SCRATCH_DIR/invalid.tsv"
EXPECTED_TSV="$SCRATCH_DIR/expected.tsv"
MODE_EXPECTED_TSV="$SCRATCH_DIR/mode-expected.tsv"
DIAGNOSTICS="$SCRATCH_DIR/diagnostics.tsv"

cat > "$FULL_FIXTURE" <<'FIXTURE_EOF'
       IDENTIFICATION DIVISION.
       PROGRAM-ID. IDMS-QUERY-GATE.
       PROCEDURE DIVISION.
       BIND RUN-UNIT.
       OBTAIN CALC CUSTOMER-REC.
       FIND CALC ACCOUNT-REC.
       READY CUSTOMER-AREA.
       ERASE CUSTOMER-REC ALL MEMBERS.
       ACCEPT WS-DB-KEY FROM CUSTOMER-REC CURRENCY.
       GET CUSTOMER-REC.
       STORE CUSTOMER-REC.
       FINISH TASK.
       MODIFY CUSTOMER-REC.
       CONNECT CUSTOMER-REC TO CUST-ORDER-SET.
       ROLLBACK CONTINUE.
       COMMIT TASK ALL.
       DISCONNECT CUSTOMER-REC FROM CUST-ORDER-SET.
       OBTAIN ANY ORDER-REC.
       FIND DUPLICATE ORDER-REC.
       OBTAIN FIRST ORDER-REC WITHIN ORDER-SET.
       FIND LAST ORDER-REC WITHIN ORDER-SET.
       OBTAIN PRIOR ORDER-REC WITHIN ORDER-SET.
       FIND 3 ORDER-REC WITHIN ORDER-SET.
       OBTAIN ORDER-REC DB-KEY IS WS-KEY PAGE-INFO WS-PAGE.
       FIND NEXT AREA-REC WITHIN CONTROL-AREA.
       STOP RUN.
FIXTURE_EOF
if [ $? -ne 0 ]; then
    harness_error "could not write synthetic 14-verb fixture"
fi

# CR-04 negative matrix: prohibited bare operands, reversed prepositions,
# cross-verb set clauses, and non-ERASE option clauses.
cat > "$INVALID_FIXTURE" <<'INVALID_EOF'
       IDENTIFICATION DIVISION.
       PROGRAM-ID. IDMS-INVALID-GATE.
       PROCEDURE DIVISION.
       STORE.
       MODIFY.
       ERASE.
       CONNECT.
       DISCONNECT.
       STORE CUSTOMER-REC TO CUSTOMER-SET.
       MODIFY CUSTOMER-REC FROM CUSTOMER-SET.
       GET CUSTOMER-REC TO CUSTOMER-SET.
       CONNECT CUSTOMER-REC FROM CUSTOMER-SET.
       DISCONNECT CUSTOMER-REC TO CUSTOMER-SET.
       STORE CUSTOMER-REC ALL MEMBERS.
       MODIFY CUSTOMER-REC PERMANENT MEMBERS.
       CONNECT CUSTOMER-REC SELECTIVE MEMBERS.
       STOP RUN.
INVALID_EOF
if [ $? -ne 0 ]; then
    harness_error "could not write synthetic invalid-update fixture"
fi

normalize_query() {
    NORMALIZE_SOURCE="$1"
    NORMALIZE_RAW="$2"
    NORMALIZE_OUT="$3"
    if [ "$FORCE_NORMALIZER_FAILURE" = "1" ]; then
        return 1
    fi
    python3 - "$NORMALIZE_SOURCE" "$NORMALIZE_RAW" "$NORMALIZE_OUT" <<'PY'
import re
import sys
from pathlib import Path

source_path, raw_path, out_path = map(Path, sys.argv[1:])
try:
    source = source_path.read_text(encoding="ascii").splitlines()
    raw = raw_path.read_text(encoding="utf-8")
except OSError:
    sys.exit(1)

pattern = re.compile(
    r"capture: (?:\d+ - )?([A-Za-z_][A-Za-z0-9_]*), "
    r"start: \((\d+), (\d+)\), end: \((\d+), (\d+)\)"
)
rows = []
seen = set()
for match in pattern.finditer(raw):
    name, sr, sc, er, ec = match.groups()
    sr, sc, er, ec = map(int, (sr, sc, er, ec))
    if sr >= len(source) or er >= len(source) or (er, ec) < (sr, sc):
        sys.exit(1)
    if sr == er:
        text = source[sr][sc:ec]
    else:
        parts = [source[sr][sc:], *source[sr + 1:er], source[er][:ec]]
        text = " ".join(parts)
    text = " ".join(text.split())
    row = (name, sr, sc, er, ec, text)
    if row in seen:
        sys.exit(1)
    seen.add(row)
    rows.append(row)
try:
    out_path.write_text("".join("\t".join(map(str, row)) + "\n" for row in rows), encoding="utf-8")
except OSError:
    sys.exit(1)
PY
}

run_query() {
    QUERY_LABEL="$1"
    QUERY_FIXTURE="$2"
    QUERY_RAW="$3"
    QUERY_TSV="$4"
    (cd "$TOP_DIR" && "$TREE_SITTER" query "$QUERY_CANONICAL" "$QUERY_FIXTURE") > "$QUERY_RAW" 2>&1
    QUERY_STATUS=$?
    if [ "$QUERY_STATUS" -ne 0 ]; then
        harness_error "$QUERY_LABEL query exited $QUERY_STATUS"
    fi
    normalize_query "$QUERY_FIXTURE" "$QUERY_RAW" "$QUERY_TSV"
    if [ $? -ne 0 ]; then
        harness_error "$QUERY_LABEL output normalizer failed"
    fi
}

run_query full "$FULL_FIXTURE" "$FULL_RAW" "$FULL_TSV"
run_query invalid "$INVALID_FIXTURE" "$INVALID_RAW" "$INVALID_TSV"
report "QUERY_OK: full and invalid synthetic subjects completed"
report "NORMALIZER_OK: exact source ranges normalized"

cat > "$EXPECTED_TSV" <<'EXPECTED_EOF'
verb	3	7	3	11	BIND
verb	4	7	4	13	OBTAIN
record	4	19	4	31	CUSTOMER-REC
verb	5	7	5	11	FIND
record	5	17	5	28	ACCOUNT-REC
verb	6	7	6	12	READY
verb	7	7	7	12	ERASE
record	7	13	7	25	CUSTOMER-REC
verb	8	7	8	13	ACCEPT
record	8	29	8	41	CUSTOMER-REC
verb	9	7	9	10	GET
record	9	11	9	23	CUSTOMER-REC
verb	10	7	10	12	STORE
record	10	13	10	25	CUSTOMER-REC
verb	11	7	11	13	FINISH
verb	12	7	12	13	MODIFY
record	12	14	12	26	CUSTOMER-REC
verb	13	7	13	14	CONNECT
record	13	15	13	27	CUSTOMER-REC
set	13	31	13	45	CUST-ORDER-SET
verb	14	7	14	15	ROLLBACK
verb	15	7	15	13	COMMIT
verb	16	7	16	17	DISCONNECT
record	16	18	16	30	CUSTOMER-REC
set	16	36	16	50	CUST-ORDER-SET
verb	17	7	17	13	OBTAIN
record	17	18	17	27	ORDER-REC
verb	18	7	18	11	FIND
record	18	22	18	31	ORDER-REC
verb	19	7	19	13	OBTAIN
record	19	20	19	29	ORDER-REC
set	19	37	19	46	ORDER-SET
verb	20	7	20	11	FIND
record	20	17	20	26	ORDER-REC
set	20	34	20	43	ORDER-SET
verb	21	7	21	13	OBTAIN
record	21	20	21	29	ORDER-REC
set	21	37	21	46	ORDER-SET
verb	22	7	22	11	FIND
record	22	14	22	23	ORDER-REC
set	22	31	22	40	ORDER-SET
verb	23	7	23	13	OBTAIN
record	23	14	23	23	ORDER-REC
verb	24	7	24	11	FIND
record	24	17	24	25	AREA-REC
EXPECTED_EOF

python3 - "$FULL_TSV" "$EXPECTED_TSV" "$DIAGNOSTICS" "$EXPECTED_VERBS" <<'PY'
import sys
from pathlib import Path

actual_path, expected_path, diagnostics_path = map(Path, sys.argv[1:4])
expected_verbs = sys.argv[4].split()

def read_rows(path):
    rows = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        fields = line.split("\t")
        if len(fields) != 6 or fields[0] not in {"verb", "record", "set"}:
            raise ValueError(f"malformed capture row {number}")
        rows.append(tuple(fields))
    return rows

try:
    actual = read_rows(actual_path)
    expected = read_rows(expected_path)
except (OSError, ValueError) as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)

actual_set = set(actual)
expected_set = set(expected)
if len(actual_set) != len(actual):
    print("duplicate normalized capture row", file=sys.stderr)
    sys.exit(1)

diagnostics = []
for row in expected:
    if row not in actual_set:
        diagnostics.append(("missing",) + row)
for row in actual:
    if row not in expected_set:
        diagnostics.append(("unexpected",) + row)
actual_verbs = [row[5] for row in actual if row[0] == "verb" and int(row[1]) <= 16]
if [row[5] for row in expected if row[0] == "verb" and int(row[1]) <= 16] != expected_verbs:
    print("expected oracle does not contain the 14 required verbs", file=sys.stderr)
    sys.exit(1)
with diagnostics_path.open("w", encoding="utf-8") as output:
    for row in diagnostics:
        output.write("\t".join(row) + "\n")
PY
if [ $? -ne 0 ]; then
    harness_error "capture contract analyzer failed"
fi

# Build the complete expected stream for the selected stage from the single
# future-GREEN oracle, then compare every row exactly while preserving actual
# query source order. This pins ranges, text, count, and multiplicity without
# assuming pattern-group order from tree-sitter's query printer.
python3 - "$EXPECTED_TSV" "$MODE_EXPECTED_TSV" "$MODE" <<'PY'
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:3])
mode = sys.argv[3]
rows = [line.split("\t") for line in source.read_text(encoding="utf-8").splitlines()]
missing_verb_lines = {3, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16}
output = []
for row in rows:
    line = int(row[1])
    if mode == "verbs" and row == ["verb", "8", "7", "8", "13", "ACCEPT"]:
        output.append(["verb", "8", "7", "8", "50", "ACCEPT WS-DB-KEY FROM CUSTOMER-REC CURRENCY"])
        continue
    if mode == "verbs" and row[0] == "verb" and line in missing_verb_lines:
        continue
    if mode == "roles" and row == ["verb", "6", "7", "6", "12", "READY"]:
        output.append(row)
        output.append(["record", "6", "13", "6", "26", "CUSTOMER-AREA"])
        continue
    if mode == "verbs" and row == ["record", "5", "17", "5", "28", "ACCOUNT-REC"]:
        output.append(row)
        output.append(["record", "6", "13", "6", "26", "CUSTOMER-AREA"])
        continue
    if mode in {"verbs", "roles"} and row == ["record", "18", "22", "18", "31", "ORDER-REC"]:
        output.append(["record", "18", "12", "18", "21", "DUPLICATE"])
        continue
    output.append(row)
    if mode in {"verbs", "roles"} and row == ["record", "24", "17", "24", "25", "AREA-REC"]:
        output.append(["set", "24", "33", "24", "45", "CONTROL-AREA"])
destination.write_text("".join("\t".join(row) + "\n" for row in output), encoding="utf-8")
PY
if [ $? -ne 0 ]; then
    harness_error "could not construct exact staged oracle"
fi

if [ -s "$INVALID_TSV" ]; then
    if [ "$MODE" = "invalid" ] || [ "$MODE" = "green" ]; then
        report "CONTRACT_MISMATCH: invalid update subject emitted graph-bearing captures"
    else
        report "STAGED_RED: invalid update subject remains assigned to plan 02-08"
    fi
    INVALID_MISMATCH=1
else
    INVALID_MISMATCH=0
fi

if [ "$MODE" = "verbs" ] && [ "$INVALID_MISMATCH" -ne 0 ]; then
    python3 - "$INVALID_TSV" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    rows = [line.split("\t") for line in path.read_text(encoding="utf-8").splitlines() if line]
except OSError:
    sys.exit(1)
if not rows or any(len(row) != 6 or row[0] not in {"record", "set"} for row in rows):
    sys.exit(1)
sys.exit(0)
PY
    if [ $? -ne 0 ]; then
        report "CONTRACT_MISMATCH: invalid-update RED differs from the exact plan 02-08 handoff"
        exit 1
    fi
fi

python3 - "$DIAGNOSTICS" "$MODE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
mode = sys.argv[2]
rows = [tuple(line.split("\t")) for line in path.read_text().splitlines() if line]

missing_verbs = {
    ("missing", "verb", "3", "7", "3", "11", "BIND"),
    ("missing", "verb", "6", "7", "6", "12", "READY"),
    ("missing", "verb", "7", "7", "7", "12", "ERASE"),
    ("missing", "verb", "9", "7", "9", "10", "GET"),
    ("missing", "verb", "10", "7", "10", "12", "STORE"),
    ("missing", "verb", "11", "7", "11", "13", "FINISH"),
    ("missing", "verb", "12", "7", "12", "13", "MODIFY"),
    ("missing", "verb", "13", "7", "13", "14", "CONNECT"),
    ("missing", "verb", "14", "7", "14", "15", "ROLLBACK"),
    ("missing", "verb", "15", "7", "15", "13", "COMMIT"),
    ("missing", "verb", "16", "7", "16", "17", "DISCONNECT"),
}
accept_defect = {
    ("missing", "verb", "8", "7", "8", "13", "ACCEPT"),
    ("unexpected", "verb", "8", "7", "8", "50", "ACCEPT WS-DB-KEY FROM CUSTOMER-REC CURRENCY"),
}
role_defects = {
    ("unexpected", "record", "6", "13", "6", "26", "CUSTOMER-AREA"),
    ("missing", "record", "18", "22", "18", "31", "ORDER-REC"),
    ("unexpected", "record", "18", "12", "18", "21", "DUPLICATE"),
    ("unexpected", "set", "24", "33", "24", "45", "CONTROL-AREA"),
}
actual = set(rows)
if mode == "verbs":
    wanted = missing_verbs | accept_defect | role_defects
elif mode == "roles":
    wanted = role_defects
elif mode == "green":
    wanted = set()
else:
    sys.exit(0)
if actual != wanted:
    for row in sorted(actual - wanted):
        print("unexpected diagnostic: " + "\t".join(row), file=sys.stderr)
    for row in sorted(wanted - actual):
        print("missing diagnostic: " + "\t".join(row), file=sys.stderr)
    sys.exit(1)
PY
CONTRACT_STATUS=$?
if [ "$MODE" != "invalid" ]; then
    python3 - "$MODE_EXPECTED_TSV" "$FULL_TSV" <<'PY'
import sys
from collections import Counter
from pathlib import Path

expected_path, actual_path = map(Path, sys.argv[1:])
expected = expected_path.read_text(encoding="utf-8").splitlines()
actual = actual_path.read_text(encoding="utf-8").splitlines()
sys.exit(0 if len(expected) == len(actual) and Counter(expected) == Counter(actual) else 1)
PY
    EXACT_STATUS=$?
    if [ "$EXACT_STATUS" -ne 0 ]; then
        report "CONTRACT_MISMATCH: exact ordered capture stream differs for mode '$MODE'"
        if [ "${IDMS_DEBUG:-0}" = "1" ]; then
            diff -u "$MODE_EXPECTED_TSV" "$FULL_TSV"
        fi
        CONTRACT_STATUS=1
    fi
fi

if [ "$MODE" = "invalid" ]; then
    if [ "$INVALID_MISMATCH" -eq 0 ]; then
        report "INVALID_CONTRACT_GREEN: invalid update subject emitted no graph-bearing captures"
        exit 0
    fi
    exit 1
fi
if [ "$INVALID_MISMATCH" -ne 0 ] && [ "$MODE" != "verbs" ]; then
    exit 1
fi
if [ "$CONTRACT_STATUS" -ne 0 ]; then
    report "CONTRACT_MISMATCH: diagnostics do not match mode '$MODE'"
    exit 1
fi

if [ -n "$IDMS_CAPTURE_OUT" ]; then
    CAPTURE_PARENT="$(dirname "$IDMS_CAPTURE_OUT")"
    CAPTURE_NAME="$(basename "$IDMS_CAPTURE_OUT")"
    CAPTURE_PARENT_CANONICAL="$(python3 - "$TOP_DIR" "$IDMS_CAPTURE_OUT" <<'PY'
import os
import pathlib
import sys
try:
    repo = pathlib.Path(sys.argv[1]).resolve(strict=True)
    destination = pathlib.Path(sys.argv[2])
    if destination.is_symlink():
        raise OSError("symlink destination refused")
    if destination.exists() and not destination.is_file():
        raise OSError("destination is not a regular file")
    parent = destination.parent.resolve(strict=True)
except (OSError, RuntimeError):
    sys.exit(1)
if not parent.is_dir() or os.path.commonpath((str(repo), str(parent))) == str(repo):
    sys.exit(1)
print(parent)
PY
)"
    if [ $? -ne 0 ] || [ -z "$CAPTURE_PARENT_CANONICAL" ]; then
        harness_error "IDMS_CAPTURE_OUT parent must resolve outside the repository"
    fi
    CAPTURE_TEMP="$(mktemp "$CAPTURE_PARENT_CANONICAL/.${CAPTURE_NAME}.XXXXXX")"
    if [ $? -ne 0 ] || [ -z "$CAPTURE_TEMP" ]; then
        harness_error "could not create atomic capture output"
    fi
    cp "$FULL_TSV" "$CAPTURE_TEMP"
    if [ $? -ne 0 ]; then
        rm -f "$CAPTURE_TEMP"
        harness_error "could not stage capture output"
    fi
    mv "$CAPTURE_TEMP" "$CAPTURE_PARENT_CANONICAL/$CAPTURE_NAME"
    if [ $? -ne 0 ]; then
        rm -f "$CAPTURE_TEMP"
        harness_error "could not publish capture output"
    fi
fi

case "$MODE" in
    verbs) report "EXPECTED_RED: exact pre-fix verb defects reproduced; role defects isolated" ;;
    roles) report "EXPECTED_RED: exact post-verb semantic-role defects reproduced" ;;
    green) report "QUERY_CONTRACT_GREEN: exact IDMS capture stream matched" ;;
esac
exit 0
