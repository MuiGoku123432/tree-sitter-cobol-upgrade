#!/bin/bash
# Phase 02 closeout harness.
#
# Runs the raw-evidence gauntlet without assigning a security, verification,
# or validation verdict. Proprietary output stays in external task scratch and
# is reduced to aggregate counts before tracked evidence is written.

TOP_DIR=$(cd -P "$(dirname "$0")/../../.." && pwd)
PHASE_DIR="$TOP_DIR/.planning/phases/02-idms-dml-statement-nodes"
EVIDENCE="$PHASE_DIR/02-11-EVIDENCE.md"
BASELINE_REF=39886c7
DCC_ROOT="$HOME/repos/mine/cobolCode/cam-corpus-dcc/DCC"
DEFAULT_ESTATE_ROOT="/Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-upgrade/estate"
ESTATE_ROOT=${ESTATE_ROOT:-$DEFAULT_ESTATE_ROOT}
GORTEX_ROOT="$HOME/repos/mine/GoApps/gortex"
EXPECTED_SHIM_DIR="$TOP_DIR/forest-shim/cobol"
GORTEX_GOWORK_FILE="$GORTEX_ROOT/go.work"
GORTEX_GOWORK_SHA_BEFORE=""
GORTEX_GOWORK_SHA_AFTER=""
TEMP_PARENT="/var/folders/ks/sc4623gx7c144xx9_sxj53b00000gn/T/opencode"
CURRENT_REF=$(git -C "$TOP_DIR" rev-parse HEAD 2>/dev/null)
SECURITY_FILE="$PHASE_DIR/02-SECURITY.md"
VERIFICATION_FILE="$PHASE_DIR/02-VERIFICATION.md"
VALIDATION_FILE="$PHASE_DIR/02-VALIDATION.md"

TASK_TMP=""
TEMP_WORKTREE=""
DCC_TMP=""
ESTATE_TMP=""
TMP_GOWORK_DIR=""
CLEANUP_STATUS=not-run
EVIDENCE_WRITTEN=0
FINAL_STATUS=1
CLEANUP_RUNNING=0
NIST_SUMMARY_EXISTED=0
NIST_RESULT_EXISTED=0
NIST_SUMMARY_BACKUP=""
NIST_RESULT_BACKUP=""

FAST_DIFFERENTIAL_ST=not-run
QUERY_ST=not-run
REFRESH_ST=not-run
SOURCE_SHIM_CMP_ST=not-run
SHIM_QUERY_ST=not-run
SHIM_GO_ST=not-run
ESTATE_PREFLIGHT_ST=not-run
DCC_ST=not-run
ESTATE_ST=not-run
FOCUSED_ST=not-run
FULL_CORPUS_ST=not-run
NIST_ST=not-run
NIST_FINAL_LINE=not-run
NIST_ALLOWLIST_ST=not-run
GOWORK_INIT_ST=not-run
GOWORK_LIST_ST=not-run
GOWORK_RESOLUTION_ST=not-run
CASCADE_ST=not-run
ESTATE_GUARD_SELFTEST_ST=not-run
RANGE_VALIDATION_ST=not-run
HASH_INVARIANT_ST=not-run

DCC_SELECTOR_SUMMARY=not-run
DCC_BEFORE_SUMMARY=not-run
DCC_AFTER_SUMMARY=not-run
DCC_COMPARE_SUMMARY=not-run
DCC_RECLASSIFIED=not-run
DCC_CONVERTED=not-run
DCC_NEW=not-run
ESTATE_SELECTOR_SUMMARY=not-run
ESTATE_BEFORE_SUMMARY=not-run
ESTATE_AFTER_SUMMARY=not-run
ESTATE_COMPARE_SUMMARY=not-run
ESTATE_RECLASSIFIED=not-run
ESTATE_CONVERTED=not-run
ESTATE_NEW=not-run

RANGE_02_07="$(git -C "$TOP_DIR" rev-parse '6bbdd47^' 2>/dev/null)..$(git -C "$TOP_DIR" rev-parse 8ef8c1b 2>/dev/null)"
RANGE_02_08="$(git -C "$TOP_DIR" rev-parse '7256b32^' 2>/dev/null)..$(git -C "$TOP_DIR" rev-parse 909ca09 2>/dev/null)"
RANGE_02_09="$(git -C "$TOP_DIR" rev-parse '8f5f0a9^' 2>/dev/null)..$(git -C "$TOP_DIR" rev-parse 39eea73 2>/dev/null)"
RANGE_02_10="$(git -C "$TOP_DIR" rev-parse '6298669^' 2>/dev/null)..$(git -C "$TOP_DIR" rev-parse a4f122d 2>/dev/null)"
SEP_02_07_ST=not-run
ESTATE_GUARD_02_07_ST=not-run
SEP_02_08_ST=not-run
ESTATE_GUARD_02_08_ST=not-run
SEP_02_09_ST=not-run
ESTATE_GUARD_02_09_ST=not-run
SEP_02_10_ST=not-run
ESTATE_GUARD_02_10_ST=not-run

