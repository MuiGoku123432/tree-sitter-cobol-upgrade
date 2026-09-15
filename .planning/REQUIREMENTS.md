# Requirements: tree-sitter-cobol-upgrade — COBOL grammar: nodes for edges

**Defined:** 2026-08-28
**Core Value:** A CICS transaction/program/map name, a DB2 table name, and an IDMS record + set
name are each reachable as named AST nodes with accurate positions — because those nodes are what
become graph edges.

**Source:** `docs/spec/SPEC-001-nodes-for-edges.md`, distilled via `.planning/intel/`.

Requirement structure mirrors SPEC §6: the six acceptance criteria are applied **per construct
family**, so each family phase carries its own cascade, capture, recall, regression, and
upstreamability gate.

## v1 Requirements

### Delivery Pipe (VEND)

- [x] **VEND-01**: A Go module in this repo wraps the fork's generated parser — `binding.go`,
  `parser.c`, `parser.h`, `scanner.c`, `grammar.json` — mirroring the `go-sitter-forest/cobol`
  package layout, so it is a drop-in substitute.

- [x] **VEND-02**: gortex consumes this fork's grammar through a `go.mod` `replace` directive and
  `cobolprobe` runs end-to-end against it with the **unmodified** grammar, proving the pipe before
  any grammar change exists.

- [x] **VEND-03**: The `tree-sitter-cli` version question is answered with evidence (OQ-2): the CLI
  used to generate `parser.c` produces a parser that gortex's `go-tree-sitter v0.25.0` loads, and
  the effect of the 0.24.5 → 0.25.x bump on upstream's 13 corpus fixtures is measured and recorded
  as pass/fail. Upstream's `dependabot/npm_and_yarn/tree-sitter-cli-0.25.3` branch is checked for
  existing evidence first.

- [x] **VEND-04**: A repeatable regenerate-and-refresh sequence is documented and executed at least
  twice, so any subsequent grammar change reaches gortex without an upstream merge or a forest
  regeneration.

- [x] **VEND-05**: A `cobolprobe` recall baseline is re-measured through the local vendoring path
  on the same corpus with the same method (`.cbl` and `.cpy`, grammar-alone and `+ neutralize()`),
  reproducing the published 15% / 27% / 0% / 93% figures, so every later family's delta is
  apples-to-apples.

### Fork Hygiene & Sequencing (FORK, SEQ)

- [~] **FORK-01** — **DEFERRED 2026-08-28** (Phase 1 discussion; see
  `.planning/phases/01-delivery-pipe-measurement-baseline/01-CONTEXT.md` D-12…D-15). Original text:
  a repeatable branch-hygiene check that fails a topic branch containing any `.planning/` or
  `docs/spec/` path and passes on a clean branch cut from a freshly fetched `upstream/main`.
  Deferred because it protects an upstream PR diff, and upstream PRs are not a project goal.
  Replaced in v1 by **FORK-03** below, which preserves the option at no per-cycle cost.

- [x] **FORK-03**: Grammar commits stay separable from fork-local commits — no commit mixes
  `grammar.js` / `test/corpus/*` changes with shim, `docs/`, or `.planning/` changes. This is the
  only PR-preservation property that cannot be recovered retroactively; with it, a clean topic
  branch can be reconstructed from `main` on demand in minutes.

- [x] **FORK-02**: An estate-leak guard exists and passes. `estate/` is proprietary production source
  and this fork is **public on GitHub**; the guard fails any branch, commit, or staged change that
  contains an `estate/` path or estate-derived source, and asserts `/estate/` remains excluded via
  `.git/info/exclude` (not `.gitignore`, so the upstream PR diff stays at zero). Estate source is
  never quoted verbatim into a commit message, issue, or upstream PR.
  **Re-closed 2026-08-29** by `phases/01-delivery-pipe-measurement-baseline/01-07-PLAN.md`, the
  GREEN half of the 01-06/01-07 red-then-green gap closure: CR-01 (endpoint-only diff blind to
  intermediate commits), CR-02 (C-quoted paths evading the `^estate/` match), CR-03 (unresolvable
  range reporting PASS instead of failing closed), and CR-04 (`--not --remotes` ignoring which
  remote is being pushed to) are fixed in `.githooks/estate-guard.sh`, and its self-test
  (`.githooks/estate-guard-selftest.sh`) is wired into `.githooks/pre-push` (WR-13). Closure
  evidence: `01-07-SUMMARY.md`'s red-to-green table, and `bash .githooks/estate-guard-selftest.sh`
  exiting 0 against the guard exactly as shipped.

