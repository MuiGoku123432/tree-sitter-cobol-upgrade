#!/bin/bash
# run_accept_differential.sh
#
# ACCEPT before/after differential (D-07/D-08, IDMS-03). This is what
# empirically proves the "provably unaffected" gate: every node that was a
# CLEAN accept_statement before a grammar change is still accept_statement
# after -- zero reclassifications, a hard gate. Fork-local (never enters the
# separable grammar commit, FORK-03) and re-runnable, matching
# run_nist_cobol85.sh's convention of a shell script committed at repo root.
# Deliberately NOT wired into pre-push (D-08): a full estate parse is far too
# slow for that choke point, and a sampled gate would be a weaker guarantee
# than this manual, full, re-runnable one. Invoke it manually at the end of
# each verb family's work.
#
# Three sub-commands:
#
#   snapshot <CORPUS_DIR> <OUT_FILE> [NODE_TYPE_REGEX]
#       Walks every *.cbl/*.CBL and extensionless regular file under
#       CORPUS_DIR, runs $TREE_SITTER parse on each, and writes one
#       tab-separated inventory record per node whose
#       type matches NODE_TYPE_REGEX (default: accept_statement|idms_accept_statement):
#           <relative-path>\t<startRow>,<startCol>\t<node-type>\t<qualifier>
#       qualifier is "clean" or "trailing_error", derived from tree-sitter
#       parse's own printed s-expression tree: a record is "trailing_error"
#       when an (ERROR ...) node BEGINS on the same source row on which the
#       matched node ENDS, "clean" otherwise. This is a same-row heuristic --
#       it rests on IDMS DML being written one statement per source line,
#       exactly the assumption gortex's own reDML regex ([^.]*\.) already
#       relies on successfully across all 606 DCC .cbl files (see
#       ~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/neutralize_test.go:24).
#       Output is sorted (by the whole line, so path then position) so
#       `compare` can rely on both inventories being in the same collation
#       order. Files that emit no tree are counted separately from files whose
#       emitted tree contains parse errors, and both are reported separately
#       from files that yield zero matching-type records. Error-bearing trees
#       are still inventoried because the trailing_error qualifier depends on
#       them; silently dropping them would make the gate unsatisfiable.
#       NODE_TYPE_REGEX exists so a later plan (02-06) can reuse this same
#       tool for an idms_unparsed_tail census rather than a second
#       corpus-scanning harness (PROJECT.md forbids a parallel one).
#       Estate guard (T-02-02): refuses to write OUT_FILE if its resolved
#       absolute path is under this repository's root -- corpus paths are
#       proprietary, and an inventory landing inside the working tree is one
#       `git add -A` away from the public remote. Never reads corpus
#       *content* into itself; only ever passes paths to $TREE_SITTER,
#       exactly as run_nist_cobol85.sh does with test/cobol85/src.
#
#   compare <BEFORE_FILE> <AFTER_FILE>
#       Joins the two inventories on path + position and reports: total
#       before/after record counts, accept_statement/idms_accept_statement
#       counts in each, and the before clean/trailing_error split. Computes
#       two SEPARATE tallies, never summed into one:
#         RECLASSIFIED_COUNT -- records whose before-type is
#           accept_statement with a CLEAN qualifier and whose after-type is
#           anything other than accept_statement, including absent. Prints
#           every offending record. Drives the exit code: compare exits 1
#           when this is > 0.
#         CONVERTED_COUNT -- records whose before-type is accept_statement
#           with a TRAILING_ERROR qualifier and whose after-type is
#           idms_accept_statement. Reported as a count and never fails the
#           gate -- this is the ~634-shaped conversion D-07 expects.
#       A record present only in the after-inventory is NEW_COUNT: neither
#       reclassified nor converted.
#       When both inventories are empty, the summary states explicitly that
#       zero records were compared, rather than emitting a bare PASS.
#
#   run <BASELINE_REF> <CORPUS_DIR> [NODE_TYPE_REGEX] [TEXT_PREFILTER_RE|--no-prefilter]
#       Orchestrates the two: creates a throwaway `git worktree` at
#       BASELINE_REF and compares the caller-selected node set. The optional
#       NODE_TYPE_REGEX is a bare alternation with no anchors or surrounding
#       group; run wraps it exactly once as ^(<regex>)$ for each helper. The
#       distinct TEXT_PREFILTER_RE selects source files before parsing;
#       --no-prefilter selects every discovered source file. Omission retains
#       the byte-for-byte ACCEPT prefilter used by earlier phases.
#       BASELINE_REF under $DIFF_TMP, generates its parser sources, compiles
#       one private inventory helper for each parser revision, snapshots the
#       selected source-file set with both helpers, compares
#       the inventories, then removes every script-owned artifact. The C
#       helper walks only node kinds and source positions in memory; it never
#       writes source text or renders full ASTs. This keeps the differ
#       re-runnable for Phases 3-4 and after any upstream pull.
#
# Env overrides (matching forest-shim/refresh.sh's convention):
#   TREE_SITTER   path to the pinned CLI (default: node_modules/.bin/tree-sitter)
#   DIFF_TMP      scratch dir for `run`'s worktree (default: mktemp -d,
#                 always outside the repository -- see the estate guard
#                 above; the same refusal applies to DIFF_TMP itself)
#   CORPUS_DIR    default corpus for `run` when not given as an argument
#   BASELINE_REF  default baseline ref for `run` when not given as an
#                 argument
#   PARSE_TIMEOUT_US per-file tree-sitter deadline in microseconds (default:
#                    5000000)
#   PARSE_WALL_TIMEOUT_SECONDS external per-file wall-clock deadline (default: 15)
#   BUILD_WALL_TIMEOUT_SECONDS helper compilation deadline (default: 120)
#   BATCH_WALL_TIMEOUT_SECONDS whole helper snapshot deadline (default: 1800)
#   TREE_SITTER_RUNTIME_DIR tree-sitter v0.25 runtime source root; defaults
#                           to the existing Go module cache entry
#   WALL_TIMEOUT_BIN GNU timeout command (default: timeout)
#
# House style (matches run_nist_cobol85.sh / forest-shim/refresh.sh): no
# `set -e`/`set -u` anywhere in this repo's shell scripts -- every command
# that can fail is followed by an explicit $? check. Integer counters
# accumulate a result; the exit code is driven by the counter, not by the
# last command run.
#
# Deliberate omission: unlike run_nist_cobol85.sh's tee'd summary file, this
# script writes NO default log file. Its own report lines can contain
# corpus-derived relative paths (proprietary), so tee-ing them to a fixed
# path inside this repository would recreate the exact leak T-02-02 guards
# against. Output goes to stdout only; redirect it yourself if you need a
# copy, and keep that redirect target outside the working tree.