SECURITY_SHA_BEFORE=""
VERIFICATION_SHA_BEFORE=""
VALIDATION_SHA_BEFORE=""
SECURITY_SHA_AFTER=""
VERIFICATION_SHA_AFTER=""
VALIDATION_SHA_AFTER=""

report() { printf '%s\n' "$1"; }
status_label() {
    if [ "$1" = "0" ]; then printf 'PASS (exit 0)'
    elif [ "$1" = "not-run" ]; then printf 'NOT RUN'
    else printf 'FAIL (exit %s)' "$1"
    fi
}
extract_line() {
    EXTRACT_VALUE=$(grep -E "$2" "$1" 2>/dev/null | tail -1)
    [ -n "$EXTRACT_VALUE" ] && printf '%s' "$EXTRACT_VALUE" || printf 'missing'
}
redact_differential_log() {
    grep -E '^(snapshot: (estate selector|discovered_files=|files_walked=)|SUMMARY:|RECLASSIFIED_COUNT:|CONVERTED_COUNT:|NEW_COUNT:|run: (generating|compiling))' \
        "$1" > "$2" 2>/dev/null
    REDACT_ST=$?
    [ "$REDACT_ST" -eq 0 ] || [ "$REDACT_ST" -eq 1 ]
}

write_evidence() {
    [ "$EVIDENCE_WRITTEN" -eq 1 ] && return 0
    EVIDENCE_WRITTEN=1
    cat > "$EVIDENCE.tmp" <<EOF
---
phase: 02-idms-dml-statement-nodes
plan: 11
task: 1
status: raw-evidence-only
baseline: 39886c7
implementation_ref: ${CURRENT_REF:-unresolved}
---

# Phase 02 Plan 11 Task 1 Raw Closeout Evidence

This file records commands, statuses, and aggregate counts only. It makes no
security, verification, or validation verdict. No proprietary file name,
relative path, source line, or inventory row is recorded.

## Canonical Invocation

\`ESTATE_ROOT=<approved-external-copy> bash .planning/phases/02-idms-dml-statement-nodes/02-11-closeout.sh\`

- Overall harness status: $(status_label "$FINAL_STATUS")
- Cleanup status: ${CLEANUP_STATUS}
- Baseline: \`${BASELINE_REF}\`
- Current implementation ref: \`${CURRENT_REF:-unresolved}\`
- Harness status: $(status_label "$FINAL_STATUS")
- DCC status: $(status_label "$DCC_ST")
- Estate status: $(status_label "$ESTATE_ST")
- NIST status: $(status_label "$NIST_ST")
- GOWORK cascade status: $(status_label "$CASCADE_ST")
- Guard status: $(if [ "$SEP_02_07_ST" = 0 ] && [ "$ESTATE_GUARD_02_07_ST" = 0 ] && [ "$SEP_02_08_ST" = 0 ] && [ "$ESTATE_GUARD_02_08_ST" = 0 ] && [ "$SEP_02_09_ST" = 0 ] && [ "$ESTATE_GUARD_02_09_ST" = 0 ] && [ "$SEP_02_10_ST" = 0 ] && [ "$ESTATE_GUARD_02_10_ST" = 0 ] && [ "$ESTATE_GUARD_SELFTEST_ST" = 0 ]; then printf 'PASS (all range and self-test gates)'; else printf 'FAIL or incomplete'; fi)
- Resolved DCC root: \`${DCC_ROOT}\`
- Resolved estate root: \`${ESTATE_ROOT}\`
- Estate differential input: exactly \`\$TEMP_WORKTREE/estate\`

## Verdict Artifact Integrity

| Artifact | SHA-256 before | SHA-256 after | Result |
|---|---|---|---|
| \`02-SECURITY.md\` | \`${SECURITY_SHA_BEFORE:-unavailable}\` | \`${SECURITY_SHA_AFTER:-unavailable}\` | $([ -n "$SECURITY_SHA_BEFORE" ] && [ "$SECURITY_SHA_BEFORE" = "$SECURITY_SHA_AFTER" ] && printf unchanged || printf changed-or-unavailable) |
| \`02-VERIFICATION.md\` | \`${VERIFICATION_SHA_BEFORE:-unavailable}\` | \`${VERIFICATION_SHA_AFTER:-unavailable}\` | $([ -n "$VERIFICATION_SHA_BEFORE" ] && [ "$VERIFICATION_SHA_BEFORE" = "$VERIFICATION_SHA_AFTER" ] && printf unchanged || printf changed-or-unavailable) |
| \`02-VALIDATION.md\` | \`${VALIDATION_SHA_BEFORE:-unavailable}\` | \`${VALIDATION_SHA_AFTER:-unavailable}\` | $([ -n "$VALIDATION_SHA_BEFORE" ] && [ "$VALIDATION_SHA_BEFORE" = "$VALIDATION_SHA_AFTER" ] && printf unchanged || printf changed-or-unavailable) |

Hash invariant gate: $(status_label "$HASH_INVARIANT_ST")

## Fast Gates

| Gate | Exact command | Raw status |
|---|---|---|
| Differential adversarial self-test | \`bash run_accept_differential_selftest.sh\` | $(status_label "$FAST_DIFFERENTIAL_ST") |
| Symlink-root canonicalization regression | differential self-test plus \`cd -P\` before selector dispatch | $(status_label "$FAST_DIFFERENTIAL_ST") |
| Exact source query | \`./run_idms_query_capture.sh\` | $(status_label "$QUERY_ST") |
| Refresh self-test | \`./forest-shim/refresh-selftest.sh\` | $(status_label "$REFRESH_ST") |
| Source/shim query identity | \`cmp queries/idms.scm forest-shim/cobol/idms.scm\` | $(status_label "$SOURCE_SHIM_CMP_ST") |
| Exact shim query | \`IDMS_QUERY_FILE="\$PWD/forest-shim/cobol/idms.scm" ./run_idms_query_capture.sh\` | $(status_label "$SHIM_QUERY_ST") |
| Shim Go tests | \`(cd forest-shim/cobol && IDMS_SOURCE_QUERY="<target>/queries/idms.scm" go test ./...)\` | $(status_label "$SHIM_GO_ST") |

## Threat-Test Raw Status

| Threat | Raw executable evidence | Status |
|---|---|---|
| T-02-R01 | Symlink containment cases, including physical estate-root selection | $(status_label "$FAST_DIFFERENTIAL_ST") |
| T-02-R03 | Strict TSV, duplicate-key, regex, and extraction-failure cases | $(status_label "$FAST_DIFFERENTIAL_ST") |
| T-02-R05 | Focused IDMS corpus plus exact invalid-update query subject | $(if [ "$FOCUSED_ST" = 0 ] && [ "$QUERY_ST" = 0 ]; then printf 'PASS (both exit 0)'; else printf 'FAIL or incomplete'; fi) |
| T-02-R06 | Exact source and delivered-shim all-14 capture gates | $(if [ "$QUERY_ST" = 0 ] && [ "$SHIM_QUERY_ST" = 0 ]; then printf 'PASS (both exit 0)'; else printf 'FAIL or incomplete'; fi) |

These are raw test outcomes only. The independent security workflow owns every
threat disposition and final closure decision.

## Differential Gates

\`DCC_TMP=\$(mktemp -d); DIFF_TMP="\$DCC_TMP" sh run_accept_differential.sh run 39886c7 "\$DCC_ROOT"; DCC_ST=\$?\`

\`ESTATE_TMP=\$(mktemp -d); DIFF_TMP="\$ESTATE_TMP" sh "\$TEMP_WORKTREE/run_accept_differential.sh" run 39886c7 "\$TEMP_WORKTREE/estate"; ESTATE_ST=\$?\`

| Corpus | Status | Selector aggregate | Baseline aggregate | Current aggregate | Comparator aggregate | Reclassified | Converted | New |
|---|---|---|---|---|---|---|---|---|
| DCC | $(status_label "$DCC_ST") | ${DCC_SELECTOR_SUMMARY} | ${DCC_BEFORE_SUMMARY} | ${DCC_AFTER_SUMMARY} | ${DCC_COMPARE_SUMMARY} | ${DCC_RECLASSIFIED} | ${DCC_CONVERTED} | ${DCC_NEW} |
| Approved copied estate | $(status_label "$ESTATE_ST") | ${ESTATE_SELECTOR_SUMMARY} | ${ESTATE_BEFORE_SUMMARY} | ${ESTATE_AFTER_SUMMARY} | ${ESTATE_COMPARE_SUMMARY} | ${ESTATE_RECLASSIFIED} | ${ESTATE_CONVERTED} | ${ESTATE_NEW} |

Estate selector preflight: $(status_label "$ESTATE_PREFLIGHT_ST"). It requires
exactly 3,781 declared members, 1,369 compilable programs, and the default-mode
2,391 ACCEPT denominator before a full differential starts.

## Corpus and NIST Gates

| Gate | Exact command or invariant | Raw status |
|---|---|---|
| Focused IDMS corpus | \`node_modules/.bin/tree-sitter test -i 'idms'\` | $(status_label "$FOCUSED_ST") |
| Full non-comment corpus | \`node_modules/.bin/tree-sitter test -e '^comment$'\` | $(status_label "$FULL_CORPUS_ST") |
| NIST runner | \`sh run_nist_cobol85.sh\` | $(status_label "$NIST_ST") |
| NIST final line | \`382 tests. (Success: 371, Fail: 0, Skip: 11)\` | ${NIST_FINAL_LINE} |
| Canonical 11-entry allowlist | sorted nonblank \`skip_tests.txt\` byte comparison | $(status_label "$NIST_ALLOWLIST_ST") |

## Isolated GOWORK Cascade

Commands:

- \`(cd "$TMP_GOWORK_DIR" && GOWORK=off go work init "$GORTEX_ROOT" "$EXPECTED_SHIM_DIR")\`
- \`(cd "$GORTEX_ROOT" && GOWORK="$TMP_GOWORK_DIR/go.work" go list -m -json github.com/alexaandru/go-sitter-forest/cobol)\`
- \`(cd "$GORTEX_ROOT" && GOWORK="$TMP_GOWORK_DIR/go.work" go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -count=2 -args -enhanced-parser)\`

| Gate | Raw status |
|---|---|
| \`go work init <gortex> <target-worktree-shim>\` | $(status_label "$GOWORK_INIT_ST") |
| \`GOWORK=<temporary-go.work> go list -m -json github.com/alexaandru/go-sitter-forest/cobol\` | $(status_label "$GOWORK_LIST_ST") |
| Module \`.Dir\` equals \`${EXPECTED_SHIM_DIR}\` | $(status_label "$GOWORK_RESOLUTION_ST") |
| \`GOWORK=<temporary-go.work> go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -count=2 -args -enhanced-parser\` | $(status_label "$CASCADE_ST") |

The temporary workspace is isolated from gortex's existing \`go.work\` and is
removed by the task-level cleanup trap. Existing \`go.work\` SHA-256 before and
after: \`${GORTEX_GOWORK_SHA_BEFORE:-unavailable}\` / \`${GORTEX_GOWORK_SHA_AFTER:-unavailable}\`.

## Commit-Range Guards

| Plan | Inclusive range | Family | Separability | Estate guard |
|---|---|---|---|---|
| 02-07 | \`${RANGE_02_07}\` | fork-local | $(status_label "$SEP_02_07_ST") | $(status_label "$ESTATE_GUARD_02_07_ST") |
| 02-08 | \`${RANGE_02_08}\` | grammar | $(status_label "$SEP_02_08_ST") | $(status_label "$ESTATE_GUARD_02_08_ST") |
| 02-09 | \`${RANGE_02_09}\` | grammar plus isolated fork-local gate | $(status_label "$SEP_02_09_ST") | $(status_label "$ESTATE_GUARD_02_09_ST") |
| 02-10 | \`${RANGE_02_10}\` | fork-local | $(status_label "$SEP_02_10_ST") | $(status_label "$ESTATE_GUARD_02_10_ST") |

- Estate guard self-test: $(status_label "$ESTATE_GUARD_SELFTEST_ST")
- Listed-commit containment in literal ranges: $(status_label "$RANGE_VALIDATION_ST")
- Guard commands run only after every implementation commit listed by each
  source summary is confirmed in its corresponding range.

## Independent Gates Required

Task 1 produces raw evidence only. Phase 2 remains blocked in this order:

1. \`/gsd-secure-phase 2\` must independently rewrite \`02-SECURITY.md\` with \`threats_open: 0\`.
2. The independent Phase 2 gsd-verifier must then rewrite \`02-VERIFICATION.md\`.
3. \`/gsd-validate-phase 2\` must then own lifecycle changes in \`02-VALIDATION.md\`.
EOF
    EVIDENCE_WRITE_ST=$?
    if [ "$EVIDENCE_WRITE_ST" -eq 0 ]; then
        mv "$EVIDENCE.tmp" "$EVIDENCE"
        EVIDENCE_WRITE_ST=$?
    fi
    [ "$EVIDENCE_WRITE_ST" -eq 0 ] || rm -f "$EVIDENCE.tmp"
    return "$EVIDENCE_WRITE_ST"
}

cleanup() {
    ENTRY_STATUS=$?
    [ "$CLEANUP_RUNNING" -eq 1 ] && return
    CLEANUP_RUNNING=1
    trap - EXIT INT TERM
    CLEANUP_STATUS=pass
    for DIFF_DIR in "$DCC_TMP" "$ESTATE_TMP"; do
        if [ -n "$DIFF_DIR" ] && [ -d "$DIFF_DIR/accept-differential-worktree" ]; then
            git -C "$TOP_DIR" worktree remove --force "$DIFF_DIR/accept-differential-worktree" >/dev/null 2>&1 || CLEANUP_STATUS=fail
        fi
    done
    if [ -n "$TEMP_WORKTREE" ] && [ -L "$TEMP_WORKTREE/estate" ]; then
        rm "$TEMP_WORKTREE/estate" || CLEANUP_STATUS=fail
    fi
    if [ -n "$TEMP_WORKTREE" ] && [ -d "$TEMP_WORKTREE" ]; then
        git -C "$TOP_DIR" worktree remove --force "$TEMP_WORKTREE" >/dev/null 2>&1 || CLEANUP_STATUS=fail
    fi
    if [ -n "$TASK_TMP" ] && [ -d "$TASK_TMP" ]; then
        if [ "$NIST_SUMMARY_EXISTED" -eq 1 ]; then
            cp "$NIST_SUMMARY_BACKUP" "$TOP_DIR/test/cobol85/summary.txt" || CLEANUP_STATUS=fail
        else
            rm -f "$TOP_DIR/test/cobol85/summary.txt" || CLEANUP_STATUS=fail
        fi
        if [ "$NIST_RESULT_EXISTED" -eq 1 ]; then
            rm -rf "$TOP_DIR/test/cobol85/result" || CLEANUP_STATUS=fail
            cp -R "$NIST_RESULT_BACKUP" "$TOP_DIR/test/cobol85/result" || CLEANUP_STATUS=fail
        else
            rm -rf "$TOP_DIR/test/cobol85/result" || CLEANUP_STATUS=fail
        fi
    fi
    for OWNED_DIR in "$DCC_TMP" "$ESTATE_TMP" "$TMP_GOWORK_DIR" "$TASK_TMP"; do
        if [ -n "$OWNED_DIR" ] && [ -e "$OWNED_DIR" ]; then
            rm -rf "$OWNED_DIR" || CLEANUP_STATUS=fail
        fi
    done
    SECURITY_SHA_AFTER=$(shasum -a 256 "$SECURITY_FILE" 2>/dev/null | cut -d' ' -f1)
    VERIFICATION_SHA_AFTER=$(shasum -a 256 "$VERIFICATION_FILE" 2>/dev/null | cut -d' ' -f1)
    VALIDATION_SHA_AFTER=$(shasum -a 256 "$VALIDATION_FILE" 2>/dev/null | cut -d' ' -f1)
    GORTEX_GOWORK_SHA_AFTER=$(shasum -a 256 "$GORTEX_GOWORK_FILE" 2>/dev/null | cut -d' ' -f1)
    if [ -n "$SECURITY_SHA_BEFORE" ] && [ "$SECURITY_SHA_BEFORE" = "$SECURITY_SHA_AFTER" ] &&
       [ "$VERIFICATION_SHA_BEFORE" = "$VERIFICATION_SHA_AFTER" ] &&
       [ "$VALIDATION_SHA_BEFORE" = "$VALIDATION_SHA_AFTER" ] &&
       [ -n "$GORTEX_GOWORK_SHA_BEFORE" ] && [ "$GORTEX_GOWORK_SHA_BEFORE" = "$GORTEX_GOWORK_SHA_AFTER" ]; then
        HASH_INVARIANT_ST=0
    else
        HASH_INVARIANT_ST=1
        FINAL_STATUS=1
    fi
    [ "$CLEANUP_STATUS" = pass ] || FINAL_STATUS=1
    write_evidence || FINAL_STATUS=1
    if [ "$FINAL_STATUS" -eq 0 ] && [ "$ENTRY_STATUS" -eq 0 ]; then exit 0; fi
    [ "$ENTRY_STATUS" -ne 0 ] && exit "$ENTRY_STATUS"
    exit 1
}
trap cleanup EXIT INT TERM

fail() { report "closeout: FAIL - $1"; FINAL_STATUS=1; exit 1; }
run_gate() { GATE_NAME="$1"; shift; report "closeout: running $GATE_NAME"; "$@"; return $?; }
require_plan_range() {
    RANGE_NAME="$1"; RANGE_VALUE="$2"; shift 2
    [ -n "$RANGE_VALUE" ] && git -C "$TOP_DIR" rev-list "$RANGE_VALUE" >/dev/null 2>&1 || fail "$RANGE_NAME could not be resolved"
    RANGE_COMMITS=$(git -C "$TOP_DIR" rev-list "$RANGE_VALUE")
    for REQUIRED_COMMIT in "$@"; do
        REQUIRED_FULL=$(git -C "$TOP_DIR" rev-parse "$REQUIRED_COMMIT" 2>/dev/null) || fail "$RANGE_NAME listed commit could not be resolved"
        printf '%s\n' "$RANGE_COMMITS" | grep -qx "$REQUIRED_FULL" || fail "$RANGE_NAME omits an implementation commit listed in its summary"
    done
}
capture_differential_aggregates() {
    AGG_PREFIX="$1"; AGG_LOG="$2"; AGG_REDACTED="$3"
    redact_differential_log "$AGG_LOG" "$AGG_REDACTED" || fail "$AGG_PREFIX differential output could not be reduced safely"
    AGG_SELECTOR=$(extract_line "$AGG_REDACTED" '^snapshot: (estate selector|discovered_files=)')
    AGG_SNAPSHOTS=$(grep -E '^snapshot: files_walked=' "$AGG_REDACTED" 2>/dev/null)
    AGG_BEFORE=$(printf '%s\n' "$AGG_SNAPSHOTS" | sed -n '1p')
    AGG_AFTER=$(printf '%s\n' "$AGG_SNAPSHOTS" | sed -n '2p')
    AGG_COMPARE=$(extract_line "$AGG_REDACTED" '^SUMMARY:')
    AGG_RECLASSIFIED=$(extract_line "$AGG_REDACTED" '^RECLASSIFIED_COUNT:')
    AGG_CONVERTED=$(extract_line "$AGG_REDACTED" '^CONVERTED_COUNT:')
    AGG_NEW=$(extract_line "$AGG_REDACTED" '^NEW_COUNT:')
    if [ "$AGG_PREFIX" = DCC ]; then
        DCC_SELECTOR_SUMMARY="$AGG_SELECTOR"; DCC_BEFORE_SUMMARY="${AGG_BEFORE:-missing}"; DCC_AFTER_SUMMARY="${AGG_AFTER:-missing}"
        DCC_COMPARE_SUMMARY="$AGG_COMPARE"; DCC_RECLASSIFIED="$AGG_RECLASSIFIED"; DCC_CONVERTED="$AGG_CONVERTED"; DCC_NEW="$AGG_NEW"
    else
        ESTATE_SELECTOR_SUMMARY="$AGG_SELECTOR"; ESTATE_BEFORE_SUMMARY="${AGG_BEFORE:-missing}"; ESTATE_AFTER_SUMMARY="${AGG_AFTER:-missing}"
        ESTATE_COMPARE_SUMMARY="$AGG_COMPARE"; ESTATE_RECLASSIFIED="$AGG_RECLASSIFIED"; ESTATE_CONVERTED="$AGG_CONVERTED"; ESTATE_NEW="$AGG_NEW"
    fi
}

cd "$TOP_DIR" || fail "target worktree is unavailable"
[ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$TOP_DIR" ] || fail "must run from the target worktree"
[ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = agent-02-closeout ] || fail "target branch must be agent-02-closeout"
[ -n "$CURRENT_REF" ] || fail "current implementation ref could not be resolved"
[ -d "$TEMP_PARENT" ] && [ -w "$TEMP_PARENT" ] || fail "approved external temporary parent is unavailable"
[ -r "$DCC_ROOT" ] || fail "DCC corpus is required at $DCC_ROOT"
DCC_ROOT=$(cd -P "$DCC_ROOT" 2>/dev/null && pwd) || fail "DCC corpus root could not be canonicalized"
case "$DCC_ROOT" in
    "$TOP_DIR"|"$TOP_DIR"/*) fail "DCC root must remain outside the target worktree" ;;
esac
if [ ! -d "$ESTATE_ROOT/endevor" ]; then
    fail "Set ESTATE_ROOT to the approved existing copied estate outside the target worktree; do not copy proprietary content into this repository."
fi
[ ! -L "$ESTATE_ROOT" ] || fail "ESTATE_ROOT must name the approved copied estate itself, not another symlink"
ESTATE_ROOT=$(cd -P "$ESTATE_ROOT" 2>/dev/null && pwd) || fail "estate root could not be canonicalized"
case "$ESTATE_ROOT" in
    "$TOP_DIR"|"$TOP_DIR"/*) fail "estate root must remain outside the target worktree" ;;
esac
[ -d "$GORTEX_ROOT" ] || fail "gortex is required at $GORTEX_ROOT"
[ -f "$GORTEX_GOWORK_FILE" ] || fail "gortex go.work is unavailable for integrity verification"
[ -x "$TOP_DIR/node_modules/.bin/tree-sitter" ] || fail "lockfile-pinned tree-sitter CLI is unavailable"
[ -x "$TOP_DIR/run_accept_differential_selftest.sh" ] || fail "differential self-test is not executable"
TREE_SITTER="$TOP_DIR/node_modules/.bin/tree-sitter"
export TREE_SITTER

SECURITY_SHA_BEFORE=$(shasum -a 256 "$SECURITY_FILE" | cut -d' ' -f1)
VERIFICATION_SHA_BEFORE=$(shasum -a 256 "$VERIFICATION_FILE" | cut -d' ' -f1)
VALIDATION_SHA_BEFORE=$(shasum -a 256 "$VALIDATION_FILE" | cut -d' ' -f1)
GORTEX_GOWORK_SHA_BEFORE=$(shasum -a 256 "$GORTEX_GOWORK_FILE" | cut -d' ' -f1)
[ -n "$SECURITY_SHA_BEFORE" ] && [ -n "$VERIFICATION_SHA_BEFORE" ] && [ -n "$VALIDATION_SHA_BEFORE" ] && [ -n "$GORTEX_GOWORK_SHA_BEFORE" ] || fail "integrity hashes could not be captured"

TASK_TMP=$(mktemp -d "$TEMP_PARENT/02-11-closeout.XXXXXX") || fail "could not create task scratch"
NIST_CAPTURE="$TASK_TMP/nist.out"
EXPECTED_SKIPS="$TASK_TMP/expected-skips.txt"
ACTUAL_SKIPS="$TASK_TMP/actual-skips.txt"
NIST_SUMMARY_BACKUP="$TASK_TMP/nist-summary.before"
NIST_RESULT_BACKUP="$TASK_TMP/nist-result.before"
TMPDIR="$TASK_TMP"
export TMPDIR
if [ -f "$TOP_DIR/test/cobol85/summary.txt" ]; then
    cp "$TOP_DIR/test/cobol85/summary.txt" "$NIST_SUMMARY_BACKUP" || fail "could not preserve pre-run NIST summary"
    NIST_SUMMARY_EXISTED=1
fi
if [ -d "$TOP_DIR/test/cobol85/result" ]; then
    cp -R "$TOP_DIR/test/cobol85/result" "$NIST_RESULT_BACKUP" || fail "could not preserve pre-run NIST results"
    NIST_RESULT_EXISTED=1
fi

run_gate "differential adversarial self-test" bash run_accept_differential_selftest.sh; FAST_DIFFERENTIAL_ST=$?
[ "$FAST_DIFFERENTIAL_ST" -eq 0 ] || fail "fast differential self-test failed"
run_gate "exact source query" ./run_idms_query_capture.sh; QUERY_ST=$?
[ "$QUERY_ST" -eq 0 ] || fail "exact source query gate failed"
run_gate "refresh self-test" ./forest-shim/refresh-selftest.sh; REFRESH_ST=$?
[ "$REFRESH_ST" -eq 0 ] || fail "refresh self-test failed"
run_gate "source/shim query identity" cmp queries/idms.scm forest-shim/cobol/idms.scm; SOURCE_SHIM_CMP_ST=$?
[ "$SOURCE_SHIM_CMP_ST" -eq 0 ] || fail "source/shim query identity failed"
IDMS_QUERY_FILE="$TOP_DIR/forest-shim/cobol/idms.scm" ./run_idms_query_capture.sh; SHIM_QUERY_ST=$?
[ "$SHIM_QUERY_ST" -eq 0 ] || fail "exact shim query gate failed"
(cd "$TOP_DIR/forest-shim/cobol" && IDMS_SOURCE_QUERY="$TOP_DIR/queries/idms.scm" go test ./...); SHIM_GO_ST=$?
[ "$SHIM_GO_ST" -eq 0 ] || fail "shim Go tests failed"

TEMP_WORKTREE=$(mktemp -d "$TEMP_PARENT/02-11-estate-worktree.XXXXXX") || fail "could not reserve detached worktree path"
rmdir "$TEMP_WORKTREE" || fail "could not prepare detached worktree path"
git worktree add --detach "$TEMP_WORKTREE" "$CURRENT_REF" >/dev/null || fail "could not create detached current-ref worktree"
# The closeout's physical symlink-root fix is uncommitted until this task's
# atomic commit, so mirror that one harness file into the detached current-ref
# worktree. No corpus byte or other implementation file is copied.
cmp "$TOP_DIR/run_accept_differential.sh" "$TEMP_WORKTREE/run_accept_differential.sh" >/dev/null 2>&1 ||
    cp "$TOP_DIR/run_accept_differential.sh" "$TEMP_WORKTREE/run_accept_differential.sh" || fail "could not stage the current differential harness in the detached worktree"
ln -s "$ESTATE_ROOT" "$TEMP_WORKTREE/estate" || fail "could not create detached-worktree estate link"
[ -L "$TEMP_WORKTREE/estate" ] || fail "estate input is not the detached-worktree symlink"

# Source only the selector function, so population checks happen before either
# full differential. The sourced script has no dispatch side effect.
ESTATE_PREFLIGHT_TMP=$(mktemp -d) || fail "could not create selector preflight scratch"
ESTATE_TMP="$ESTATE_PREFLIGHT_TMP"
sed '/^# Dispatch$/,$d' "$TEMP_WORKTREE/run_accept_differential.sh" > "$TASK_TMP/differential-functions.sh" || fail "could not isolate selector functions"
(
    cd "$TEMP_WORKTREE" || exit 1
    . "$TASK_TMP/differential-functions.sh"
    TOP_DIR="$TEMP_WORKTREE"
    prepare_accept_paths "$TEMP_WORKTREE/estate" "$ESTATE_PREFLIGHT_TMP/selected-paths.bin" '' 0
) > "$TASK_TMP/estate-preflight.raw" 2>&1
ESTATE_PREFLIGHT_ST=$?
[ "$ESTATE_PREFLIGHT_ST" -eq 0 ] || fail "estate selector preflight failed"
ESTATE_PREFLIGHT_SELECTOR=$(grep -E '^snapshot: estate selector ' "$TASK_TMP/estate-preflight.raw" | tail -1)
printf '%s\n' "$ESTATE_PREFLIGHT_SELECTOR" | grep -q 'declared_cobol_members=3781 compilable_programs=1369' || fail "estate selector did not match 3781/1369"
printf '%s\n' "$ESTATE_PREFLIGHT_SELECTOR" | grep -q 'statements=2391 selection_failures=0' || fail "estate selector did not match the 2391 ACCEPT denominator"
rm -rf "$ESTATE_PREFLIGHT_TMP"; ESTATE_TMP=""

DCC_TMP=$(mktemp -d) || fail "could not create DCC scratch"
DIFF_TMP="$DCC_TMP" sh run_accept_differential.sh run "$BASELINE_REF" "$DCC_ROOT" > "$TASK_TMP/dcc.raw" 2>&1; DCC_ST=$?
capture_differential_aggregates DCC "$TASK_TMP/dcc.raw" "$TASK_TMP/dcc.aggregate"
[ "$DCC_ST" -eq 0 ] || fail "DCC differential failed"

ESTATE_TMP=$(mktemp -d) || fail "could not create estate scratch"
DIFF_TMP="$ESTATE_TMP" sh "$TEMP_WORKTREE/run_accept_differential.sh" run "$BASELINE_REF" "$TEMP_WORKTREE/estate" > "$TASK_TMP/estate.raw" 2>&1; ESTATE_ST=$?
capture_differential_aggregates ESTATE "$TASK_TMP/estate.raw" "$TASK_TMP/estate.aggregate"
[ "$ESTATE_ST" -eq 0 ] || fail "estate differential failed"
printf '%s\n' "$ESTATE_SELECTOR_SUMMARY" | grep -q 'declared_cobol_members=3781 compilable_programs=1369' || fail "estate evidence omitted 3781/1369"
printf '%s\n' "$ESTATE_SELECTOR_SUMMARY" | grep -q 'statements=2391 selection_failures=0' || fail "estate evidence omitted 2391"

run_gate "focused IDMS corpus" node_modules/.bin/tree-sitter test -i 'idms'; FOCUSED_ST=$?
[ "$FOCUSED_ST" -eq 0 ] || fail "focused IDMS corpus failed"
run_gate "full non-comment corpus" node_modules/.bin/tree-sitter test -e '^comment$'; FULL_CORPUS_ST=$?
[ "$FULL_CORPUS_ST" -eq 0 ] || fail "full non-comment corpus failed"
sh run_nist_cobol85.sh > "$NIST_CAPTURE" 2>&1; NIST_ST=$?
[ "$NIST_ST" -eq 0 ] || fail "NIST runner failed"
if [ "$(tail -1 "$NIST_CAPTURE")" = "382 tests. (Success: 371, Fail: 0, Skip: 11)" ]; then NIST_FINAL_LINE="PASS (exact match)"
else NIST_FINAL_LINE="FAIL (mismatch)"; fail "NIST final line did not match"
fi
printf '%s\n' NC205A SM101A SM103A SM105A SM107A SM201A SM203A SM205A SM206A SM208A SM401M | sort > "$EXPECTED_SKIPS"
grep -v '^[[:space:]]*$' skip_tests.txt | sort > "$ACTUAL_SKIPS"
if [ "$(wc -l < "$ACTUAL_SKIPS" | tr -d ' ')" -eq 11 ] && cmp "$EXPECTED_SKIPS" "$ACTUAL_SKIPS" >/dev/null 2>&1; then NIST_ALLOWLIST_ST=0
else NIST_ALLOWLIST_ST=1; fail "NIST skip allowlist differs from the canonical 11 entries"
fi

TMP_GOWORK_DIR=$(mktemp -d) || fail "could not create isolated GOWORK scratch"
(cd "$TMP_GOWORK_DIR" && GOWORK=off go work init "$GORTEX_ROOT" "$EXPECTED_SHIM_DIR"); GOWORK_INIT_ST=$?
[ "$GOWORK_INIT_ST" -eq 0 ] || fail "isolated go work init failed"
(cd "$GORTEX_ROOT" && GOWORK="$TMP_GOWORK_DIR/go.work" go list -m -json github.com/alexaandru/go-sitter-forest/cobol) > "$TASK_TMP/gowork-module.json"; GOWORK_LIST_ST=$?
[ "$GOWORK_LIST_ST" -eq 0 ] || fail "isolated GOWORK module listing failed"
GOWORK_DIR=$(python3 - "$TASK_TMP/gowork-module.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    print(json.load(stream).get("Dir", ""))
PY
)
if [ "$GOWORK_DIR" = "$EXPECTED_SHIM_DIR" ]; then GOWORK_RESOLUTION_ST=0
else GOWORK_RESOLUTION_ST=1; fail "isolated GOWORK resolved COBOL outside the target shim"
fi
(cd "$GORTEX_ROOT" && GOWORK="$TMP_GOWORK_DIR/go.work" go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -count=2 -args -enhanced-parser); CASCADE_ST=$?
[ "$CASCADE_ST" -eq 0 ] || fail "target-shim cascade failed"

require_plan_range RANGE_02_07 "$RANGE_02_07" 6bbdd47 e281264 fc7f826 13713f3 8ef8c1b
require_plan_range RANGE_02_08 "$RANGE_02_08" 7256b32 c32f413 909ca09
require_plan_range RANGE_02_09 "$RANGE_02_09" 8f5f0a9 3adaba8 39eea73
require_plan_range RANGE_02_10 "$RANGE_02_10" 6298669 a4f122d
RANGE_VALIDATION_ST=0
for PLAN_NUM in 02_07 02_08 02_09 02_10; do
    eval RANGE_VALUE=\$RANGE_${PLAN_NUM}
    sh .githooks/commit-separability.sh --range "$RANGE_VALUE"; SEP_STATUS=$?; eval SEP_${PLAN_NUM}_ST=$SEP_STATUS
    [ "$SEP_STATUS" -eq 0 ] || fail "commit separability failed for ${PLAN_NUM}"
    sh .githooks/estate-guard.sh --range "$RANGE_VALUE"; GUARD_STATUS=$?; eval ESTATE_GUARD_${PLAN_NUM}_ST=$GUARD_STATUS
    [ "$GUARD_STATUS" -eq 0 ] || fail "estate guard failed for ${PLAN_NUM}"
done
run_gate "estate guard self-test" bash .githooks/estate-guard-selftest.sh; ESTATE_GUARD_SELFTEST_ST=$?
[ "$ESTATE_GUARD_SELFTEST_ST" -eq 0 ] || fail "estate guard self-test failed"

FINAL_STATUS=0
report "closeout: PASS - raw aggregate evidence complete; independent verdict gates remain mandatory"
exit 0