- [x] **SEQ-01**: The build order is fixed to measured volume and recorded with its counts — IDMS
  DML (541 programs / 14,764 statements) first, `EXEC CICS` (221 / 3,539) second, `EXEC SQL`
  (49 / 489) third, `EXEC DLI` (0 / 0) not built per locked decision D4.

### IDMS DML (IDMS)

- [x] **IDMS-01**: The grammar parses the estate's 14 IDMS DML verbs — BIND, OBTAIN, FIND, READY,
  ERASE, ACCEPT, GET, STORE, FINISH, MODIFY, CONNECT, ROLLBACK, COMMIT, DISCONNECT — into named
  statement nodes with accurate positions, not ERROR nodes.

- [x] **IDMS-02**: A tree-sitter query extracts the IDMS **record name** and **set name** from a
  DML verb as named captures.

- [x] **IDMS-03**: `ACCEPT` is disambiguated on the operand tail, never on the verb alone. Corpus
  tests cover both the IDMS forms and ordinary standard-COBOL `ACCEPT`, and the standard
  occurrences are provably unaffected. *Amended 2026-09-01 by 02-04: the operand tail is a required
  `CURRENCY` anchor, optionally preceded by `NEXT`, `PRIOR` or `OWNER`. The `… DB-KEY` anchor was
  disproved — zero of 2,391 estate `ACCEPT`s use it — and the 634 figure is restated as **631**.
  See 02-04-SUMMARY.md "Deviations from Plan".*

- [x] **IDMS-04**: `TestErrorCascade` in `cobolprobe` shows paragraphs and data items after an IDMS
  DML statement surviving at parity with a file that lacks the construct.
  *Checkbox corrected 2026-09-09 (Phase 3 pre-planning amendment 3). The checkbox was stale: the
  cascade harness satisfies IDMS-04 in full — verified against the Phase 2 measurement record.*

- [x] **IDMS-05**: `.cbl` recall in `cobolprobe`, measured through the VEND-04 path on the
  VEND-05 baseline, rises on the **grammar-alone `paragraph_header` axis** (the counter in
  `cobolprobe/neutralize_test.go`) and `idms_unparsed_tail` does not grow.
  *Amended 2026-08-29 from "rises measurably above 27%" —
  `neutralize()` already rewrites IDMS DML, so 26.6% is a ceiling, not a bar. See
  `phases/02-idms-dml-statement-nodes/02-CONTEXT.md` D-13.*
  *Re-scoped 2026-09-09 per Phase 3 D-25/D-26 onto the `paragraph_header` axis, and closed in
  Phase 3 alongside CICS-04. Requires the reconstructed Phase 1 `paragraph_header` baseline
  (D-26) before a before/after can be read — `docs/baseline.md:163` records only the Phase 2
  completion pair `15,323 → 16,732`, with no Phase 1 number.*
  **Prior OUTSTANDING record (measured 2026-09-04), retained for provenance.** Second clause
  PASSED — `idms_unparsed_tail` fell 119 → 9.
  First clause FAILED on the old `dataItems` axis — recall held at 17,905, unchanged. Cause on
  file: `dataItems` is a DATA
  DIVISION metric and the DATA DIVISION is gated at `SCHEMA SECTION` in 321 of 606 `.cbl` (53%),
  which contribute just 213 of the 17,905 items. Locked decision D3 assigns `SCHEMA SECTION` to
  preprocessing, in a different repository, so **no grammar-only phase can satisfy this clause as
  written**. The requirement is mis-specified for a grammar phase rather than unmet by the work;
  see `docs/baseline.md` §4. That mis-specification is what the 2026-09-09 re-scope resolves.
  **CLOSED 2026-09-11 on the re-scoped axis.** The reconstructed Phase 1 grammar-alone
  `paragraph_header` value is 9,187; Phase 2 reached 15,323 (+6,136), and Phase 3 reached
  18,234. The IDMS contribution is now measurable rather than inferred, and
  `idms_unparsed_tail` had already fallen 119 -> 9. See `docs/baseline.md` §§5-6.

