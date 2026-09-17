---
phase: 2
slug: idms-dml-statement-nodes
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-29
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded by `/gsd-plan-phase 2` from `02-RESEARCH.md` § Validation Architecture.
> The Per-Task Verification Map is populated once PLAN.md task IDs exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | tree-sitter corpus tests (`test/corpus/*.txt`, source / `---` / expected s-expression) via the pinned CLI, plus `go test` in the external `gortex` repo for the `cobolprobe` gates |
| **Config file** | none — the corpus format is convention-based (no config file required beyond the optional `--config-path`) |
| **Quick run command** | `node_modules/.bin/tree-sitter test -i '<touched-fixture-name-regex>'` |
| **Full suite command** | `node_modules/.bin/tree-sitter test -e '^comment$' && sh run_nist_cobol85.sh` |
| **Estimated runtime** | quick: seconds. Full suite: not yet measured in-repo; the NIST runner dominates. Out-of-band gates are slower — DCC parse ~18s, the D-08 estate differential ~30 min one-off. |

**Pinned CLI:** `tree-sitter-cli` 0.24.5 was verified in the original planning checkout. `-i/--include` and
`-e/--exclude` take test-name regexes; `-e '^comment$'` was run this session and exits 0 with the
other 12 fixtures passing, while the unfiltered run exits 1. That is the exact mechanism D-11's
`.github/workflows/fork-checks.yml` uses to hold the corpus gate while the pre-existing upstream
`comment` fixture failure stays excluded and annotated. The gap-closure exact query gate does not use
`test/idms/query-sample.cbl`; it owns a temporary synthetic fixture outside tracked paths through
`run_idms_query_capture.sh`.

**Target-worktree qualification:** the historical verification above does not guarantee a fresh
worktree has `node_modules`. Plans 02-07…02-11 require
`node_modules/tree-sitter-cli/tree-sitter`; if absent, run lockfile-pinned `npm ci` as setup, then
assert exact 0.24.5. This restores an existing dependency only; no package is added.

---

## Sampling Rate

