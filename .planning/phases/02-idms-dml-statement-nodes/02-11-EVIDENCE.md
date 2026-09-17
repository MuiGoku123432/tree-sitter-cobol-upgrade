---
phase: 02-idms-dml-statement-nodes
plan: 11
task: 1
status: raw-evidence-only
baseline: 39886c7
implementation_ref: f061fed19f0ee4f6e7eb4fc98c05fea3d38be6a0
---

# Phase 02 Plan 11 Task 1 Raw Closeout Evidence

This file records commands, statuses, and aggregate counts only. It makes no
security, verification, or validation verdict. No proprietary file name,
relative path, source line, or inventory row is recorded.

## Canonical Invocation

`ESTATE_ROOT=<approved-external-copy> bash .planning/phases/02-idms-dml-statement-nodes/02-11-closeout.sh`

- Overall harness status: PASS (exit 0)
- Cleanup status: pass
- Baseline: `39886c7`
- Current implementation ref: `f061fed19f0ee4f6e7eb4fc98c05fea3d38be6a0`
- Harness status: PASS (exit 0)
- DCC status: PASS (exit 0)
- Estate status: PASS (exit 0)
- NIST status: PASS (exit 0)
- GOWORK cascade status: PASS (exit 0)
- Guard status: PASS (all range and self-test gates)
- Resolved DCC root: `/Users/e1001547-mbp-it/repos/mine/cobolCode/cam-corpus-dcc/DCC`
- Resolved estate root: `/private/var/folders/ks/sc4623gx7c144xx9_sxj53b00000gn/T/opencode/mainframe-consolidated-parser-assessment/mainframe-consolidated-20260827-134930/Users/e1001547-mbp-it/repos/mine/cobolCode/mainframe-consolidated`
- Estate differential input: exactly `$TEMP_WORKTREE/estate`

## Verdict Artifact Integrity

| Artifact | SHA-256 before | SHA-256 after | Result |
|---|---|---|---|
| `02-SECURITY.md` | `774c49cd6363d55141ba8438dfd2dbae9838a044af65b7e6537af7760818b5f4` | `774c49cd6363d55141ba8438dfd2dbae9838a044af65b7e6537af7760818b5f4` | unchanged |
| `02-VERIFICATION.md` | `4d6b9b112b1f745ee7cfcb661631ed06926e682fb16aaeab2ecc446cebf1da52` | `4d6b9b112b1f745ee7cfcb661631ed06926e682fb16aaeab2ecc446cebf1da52` | unchanged |
| `02-VALIDATION.md` | `c7af4ed7a3fa5d13dc208017c68040977ae15393e3e576202d282a2c16058217` | `c7af4ed7a3fa5d13dc208017c68040977ae15393e3e576202d282a2c16058217` | unchanged |

Hash invariant gate: PASS (exit 0)

## Fast Gates

| Gate | Exact command | Raw status |
|---|---|---|
| Differential adversarial self-test | `bash run_accept_differential_selftest.sh` | PASS (exit 0) |
| Symlink-root canonicalization regression | differential self-test plus `cd -P` before selector dispatch | PASS (exit 0) |
| Exact source query | `./run_idms_query_capture.sh` | PASS (exit 0) |
| Refresh self-test | `./forest-shim/refresh-selftest.sh` | PASS (exit 0) |
| Source/shim query identity | `cmp queries/idms.scm forest-shim/cobol/idms.scm` | PASS (exit 0) |
| Exact shim query | `IDMS_QUERY_FILE="$PWD/forest-shim/cobol/idms.scm" ./run_idms_query_capture.sh` | PASS (exit 0) |
| Shim Go tests | `(cd forest-shim/cobol && IDMS_SOURCE_QUERY="<target>/queries/idms.scm" go test ./...)` | PASS (exit 0) |

## Threat-Test Raw Status

| Threat | Raw executable evidence | Status |
|---|---|---|
| T-02-R01 | Symlink containment cases, including physical estate-root selection | PASS (exit 0) |
| T-02-R03 | Strict TSV, duplicate-key, regex, and extraction-failure cases | PASS (exit 0) |
| T-02-R05 | Focused IDMS corpus plus exact invalid-update query subject | PASS (both exit 0) |
| T-02-R06 | Exact source and delivered-shim all-14 capture gates | PASS (both exit 0) |

These are raw test outcomes only. The independent security workflow owns every
threat disposition and final closure decision.

## Differential Gates

`DCC_TMP=$(mktemp -d); DIFF_TMP="$DCC_TMP" sh run_accept_differential.sh run 39886c7 "$DCC_ROOT"; DCC_ST=$?`

`ESTATE_TMP=$(mktemp -d); DIFF_TMP="$ESTATE_TMP" sh "$TEMP_WORKTREE/run_accept_differential.sh" run 39886c7 "$TEMP_WORKTREE/estate"; ESTATE_ST=$?`