- [x] **IDMS-06**: `tree-sitter test` passes against the corpus fixtures, and `run_nist_cobol85.sh`
  gains no failures beyond the **11** already listed in `skip_tests.txt`.

- [x] **IDMS-07**: The change ships as a self-contained commit or commit series that is
  separable from all fork-local changes (FORK-03), with corpus tests included and no
  site-specific naming; it passes FORK-02. A rebased topic branch is reconstructible from this on
  demand but is no longer required per-family. Every IDMS DML corpus fixture is a minimal, hand-written
  construct — never an estate excerpt.

- [x] **IDMS-08**: A concrete `.cbl` gap-closure target for Phase 3 is set from the observed IDMS
  slope and recorded, resolving OQ-3. Expressed as a fraction of the
  `(32,360 - 17,905)` = 14,455 `dataItems` gap, not as an absolute percentage. Phase 4 is excluded
  — the corpus of record contains zero `EXEC SQL`. *Amended 2026-08-29; see
  `phases/02-idms-dml-statement-nodes/02-CONTEXT.md` D-13 and D-14.*
  **MET 2026-09-04** — Phase 3 target set at **6% of the 14,455-item gap** (grammar-alone `.cbl`
  dataItems >= 18,772), recorded in `docs/baseline.md` §4 with its derivation, and carried into
  ROADMAP.md, PROJECT.md and STATE.md. Phase 2's own measured share is recorded as 0 with cause.

### EXEC CICS (CICS)

- [x] **CICS-01**: The grammar parses `EXEC CICS … END-EXEC` blocks into named nodes with accurate
  positions, not ERROR nodes. **MET:** `test/corpus/exec_cics.txt` carries 17 green cases
  covering the measured forms; `tree-sitter test -e '^comment$'` passes.

- [x] **CICS-02**: A tree-sitter query extracts the CICS **transaction name**, **program name**, and
  **map name** as named captures. **MET:** `sh run_cics_query_capture.sh` emits command,
  transaction, program, map and mapset captures; `queries/cics.scm` is byte-identical to the
  vendored query. **D-22 disclosure:** 30 of 33 measured PROGRAM operands are data names, so
  the capture generally yields a variable rather than a resolvable edge target. **D-24:** the
  query is a published contract with no gortex reader today; the fork-local gate is its current
  consumer and satisfies the extraction criterion literally.

- [x] **CICS-03**: `TestErrorCascade` shows paragraphs after an `EXEC CICS` surviving at parity with
  a file that lacks the construct (measured baseline: 1 of 20 survive). **MET:** gortex
  `TestErrorCascade` asserts four representative shapes at 20/20 paragraph and 20/20 data-item
  parity; reverting to the pre-Phase-3 parser fails all four paragraph assertions at 1/20.

- [x] **CICS-04**: `.cbl` recall measured through the VEND-04 path closes **100% of the measured
  1,409-item `paragraph_header` gap — grammar-alone `.cbl` `paragraph_header` >= 16,732** — on the
  grammar-alone axis, under the direction-hard / magnitude-explained rule. The axis is the
  `paragraph_header` counter in `cobolprobe/neutralize_test.go`, named verbatim to disambiguate it
  from the different, much smaller counter in `probe_test.go`. Terminal condition on this axis.
  *Amended 2026-08-29. Re-scoped 2026-09-09 per Phase 3 D-16a–d: the prior `dataItems` formulation
  is unsatisfiable for a CICS phase — `EXEC CICS` costs 19 of 20 paragraphs but 0 data items, and
  0 of the 169 `.cbl` containing `EXEC CICS` have the construct before `PROCEDURE DIVISION`.*
  **MET 2026-09-11:** reconstructed Phase 1 = 9,187, Phase 2 = 15,323, Phase 3 = 18,234.
  `18,234 >= 16,732` passes by 1,502; residual closure is 2,911 / 1,409 = 206.6%.
  Per the confirm-with-note checkpoint, the target is explicitly qualified: IDMS closed 6,136
  of the original gap and CICS was responsible for the remaining 1,409. See `docs/baseline.md` §§5-6.

