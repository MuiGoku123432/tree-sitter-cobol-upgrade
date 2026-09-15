---
phase: 3
slug: exec-cics-blocks
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-09
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `03-RESEARCH.md` § Validation Architecture. The planner fills the
> Per-Task Verification Map once task IDs exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (grammar)** | `tree-sitter test` (tree-sitter-cli 0.24.5) |
| **Framework (measurement)** | Go `testing`, in the gortex repo (`internal/parser/forest/cobolprobe/`) |
| **Config file** | `package.json` (`"test": "tree-sitter test"`); fixtures in `test/corpus/*.txt` |
| **Quick run command** | `node_modules/.bin/tree-sitter test -e '^comment$'` |
| **Full suite command** | `node_modules/.bin/tree-sitter test -e '^comment$' && sh run_nist_cobol85.sh` |
| **Estimated runtime** | quick ~seconds; full ~minutes; `-neut-corpus` probe up to 20m |

The `-e '^comment$'` exclusion is the pre-existing upstream corpus failure (12/13),
explicitly out of scope for this phase.

---

## Sampling Rate

- **After every task commit:** Run `node_modules/.bin/tree-sitter test -e '^comment$'`
- **After every plan wave:** Run `tree-sitter test -e '^comment$'`, then
  `forest-shim/refresh.sh`, then
  `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v`
- **Before `/gsd-verify-work`:** the above plus `sh run_nist_cobol85.sh`, the full
  `-neut-corpus` probe (20m timeout), and both differential runs (DCC + estate) green
- **Max feedback latency:** ~30 seconds at task granularity

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-T1 (tracer) | 03-01 | 1 | CICS-01, CICS-02, CICS-05 | T-03-01, T-03-02 | Fixtures invented/neutral (D-32); tail is a bounded `repeat()` | unit (corpus) + CLI query | `node_modules/.bin/tree-sitter generate && node_modules/.bin/tree-sitter test -e '^comment$' && sh run_cics_query_capture.sh && forest-shim/refresh.sh` | ❌ W0 → created by this task | ⬜ pending |
| 03-01-T2 | 03-01 | 1 | CICS-05 (D-31 prep), CICS-04 (D-26 prep) | T-03-01 | Continuation probe reads estate, writes no matched line | doc-assert | `test -f .planning/phases/03-exec-cics-blocks/03-FINDINGS.md && grep -qi 'pre-phase-2' … && grep -q 'NODE_TYPE_REGEX' …` | ❌ W0 → created by this task | ⬜ pending |
| 03-02-T1 | 03-02 | 2 | CICS-01, CICS-05 | T-03-02 | `cics_unparsed_tail` bounded, linear, terminator-safe | unit (corpus) | `node_modules/.bin/tree-sitter generate && node_modules/.bin/tree-sitter test -e '^comment$'` | ✅ (03-01) | ⬜ pending |
| 03-02-T2 | 03-02 | 2 | CICS-01, CICS-02, CICS-06 | T-03-01 | All operand fixtures invented/neutral | unit (corpus) | `node_modules/.bin/tree-sitter generate && node_modules/.bin/tree-sitter test -e '^comment$'` | ✅ (03-01) | ⬜ pending |
| 03-02-T3 | 03-02 | 2 | CICS-02, CICS-05 | T-03-03 | Shim Go surface untouched; no `refresh.sh` drift override | unit (fork-local CLI) | `sh run_cics_query_capture.sh && forest-shim/refresh.sh && node_modules/.bin/tree-sitter test -e '^comment$'` | ✅ (03-01) | ⬜ pending |
| 03-03-T1 | 03-03 | 3 | CICS-03 | T-03-01, T-03-04 | Injected shape names invented/neutral; refresh precondition asserted | integration (cross-repo) | `cd ~/repos/mine/GoApps/gortex && go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v` | ✅ | ⬜ pending |
| 03-03-T2 | 03-03 | 3 | CICS-03 | T-03-04 | Fail-first evidence recorded against pre-Phase-3 parser | integration (cross-repo) | `cd ~/repos/mine/GoApps/gortex && go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v -count=2` | ✅ | ⬜ pending |
| 03-04-T1 (D-26 baseline) | 03-04 | 4 | CICS-04 | T-03-01, T-03-04 | Tree + shim restored and re-refreshed; no estate path in `docs/` | manual-then-recorded | `test -f .git/PHASE3_PRE_CHECKOUT_HEAD && [ "$(git rev-parse HEAD)" = "$(cat .git/PHASE3_PRE_CHECKOUT_HEAD)" ] && forest-shim/refresh.sh && node_modules/.bin/tree-sitter test -e '^comment$' && grep -qi 'paragraph_header' docs/baseline.md` | ✅ tooling | ⬜ pending |
| 03-04-CP (D-16d) | 03-04 | 4 | CICS-04 | — | N/A | checkpoint:decision (one-way gate) | manual — human confirms D-16d against the reconstructed partition | n/a | ⬜ pending |
| 03-04-T2 | 03-04 | 4 | CICS-04, CICS-05 (incl. D-31) | T-03-01, T-03-04 | Differential output written outside repo root | integration | `node_modules/.bin/tree-sitter test -e '^comment$' && sh run_nist_cobol85.sh`; plus `./run_accept_differential.sh snapshot <DIR> <OUT> <REGEX>` then `compare <BEFORE> <AFTER>` on DCC **and** estate | ✅ | ⬜ pending |
| 03-04-T3 | 03-04 | 4 | CICS-04, CICS-06, IDMS-05 | T-03-01, T-03-05 | Every number attested with its verbatim raw log line | doc-assert + manual review | `grep -q '^- \[x\] \*\*IDMS-05\*\*' .planning/REQUIREMENTS.md && grep -q '^- \[x\] \*\*CICS-04\*\*' .planning/REQUIREMENTS.md && grep -qi 'paragraph_header' docs/baseline.md`; then `git show --stat` per commit against the four declared path constraints | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Planner instruction:** replace `_pending_` rows with real task IDs. Every task must map
to at least one row, and no 3 consecutive tasks may lack an automated verify.