| Corpus | Status | Selector aggregate | Baseline aggregate | Current aggregate | Comparator aggregate | Reclassified | Converted | New |
|---|---|---|---|---|---|---|---|---|
| DCC | PASS (exit 0) | snapshot: discovered_files=606 selected_files=451 prefilter_failures=0 text_prefilter='(^|[^A-Za-z0-9-])ACCEPT([^A-Za-z0-9-]|$)' | snapshot: files_walked=451 files_failed_to_emit_tree=0 files_timed_out=0 files_with_parse_errors=448 files_zero_match=166 records_written=587 | snapshot: files_walked=451 files_failed_to_emit_tree=0 files_timed_out=0 files_with_parse_errors=448 files_zero_match=96 records_written=965 | SUMMARY: before=587 after=965 before_accept_statement=587 before_idms_accept_statement=0 before_clean=584 before_trailing_error=3 after_accept_statement=780 after_idms_accept_statement=185 | RECLASSIFIED_COUNT: 0 | CONVERTED_COUNT: 2 | NEW_COUNT: 378 |
| Approved copied estate | PASS (exit 0) | snapshot: estate selector declared_cobol_members=3781 compilable_programs=1369 selected_files=836 statements=2391 selection_failures=0 text_prefilter='(^|[^A-Za-z0-9-])ACCEPT([^A-Za-z0-9-]|$)' | snapshot: files_walked=836 files_failed_to_emit_tree=0 files_timed_out=0 files_with_parse_errors=792 files_zero_match=307 records_written=1065 | snapshot: files_walked=836 files_failed_to_emit_tree=0 files_timed_out=0 files_with_parse_errors=792 files_zero_match=215 records_written=1510 | SUMMARY: before=1065 after=1510 before_accept_statement=1065 before_idms_accept_statement=0 before_clean=1061 before_trailing_error=4 after_accept_statement=1316 after_idms_accept_statement=194 | RECLASSIFIED_COUNT: 0 | CONVERTED_COUNT: 2 | NEW_COUNT: 445 |

Estate selector preflight: PASS (exit 0). It requires
exactly 3,781 declared members, 1,369 compilable programs, and the default-mode
2,391 ACCEPT denominator before a full differential starts.

## Corpus and NIST Gates

| Gate | Exact command or invariant | Raw status |
|---|---|---|
| Focused IDMS corpus | `node_modules/.bin/tree-sitter test -i 'idms'` | PASS (exit 0) |
| Full non-comment corpus | `node_modules/.bin/tree-sitter test -e '^comment$'` | PASS (exit 0) |
| NIST runner | `sh run_nist_cobol85.sh` | PASS (exit 0) |
| NIST final line | `382 tests. (Success: 371, Fail: 0, Skip: 11)` | PASS (exact match) |
| Canonical 11-entry allowlist | sorted nonblank `skip_tests.txt` byte comparison | PASS (exit 0) |

## Isolated GOWORK Cascade

Commands:

- `(cd "/var/folders/ks/sc4623gx7c144xx9_sxj53b00000gn/T/tmp.Lx8IDNDBSs" && GOWORK=off go work init "/Users/e1001547-mbp-it/repos/mine/GoApps/gortex" "/Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-phase2-fixes/forest-shim/cobol")`
- `(cd "/Users/e1001547-mbp-it/repos/mine/GoApps/gortex" && GOWORK="/var/folders/ks/sc4623gx7c144xx9_sxj53b00000gn/T/tmp.Lx8IDNDBSs/go.work" go list -m -json github.com/alexaandru/go-sitter-forest/cobol)`
- `(cd "/Users/e1001547-mbp-it/repos/mine/GoApps/gortex" && GOWORK="/var/folders/ks/sc4623gx7c144xx9_sxj53b00000gn/T/tmp.Lx8IDNDBSs/go.work" go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -count=2 -args -enhanced-parser)`

| Gate | Raw status |
|---|---|
| `go work init <gortex> <target-worktree-shim>` | PASS (exit 0) |
| `GOWORK=<temporary-go.work> go list -m -json github.com/alexaandru/go-sitter-forest/cobol` | PASS (exit 0) |
| Module `.Dir` equals `/Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-phase2-fixes/forest-shim/cobol` | PASS (exit 0) |
| `GOWORK=<temporary-go.work> go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -count=2 -args -enhanced-parser` | PASS (exit 0) |

The temporary workspace is isolated from gortex's existing `go.work` and is
removed by the task-level cleanup trap. Existing `go.work` SHA-256 before and
after: `5e74467f52759bbbe8735597df618460db8ac1a0915ae60a96c363a1522a83f7` / `5e74467f52759bbbe8735597df618460db8ac1a0915ae60a96c363a1522a83f7`.

## Commit-Range Guards

| Plan | Inclusive range | Family | Separability | Estate guard |
|---|---|---|---|---|
| 02-07 | `d94517d3e25186dd1bcca82edd6b5b0a484ad7f6..8ef8c1b5caca293ed9dda81a62b96b0806f1c4dc` | fork-local | PASS (exit 0) | PASS (exit 0) |
| 02-08 | `46e94f5c584796d84f09b68615331e7c2d59d95a..909ca09d39b2acd181263aa116934560d5cfd549` | grammar | PASS (exit 0) | PASS (exit 0) |
| 02-09 | `844a487cbfa90b4094cbf475d0ffbeb3f89630b9..39eea735e92b46baa1d52460c569fee94ae30cbb` | grammar plus isolated fork-local gate | PASS (exit 0) | PASS (exit 0) |
| 02-10 | `8a59e91d5d0e7e8be302e44485aed27bbefc7413..a4f122dfd33f54bb23089cd018d7363c62699bdd` | fork-local | PASS (exit 0) | PASS (exit 0) |

- Estate guard self-test: PASS (exit 0)
- Listed-commit containment in literal ranges: PASS (exit 0)
- Guard commands run only after every implementation commit listed by each
  source summary is confirmed in its corresponding range.

## Independent Gates Required

Task 1 produces raw evidence only. Phase 2 remains blocked in this order:

1. `/gsd-secure-phase 2` must independently rewrite `02-SECURITY.md` with `threats_open: 0`.
2. The independent Phase 2 gsd-verifier must then rewrite `02-VERIFICATION.md`.
3. `/gsd-validate-phase 2` must then own lifecycle changes in `02-VALIDATION.md`.