TOP_DIR=$(cd -P "$(dirname "$0")" && pwd)
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/.bin/tree-sitter}
DIFF_TMP=${DIFF_TMP:-}
CORPUS_DIR=${CORPUS_DIR:-}
BASELINE_REF=${BASELINE_REF:-}
PARSE_TIMEOUT_US=${PARSE_TIMEOUT_US:-5000000}
PARSE_WALL_TIMEOUT_SECONDS=${PARSE_WALL_TIMEOUT_SECONDS:-15}
BUILD_WALL_TIMEOUT_SECONDS=${BUILD_WALL_TIMEOUT_SECONDS:-120}
BATCH_WALL_TIMEOUT_SECONDS=${BATCH_WALL_TIMEOUT_SECONDS:-1800}
WALL_TIMEOUT_BIN=${WALL_TIMEOUT_BIN:-timeout}
DEFAULT_NODE_TYPE_REGEX='accept_statement|idms_accept_statement'
DEFAULT_TEXT_PREFILTER_RE='(^|[^A-Za-z0-9-])ACCEPT([^A-Za-z0-9-]|$)'

# Overridden by cmd_run around each isolated snapshot. Standalone snapshots
# use the caller's normal parser cache and release build.
SNAPSHOT_INVOKE_DIR="$TOP_DIR"
SNAPSHOT_TREE_SITTER_BIN="$TREE_SITTER"
SNAPSHOT_TREE_SITTER_LIBDIR=""

report() {
    printf '%s\n' "$1"
}

cleanup_parser_libdirs() {
    for CACHE_DIR in "${BASELINE_LIBDIR:-}" "${CURRENT_LIBDIR:-}"; do
        if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
            find "$CACHE_DIR" -depth -delete >/dev/null 2>&1
        fi
    done
}

usage() {
    report "usage: run_accept_differential.sh snapshot <CORPUS_DIR> <OUT_FILE> [NODE_TYPE_REGEX]"
    report "       run_accept_differential.sh compare <BEFORE_FILE> <AFTER_FILE>"
    report "       run_accept_differential.sh run <BASELINE_REF> <CORPUS_DIR> [NODE_TYPE_REGEX] [TEXT_PREFILTER_RE|--no-prefilter]"
    report "       NODE_TYPE_REGEX is a bare alternation; run adds ^(...)$ exactly once"
    report "       TEXT_PREFILTER_RE is distinct from NODE_TYPE_REGEX; omit it for the default ACCEPT prefilter"
}

# ---------------------------------------------------------------------------
# Estate guard (T-02-02): refuse a write target that resolves under this
# repository's root. Existing final components and directories are resolved
# strictly through symlinks. A new file is accepted only after its existing
# parent is resolved strictly. Return 2 when containment cannot be proved.
# ---------------------------------------------------------------------------
path_is_under_repo() {
    CANDIDATE="$1"
    CANDIDATE_KIND="${2:-file}"
    python3 - "$TOP_DIR" "$CANDIDATE" "$CANDIDATE_KIND" <<'PY'
import os
import pathlib
import sys

repo_arg, candidate_arg, kind = sys.argv[1:]
try:
    repo = pathlib.Path(repo_arg).resolve(strict=True)
    candidate = pathlib.Path(candidate_arg)
    if kind == "dir":
        resolved = candidate.resolve(strict=True)
        if not resolved.is_dir():
            raise NotADirectoryError(candidate)
    elif kind == "file":
        if candidate.exists() or candidate.is_symlink():
            resolved = candidate.resolve(strict=True)
        else:
            parent = candidate.parent.resolve(strict=True)
            if not parent.is_dir():
                raise NotADirectoryError(parent)
            resolved = parent / candidate.name
    else:
        raise ValueError(f"unsupported candidate kind: {kind}")
    under_repo = os.path.commonpath((str(repo), str(resolved))) == str(repo)
except (OSError, RuntimeError, ValueError):
    sys.exit(2)
sys.exit(0 if under_repo else 1)
PY
}