**Filled 2026-09-09.** All 10 tasks + 1 checkpoint map to a row. Sampling continuity holds:
every task carries an `<automated>` verify; the only non-automated row is the `03-04-CP`
one-way reversibility checkpoint, which sits between two automated tasks.

---

## Wave 0 Requirements

- [x] `test/corpus/exec_cics.txt` — covers CICS-01. Must carry the four mandatory
      early-signal cases: (a) the **D-32 keyword-extraction proof** (`EXEC CICS
      READ/WRITE/DELETE/RETURN` alongside ordinary COBOL `READ`/`WRITE` in one file);
      (b) the `END-EXEC` vs `cics_unparsed_tail` boundary; (c) `EXEC SQL`
      no-regression; (d) a multi-line block. **Plan the D-32 case first** — everything
      else is built on the assumption it proves.
      → **Planned:** (a) in `03-01-T1` (the tracer, wave 1); (b) in `03-02-T1`;
      (c) and (d) in `03-02-T2`.
- [x] `queries/cics.scm` + a fork-local query-compile/capture test — covers CICS-02
      (four named captures: transaction, program, map, mapset)
      → **Planned:** `03-01-T1` creates the file and `run_cics_query_capture.sh` with the
      command capture; `03-02-T3` adds the four operand captures and the five-capture
      assertion. Route (a) from PATTERNS.md is taken — a CLI-based shell gate, because
      `forest-shim/cobol/go.mod` has zero dependencies and `refresh.sh` Step 5 hard-fails
      on drift, so a Go query test inside the shim cannot add a tree-sitter binding.
- [x] `cascade_test.go` edits in gortex (D-27 assertions `pa2 == pa` and `d2 == d`,
      D-28 four representative shapes) — covers CICS-03
      → **Planned:** `03-03-T1` lands the four shapes logged-only; `03-03-T2` turns them
      into eight blocking parity assertions. Two commits, per RESEARCH open question 4.
- [x] The exact `NODE_TYPE_REGEX` for the CICS differential — covers D-31.
      **Open:** Phase 2's `accept_statement` default would NOT detect the
      `READ`/`WRITE`/`DELETE`/`RETURN` reclassification D-31 exists to catch.
      → **Planned:** resolved and recorded in `03-01-T2`, consumed by `03-04-T2`.
- [x] The pre-Phase-2 commit SHA for the D-26 baseline reconstruction
      → **Planned:** derived and recorded in `03-01-T2` as the parent of the earliest
      Phase-2 `grammar.js` commit; consumed by `03-04-T1`.