- [x] **CICS-05**: `tree-sitter test` passes, and `run_nist_cobol85.sh` gains no failures beyond the
  11 in `skip_tests.txt`. **MET:** corpus suite green; NIST reports
  `382 tests. (Success: 371, Fail: 0, Skip: 11)`; DCC and estate differentials each report
  `CLEAN_RECLASSIFIED_COUNT: 0`.

- [x] **CICS-06**: The change ships as a self-contained commit or commit series that is
  separable from all fork-local changes (FORK-03), with corpus tests included and no
  site-specific naming; it passes FORK-02. A rebased topic branch is reconstructible from this on
  demand but is no longer required per-family. Every EXEC CICS corpus fixture is a minimal, hand-written
  construct — never an estate excerpt. **MET:** per-commit path review keeps docs/planning,
  grammar, fork-local gate and cross-repo changes in separate commits; fixtures are hand-written,
  invented and neutral; the pre-push estate guard remains active.

### EXEC SQL (SQL)

- [x] **SQL-01**: The `EXEC SQL` node-granularity question (OQ-1) is closed with a written decision
  and rationale — full SQL grammar vs. opaque statement body plus extracted table names —
  **before** grammar work begins.

- [x] **SQL-02**: The grammar parses `EXEC SQL … END-EXEC` blocks into named nodes at the chosen
  granularity, with accurate positions, not ERROR nodes.

- [x] **SQL-03**: A tree-sitter query extracts the **DB2 table name** as a named capture.
- [x] **SQL-04**: `TestErrorCascade` shows paragraphs and data items after an `EXEC SQL` statement
  surviving at parity with a file that lacks the construct.

- [ ] ~~**SQL-05**: `.cbl` recall measured through the VEND-04 path meets or exceeds the target set in
  IDMS-08.~~ **Retired 2026-08-29 — unmeasurable.** The corpus of record contains zero `EXEC SQL`
  (0 occurrences, 0 `SQLCODE`, 0 `SQLCA`, 0 `DCLGEN`), so Phase 4 has no recall signal available.
  Phase 4 is gated by SQL-01…SQL-04, SQL-06, SQL-07. See
  `phases/02-idms-dml-statement-nodes/02-CONTEXT.md` D-14.

- [x] **SQL-06**: `tree-sitter test` passes, and `run_nist_cobol85.sh` gains no failures beyond the
  11 in `skip_tests.txt`.

- [x] **SQL-07**: The change ships as a self-contained commit or commit series that is
  separable from all fork-local changes (FORK-03), with corpus tests included and no
  site-specific naming; it passes FORK-02. A rebased topic branch is reconstructible from this on
  demand but is no longer required per-family. Every EXEC SQL corpus fixture is a minimal, hand-written
  construct — never an estate excerpt.

## v2 Requirements

Deferred. Tracked but not in the current roadmap.

### Upstream Acceptance

- **UPS-01**: An issue is opened with `@yutaro-sakamoto` asking about appetite for COBOL dialect
  support, before investing in PR-shaped work (OQ-4). *Deferred as a requirement because the
  outcome is outside our control; the work itself is cheap and may be done opportunistically.*

- **UPS-02**: The IDMS DML / `EXEC CICS` / `EXEC SQL` topic branches are accepted upstream and
  `go-sitter-forest/cobol` regenerates, retiring the local `replace` directive. *Outcome depends on
  a third-party maintainer — "months, or never."*

### SQL Depth

- **SQLX-01**: A full SQL grammar for `EXEC SQL` bodies, if OQ-1 resolves to opaque-plus-extraction
  and richer SQL nodes later prove necessary.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| `EXEC DLI` support | Zero occurrences across the 1,369 real programs. Locked decision D4. |
