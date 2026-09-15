#!/bin/bash
# Aggregate-only EXEC SQL census. Scratch may contain source-derived details,
# but the caller-visible TSV and Markdown outputs contain counts only.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TOP_DIR=${TOP_DIR:-$SCRIPT_DIR}
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/tree-sitter-cli/tree-sitter}
QUERY_FILE=${QUERY_FILE:-$TOP_DIR/queries/sql.scm}
PYTHON=${PYTHON:-python3}
PARSE_TIMEOUT_SECONDS=${PARSE_TIMEOUT_SECONDS:-10}
FAIL_COUNTER=0

report() { printf '%s\n' "$1"; }

run_census() {
    POPULATION=$1
    CORPUS=$2
    OUTPUT=$3
    DROP_CAPTURE=${4:-}
    SCRATCH=$(mktemp -d)
    if [ $? -ne 0 ] || [ -z "$SCRATCH" ]; then
        report "census: FAIL - could not create owned scratch"
        return 1
    fi

    "$PYTHON" - "$TOP_DIR" "$TREE_SITTER" "$QUERY_FILE" "$CORPUS" "$POPULATION" "$OUTPUT" "$SCRATCH" "$PARSE_TIMEOUT_SECONDS" "$DROP_CAPTURE" <<'PY'
import collections
import pathlib
import re
import subprocess
import sys

top_dir, tree_sitter, query_file, corpus, population, output, scratch, timeout_s, drop = sys.argv[1:]
timeout_s = int(timeout_s)
root = pathlib.Path(corpus)
if not root.is_dir():
    print(f"census: FAIL - corpus not found: {corpus}", file=sys.stderr)
    sys.exit(1)

files = sorted(p for p in root.rglob("*") if p.is_file() and (p.suffix.lower() == ".cbl" or not p.suffix))
if not files:
    print("census: FAIL - zero source files", file=sys.stderr)
    sys.exit(1)

categories = ("SELECT", "INSERT", "UPDATE", "DELETE", "MERGE", "CREATE", "ALTER", "DROP", "PREPARE", "OTHER")
stats = {name: collections.Counter() for name in categories}
failures = 0
failure_reasons = collections.Counter()

statement_re = re.compile(r"EXEC\s+SQL\b(.*?)END-EXEC", re.I | re.S)
kind_re = re.compile(r"^\s*(SELECT|INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|PREPARE)\b", re.I)
object_re = r"((?:\"[^\"]+\"|[A-Z0-9-]+)(?:\.(?:\"[^\"]+\"|[A-Z0-9-]+)){0,2})"
from_join_re = re.compile(r"\b(?:FROM|JOIN)\s+" + object_re, re.I)
cte_re = re.compile(r"(?:\bWITH\b|,)\s*([A-Z0-9-]+)\s+AS\s*\(", re.I)

def expected_tables(body, kind):
    patterns = []
    if kind in ("SELECT", "DELETE", "OTHER"):
        patterns.append(from_join_re)
    elif kind == "INSERT":
        patterns.extend((re.compile(r"^\s*INSERT\s+INTO\s+" + object_re, re.I), from_join_re))
    elif kind == "UPDATE":
        patterns.extend((re.compile(r"^\s*UPDATE\s+" + object_re, re.I), from_join_re))
    elif kind == "MERGE":
        patterns.append(re.compile(r"\b(?:INTO|USING)\s+" + object_re, re.I))
    elif kind in ("CREATE", "ALTER", "DROP"):
        modifiers = r"(?:IF\s+(?:NOT\s+)?EXISTS\s+)?"
        patterns.append(re.compile(r"^\s*" + kind + r"\s+TABLE\s+" + modifiers + object_re, re.I))
    names = []
    for pattern in patterns:
        names.extend(match.group(1) for match in pattern.finditer(body))
    return names

capture_re = re.compile(r"capture:\s+(?:\d+\s+-\s+)?([^,]+),\s+start:\s+\((\d+),\s*(\d+)\),\s+end:\s+\((\d+),\s*(\d+)\)")
scratch_query = pathlib.Path(scratch) / "census.scm"
scratch_query.write_text(pathlib.Path(query_file).read_text(encoding="utf-8") + "\n(sql_unparsed_tail) @tail\n", encoding="utf-8")

jobs = []
def normalize_block_body(body):
    normalized = []
    for index, line in enumerate(body.splitlines()):
        if "**" in line:
            normalized.append("")
            continue
        if index == 0:
            normalized.append(line[:72])
            continue
        if len(line) > 6 and line[6] in "*/":
            normalized.append("")
            continue
        normalized.append(line[7:72] if len(line) > 7 else "")
    return "\n".join(normalized)

for file_index, path in enumerate(files):
    try:
        source = path.read_text(encoding="utf-8", errors="replace")
        raw_matches = list(statement_re.finditer(source))
        normalized_blocks = []
        for raw_match in raw_matches:
            normalized_blocks.append(normalize_block_body(raw_match.group(1)))
        scan_source = "\n".join("EXEC SQL" + body + " END-EXEC" for body in normalized_blocks)
        expected = collections.Counter()
        matches = list(statement_re.finditer(scan_source))
        if not matches:
            continue
        for match in matches:
            body = match.group(1)
            kind_match = kind_re.match(body)
            kind = kind_match.group(1).upper() if kind_match else "OTHER"
            stats[kind]["statements"] += 1
            ctes = {name.upper() for name in cte_re.findall(body)}
            names = [name.upper() for name in expected_tables(body, kind) if name.upper() not in ctes]
            count = len(names)
            expected[kind] += count
            stats[kind]["expected"] += count

        query_blocks = []
        for match in matches:
            body = match.group(1)
            if re.match(r"\s*(?:BEGIN|END)\s+DECLARE\s+SECTION\b", body, re.I):
                continue
            query_blocks.append(body)
        jobs.extend((file_index, block_index, body) for block_index, body in enumerate(query_blocks))
    except (OSError, subprocess.TimeoutExpired):
        failures += 1
        failure_reasons["io_or_timeout"] += 1

def contains(stmt, cap):
    return stmt[0] <= cap[0] and cap[1] <= stmt[1]

def fixed_format_block(body):
    body = re.sub(r"'(?:''|[^'])*'", "'X'", body)
    tokens = re.findall(r'"(?:""|[^"])*"|\S+', body)
    lines = []
    current = "EXEC SQL"
    for token in tokens:
        if len(current) + 1 + len(token) > 52:
            lines.append("           " + current)
            current = token
        else:
            current += " " + token
    if current:
        lines.append("           " + current)
    lines.append("           END-EXEC.")
    return "\n".join(lines)

def prepare_block(job):
    file_index, block_index, body = job
    kind_match = kind_re.match(body)
    kind = kind_match.group(1).upper() if kind_match else "OTHER"
    body_ctes = {name.upper() for name in cte_re.findall(body)}
    block_expected = sum(1 for name in expected_tables(body, kind) if name.upper() not in body_ctes)
    isolated_source = (
        "       identification division.\n"
        "       program-id. census.\n"
        "       procedure division.\n"
        + fixed_format_block(body) + "\n"
    )
    isolated_path = pathlib.Path(scratch) / f"input-{file_index}-{block_index}.cbl"
    isolated_path.write_text(isolated_source, encoding="utf-8")
    return isolated_path, isolated_source, body, kind, block_expected

prepared = [prepare_block(job) for job in jobs]
parsed_results = []
for offset in range(0, len(prepared), 96):
    batch = prepared[offset:offset + 96]
    try:
        queried = subprocess.run(
            [tree_sitter, "query", str(scratch_query), *(str(item[0]) for item in batch)], cwd=top_dir,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
            timeout=timeout_s,
        )
        if queried.returncode != 0:
            failures += len(batch)
            failure_reasons["query_status"] += len(batch)
            continue
        sections = re.split(r"(?m)^(?=" + re.escape(str(pathlib.Path(scratch))) + r"/input-)", queried.stdout)
        output_by_name = {}
        for section in sections:
            first = section.splitlines()[0] if section.splitlines() else ""
            if first.endswith(".cbl"):
                output_by_name[pathlib.Path(first).name] = section
        for isolated_path, isolated_source, body, kind, block_expected in batch:
            parsed_results.append((isolated_path, isolated_source, body, kind, block_expected, output_by_name.get(isolated_path.name, "")))
    except (OSError, subprocess.TimeoutExpired):
        failures += len(batch)
        failure_reasons["io_or_timeout"] += len(batch)

results = []
for isolated_path, isolated_source, body, kind, block_expected, query_output in parsed_results:
    try:
        lines = isolated_source.splitlines()
        captures = []
        for raw in query_output.splitlines():
            match = capture_re.search(raw)
            if not match:
                continue
            role = match.group(1)
            start = (int(match.group(2)), int(match.group(3)))
            end = (int(match.group(4)), int(match.group(5)))
            if start[0] == end[0]:
                text = lines[start[0]][start[1]:end[1]]
            else:
                text = " ".join([lines[start[0]][start[1]:], *lines[start[0] + 1:end[0]], lines[end[0]][:end[1]]])
            captures.append((role, start, end, text))
        statements = [c for c in captures if c[0] == "statement"]
        if not statements:
            punctuation = collections.Counter(ch for ch in body if not ch.isalnum() and not ch.isspace() and ch not in "-_.,:()=><+*!\"'")
            results.append(((kind, block_expected, 0, 0, [], punctuation, True), None))
            continue
        stmt = statements[0]
        ctes = {c[3].split()[0].upper() for c in captures if c[0] == "cte_definition" and contains((stmt[1], stmt[2]), (c[1], c[2]))}
        tables = [c[3].upper() for c in captures if c[0] == "table" and contains((stmt[1], stmt[2]), (c[1], c[2]))]
        tails = sum(1 for c in captures if c[0] == "tail" and contains((stmt[1], stmt[2]), (c[1], c[2])))
        results.append(((kind, block_expected, sum(1 for name in tables if name not in ctes), tails, tables, collections.Counter(), False), None))
    except (OSError, subprocess.TimeoutExpired):
        results.append((None, "io_or_timeout"))

drop_pending = bool(drop)
unsupported_punctuation = collections.Counter()
missing_containers = collections.Counter()
missing_expected_tables = collections.Counter()
block_deltas = collections.Counter()
for result, reason in results:
    if reason:
        failures += 1
        failure_reasons[reason] += 1
        continue
    kind, expected, captured, tails, tables, punctuation, missing_container = result
    unsupported_punctuation.update(punctuation)
    if missing_container:
        missing_containers[kind] += 1
        missing_expected_tables[kind] += expected
    if expected != captured:
        block_deltas[(kind, expected, captured)] += 1
    if drop_pending and tables:
        captured -= 1
        drop_pending = False
    stats[kind]["captured"] += captured
    stats[kind]["tails"] += tails

if failures:
    reasons = ",".join(f"{name}={count}" for name, count in sorted(failure_reasons.items()))
    print(f"census: FAIL - failures={failures} reasons={reasons}", file=sys.stderr)
    sys.exit(1)

mismatches = [kind for kind in categories if stats[kind]["expected"] != stats[kind]["captured"]]
if mismatches:
    detail = ", ".join(f"{kind} expected={stats[kind]['expected']} captured={stats[kind]['captured']}" for kind in mismatches)
    if population == "DIAGNOSTIC" and unsupported_punctuation:
        chars = ",".join(f"U+{ord(ch):04X}={count}" for ch, count in sorted(unsupported_punctuation.items()))
        detail += f"; unsupported_punctuation={chars}"
    if population == "DIAGNOSTIC" and missing_containers:
        containers = ",".join(f"{name}={count}" for name, count in sorted(missing_containers.items()))
        detail += f"; missing_containers={containers}"
        missing_tables = ",".join(f"{name}={count}" for name, count in sorted(missing_expected_tables.items()))
        detail += f"; missing_expected_tables={missing_tables}"
    if population == "DIAGNOSTIC" and block_deltas:
        deltas = ",".join(f"{kind}:{expected}->{captured}={count}" for (kind, expected, captured), count in sorted(block_deltas.items()))
        detail += f"; block_deltas={deltas}"
    print(f"census: FAIL - {detail}", file=sys.stderr)
    sys.exit(1)

with open(output, "w", encoding="ascii") as out:
    out.write("population\tcategory\tstatements\ttails\texpected_tables\tcaptured_tables\n")
    for kind in categories:
        row = stats[kind]
        out.write(f"{population}\t{kind}\t{row['statements']}\t{row['tails']}\t{row['expected']}\t{row['captured']}\n")
PY
    STATUS=$?
    rm -rf "$SCRATCH"
    return "$STATUS"
}