# ---------------------------------------------------------------------------
# snapshot <CORPUS_DIR> <OUT_FILE> [NODE_TYPE_REGEX]
# ---------------------------------------------------------------------------
cmd_snapshot() {
    SNAP_CORPUS_DIR="$1"
    SNAP_OUT_FILE="$2"
    SNAP_NODE_TYPE_REGEX="${3:-$DEFAULT_NODE_TYPE_REGEX}"

    if [ -z "$SNAP_CORPUS_DIR" ] || [ -z "$SNAP_OUT_FILE" ]; then
        report "snapshot: usage: snapshot <CORPUS_DIR> <OUT_FILE> [NODE_TYPE_REGEX]"
        return 1
    fi
    if [ ! -d "$SNAP_CORPUS_DIR" ]; then
        report "snapshot: FAIL - corpus directory not found: $SNAP_CORPUS_DIR"
        return 1
    fi
    if ! command -v "$WALL_TIMEOUT_BIN" >/dev/null 2>&1; then
        report "snapshot: FAIL - wall-clock timeout command not found: $WALL_TIMEOUT_BIN"
        return 1
    fi
    path_is_under_repo "$SNAP_OUT_FILE" file
    SNAP_PATH_STATUS=$?
    if [ "$SNAP_PATH_STATUS" -eq 0 ]; then
        report "snapshot: REFUSED - output path resolves under the repository root ($TOP_DIR); corpus-derived inventories must never be written inside the working tree (T-02-02)"
        return 1
    fi
    if [ "$SNAP_PATH_STATUS" -ne 1 ]; then
        report "snapshot: REFUSED - output path could not be canonicalized safely"
        return 1
    fi

    SNAP_CORPUS_DIR_ABS=$(cd -P "$SNAP_CORPUS_DIR" && pwd)
    if [ -z "$SNAP_CORPUS_DIR_ABS" ]; then
        report "snapshot: FAIL - could not resolve corpus directory to an absolute path: $SNAP_CORPUS_DIR"
        return 1
    fi

    SNAP_ACCUM="$(mktemp)"
    if [ $? -ne 0 ] || [ -z "$SNAP_ACCUM" ]; then
        report "snapshot: FAIL - could not create a scratch file"
        return 1
    fi
    : > "$SNAP_ACCUM"
    if [ $? -ne 0 ]; then
        report "snapshot: FAIL - could not initialize scratch inventory"
        rm -f "$SNAP_ACCUM"
        return 1
    fi

    SNAP_FILELIST="$(mktemp)"
    if [ $? -ne 0 ] || [ -z "$SNAP_FILELIST" ]; then
        report "snapshot: FAIL - could not create a scratch file list"
        rm -f "$SNAP_ACCUM"
        return 1
    fi
    find "$SNAP_CORPUS_DIR_ABS" -type f \( -name '*.cbl' -o -name '*.CBL' -o ! -name '*.*' \) -print0 > "$SNAP_FILELIST" 2>/dev/null
    if [ $? -ne 0 ]; then
        report "snapshot: FAIL - could not enumerate *.cbl/*.CBL/extensionless files under $SNAP_CORPUS_DIR_ABS"
        rm -f "$SNAP_ACCUM" "$SNAP_FILELIST"
        return 1
    fi
    if [ ! -s "$SNAP_FILELIST" ]; then
        report "snapshot: FAIL - zero source files found; refusing an empty denominator"
        rm -f "$SNAP_ACCUM" "$SNAP_FILELIST"
        return 1
    fi

    FILES_DISCOVERED=$(tr -cd '\000' < "$SNAP_FILELIST" | wc -c | tr -d ' ')
    FILES_PREFILTER_FAILED=0
    if [ "$SNAP_NODE_TYPE_REGEX" = "$DEFAULT_NODE_TYPE_REGEX" ]; then
        SNAP_SELECTED_FILELIST="$(mktemp)"
        if [ $? -ne 0 ] || [ -z "$SNAP_SELECTED_FILELIST" ]; then
            report "snapshot: FAIL - could not create an ACCEPT prefilter file list"
            rm -f "$SNAP_ACCUM" "$SNAP_FILELIST"
            return 1
        fi
        : > "$SNAP_SELECTED_FILELIST"
        while IFS= read -r -d '' FILE; do
            LC_ALL=C grep -Eiq '(^|[^A-Za-z0-9-])ACCEPT([^A-Za-z0-9-]|$)' "$FILE"
            PREFILTER_STATUS=$?
            if [ "$PREFILTER_STATUS" -eq 0 ]; then
                printf '%s\0' "$FILE" >> "$SNAP_SELECTED_FILELIST"
            elif [ "$PREFILTER_STATUS" -ne 1 ]; then
                FILES_PREFILTER_FAILED=$((FILES_PREFILTER_FAILED + 1))
            fi
        done < "$SNAP_FILELIST"
        rm -f "$SNAP_FILELIST"
        SNAP_FILELIST="$SNAP_SELECTED_FILELIST"
    fi
    FILES_SELECTED=$(tr -cd '\000' < "$SNAP_FILELIST" | wc -c | tr -d ' ')
    report "snapshot: discovered_files=$FILES_DISCOVERED selected_files=$FILES_SELECTED prefilter_failures=$FILES_PREFILTER_FAILED"
    if [ "$SNAP_NODE_TYPE_REGEX" = "$DEFAULT_NODE_TYPE_REGEX" ] && [ "$FILES_SELECTED" -eq 0 ]; then
        report "snapshot: FAIL - ACCEPT prefilter selected zero files; refusing an empty comparison denominator"
        rm -f "$SNAP_ACCUM" "$SNAP_FILELIST"
        return 1
    fi

    FILES_TOTAL=0
    FILES_FAILED=0
    FILES_WITH_PARSE_ERRORS=0
    FILES_TIMED_OUT=0
    FILES_ZERO_MATCH=0
    RECORDS_TOTAL=0

    NODE_LINE_RE='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*: )?\(('"$SNAP_NODE_TYPE_REGEX"'|ERROR) \[[0-9]+, [0-9]+\] - \[[0-9]+, [0-9]+\]'
    EXTRACT_SED='s/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*: )?\(([A-Za-z_][A-Za-z0-9_]*) \[([0-9]+), ([0-9]+)\] - \[([0-9]+), ([0-9]+)\].*/\2\t\3\t\4\t\5\t\6/'

    if [ -n "$SNAPSHOT_TREE_SITTER_LIBDIR" ]; then
        SNAP_BATCH_PATHS="$(mktemp)"
        SNAP_REL_PATHS="$(mktemp)"
        SNAP_BATCH_STATS="$(mktemp)"
        SNAP_BATCH_PIPE="$(mktemp)"
        if [ $? -ne 0 ] || [ -z "$SNAP_BATCH_PATHS" ] || [ -z "$SNAP_REL_PATHS" ] || [ -z "$SNAP_BATCH_STATS" ] || [ -z "$SNAP_BATCH_PIPE" ]; then
            report "snapshot: FAIL - could not create batch-parser scratch paths"
            rm -f "$SNAP_ACCUM" "$SNAP_FILELIST" "$SNAP_BATCH_PATHS" "$SNAP_REL_PATHS" "$SNAP_BATCH_STATS" "$SNAP_BATCH_PIPE"
            return 1
        fi
        rm -f "$SNAP_BATCH_PIPE"
        mkfifo "$SNAP_BATCH_PIPE"
        if [ $? -ne 0 ]; then
            report "snapshot: FAIL - could not create batch-parser stream"
            rm -f "$SNAP_ACCUM" "$SNAP_FILELIST" "$SNAP_BATCH_PATHS" "$SNAP_REL_PATHS" "$SNAP_BATCH_STATS"
            return 1
        fi

        while IFS= read -r -d '' FILE; do
            printf '%s\n' "$FILE" >> "$SNAP_BATCH_PATHS"
            printf '%s\n' "${FILE#$SNAP_CORPUS_DIR_ABS/}" >> "$SNAP_REL_PATHS"
        done < "$SNAP_FILELIST"
        rm -f "$SNAP_FILELIST"

        (cd "$SNAPSHOT_INVOKE_DIR" && "$WALL_TIMEOUT_BIN" -k 5s "${BATCH_WALL_TIMEOUT_SECONDS}s" env TREE_SITTER_LIBDIR="$SNAPSHOT_TREE_SITTER_LIBDIR" "$SNAPSHOT_TREE_SITTER_BIN" parse -0 --timeout "$PARSE_TIMEOUT_US" -t --paths "$SNAP_BATCH_PATHS" > "$SNAP_BATCH_PIPE" 2>/dev/null) &
        SNAP_BATCH_PID=$!

        awk -v selected="$FILES_SELECTED" -v stats="$SNAP_BATCH_STATS" '
            FILENAME == ARGV[1] {
                rel[++rel_count] = $0
                next
            }
            function clear_file(k) {
                for (k in err) delete err[k]
                for (k in rec_type) delete rec_type[k]
                for (k in rec_row) delete rec_row[k]
                for (k in rec_col) delete rec_col[k]
                for (k in rec_end_row) delete rec_end_row[k]
                rec_count = 0
                saw_error = 0
                timed_out = 0
            }
            function flush_file(i, qual) {
                file_count++
                if (timed_out) {
                    timed_out_count++
                    failed_count++
                } else {
                    if (saw_error) parse_error_count++
                    if (rec_count == 0) {
                        zero_match_count++
                    } else {
                        for (i = 1; i <= rec_count; i++) {
                            qual = (rec_end_row[i] in err) ? "trailing_error" : "clean"
                            print rel[file_count] "\t" rec_row[i] "," rec_col[i] "\t" rec_type[i] "\t" qual
                            record_count++
                        }
                    }
                }
                if (file_count % 1000 == 0) {
                    printf "snapshot: progress files_walked=%d files_failed_to_emit_tree=%d files_timed_out=%d files_with_parse_errors=%d records_found=%d\n", file_count, failed_count, timed_out_count, parse_error_count, record_count > "/dev/stderr"
                }
                clear_file()
            }
            /\t[[:space:]]*[0-9.]+ ms/ {
                if ($0 ~ /\(timed out\)$/) timed_out = 1
                if ($0 ~ /\t\((ERROR|MISSING)/) saw_error = 1
                flush_file()
                next
            }
            /^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*: )?\((accept_statement|idms_accept_statement|ERROR) \[[0-9]+, [0-9]+\] - \[[0-9]+, [0-9]+\]/ {
                line = $0
                sub(/^[[:space:]]*/, "", line)
                sub(/^[A-Za-z_][A-Za-z0-9_]*: /, "", line)
                sub(/^\(/, "", line)
                type = line
                sub(/ .*/, "", type)
                coords = line
                sub(/^[^[]*\[/, "", coords)
                gsub(/\] - \[/, ",", coords)
                sub(/\].*$/, "", coords)
                gsub(/[[:space:]]/, "", coords)
                split(coords, point, ",")
                if (type == "ERROR") {
                    err[point[1]] = 1
                    saw_error = 1
                } else {
                    rec_count++
                    rec_type[rec_count] = type
                    rec_row[rec_count] = point[1]
                    rec_col[rec_count] = point[2]
                    rec_end_row[rec_count] = point[3]
                }
            }
            END {
                if (file_count < selected) failed_count += selected - file_count
                printf "%d %d %d %d %d %d\n", file_count + 0, failed_count + 0, timed_out_count + 0, parse_error_count + 0, zero_match_count + 0, record_count + 0 > stats
            }
        ' "$SNAP_REL_PATHS" "$SNAP_BATCH_PIPE" > "$SNAP_ACCUM"
        SNAP_REDUCER_STATUS=$?
        wait "$SNAP_BATCH_PID"
        SNAP_BATCH_STATUS=$?
        rm -f "$SNAP_BATCH_PIPE" "$SNAP_BATCH_PATHS" "$SNAP_REL_PATHS"

        if [ "$SNAP_REDUCER_STATUS" -ne 0 ] || [ ! -s "$SNAP_BATCH_STATS" ]; then
            report "snapshot: FAIL - batch-parser reducer failed"
            rm -f "$SNAP_ACCUM" "$SNAP_BATCH_STATS"
            return 1
        fi
        read FILES_TOTAL FILES_FAILED FILES_TIMED_OUT FILES_WITH_PARSE_ERRORS FILES_ZERO_MATCH RECORDS_TOTAL < "$SNAP_BATCH_STATS"
        rm -f "$SNAP_BATCH_STATS"
        if [ "$SNAP_BATCH_STATUS" -ne 0 ] && [ "$SNAP_BATCH_STATUS" -ne 1 ]; then
            report "snapshot: FAIL - batch parser failed or exceeded its wall-clock limit (status=$SNAP_BATCH_STATUS)"
            rm -f "$SNAP_ACCUM"
            return 1
        fi
    else
        while IFS= read -r -d '' FILE; do
            FILES_TOTAL=$((FILES_TOTAL + 1))
            REL_PATH="${FILE#$SNAP_CORPUS_DIR_ABS/}"

            PARSE_OUT="$(cd "$SNAPSHOT_INVOKE_DIR" && "$WALL_TIMEOUT_BIN" -k 1s "${PARSE_WALL_TIMEOUT_SECONDS}s" "$SNAPSHOT_TREE_SITTER_BIN" parse --timeout "$PARSE_TIMEOUT_US" "$FILE" 2>/dev/null)"
            PARSE_STATUS=$?
            if [ "$PARSE_STATUS" -eq 124 ] || [ "$PARSE_STATUS" -eq 137 ]; then
                FILES_TIMED_OUT=$((FILES_TIMED_OUT + 1))
                FILES_FAILED=$((FILES_FAILED + 1))
                continue
            fi
            if [ -z "$PARSE_OUT" ]; then
                FILES_FAILED=$((FILES_FAILED + 1))
                continue
            fi
            if [ "$PARSE_STATUS" -ne 0 ]; then
                FILES_WITH_PARSE_ERRORS=$((FILES_WITH_PARSE_ERRORS + 1))
            fi

            FILE_RECORDS="$(printf '%s\n' "$PARSE_OUT" | grep -E "$NODE_LINE_RE" | sed -E "$EXTRACT_SED")"
            if [ -z "$FILE_RECORDS" ]; then
                FILES_ZERO_MATCH=$((FILES_ZERO_MATCH + 1))
                continue
            fi

            FILE_RECORDS_TMP="$(mktemp)"
            if [ $? -ne 0 ] || [ -z "$FILE_RECORDS_TMP" ]; then
                report "snapshot: FAIL - could not create a per-file scratch inventory"
                rm -f "$SNAP_ACCUM" "$SNAP_FILELIST"
                return 1
            fi
            printf '%s\n' "$FILE_RECORDS" > "$FILE_RECORDS_TMP"
            FILE_OUT="$(awk -F'\t' -v relpath="$REL_PATH" '
                NR==FNR { if ($1 == "ERROR") err[$2] = 1; next }
                $1 != "ERROR" {
                    qual = ($4 in err) ? "trailing_error" : "clean"
                    print relpath "\t" $2 "," $3 "\t" $1 "\t" qual
                }
            ' "$FILE_RECORDS_TMP" "$FILE_RECORDS_TMP")"
            rm -f "$FILE_RECORDS_TMP"

            if [ -z "$FILE_OUT" ]; then
                FILES_ZERO_MATCH=$((FILES_ZERO_MATCH + 1))
                continue
            fi
            printf '%s\n' "$FILE_OUT" >> "$SNAP_ACCUM"
            FILE_RECORD_COUNT=$(printf '%s\n' "$FILE_OUT" | grep -c '.')
            RECORDS_TOTAL=$((RECORDS_TOTAL + FILE_RECORD_COUNT))
        done < "$SNAP_FILELIST"
        rm -f "$SNAP_FILELIST"
    fi

    sort "$SNAP_ACCUM" > "$SNAP_OUT_FILE"
    if [ $? -ne 0 ]; then
        report "snapshot: FAIL - could not write $SNAP_OUT_FILE"
        rm -f "$SNAP_ACCUM"
        return 1
    fi
    rm -f "$SNAP_ACCUM"
    if [ $? -ne 0 ]; then
        report "snapshot: FAIL - could not remove scratch inventory"
        return 1
    fi

    report "snapshot: corpus=$SNAP_CORPUS_DIR_ABS node_type_regex='$SNAP_NODE_TYPE_REGEX' out=$SNAP_OUT_FILE"
    report "snapshot: files_walked=$FILES_TOTAL files_failed_to_emit_tree=$FILES_FAILED files_timed_out=$FILES_TIMED_OUT files_with_parse_errors=$FILES_WITH_PARSE_ERRORS files_zero_match=$FILES_ZERO_MATCH records_written=$RECORDS_TOTAL"
    if [ "$FILES_PREFILTER_FAILED" -ne 0 ] || [ "$FILES_FAILED" -ne 0 ]; then
        report "snapshot: FAIL - incomplete denominator (prefilter_failures=$FILES_PREFILTER_FAILED files_failed_to_emit_tree=$FILES_FAILED)"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# compare <BEFORE_FILE> <AFTER_FILE>
# ---------------------------------------------------------------------------
cmd_compare() {
    CMP_BEFORE="$1"
    CMP_AFTER="$2"

    if [ -z "$CMP_BEFORE" ] || [ -z "$CMP_AFTER" ]; then
        report "compare: usage: compare <BEFORE_FILE> <AFTER_FILE>"
        return 1
    fi
    if [ ! -f "$CMP_BEFORE" ]; then
        report "compare: FAIL - before-inventory not found: $CMP_BEFORE"
        return 1
    fi
    if [ ! -f "$CMP_AFTER" ]; then
        report "compare: FAIL - after-inventory not found: $CMP_AFTER"
        return 1
    fi

    # Distinguish BEFORE vs AFTER by FILENAME, not the classic NR==FNR
    # trick: NR==FNR silently misidentifies the AFTER file's first line as
    # BEFORE input whenever BEFORE is empty (0 lines), since NR and FNR both
    # restart in lockstep at 1 for the very next file read. Case 5/6 in the
    # self-test (an empty before-inventory) is exactly the shape that trips
    # this.
    awk -F'\t' -v beforefile="$CMP_BEFORE" '
        FILENAME == beforefile {
            key = $1 SUBSEP $2
            btype[key] = $3
            bqual[key] = $4
            border[++bn] = key
            next
        }
        {
            key = $1 SUBSEP $2
            atype[key] = $3
            aorder[++an] = key
        }
        END {
            for (i = 1; i <= bn; i++) {
                k = border[i]
                t = btype[k]
                if (t == "accept_statement") before_accept++
                if (t == "idms_accept_statement") before_idms++
                if (bqual[k] == "clean") before_clean++
                if (bqual[k] == "trailing_error") before_trailing++
            }
            for (i = 1; i <= an; i++) {
                k = aorder[i]
                t = atype[k]
                if (t == "accept_statement") after_accept++
                if (t == "idms_accept_statement") after_idms++
            }

            reclassified = 0
            converted = 0
            for (i = 1; i <= bn; i++) {
                k = border[i]
                if (bqual[k] == "clean") {
                    if (!(k in atype) || atype[k] != btype[k]) {
                        reclassified++
                        split(k, parts, SUBSEP)
                        after_desc = (k in atype) ? atype[k] : "ABSENT"
                        print "RECLASSIFIED RECORD: " parts[1] ":" parts[2] " (before=" btype[k] "/clean, after=" after_desc ")"
                    }
                } else if (btype[k] == "accept_statement" && bqual[k] == "trailing_error") {
                    if ((k in atype) && atype[k] == "idms_accept_statement") {
                        converted++
                    }
                }
            }

            new_count = 0
            for (i = 1; i <= an; i++) {
                k = aorder[i]
                if (!(k in btype)) new_count++
            }

            if (bn == 0 && an == 0) {
                print "SUMMARY: zero records compared (before-inventory and after-inventory are both empty)"
            } else {
                printf "SUMMARY: before=%d after=%d before_accept_statement=%d before_idms_accept_statement=%d before_clean=%d before_trailing_error=%d after_accept_statement=%d after_idms_accept_statement=%d\n", \
                    bn, an, before_accept, before_idms, before_clean, before_trailing, after_accept, after_idms
            }
            printf "RECLASSIFIED_COUNT: %d\n", reclassified
            printf "CONVERTED_COUNT: %d\n", converted
            printf "NEW_COUNT: %d\n", new_count

            exit (reclassified > 0) ? 1 : 0
        }
    ' "$CMP_BEFORE" "$CMP_AFTER"
    return $?
}

prepare_accept_paths() {
    PREP_CORPUS_ROOT="$1"
    PREP_SELECTED_PATHS="$2"
    PREP_TEXT_PREFILTER_RE="${3:-$DEFAULT_TEXT_PREFILTER_RE}"
    PREP_CUSTOM_SELECTION="${4:-0}"
    : > "$PREP_SELECTED_PATHS"

    # Named estate branch: preserve the authoritative member/program checks,
    # but apply the recorded ACCEPT statement denominator only to the default
    # selection. Custom SQL/collision runs report their measured denominator.
    if [ "$PREP_CORPUS_ROOT" = "$TOP_DIR/estate" ] && [ -d "$PREP_CORPUS_ROOT/endevor" ]; then
        PREP_STATS="$(mktemp)"
        PREP_ESTATE_PREFILTER="$PREP_TEXT_PREFILTER_RE"
        [ "$PREP_CUSTOM_SELECTION" -eq 0 ] && PREP_ESTATE_PREFILTER="--default-accept-selection"
        python3 - "$PREP_CORPUS_ROOT" "$PREP_SELECTED_PATHS" "$PREP_STATS" "$PREP_ESTATE_PREFILTER" <<'PY'
import os
import re
import subprocess
import sys

root, selected_path, stats_path, prefilter = sys.argv[1:]
identification = re.compile(r"\bIDENTIFICATION\s+DIVISION\b", re.IGNORECASE)
procedure = re.compile(r"\bPROCEDURE\s+DIVISION\b", re.IGNORECASE)
members = programs = selected = statements = failures = 0

with open(selected_path, "wb") as selected_file:
    endevor = os.path.join(root, "endevor")
    for system in sorted(os.listdir(endevor)):
        system_path = os.path.join(endevor, system)
        if not os.path.isdir(system_path):
            continue
        for subsystem in sorted(os.listdir(system_path)):
            cobol_path = os.path.join(system_path, subsystem, "COBOL")
            if not os.path.isdir(cobol_path):
                continue
            for name in sorted(os.listdir(cobol_path)):
                path = os.path.join(cobol_path, name)
                if not os.path.isfile(path):
                    continue
                members += 1
                try:
                    raw = open(path, encoding="utf-8", errors="replace").read()
                except OSError:
                    failures += 1
                    continue
                if not (identification.search(raw) and procedure.search(raw)):
                    continue
                programs += 1
                code_lines = []
                for line in raw.splitlines():
                    if len(line) > 6 and line[6] in "*/":
                        continue
                    code = line[7:72] if len(line) > 7 else ""
                    if code.strip():
                        code_lines.append(code)
                if prefilter == "--default-accept-selection":
                    count = sum(1 for code in code_lines if re.match(r"^\s*ACCEPT\b", code))
                elif prefilter == "--no-prefilter":
                    count = len(code_lines)
                else:
                    matched = subprocess.run(
                        ["rg", "-i", "-c", "--", prefilter],
                        input="\n".join(code_lines), text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                    )
                    if matched.returncode not in (0, 1):
                        sys.exit(matched.returncode)
                    count = int(matched.stdout.strip() or "0")
                if count:
                    selected += 1
                    statements += count
                    selected_file.write(os.fsencode(path) + b"\0")

with open(stats_path, "w", encoding="ascii") as stats:
    stats.write(f"{members} {programs} {selected} {statements} {failures}\n")
PY
        PREP_STATUS=$?
        if [ "$PREP_STATUS" -ne 0 ] || [ ! -s "$PREP_STATS" ]; then
            report "run: FAIL - authoritative estate selector failed"
            rm -f "$PREP_STATS"
            return 1
        fi
        read PREP_MEMBERS PREP_PROGRAMS PREP_SELECTED PREP_STATEMENTS PREP_FAILURES < "$PREP_STATS"
        rm -f "$PREP_STATS"
        report "snapshot: estate selector declared_cobol_members=$PREP_MEMBERS compilable_programs=$PREP_PROGRAMS selected_files=$PREP_SELECTED statements=$PREP_STATEMENTS selection_failures=$PREP_FAILURES text_prefilter='$PREP_TEXT_PREFILTER_RE'"
        if [ "$PREP_FAILURES" -ne 0 ] || [ "$PREP_MEMBERS" -ne 3781 ] || [ "$PREP_PROGRAMS" -ne 1369 ]; then
            report "run: FAIL - estate structural population does not match the recorded 3781/1369 denominator"
            return 1
        fi
        if [ "$PREP_CUSTOM_SELECTION" -eq 0 ] && [ "$PREP_STATEMENTS" -ne 2391 ]; then
            report "run: FAIL - estate denominator does not match the recorded 3781/1369/2391 population"
            return 1
        fi
        if [ "$PREP_SELECTED" -eq 0 ]; then
            report "run: FAIL - text prefilter selected zero files; refusing an empty comparison denominator"
            return 1
        fi
        if [ "$PREP_CUSTOM_SELECTION" -eq 1 ]; then
            report "snapshot: estate selector: custom selection recorded denominator selected_files=$PREP_SELECTED statements=$PREP_STATEMENTS"
        fi
        return 0
    fi

    PREP_ALL_PATHS="$(mktemp)"
    PREP_RG_PATHS="$(mktemp)"
    if [ $? -ne 0 ] || [ -z "$PREP_ALL_PATHS" ] || [ -z "$PREP_RG_PATHS" ]; then
        report "run: FAIL - could not create corpus-selection scratch files"
        rm -f "$PREP_ALL_PATHS" "$PREP_RG_PATHS"
        return 1
    fi
    find "$PREP_CORPUS_ROOT" -type f \( -name '*.cbl' -o -name '*.CBL' -o ! -name '*.*' \) -print0 > "$PREP_ALL_PATHS" 2>/dev/null
    if [ $? -ne 0 ]; then
        report "run: FAIL - could not enumerate corpus source files"
        rm -f "$PREP_ALL_PATHS" "$PREP_RG_PATHS"
        return 1
    fi
    PREP_DISCOVERED=$(tr -cd '\000' < "$PREP_ALL_PATHS" | wc -c | tr -d ' ')
    if [ "$PREP_DISCOVERED" -eq 0 ]; then
        report "run: FAIL - zero source files found; refusing an empty denominator"
        rm -f "$PREP_ALL_PATHS" "$PREP_RG_PATHS"
        return 1
    fi

    if [ "$PREP_TEXT_PREFILTER_RE" = "--no-prefilter" ]; then
        cp "$PREP_ALL_PATHS" "$PREP_SELECTED_PATHS"
        PREP_SELECT_STATUS=$?
    else
        rg -l -0 -a --no-ignore -i -- "$PREP_TEXT_PREFILTER_RE" "$PREP_CORPUS_ROOT" > "$PREP_RG_PATHS" 2>/dev/null
        PREP_SELECT_STATUS=$?
        if [ "$PREP_SELECT_STATUS" -eq 0 ] || [ "$PREP_SELECT_STATUS" -eq 1 ]; then
            while IFS= read -r -d '' FILE; do
                FILE_BASE=${FILE##*/}
                case "$FILE_BASE" in
                    *.cbl|*.CBL) printf '%s\0' "$FILE" >> "$PREP_SELECTED_PATHS" ;;
                    *.*) ;;
                    *) printf '%s\0' "$FILE" >> "$PREP_SELECTED_PATHS" ;;
                esac
            done < "$PREP_RG_PATHS"
        fi
    fi
    rm -f "$PREP_ALL_PATHS" "$PREP_RG_PATHS"
    if [ "$PREP_SELECT_STATUS" -ne 0 ] && [ "$PREP_SELECT_STATUS" -ne 1 ]; then
        report "run: FAIL - text prefilter failed (status=$PREP_SELECT_STATUS)"
        return 1
    fi

    PREP_SELECTED=$(tr -cd '\000' < "$PREP_SELECTED_PATHS" | wc -c | tr -d ' ')
    report "snapshot: discovered_files=$PREP_DISCOVERED selected_files=$PREP_SELECTED prefilter_failures=0 text_prefilter='$PREP_TEXT_PREFILTER_RE'"
    if [ "$PREP_SELECTED" -eq 0 ]; then
        report "run: FAIL - text prefilter selected zero files; refusing an empty comparison denominator"
        return 1
    fi
    return 0
}

compile_inventory_helper() {
    COMPILE_PARSER_ROOT="$1"
    COMPILE_OUTPUT="$2"
    COMPILE_RUNTIME_ROOT="$TREE_SITTER_RUNTIME_DIR"
    if [ -z "$COMPILE_RUNTIME_ROOT" ]; then
        COMPILE_GOMODCACHE=$(go env GOMODCACHE 2>/dev/null)
        COMPILE_RUNTIME_ROOT="$COMPILE_GOMODCACHE/github.com/tree-sitter/go-tree-sitter@v0.25.0"
    fi
    if [ ! -f "$COMPILE_RUNTIME_ROOT/include/tree_sitter/api.h" ] || [ ! -f "$COMPILE_RUNTIME_ROOT/src/lib.c" ]; then
        report "run: FAIL - tree-sitter v0.25.0 runtime source not found; set TREE_SITTER_RUNTIME_DIR"
        return 1
    fi
    if [ ! -f "$COMPILE_PARSER_ROOT/src/parser.c" ] || [ ! -f "$COMPILE_PARSER_ROOT/src/scanner.c" ]; then
        report "run: FAIL - generated COBOL parser sources are incomplete under $COMPILE_PARSER_ROOT/src"
        return 1
    fi

    "$WALL_TIMEOUT_BIN" -k 5s "${BUILD_WALL_TIMEOUT_SECONDS}s" cc \
        -std=c11 -O0 -g0 \
        -I "$COMPILE_RUNTIME_ROOT/include" \
        -I "$COMPILE_PARSER_ROOT/src" \
        "$TOP_DIR/run_accept_differential_helper.c" \
        "$COMPILE_PARSER_ROOT/src/parser.c" \
        "$COMPILE_PARSER_ROOT/src/scanner.c" \
        "$COMPILE_RUNTIME_ROOT/src/lib.c" \
        -o "$COMPILE_OUTPUT"
    COMPILE_STATUS=$?
    if [ "$COMPILE_STATUS" -ne 0 ]; then
        report "run: FAIL - inventory helper compilation failed or timed out (status=$COMPILE_STATUS)"
        return 1
    fi
    return 0
}

run_helper_snapshot() {
    HELPER_BIN="$1"
    HELPER_CORPUS_ROOT="$2"
    HELPER_SELECTED_PATHS="$3"
    HELPER_OUT="$4"
    HELPER_NODE_TYPE_REGEX="$5"
    HELPER_STATS="$(mktemp)"
    HELPER_FILE_OUT="$(mktemp)"
    HELPER_ONE_PATH="$(mktemp)"
    HELPER_UNSORTED="$(mktemp)"
    if [ $? -ne 0 ] || [ -z "$HELPER_STATS" ] || [ -z "$HELPER_FILE_OUT" ] ||
       [ -z "$HELPER_ONE_PATH" ] || [ -z "$HELPER_UNSORTED" ]; then
        report "snapshot: FAIL - could not create helper output files"
        rm -f "$HELPER_STATS" "$HELPER_FILE_OUT" "$HELPER_ONE_PATH" "$HELPER_UNSORTED"
        return 1
    fi

    FILES_TOTAL=0
    FILES_FAILED=0
    FILES_TIMED_OUT=0
    FILES_WITH_PARSE_ERRORS=0
    FILES_ZERO_MATCH=0
    RECORDS_TOTAL=0

    while IFS= read -r -d '' FILE; do
        FILES_TOTAL=$((FILES_TOTAL + 1))
        printf '%s\0' "$FILE" > "$HELPER_ONE_PATH"
        : > "$HELPER_FILE_OUT"
        : > "$HELPER_STATS"

        "$WALL_TIMEOUT_BIN" -k 1s "${PARSE_WALL_TIMEOUT_SECONDS}s" "$HELPER_BIN" \
            "$HELPER_CORPUS_ROOT" "$HELPER_ONE_PATH" \
            "$HELPER_FILE_OUT" "$HELPER_STATS" "$PARSE_TIMEOUT_US" \
            "$HELPER_NODE_TYPE_REGEX" >/dev/null 2>&1
        HELPER_STATUS=$?

        if [ "$HELPER_STATUS" -eq 124 ] || [ "$HELPER_STATUS" -eq 137 ]; then
            FILES_TIMED_OUT=$((FILES_TIMED_OUT + 1))
            FILES_FAILED=$((FILES_FAILED + 1))
        elif [ ! -s "$HELPER_STATS" ]; then
            FILES_FAILED=$((FILES_FAILED + 1))
        else
            read FILE_TOTAL FILE_FAILED FILE_TIMED_OUT FILE_PARSE_ERRORS FILE_ZERO_MATCH FILE_RECORDS < "$HELPER_STATS"
            FILES_FAILED=$((FILES_FAILED + FILE_FAILED))
            FILES_TIMED_OUT=$((FILES_TIMED_OUT + FILE_TIMED_OUT))
            FILES_WITH_PARSE_ERRORS=$((FILES_WITH_PARSE_ERRORS + FILE_PARSE_ERRORS))
            FILES_ZERO_MATCH=$((FILES_ZERO_MATCH + FILE_ZERO_MATCH))
            RECORDS_TOTAL=$((RECORDS_TOTAL + FILE_RECORDS))
            if [ "$HELPER_STATUS" -ne 0 ] && [ "$FILE_FAILED" -eq 0 ]; then
                FILES_FAILED=$((FILES_FAILED + 1))
            fi
            if [ -s "$HELPER_FILE_OUT" ]; then
                cat "$HELPER_FILE_OUT" >> "$HELPER_UNSORTED"
            fi
        fi

        if [ $((FILES_TOTAL % 100)) -eq 0 ]; then
            report "snapshot: progress files_walked=$FILES_TOTAL files_failed_to_emit_tree=$FILES_FAILED files_timed_out=$FILES_TIMED_OUT files_with_parse_errors=$FILES_WITH_PARSE_ERRORS records_found=$RECORDS_TOTAL"
        fi
    done < "$HELPER_SELECTED_PATHS"

    rm -f "$HELPER_STATS" "$HELPER_FILE_OUT" "$HELPER_ONE_PATH"
    sort "$HELPER_UNSORTED" > "$HELPER_OUT"
    SORT_STATUS=$?
    rm -f "$HELPER_UNSORTED"
    if [ "$SORT_STATUS" -ne 0 ]; then
        report "snapshot: FAIL - could not sort inventory output"
        return 1
    fi

    report "snapshot: corpus=$HELPER_CORPUS_ROOT node_type_regex='$HELPER_NODE_TYPE_REGEX' out=$HELPER_OUT"
    report "snapshot: files_walked=$FILES_TOTAL files_failed_to_emit_tree=$FILES_FAILED files_timed_out=$FILES_TIMED_OUT files_with_parse_errors=$FILES_WITH_PARSE_ERRORS files_zero_match=$FILES_ZERO_MATCH records_written=$RECORDS_TOTAL"
    if [ "$FILES_FAILED" -ne 0 ]; then
        report "snapshot: FAIL - incomplete denominator (files_failed_to_emit_tree=$FILES_FAILED)"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# run <BASELINE_REF> <CORPUS_DIR> [NODE_TYPE_REGEX] [TEXT_PREFILTER_RE|--no-prefilter]
# Caller supplies a bare node alternation without anchors or a surrounding
# group; cmd_run wraps it exactly once for the compiled helper. The text
# prefilter is a separate ERE and --no-prefilter requests a full source walk.
# ---------------------------------------------------------------------------
cmd_run() {
    RUN_BASELINE_REF="${1:-$BASELINE_REF}"
    RUN_CORPUS_DIR="${2:-$CORPUS_DIR}"
    RUN_NODE_TYPE_REGEX="${3-$DEFAULT_NODE_TYPE_REGEX}"
    RUN_TEXT_PREFILTER_RE="${4-$DEFAULT_TEXT_PREFILTER_RE}"
    RUN_CUSTOM_SELECTION=0
    [ "$RUN_NODE_TYPE_REGEX" != "$DEFAULT_NODE_TYPE_REGEX" ] && RUN_CUSTOM_SELECTION=1
    [ "$RUN_TEXT_PREFILTER_RE" != "$DEFAULT_TEXT_PREFILTER_RE" ] && RUN_CUSTOM_SELECTION=1
    RUN_HELPER_NODE_TYPE_REGEX="^(${RUN_NODE_TYPE_REGEX})$"

    if [ -z "$RUN_BASELINE_REF" ] || [ -z "$RUN_CORPUS_DIR" ] ||
       [ -z "$RUN_NODE_TYPE_REGEX" ] || [ -z "$RUN_TEXT_PREFILTER_RE" ]; then
        report "run: usage: run <BASELINE_REF> <CORPUS_DIR> [NODE_TYPE_REGEX] [TEXT_PREFILTER_RE|--no-prefilter] (or set BASELINE_REF/CORPUS_DIR env vars)"
        return 1
    fi
    if [ ! -d "$RUN_CORPUS_DIR" ]; then
        report "run: FAIL - corpus directory not found: $RUN_CORPUS_DIR"
        return 1
    fi
    if [ "$RUN_TEXT_PREFILTER_RE" != "--no-prefilter" ]; then
        printf '' | rg -q -- "$RUN_TEXT_PREFILTER_RE" >/dev/null 2>&1
        RUN_PREFILTER_VALIDATE_STATUS=$?
        if [ "$RUN_PREFILTER_VALIDATE_STATUS" -ne 0 ] && [ "$RUN_PREFILTER_VALIDATE_STATUS" -ne 1 ]; then
            report "run: FAIL - invalid text prefilter regex"
            return 1
        fi
    fi
    if ! command -v rg >/dev/null 2>&1 || ! command -v cc >/dev/null 2>&1 ||
       ! command -v go >/dev/null 2>&1 || ! command -v "$WALL_TIMEOUT_BIN" >/dev/null 2>&1; then
        report "run: FAIL - required tool missing (rg, cc, go, or $WALL_TIMEOUT_BIN)"
        return 1
    fi

    RUN_DIFF_TMP="$DIFF_TMP"
    RUN_DIFF_TMP_OWNED=0
    if [ -z "$RUN_DIFF_TMP" ]; then
        RUN_DIFF_TMP="$(mktemp -d)"
        RUN_DIFF_TMP_OWNED=1
    fi
    if [ -z "$RUN_DIFF_TMP" ] || [ ! -d "$RUN_DIFF_TMP" ]; then
        report "run: FAIL - could not create/resolve a scratch directory"
        return 1
    fi
    path_is_under_repo "$RUN_DIFF_TMP" dir
    RUN_PATH_STATUS=$?
    if [ "$RUN_PATH_STATUS" -eq 0 ]; then
        report "run: REFUSED - DIFF_TMP resolves under the repository root"
        [ "$RUN_DIFF_TMP_OWNED" -eq 1 ] && rmdir "$RUN_DIFF_TMP" 2>/dev/null
        return 1
    fi
    if [ "$RUN_PATH_STATUS" -ne 1 ]; then
        report "run: REFUSED - DIFF_TMP could not be canonicalized safely"
        [ "$RUN_DIFF_TMP_OWNED" -eq 1 ] && rmdir "$RUN_DIFF_TMP" 2>/dev/null
        return 1
    fi
    RUN_DIFF_TMP="$(python3 - "$RUN_DIFF_TMP" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]).resolve(strict=True))
PY
)"
    if [ $? -ne 0 ] || [ -z "$RUN_DIFF_TMP" ]; then
        report "run: REFUSED - DIFF_TMP could not be canonicalized safely"
        return 1
    fi

    WORKTREE_DIR="$RUN_DIFF_TMP/accept-differential-worktree"
    BEFORE_OUT="$RUN_DIFF_TMP/before-inventory.txt"
    AFTER_OUT="$RUN_DIFF_TMP/after-inventory.txt"
    SELECTED_PATHS="$RUN_DIFF_TMP/selected-paths.bin"
    BASELINE_HELPER="$RUN_DIFF_TMP/baseline-inventory-helper"
    CURRENT_HELPER="$RUN_DIFF_TMP/current-inventory-helper"

    for RUN_PATH in "$WORKTREE_DIR" "$BEFORE_OUT" "$AFTER_OUT" "$SELECTED_PATHS" "$BASELINE_HELPER" "$CURRENT_HELPER"; do
        if [ -e "$RUN_PATH" ]; then
            report "run: FAIL - scratch path already exists; refusing to delete caller-owned content"
            [ "$RUN_DIFF_TMP_OWNED" -eq 1 ] && rmdir "$RUN_DIFF_TMP" 2>/dev/null
            return 1
        fi
    done

    RUN_CORPUS_DIR_ABS=$(cd "$RUN_CORPUS_DIR" && pwd)
    prepare_accept_paths "$RUN_CORPUS_DIR_ABS" "$SELECTED_PATHS" \
        "$RUN_TEXT_PREFILTER_RE" "$RUN_CUSTOM_SELECTION"
    if [ $? -ne 0 ]; then
        rm -f "$SELECTED_PATHS"
        [ "$RUN_DIFF_TMP_OWNED" -eq 1 ] && rmdir "$RUN_DIFF_TMP" 2>/dev/null
        return 1
    fi

    (cd "$TOP_DIR" && git worktree add --detach "$WORKTREE_DIR" "$RUN_BASELINE_REF") >/dev/null
    if [ $? -ne 0 ]; then
        report "run: FAIL - could not create baseline worktree"
        rm -f "$SELECTED_PATHS"
        [ "$RUN_DIFF_TMP_OWNED" -eq 1 ] && rmdir "$RUN_DIFF_TMP" 2>/dev/null
        return 1
    fi

    report "run: generating baseline parser sources"
    (cd "$WORKTREE_DIR" && "$TREE_SITTER" generate) >/dev/null
    BASELINE_GENERATE_STATUS=$?
    if [ "$BASELINE_GENERATE_STATUS" -ne 0 ]; then
        report "run: FAIL - baseline tree-sitter generate failed"
        (cd "$TOP_DIR" && git worktree remove --force "$WORKTREE_DIR") >/dev/null 2>&1
        rm -f "$SELECTED_PATHS"
        [ "$RUN_DIFF_TMP_OWNED" -eq 1 ] && rmdir "$RUN_DIFF_TMP" 2>/dev/null
        return 1
    fi

    report "run: compiling baseline inventory helper"
    compile_inventory_helper "$WORKTREE_DIR" "$BASELINE_HELPER"
    BASELINE_COMPILE_STATUS=$?
    report "run: compiling current inventory helper"
    compile_inventory_helper "$TOP_DIR" "$CURRENT_HELPER"
    CURRENT_COMPILE_STATUS=$?
    if [ "$BASELINE_COMPILE_STATUS" -ne 0 ] || [ "$CURRENT_COMPILE_STATUS" -ne 0 ]; then
        (cd "$TOP_DIR" && git worktree remove --force "$WORKTREE_DIR") >/dev/null 2>&1
        rm -f "$SELECTED_PATHS" "$BASELINE_HELPER" "$CURRENT_HELPER"
        [ "$RUN_DIFF_TMP_OWNED" -eq 1 ] && rmdir "$RUN_DIFF_TMP" 2>/dev/null
        return 1
    fi

    run_helper_snapshot "$BASELINE_HELPER" "$RUN_CORPUS_DIR_ABS" "$SELECTED_PATHS" "$BEFORE_OUT" "$RUN_HELPER_NODE_TYPE_REGEX"
    BEFORE_STATUS=$?
    run_helper_snapshot "$CURRENT_HELPER" "$RUN_CORPUS_DIR_ABS" "$SELECTED_PATHS" "$AFTER_OUT" "$RUN_HELPER_NODE_TYPE_REGEX"
    AFTER_STATUS=$?

    (cd "$TOP_DIR" && git worktree remove --force "$WORKTREE_DIR") >/dev/null 2>&1
    WORKTREE_REMOVE_STATUS=$?
    rm -f "$SELECTED_PATHS" "$BASELINE_HELPER" "$CURRENT_HELPER"
    if [ "$WORKTREE_REMOVE_STATUS" -ne 0 ]; then
        report "run: FAIL - could not remove baseline worktree"
        return 1
    fi
    if [ "$BEFORE_STATUS" -ne 0 ] || [ "$AFTER_STATUS" -ne 0 ]; then
        report "run: FAIL - snapshot failed (before_status=$BEFORE_STATUS after_status=$AFTER_STATUS)"
        if [ "$RUN_DIFF_TMP_OWNED" -eq 1 ]; then
            rm -f "$BEFORE_OUT" "$AFTER_OUT"
            rmdir "$RUN_DIFF_TMP" 2>/dev/null
        fi
        return 1
    fi

    cmd_compare "$BEFORE_OUT" "$AFTER_OUT"
    COMPARE_STATUS=$?
    if [ "$RUN_DIFF_TMP_OWNED" -eq 1 ]; then
        rm -f "$BEFORE_OUT" "$AFTER_OUT"
        rmdir "$RUN_DIFF_TMP" 2>/dev/null
    fi
    return "$COMPARE_STATUS"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
SUBCOMMAND="$1"
if [ -n "$SUBCOMMAND" ]; then
    shift
fi

case "$SUBCOMMAND" in
    snapshot)
        cmd_snapshot "$@"
        EXIT_CODE=$?
        ;;
    compare)
        cmd_compare "$@"
        EXIT_CODE=$?
        ;;
    run)
        cmd_run "$@"
        EXIT_CODE=$?
        ;;
    *)
        usage
        EXIT_CODE=1
        ;;
esac

exit "$EXIT_CODE"