No framework installation is needed — both frameworks are present and already running in CI.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Commit separability from fork-local changes (FORK-03) | CICS-06 | Separability is a review property of the commit graph, not an assertable runtime condition | `git show --stat` each commit; confirm the touched paths match the plan's per-commit path constraints, stated separately for (a) the docs amendment commit, (b) grammar commits, (c) fork-local gate commits, (d) cross-repo gortex commits |
| No site-specific naming in any fixture | CICS-06, D-32 | Requires human judgment on whether an invented name reads as estate-derived | Read every case in `test/corpus/exec_cics.txt`; confirm all names are invented and neutral |
| D-26 Phase 1 `paragraph_header` baseline | CICS-04 | A one-time historical reconstruction across a checkout boundary, recorded rather than re-run | Identify the pre-Phase-2 SHA, check it out, run `forest-shim/refresh.sh`, run the `-neut-corpus` probe, record the number in `docs/baseline.md` |
| `cics_unparsed_tail` census cause statement | D-30 | Non-blocking but mandatory: any tail at all requires a written cause naming what is in it | Report the census; write the cause |

---

## Security Domain (ASVS L1)

Most ASVS categories are structurally inapplicable — this phase produces a parser
grammar, not a network- or user-facing service.

| ASVS Category | Applies | Control |
|---------------|---------|---------|
| V5 Input Validation | **yes** | The grammar *is* the input validator. Malformed input must degrade to a bounded `cics_unparsed_tail`, never unbounded backtracking. `repeat()` over leaf tokens is linear |
| V14 Configuration / supply chain | **yes** | `npm ci` against the committed lockfile, never `npm install` — already enforced by `refresh.sh` Step 1 and CI. No new dependencies this phase |
| V2, V3, V4, V6 | no | — |

**T-03-01 (Information Disclosure):** proprietary estate source leaking into a public
fork. Mitigations already in place: `.git/info/exclude` for `estate/`, the pre-push
estate-leak guard, `run_accept_differential.sh`'s refusal to write an inventory under
the repo root, and D-32's invented-neutral-names rule for every fixture.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s at task granularity (`tree-sitter test -e '^comment$'` is seconds;
      the 20m `-neut-corpus` probe is a phase gate, not a task gate)
- [x] `nyquist_compliant: true` set in frontmatter — audited after execution

**Approval:** validated 2026-09-11 — all 10 tasks and the decision checkpoint have completed verification evidence; no missing test was found.

---

## Validation Audit 2026-09-11

| Metric | Count |
|--------|-------|
| Task/checkpoint rows audited | 11 |
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
| Automated requirement surfaces | 6/6 CICS requirements plus IDMS-05 closeout |

Evidence reviewed: 17 green CICS corpus fixtures; five-capture query gate; four-shape gortex cascade gate with RED/GREEN proof; Phase 1 reconstruction and Phase 3 recall measurement; DCC and estate zero-clean-reclassification differentials; NIST 371/0/11; zero-tail censuses; per-commit path review. Manual-only rows were executed during 03-04 and recorded in `03-FINDINGS.md`, `03-04-SUMMARY.md`, and `03-VERIFICATION.md`.

No test-generation task is needed. The per-task map above is retained as the seeded planning-time record; this audit and the frontmatter are authoritative for completed status.

---

## Plan Set (filled by gsd-planner 2026-09-09)

| Plan | Wave | Autonomous | Requirements | Scope |
|------|------|-----------|--------------|-------|
| `03-01-PLAN.md` | 1 | yes | CICS-01, CICS-02, CICS-05, CICS-06 | Tracer: D-32 keyword proof + one block end-to-end through the query; open-question resolution |
| `03-02-PLAN.md` | 2 | yes | CICS-01, CICS-02, CICS-05, CICS-06 | Full option/argument coverage, four operand nodes, tail, remaining fixtures, complete query |
| `03-03-PLAN.md` | 3 | yes | CICS-03, CICS-06 | gortex `cascade_test.go` — four shapes, then eight blocking parity assertions |
| `03-04-PLAN.md` | 4 | **no** (one-way checkpoint) | CICS-04, CICS-05, CICS-06, IDMS-05 | D-26 reconstruction, all gates, `docs/baseline.md` record, IDMS-05 + CICS-04 closure |

Waves are strictly sequential by design: plans 03-02/03-03/03-04 each read a parser state the
previous plan produced, and 03-04 performs a historical checkout that would corrupt any concurrent
work in the tree.
