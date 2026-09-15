---
phase: 04
slug: exec-sql-blocks
status: complete
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-12
updated: 2026-09-14
---

# Phase 04 -- Validation Strategy

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | Tree-sitter 0.24.5 corpus/query runner, shell gates, Go test |
| Quick command | `node_modules/tree-sitter-cli/tree-sitter test -e '^comment$'` |
| Full suite | Plan 04-08 Task 3 closing behavioral gates |
| Feedback | Task-local gates under 60 seconds; estate differential and NIST at closeout |

## FORK-02 / FORK-03 enforcement

FORK-02 (estate leak) and FORK-03 (commit separability) are enforced by the already
installed `.githooks/pre-push` hook -- `git config core.hooksPath` is `.githooks`, and the
hook runs `estate-guard-selftest.sh`, `estate-guard.sh --remote`, and
`commit-separability.sh --range` for every ref update on every push. This is the same
mechanism Phases 1 through 3 relied on. Phase 4 adds no range-evidence artifact, no
summary-commit parser, and no commit-history audit plan.

The per-task discipline that makes the hook pass is that each executor commit touches
exactly one path family:

- grammar family: `grammar.js`, `src/`, `test/corpus/`, `queries/`
- fork-local: `forest-shim/`, `docs/`, `.planning/`, `.githooks/`, `run_*.sh`,
  `.github/workflows/fork-checks.yml`
- the gortex repository, committed only there