- **After every task commit:** Run `node_modules/.bin/tree-sitter test -i '<touched fixture>'`
- **After every plan wave:** Run `node_modules/.bin/tree-sitter test -e '^comment$'` then `sh run_nist_cobol85.sh`
- **Before independent Phase 2 verification:** Full suite green, **plus** all three out-of-band gates:
  1. the D-08 differential script on both corpora (zero `accept_statement` reclassifications — hard gate),
  2. a `cobolprobe` recall re-run through the regenerated shim (grammar-alone `dataItems` for D-13's ratio),
  3. `TestErrorCascade` with an IDMS DML case (IDMS-04).
- **Max feedback latency:** seconds for the in-repo corpus loop; the three out-of-band gates are
  deliberately phase-gate-only, not per-commit (D-08 rejects wiring the differ into `pre-push` on cost).

---

## Per-Task Verification Map

*Seeded 2026-08-29 by `/gsd-plan-phase 2` now that PLAN.md task IDs exist. `/gsd-validate-phase 2`
audits this table and flips `status: validated`.*

| Plan / Task | Requirement | Automated verify |
|---|---|---|
| 02-01 T1 (tracer) | IDMS-01, IDMS-02 | `tree-sitter generate && tree-sitter test -i 'idms navigation'` + `tree-sitter query queries/idms.scm test/idms/query-sample.cbl` grepped for both operand names |
| 02-01 T2 | IDMS-01, IDMS-02 | `tree-sitter test -i 'idms navigation'` (9 cases) + `git diff --quiet src/scanner.c` + query determinism `diff <(q) <(q)` |
| 02-01 T3 | IDMS-06, IDMS-07 | `tree-sitter test -e '^comment$'` + `sh run_nist_cobol85.sh` + `skip_tests.txt` count = 11 + `estate-guard-selftest.sh` |
| 02-02 T1 | IDMS-03 | `bash run_accept_differential_selftest.sh` (6 cases, red-and-green directions) |
| 02-02 T2 | IDMS-06, IDMS-07 | `estate-guard-selftest.sh` + `git diff --quiet` on upstream workflows + `commit-separability.sh` red/green in a throwaway repo |
| 02-03 T1 | IDMS-01, IDMS-02 | `tree-sitter test -i 'idms update'` (8 cases) + single-definition check on `idms_record_name` |
| 02-03 T2 | IDMS-01, IDMS-02 | `tree-sitter test -i 'idms session'` (10 cases) + reused-terminal count = 3 |
| 02-03 T3 | IDMS-06, IDMS-07 | `tree-sitter test -e '^comment$'` + `tree-sitter test -i 'idms'` + NIST + `commit-separability.sh` |
| 02-04 T1 | IDMS-01, IDMS-03 | `tree-sitter test -i 'idms accept'` (6 cases, 3 of them ordinary COBOL) + pre/post parse-tree diff on the standard forms |
| 02-04 T2 | IDMS-02 | `tree-sitter query` across all four classes + capture counts + no hidden-rule reference |
| 02-04 T3 | IDMS-03, IDMS-06 | `run_accept_differential.sh run` on DCC **and** the estate, RECLASSIFIED = 0 + full suite + NIST |
| 02-05 T1 (RED) | IDMS-04 | `go test -run TestErrorCascade -v` in `gortex` against the **pre-refresh** shim, cascade present |
| 02-05 T2 | IDMS-02, IDMS-04 | `bash forest-shim/refresh.sh` + `cmp queries/idms.scm forest-shim/cobol/idms.scm` + idempotence re-run |
| 02-05 T3 (GREEN) | IDMS-04 | `go test -run TestErrorCascade -count=2 -v` with parity assertions; fails with `go.work` removed |
| 02-06 T1 | IDMS-05, IDMS-08 | `go test ./…/cobolprobe/ -v -timeout 20m -corpus <DCC> -neut-corpus <DCC>` + `snapshot … idms_unparsed_tail` census |
| 02-06 T2 | IDMS-08 | `checkpoint:decision` — human choice, no automated verify by design |
| 02-06 T3 | IDMS-05, IDMS-08 | `docs/baseline.md` §4 grep gates for both Phase 1 constants, the 14,455 gap, and the tail table |
| 02-06 T4 | IDMS-08, IDMS-07 | OQ-3 grep gates across ROADMAP/STATE + all four `### Phase` entries surviving |
| 02-07 T1 (tracer) | IDMS-03, IDMS-07 | `bash run_accept_differential_selftest.sh` — parent symlink, existing-final symlink, dangling-final symlink, DIFF_TMP symlink RED/GREEN cases |
| 02-07 T2 | IDMS-03, IDMS-07 | `bash run_accept_differential_selftest.sh` — strict four-column TSV, duplicate-before/both duplicate-after orderings, malformed NODE_TYPE_REGEX for snapshot/run, pipeline failure propagation (T-02-R04) |
| 02-07 T3 | IDMS-02, IDMS-07 | `bash -n run_idms_query_capture.sh && test -x run_idms_query_capture.sh && ./run_idms_query_capture.sh --expect-red=verbs` — mode 100755, exact CLI 0.24.5/setup distinction, gate-owned fixture, staged verb RED, role mismatches separately enumerated; interface `IDMS_QUERY_FILE` + optional caller-owned `IDMS_CAPTURE_OUT` |
| 02-08 T1 (tracer) | IDMS-01, IDMS-02, IDMS-07 | captured `tree-sitter test -i 'idms update'` output must fail only named `idms update invalid ...` cases; `run_idms_query_capture.sh --invalid-only` reproduces T-02-R05 |
| 02-08 T2 | IDMS-01, IDMS-02, IDMS-06, IDMS-07 | `tree-sitter generate && tree-sitter test -i 'idms update' && tree-sitter test -i 'idms' && ./run_idms_query_capture.sh --invalid-only` |
| 02-09 T1 (tracer) | IDMS-01, IDMS-02, IDMS-07 | `tree-sitter generate && tree-sitter test -i 'idms accept' && ./run_idms_query_capture.sh --expect-red=roles` — all 14 verbs exact, only enumerated role defects remain staged RED |
| 02-09 T2 | IDMS-01, IDMS-02, IDMS-06, IDMS-07 | `tree-sitter generate && tree-sitter test -i 'idms'` + two `IDMS_CAPTURE_OUT` normal gate runs byte-identical; ANY/DUPLICATE/FIRST/LAST/PRIOR/numeric/PAGE-INFO and syntax-grounded area/set/scope exact cases |
| 02-10 T1 (tracer) | IDMS-02, IDMS-07 | two normal `run_idms_query_capture.sh` runs under the same recorded gate SHA-256, byte-identical output |
| 02-10 T2 | IDMS-02, IDMS-07 | `bash -n forest-shim/{refresh.sh,refresh-selftest.sh} && ./forest-shim/refresh-selftest.sh && bash forest-shim/refresh.sh && cmp queries/idms.scm forest-shim/cobol/idms.scm && IDMS_QUERY_FILE=... ./run_idms_query_capture.sh && (cd forest-shim/cobol && go test ./...)` |
| 02-10 T3 | IDMS-02, IDMS-03, IDMS-06, IDMS-07 | direct differential self-test + exact gate + refresh self-test + source/shim query exercise + shim Go tests + non-comment corpus in CI command order |
| 02-11 T1 (tracer) | IDMS-01, IDMS-02, IDMS-03, IDMS-06, IDMS-07 | `bash .planning/phases/02-idms-dml-statement-nodes/02-11-closeout.sh` — fast gates, exact `DCC_TMP`/`ESTATE_TMP` runs at baseline 39886c7, `$TEMP_WORKTREE/estate` population 3781/1369/2391, NIST status/final line/allowlist, isolated target-shim GOWORK cascade, literal commit-range guards, raw evidence |
| 02-11 T2 (blocking-human) | independent security/verification/validation | automated file-state gate: `threats_open: 0` in `02-SECURITY.md`, verifier-owned non-gap status in `02-VERIFICATION.md`, then `/gsd-validate-phase 2` sets `status: validated` and `nyquist_compliant: true` |

**Sampling continuity:** no three consecutive tasks lack an `<automated>` verify. The only historical
task without one is 02-06 T2, a `checkpoint:decision`; the new 02-11 blocking-human gate carries an
automated file-state check.

**Gap-closure routing:** `02-VALIDATION.md` remains `status: draft`, `nyquist_compliant: false`, and
`wave_0_complete: false` during plans 02-07 through 02-11. After implementation and independent
security/verifier reruns, `/gsd-validate-phase 2` alone audits this map and may set validated/Nyquist
status. ROADMAP progress is reconciled by phase completion after those independent gates, never by
an executor edit.

*The requirement→test mapping this table must satisfy:*

| Req ID | Behavior | Test Type | Automated Command | File Exists |
|--------|----------|-----------|-------------------|-------------|
| IDMS-01 | All 14 verbs parse to named nodes, no ERROR | corpus | `tree-sitter test -i '<idms fixture>'` | ❌ W0 |
| IDMS-02 | Query captures record + set names | scripted query | `tree-sitter query queries/idms.scm <fixture>` | ❌ W0 |
| IDMS-03 | ACCEPT disambiguation, **zero** reclassification | corpus + differential | `tree-sitter test -i 'accept'` + D-08 differ | ❌ W0 |
| IDMS-04 | Cascade parity at an IDMS DML injection | go test (external `gortex`) | `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v` | ❌ W0 |
| IDMS-05 / IDMS-08 | Grammar-alone recall rises, tail does not grow, target set | go test (external `gortex`) | `go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m -corpus <DCC> -neut-corpus <DCC>` | ✅ exists |
| IDMS-06 | 12 fixtures pass (comment excluded), NIST ≤ 11 skips | corpus + shell | `tree-sitter test -e '^comment$'` + `sh run_nist_cobol85.sh` | ✅ exists |
| IDMS-07 | Separable commit, no site-specific naming, no estate excerpts | process + guard | `02-11-closeout.sh` runs literal-range commit-separability + estate guard; reviewer checks genericness | ✅ guards exist; closeout harness planned |

### Gap-Closure Requirement → Test Addendum (Plans 02-07…02-11)

| Req / Threat | Behavior | Canonical Automated Command | Planned Artifact |
|---|---|---|---|
| IDMS-03 / T-02-R01/R03/R04 | Symlink-safe paths, strict/unique TSV, malformed regex fail-closed | `bash run_accept_differential_selftest.sh` | `run_accept_differential_selftest.sh` expanded in 02-07 |
| IDMS-01/02 / T-02-R05 | Invalid update forms cannot become graph-bearing AST/captures | `node_modules/.bin/tree-sitter test -i 'idms update' && ./run_idms_query_capture.sh --invalid-only` | update corpus + exact gate |
| IDMS-01/02 / T-02-R06 | All 14 verbs exact; ANY/DUPLICATE/FIRST/LAST/PRIOR/numeric/PAGE-INFO and role semantics safe | `node_modules/.bin/tree-sitter test -i 'idms' && ./run_idms_query_capture.sh` | navigation/session/accept corpus + query gate |
| IDMS-02/03/06/07 | Shim query executable and all blocker gates continuous | `./forest-shim/refresh-selftest.sh && IDMS_QUERY_FILE="$PWD/forest-shim/cobol/idms.scm" ./run_idms_query_capture.sh && (cd forest-shim/cobol && go test ./...)` | refresh self-test, shim, CI |
| IDMS-01/02/03/06/07 | Full raw closeout evidence | `bash .planning/phases/02-idms-dml-statement-nodes/02-11-closeout.sh` | closeout harness + evidence |

---

## Wave 0 Requirements

Planner's resolution of each gap, with the owning plan and task:

- [ ] `test/corpus/idms_navigation.txt` / `idms_update.txt` / `idms_session.txt` — per-cluster split chosen over a single `idms_dml.txt`, matching the repo's per-topic convention. Owned by 02-01 T1/T2 and 02-03 T1/T2. Covers IDMS-01, IDMS-02.
- [ ] `test/corpus/idms_accept.txt` — the ACCEPT regression fixture, isolated in its own file because it is the phase's named regression gate and carries three ordinary-COBOL cases alongside the two IDMS ones. Owned by 02-04 T1. Covers IDMS-03.
- [ ] `test/idms/query-sample.cbl` — a hand-written subject for `tree-sitter query`, added so IDMS-02's check is a reproducible command rather than an ad-hoc scratch file. Owned by 02-01 T1, extended by 02-03 and 02-04 T2.
- [ ] `queries/idms.scm` — owned by 02-01 T1, completed across all four classes by 02-04 T2. Covers IDMS-02.
- [ ] `run_accept_differential.sh` + `run_accept_differential_selftest.sh` at repo root — the D-08 differential, with a self-test proving the comparison discriminates in both directions. Owned by 02-02 T1. Covers IDMS-03.
- [ ] `.github/workflows/fork-checks.yml` (fork-local, `main`-only, `-e '^comment$'`, annotated with upstream `4bc6ff5` and `.planning/WINDOWS.md`) — owned by 02-02 T2. Covers IDMS-06's CI enforcement per D-11.
- [ ] A `TestErrorCascade` IDMS DML injection case in the external `gortex` repo — **decided, not deferred**: planned as an explicitly marked cross-repo task, split red-then-green across 02-05 T1 (log-only case run against the pre-refresh shim, capturing the cascade baseline) and 02-05 T3 (parity assertions against the refreshed grammar). Covers IDMS-04.
- [ ] `forest-shim/refresh.sh` `queries/*.scm` carry-through — a gap this strategy did not originally list. `refresh.sh` copies no `.scm` file today and `forest-shim/cobol/plugin.go:25` embeds `grammar.json *.scm` from the shim directory only, so `queries/idms.scm` would exist in this fork and be invisible to gortex. Owned by 02-05 T2.
- [ ] `.githooks/commit-separability.sh` path families — a second unlisted gap: `GRAMMAR_PATH_RE` covers neither `^queries/` nor `^test/idms/`, so a commit mixing `queries/idms.scm` with `docs/` passes today. Owned by 02-02 T2. Covers IDMS-07's enforcement.

**Historical Wave 0 note -- resolved:** the original strategy observed no IDMS DML cascade case.
Plan 02-05 added the coordinated gortex cases and assertions; `02-05-SUMMARY.md` records RED/GREEN
and deterministic evidence. Gap-closure plan 02-11 reruns that existing gate through an isolated
GOWORK resolved to this target worktree shim.

---

## Judgment Verifications (Backstopped by Automation)

| Behavior | Requirement | Why Judgment Remains | Automated Backstop + Review Instructions |
|----------|-------------|------------|-------------------|
| Commit separability from fork-local changes | IDMS-07 (FORK-03) | Separability is a property of commit boundaries, not of any runnable artifact | Inspect `git log`/`git show` for the phase: the grammar commit(s) must touch only upstream-owned paths (`grammar.js`, `src/`, `test/corpus/`, `queries/`) and no fork-local path (`.githooks/`, `forest-shim/`, `docs/`, `.planning/`, the D-08 differ, `fork-checks.yml`). `.githooks/commit-separability.sh` assists but the boundary call is human. |
| No site-specific naming; every fixture hand-written | IDMS-07, D-10 | Requires judgment about whether a name is generic or estate-derived | Review every new fixture: names must be invented neutral constructs (e.g. `CUSTOMER-REC`, `CUST-ORDER-SET`) traceable to the published CA IDMS manual's generic shapes, never an estate excerpt or paraphrase. `.githooks/estate-guard.sh` catches literal leaks; genericness is the manual part. |
| Written cause on file for a recall miss | IDMS-08, D-15 | D-15 makes magnitude explained rather than gated | If grammar-alone rises but falls short of the allocated share, a written cause naming what absorbed it must exist on file before phase close. Non-blocking but mandatory. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency acceptable for the in-repo loop; out-of-band gates run at the phase gate only
- [ ] `nyquist_compliant: true` set in frontmatter
- [ ] Independent `/gsd-secure-phase 2` reports `threats_open: 0` before verifier rerun
- [ ] Independent Phase 2 verifier rerun completes before validate-phase approval

**Approval:** pending

**Required final route:** execute 02-07 → 02-11, stop at 02-11's blocking security checkpoint,
run `/gsd-secure-phase 2`, run the independent Phase 2 verifier, then run
`/gsd-validate-phase 2`. Only validate-phase may change this file's lifecycle fields; phase
completion reconciles ROADMAP progress afterward.