| Endevor `-INC <MEMBER>` rewriting | Not COBOL — a site include directive (837 of 1,361 programs, 12,819 statements). Handled by preprocessing in the preprocessing repo. |
| `IDMS-CONTROL SECTION`, `PROTOCOL.`, `SCHEMA SECTION`, `DB x WITHIN y` | Structural; the real IDMS precompiler comments these out. Preprocessing owns them per locked decision D3. |
| `site-macro` / `%`-macro site preprocessor language | Not COBOL. |
| Any site-specific naming or hack | Unjustifiable as generic dialect support; kept out on maintainability grounds (amended 2026-08-28 from "would make a PR unupstreamable"). |
| Cascade-removal as the success condition | "No ERROR nodes" is achievable in preprocessing and yields no graph content. Locked decision D1. |
| Adopting an alternative COBOL parser | cobol-rekt scored 1/74 on IDMS; ProLeap/Koopa/GnuCOBOL skip DML and are JVM/C. Locked decision D2. |
| Estate source as test-fixture material | `estate/` is proprietary production source and this fork is public. Fixtures must be minimal, hand-written constructs. The estate is a measurement input only. |
| A parallel test harness | A regression net already exists (`test/corpus/*.txt`, `run_nist_cobol85.sh`, `skip_tests.txt`, `test/check_tests.sh`). Build on it. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| VEND-01 | Phase 1 | Complete |
| VEND-02 | Phase 1 | Complete |
| VEND-03 | Phase 1 | Complete |
| VEND-04 | Phase 1 | Complete |
| VEND-05 | Phase 1 | Complete |
| FORK-01 | — | Deferred 2026-08-28 (upstream PRs not a goal) |
| FORK-03 | Phase 1 | Complete |
| FORK-02 | Phase 1 | Re-closed 2026-08-29 — CR-01…CR-04 fixed, self-test wired into pre-push (01-07) |
| SEQ-01 | Phase 1 | Complete |
| IDMS-01 | Phase 2 | Complete |
| IDMS-02 | Phase 2 | Complete |
| IDMS-03 | Phase 2 | Complete |
| IDMS-04 | Phase 2 | Complete — checkbox corrected 2026-09-09 (Phase 3 pre-planning amendment) |
| IDMS-05 | Phase 2 | Complete 2026-09-11 — reconstructed 9,187 -> Phase 2 15,323 -> Phase 3 18,234 |
| IDMS-06 | Phase 2 | Complete |
| IDMS-07 | Phase 2 | Complete |
| IDMS-08 | Phase 2 | Complete |
| CICS-01 | Phase 3 | Complete |
| CICS-02 | Phase 3 | Complete |
| CICS-03 | Phase 3 | Complete |
| CICS-04 | Phase 3 | Complete — 18,234 >= 16,732 |
| CICS-05 | Phase 3 | Complete — corpus, NIST and two-corpus differential green |
| CICS-06 | Phase 3 | Complete — separable commit series |
| SQL-01 | Phase 4 | Complete |
| SQL-02 | Phase 4 | Complete |
| SQL-03 | Phase 4 | Complete |
| SQL-04 | Phase 4 | Complete |
| SQL-05 | Phase 4 | Complete |
| SQL-06 | Phase 4 | Complete |
| SQL-07 | Phase 4 | Complete |

**Coverage:**

- v1 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0 ✓

### Intel requirement → REQ-ID crosswalk

The nine requirements distilled in `.planning/intel/requirements.md` decompose as follows. The
cross-cutting ones (cascade, recall, upstreamability) are split per family so each REQ-ID maps to
exactly one phase.

| Intel requirement | REQ-IDs |
|---|---|
| REQ-idms-dml-nodes | IDMS-01, IDMS-02 |
| REQ-exec-cics-nodes | CICS-01, CICS-02 |
| REQ-exec-sql-nodes | SQL-01, SQL-02, SQL-03 |
| REQ-scope-ordering-by-volume | SEQ-01 |
| REQ-accept-disambiguation | IDMS-03 |
| REQ-cascade-elimination | IDMS-04, CICS-03, SQL-04 |
| REQ-recall-improvement | VEND-05, IDMS-05, IDMS-08, CICS-04, SQL-05 |
| REQ-local-vendoring-path | VEND-01, VEND-02, VEND-03, VEND-04 |
| REQ-upstreamable-delivery (softened to *separable* delivery 2026-08-28) | FORK-03, IDMS-06, IDMS-07, CICS-05, CICS-06, SQL-06, SQL-07 |
| (new, SPEC §3 revision 2026-08-28) proprietary `estate/` must never reach the public fork | FORK-02 |

---
*Requirements defined: 2026-08-28*
*Last updated: 2026-08-28 after ingest of SPEC-001*