The single cross-repo check is scoped and local: Plan 04-07 Task 2 asserts, from the
gortex worktree, that the most recent commit touching `cascade_test.go` changed only that
path. No ranges are persisted.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Artifact created/used | Automated command |
|---|---:|---:|---|---|---|
| 04-01-01 | 01 | 1 | SQL-01, SQL-02, SQL-07 | records the D-01 granularity decision; creates `test/corpus/exec_sql.txt` and generated `src/` | `tree-sitter generate && tree-sitter test -e '^comment$'` |
| 04-01-02 | 01 | 1 | SQL-03, SQL-07 | creates `queries/sql.scm` with `(exec_sql_statement) @statement` plus direct table/alias/CTE/source-candidate captures | regenerate, compile, and require statement plus role capture output |
| 04-03-01 | 03 | 1 | SQL-06, SQL-07 | modifies the estate-safe isolated differential and its selftest | `sh run_accept_differential_selftest.sh` |
| 04-03-02 | 03 | 1 | SQL-06, SQL-07 | parameterizes corpus path selection with a caller-supplied source-TEXT prefilter distinct from the node regex, adds `--no-prefilter`, and makes the named estate branch's ACCEPT denominator gate conditional | `sh run_accept_differential_selftest.sh` with a fail-first case for a collision-bearing ACCEPT-free file selected through the real selection function |
| 04-03-03 | 03 | 1 | SQL-06, SQL-07 | directly checks default/custom node regex, default/custom text prefilter, invalid inputs, and scratch isolation | selftest plus two separate `sh -n` invocations |
| 04-02-01 | 02 | 2 | SQL-03, SQL-07 | assigns every role to the unique smallest enclosing @statement `(row, column)` range and performs same-statement CTE subtraction | gate covers adjacent same-name statements, nested subqueries, boundaries, no/multiple containers, outside positions, and overlapping sibling ranges |
| 04-02-02 | 02 | 2 | SQL-03, SQL-07 | directly checks text, `(row, column)` positions, multiplicity, ordering, and exclusions for roles available after 04-01; exposes extension points used by 04-04/04-05 | query gate plus `sh -n` |
| 04-02-03 | 02 | 2 | SQL-07 | widens `.githooks/commit-separability.sh` `FORKLOCAL_PATH_RE` additively to `^run_accept_differential\|^run_[a-z0-9_]*\.(sh\|c)$` in a fork-local commit so the hook rejects grammar-plus-`run_*` mixed commits without dropping the tracked `run_accept_differential_helper.c` or the digit-bearing `run_nist_cobol85.sh` | `sh -n` plus a synthetic throwaway-repo range proven PASS before and FAIL after the change, plus a `grammar.js` + `run_accept_differential_helper.c` range required FAIL both before and after, with unconditional scratch cleanup |
| 04-04-01 | 04 | 3 | SQL-02, SQL-07 | directly checks DATA marker nodes and intact data descriptions | generate plus corpus |
| 04-04-02 | 04 | 3 | SQL-02, SQL-03, SQL-07 | creates `sql_include_name`, regenerates the grammar, checks include placement and tree positions, and adds the compiled direct include role in one grammar-family commit | regenerate, corpus, then compile/run the query |
| 04-04-03 | 04 | 3 | SQL-03, SQL-07 | separately modifies fork-local `run_sql_query_capture.sh` to activate exact include text/count/position and negative raw-`@table`/physical-table assertions | regenerate, compile query, exact query gate, `sh -n` |
| 04-05-01 | 05 | 4 | SQL-02, SQL-03, SQL-07 | directly checks static DML/DDL nodes with exact corpus trees; physical-table output is asserted by 04-05-03, not here | generate, corpus, existing query gate as a no-regression check |
| 04-05-02 | 05 | 4 | SQL-02, SQL-03, SQL-07 | creates `sql_dynamic_source`, regenerates the grammar, checks dynamic and tail tree positions, and adds the compiled direct dynamic-source role in one grammar-family commit | regenerate, corpus, then compile/run the query |
| 04-05-03 | 05 | 4 | SQL-03, SQL-07 | separately modifies fork-local `run_sql_query_capture.sh` to add exact expected physical-table records -- text, count, source order, start/end `(row, column)` -- for every D-04 form from 04-05-01 including nested-subquery and MERGE USING sources, plus negative alias assertions | regenerate, compile query, exact query gate, `sh -n` |
| 04-05-04 | 05 | 4 | SQL-03, SQL-07 | separately modifies fork-local `run_sql_query_capture.sh` to activate exact dynamic-source text/count/position and negative raw-`@table`/physical-table assertions | regenerate, compile query, exact query gate, `sh -n` |
| 04-06-01 | 06 | 5 | SQL-07 | directly checks separable parser/query delivery through the shim | refresh, byte comparison, SQL-node checks |
| 04-06-02 | 06 | 5 | SQL-07 | directly checks deterministic, path-limited shim delivery | repeat refresh and diff-scope check |
| 04-07-01 | 07 | 6 | SQL-04, SQL-07 | adds the procedure and DATA DIVISION SQL cascade fixtures in gortex and observes parity against the immutable clean control | `go test ... -run TestErrorCascade -v -count=2` |
| 04-07-02 | 07 | 6 | SQL-04, SQL-07 | enforces fail-first cascade parity in a gortex-only commit | scoped single-commit path check on `cascade_test.go`, then the exact cross-repo Go test |
| 04-08-01 | 08 | 7 | SQL-01, SQL-03, SQL-07 | directly reconciles independent expected anchors with final physical-table results and emits privacy-safe aggregates | census selftest, OCESQL census, render, all in fresh `mktemp -d` scratch |
| 04-08-02 | 08 | 7 | SQL-06, SQL-07 | validates explicit DCC and estate corpus roots, derives the pre-Phase-4 baseline from the commit that added `test/corpus/exec_sql.txt`, and runs both differentials with an explicit SQL/collision source-TEXT prefilter | directory validation with named-halt, baseline `rev-parse --verify`, census render, and two four-argument `run_accept_differential.sh run` calls (node regex plus text prefilter) each with its own fresh `mktemp -d` DIFF_TMP; the estate run is recorded as entering the named estate branch with its ACCEPT denominator gate suppressed and its measured denominator recorded |
| 04-08-03 | 08 | 7 | SQL-02, SQL-03, SQL-04, SQL-06, SQL-07 | captures the closing behavioral gates and NIST output | preserved runner exit status, final line exactly `382 tests. (Success: 371, Fail: 0, Skip: 11)`, exact ordered 11-name allowlist after excluding blank/whitespace-only lines and rejecting nonblank comments/duplicates/replacements/extras, unchanged skip file, corpus/query/refresh/cascade commands |

## Wave 0 Artifact Linkage