render_report() {
    DEST=$1
    shift
    {
        printf '# EXEC SQL Tail Census\n\n'
        printf 'SQL-05 remains retired. This census is aggregate accounting, not a replacement recall metric.\n\n'
        printf '| Population | Category | Statements | Tails | Expected tables | Captured tables |\n'
        printf '|------------|----------|------------|-------|-----------------|-----------------|\n'
        for TSV in "$@"; do
            awk -F '\t' 'NR>1 {printf "| %s | %s | %s | %s | %s | %s |\n",$1,$2,$3,$4,$5,$6}' "$TSV"
        done
    } > "$DEST"
}

case "$1" in
    --selftest)
        ROOT=$(mktemp -d)
        OUT=$(mktemp)
        mkdir -p "$ROOT/corpus"
        printf '%s\n' '       identification division.' '       program-id. t.' '       procedure division.' '       EXEC SQL SELECT ID FROM APP.TEST END-EXEC.' > "$ROOT/corpus/test.cbl"
        run_census SELFTEST "$ROOT/corpus" "$OUT"
        GOOD=$?
        run_census SELFTEST "$ROOT/corpus" "$OUT" drop-one >/dev/null 2>&1
        BAD=$?
        rm -rf "$ROOT" "$OUT"
        if [ "$GOOD" -eq 0 ] && [ "$BAD" -ne 0 ]; then report "selftest: PASS"; exit 0; fi
        report "selftest: FAIL - success=$GOOD missing-capture=$BAD"
        exit 1
        ;;
    --population)
        POPULATION=$2; shift 2
        [ "$1" = "--corpus" ] || exit 2; CORPUS=$2; shift 2
        [ "$1" = "--output" ] || exit 2; OUTPUT=$2
        run_census "$POPULATION" "$CORPUS" "$OUTPUT"
        exit $?
        ;;
    --render)
        shift
        ARGS=""
        while [ $# -gt 1 ]; do ARGS="$ARGS $1"; shift; done
        # shellcheck disable=SC2086
        render_report "$1" $ARGS
        exit $?
        ;;
    --verify-report)
        test -s "$2" && grep -q '^| OCESQL ' "$2" && grep -q 'SQL-05 remains retired' "$2"
        exit $?
        ;;
    *)
        report "usage: $0 --selftest | --population LABEL --corpus DIR --output FILE | --render TSV... DOC | --verify-report DOC"
        exit 2
        ;;
esac