| Artifact | Creator | First dependent verification |
|---|---|---|
| `test/corpus/exec_sql.txt` | 04-01-01 | 04-01-02 raw query; 04-02 exact gate; all later corpus gates |
| `queries/sql.scm` | 04-01-02 initial @statement/table/alias/CTE/source-candidate contract; 04-04-02 include extension; 04-05-02 dynamic-source extension | 04-02 assigns roles by unique smallest enclosing statement `(row, column)` range; later gates activate staged roles |
| widened `.githooks/commit-separability.sh` fork-local family | 04-02-03 | every later fork-local `run_*.sh` commit in 04-04, 04-05, and 04-08 |
| `run_sql_query_capture.sh` | 04-02-01 initial gate; 04-04-03 include assertions; 04-05-03 static physical-table records for every D-04 form; 04-05-04 dynamic-source assertions | 04-02-02 initial-role checks, each staged role activation, and 04-08 behavioral closeout |
| SQL-regex differential support | 04-03-01 | 04-08-02 DCC and estate runs |
| custom text-prefilter path selection and conditional estate denominator | 04-03-02 | 04-08-02 DCC and estate runs |
| differential selftest coverage | 04-03-03 | 04-08-02 and 04-08-03 differential gates |
| refreshed `forest-shim/cobol/*` | 04-06-01 | 04-07-01 gortex observation and 04-08-03 cascade |
| gortex SQL cascade assertions | 04-07-02 | 04-08-03 cross-repo cascade gate |
| `run_sql_tail_census.sh` | 04-08-01 | 04-08-02 estate census and 04-08-03 report verification |
| `docs/sql-tail-census.md` | 04-08-01/02/03 | 04-08-03 `--verify-report` |

## Multi-Source Coverage Audit

| Source | ID | Coverage | Plans | Status |
|---|---|---|---|---|
| GOAL | Phase 4 | Walkable EXEC SQL nodes with queryable DB2 names at deliberate granularity | 01-08 | COVERED |
| REQ | SQL-01 | Granularity decision before grammar | 01, 08 | COVERED |
| REQ | SQL-02 | Accurate named EXEC SQL nodes | 01, 04, 05, 06, 08 | COVERED |
| REQ | SQL-03 | Queryable physical DB2 table names | 01, 02, 04, 05, 08 | COVERED |
| REQ | SQL-04 | Paragraph/data-item cascade parity | 06, 07, 08 | COVERED |
| REQ | SQL-05 | Retired/unmeasurable, no substitute recall | 01, 02, 03, 04, 05, 07 | COVERED (retired) |
| REQ | SQL-06 | Corpus/NIST and regression gates | 03, 08 | COVERED |
| REQ | SQL-07 | Estate-safe separable delivery via the installed pre-push hook (fork-local family widened in 04-02-03) plus one-family per-task commits | 01-08 | COVERED |
| RESEARCH | Architecture | Bounded grammar, direct query, exact fork-local gate, isolated differential, shim delivery | 01-08 | COVERED |
| RESEARCH | Constraint | No new packages; generated files only through CLI/refresh | 01, 04, 05, 06 | COVERED |
| CONTEXT | D-01--D-03 | Bounded generic statement and limited semantic roles | 01, 05 | COVERED |
| CONTEXT | D-04--D-08 | Static tables, whole names, aliases, exclusions, dynamic source | 01, 02, 05 | COVERED |
| CONTEXT | D-09--D-12 | Both placements, markers, sibling data items, generic include | 04 | COVERED |
| CONTEXT | D-13--D-15 | Named bounded tail, complete census, invented fixtures | 01, 04, 05, 08 | COVERED |
| CONTEXT | D-16--D-18 | Cascade, differential, direct query, explicit statement identity, safe scoped subtraction | 01, 02, 03, 06, 07, 08 | COVERED |

Deferred SQLX-01, richer semantic nodes, dynamic resolution, gortex query consumption, and
replacement recall remain excluded by CONTEXT.md.

## Sampling and Sign-Off

- After each grammar/query task: regenerate, run the full non-comment corpus, and compile the
  SQL query against the regenerated grammar.
- After each fork-local script task: regenerate and compile first, then run its exact capture
  gate and syntax check.
- Before gortex work: Plan 04-06 refresh must be green.
- At closure: 04-08 runs both differentials, the census, corpus and query gates, captured NIST,
  refresh/smoke, and cascade. There is no separate history-audit plan; FORK-02/FORK-03 are
  proven at push time by the installed hook.
- No manual-only verification and no watch-mode commands.
- SQL-05 has no executable recall gate; every reference must say retired/unmeasurable.

**Approval:** approved -- all mapped execution evidence passed on 2026-09-14
