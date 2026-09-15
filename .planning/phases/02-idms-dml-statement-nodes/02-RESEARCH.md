# Phase 2: IDMS DML Statement Nodes - Research

**Researched:** 2026-08-29
**Domain:** tree-sitter grammar engineering (LR/GLR conflict resolution) + CA IDMS DML syntax
**Confidence:** MEDIUM — IDMS syntax is CITED against the published manual (D-10's mandated source); the
tree-sitter mechanics and CI/regeneration findings are VERIFIED by directly running the pinned toolchain
in this repo this session.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Node shape**
- **D-01:** DML statements are modelled as **four verb-class node types**: `idms_navigation_statement`
  (OBTAIN, FIND), `idms_update_statement` (STORE, MODIFY, ERASE, CONNECT, DISCONNECT, GET),
  `idms_session_statement` (BIND, READY, FINISH, COMMIT, ROLLBACK), `idms_accept_statement` (ACCEPT).
  Each carries `field('verb', …)` and shares record/set operand sub-rules.
  — Reversibility: costly (cross-repo query contract with gortex).
- **D-02:** Record and set names are their own named rules — `idms_record_name` and `idms_set_name` —
  not `field()` labels on the statement node, so the query is depth-independent.
  — Reversibility: costly (same cross-repo query contract).
- **D-03:** An operand tail the grammar does not model is absorbed into a named `idms_unparsed_tail`
  node, never ERROR, never silently swallowed — this is also the coverage-gap counter driving D-07's
  extension list.
- **D-04:** The extraction query ships from this fork as `queries/idms.scm` — capturing
  `(idms_record_name) @record`, `(idms_set_name) @set`, and the verb.

**ACCEPT containment**
- **D-05:** A separate `idms_accept_statement` rule alongside `accept_statement`, anchored on the
  required trailing keyword. `_accept_body` (grammar.js:1513) already ends with
  `seq($._FROM, field('from', choice(…, $.WORD)))`, so an IDMS ACCEPT already matches a complete
  standard ACCEPT and diverges only on the following token — an explicit `conflicts:` entry or
  precedence is required, and that resolution is exactly where silent reclassification could hide.
  — Reversibility: costly.
- **D-06:** Anchor keywords are **CURRENCY and DB-KEY only** (the two named forms the 634 figure was
  derived from). Extend only on evidence if the differential lands short of 634. `idms_unparsed_tail`
  does NOT fire for a missed IDMS ACCEPT — an unanchored form falls back to standard `accept_statement`
  and ERRORs on the tail; the ACCEPT coverage signal is "`idms_accept_statement` count short of 634".
- **D-07 (evidence standard):** A before/after differential parse — every node that was
  `accept_statement` before the change is still `accept_statement` after (zero reclassifications, hard
  gate), and the new `idms_accept_statement` count lands near 634. Run on **both** corpora: DCC (fast
  inner loop, 606 `.cbl`, ~18s) and the estate (authority for the 1,757/634 split, 52,233 files).
- **D-08:** The differ is a committed fork-local, re-runnable shell script at repo root (matching
  `run_nist_cobol85.sh`'s convention), invoked manually at the end of each family's work. Not wired
  into `pre-push` (too slow for that choke point).

**Coverage surface**
- **D-09:** Initial option set is minimal-to-edges — only what's needed to expose `verb` +
  `idms_record_name` + `idms_set_name` (`WITHIN`/`TO`/`FROM` clauses, `CALC`/`OWNER`/`DB-KEY`/
  `FIRST`/`LAST`/`NEXT`/`PRIOR`/`CURRENT` selectors). Everything else lands in `idms_unparsed_tail`,
  then extend where the volume is.
- **D-10:** Syntax ground truth is the published CA IDMS DML reference syntax diagrams; the estate
  contributes counts only. Fixtures use invented neutral names (`CUSTOMER-REC`, `CUST-ORDER-SET`).
  Nothing estate-derived crosses into a tracked file.
- **D-11:** Fork-local `.github/workflows/fork-checks.yml` on `main` running `tree-sitter test`, with
  the `comment` fixture excluded and annotated (pointer to upstream `4bc6ff5` and `.planning/WINDOWS.md`).
- **D-12:** Precompiled `CALL 'IDMS' USING SUBSCHEMA-CTRL` is out of scope. Measured: 0 occurrences in
  DCC `.cbl` — estate-only concern, doesn't affect DCC recall.

**Recall target**
- **D-13:** Gap-closure fraction on the grammar-alone axis: `(X − 17,905) / (32,360 − 17,905)`. Phase
  2's measured share sets N; terminal condition grammar-alone ≥ neutralized (`neutralize()` retires).
- **D-14:** The 14,455-item gap is allocated entirely across Phases 2–3; Phase 4's recall criterion is
  retired (DCC has zero `EXEC SQL`).
- **D-15:** Hard on direction (grammar-alone must rise, `idms_unparsed_tail` must not grow), explained
  on magnitude (a miss against the allocated share needs a written cause on file).
- **D-16:** ROADMAP/PROJECT amendments land as a docs commit before this phase's plan runs, not as a
  task inside the plan.

### Claude's Discretion
- Exact rule/node spelling within the four verb classes (the class names are agreed; `idms_record_name`
  / `idms_set_name` / `idms_unparsed_tail` must be used verbatim — they are the query contract).
- Fixture file layout under `test/corpus/` (one file vs. per-cluster vs. a separate ACCEPT-regression
  file). Repo convention is per-topic files.
- The D-05 conflict-resolution mechanism (`conflicts:` vs. `prec` vs. `prec.dynamic`), provided the
  zero-reclassification differential passes.
- The differ script's name, language, output format, and whether it takes a corpus path argument.
- How `idms_unparsed_tail` counts are reported at phase end (table vs. separate note).
- Plan decomposition and commit sequencing, subject to FORK-03.

### Deferred Ideas (OUT OF SCOPE)
- Full manual-complete IDMS DML option coverage (usage modes, `PERMANENT`/`SELECTIVE`/`ALL`, sort keys,
  LRF verbs `KEEP`/`RETURN`/`IF … MEMBER`, verbs outside the estate's 14) beyond what
  `idms_unparsed_tail` counts justify extending to within this phase.
- Recognising the precompiled `CALL 'IDMS'` form as IDMS nodes.
- Fixing the upstream `comment` corpus fixture (excluded, not repaired).
- A second corpus containing `EXEC SQL`.
- An estate-measured substitute recall metric for Phase 4.
- Wiring the differ into `pre-push`.
- `.cpy` grammar-alone recall (0%) — structural, not an IDMS problem.
- FORK-01 (branch-hygiene guard).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| IDMS-01 | Grammar parses the 14 verbs into named statement nodes, accurate positions, no ERROR nodes | §"CA IDMS DML Syntax by Verb Class" gives verified manual syntax for all 14 verbs; §"Architecture Patterns" gives the four-node skeleton |
| IDMS-02 | tree-sitter query extracts record name + set name as named captures | §"Code Examples" — `queries/idms.scm` pattern, precedented by `queries/sample.scm` (read this session) |
| IDMS-03 | ACCEPT disambiguated on operand tail, never the verb alone; both forms provably unaffected | §"The ACCEPT Conflict" — verified `conflicts`/`prec`/`prec.dynamic` semantics, recommended resolution order |
| IDMS-04 | `TestErrorCascade` shows cascade elimination at parity | §"Common Pitfalls" Pitfall 3 — `TestErrorCascade` (read this session) has NO existing IDMS DML case; must be added in the gortex repo |
| IDMS-05 | `.cbl` grammar-alone recall rises, `idms_unparsed_tail` does not grow | §"The Regeneration and Measurement Mechanics" — exact commands, verified against `docs/vendoring.md`/`docs/baseline.md` |
| IDMS-06 | `tree-sitter test` passes 13 fixtures (comment excluded), NIST gains no failure beyond 11 | §"CI Workflow Mechanics" — `-e '^comment$'` verified empirically in this repo this session (exit 0 vs exit 1) |
| IDMS-07 | Self-contained, separable (FORK-03) commit, no site-specific naming, hand-written fixtures | §"Don't Hand-Roll" and §"Package Legitimacy Audit" (N/A — no new deps) |
| IDMS-08 | Concrete `.cbl` gap-closure target set from observed slope, resolving OQ-3 | §"The Regeneration and Measurement Mechanics" — this is a measurement the plan must schedule as its last task, not something research can pre-compute |
</phase_requirements>

## Summary

This phase is pure `grammar.js` engineering plus two small pieces of fork-local tooling (a differ
script and a CI workflow) — there are no new runtime dependencies. The two hardest technical
questions are (1) how to disambiguate `ACCEPT … FROM x CURRENCY`/`… DB-KEY` from a standard COBOL
`ACCEPT … FROM x` without ever misclassifying the 1,757 standard occurrences, and (2) where to put the
`idms_unparsed_tail` catch-all so it absorbs an unmodelled operand tail without swallowing the next
statement. Both are answered by tree-sitter's own LR(1)/GLR mechanics, verified against the official
grammar-DSL docs this session: **`prec()`/`prec.left`/`prec.right` resolve ordinary one-token-lookahead
shift/reduce conflicts entirely at parser-generation time — deterministically, with a compile-time
failure if they don't suffice** — whereas `conflicts:` + `prec.dynamic()` invoke the GLR algorithm,
which forks the parse and picks a winner by a runtime heuristic score. The static route is strictly
safer for a "provable zero-reclassification" gate (IDMS-03) because it either succeeds and is
deterministic, or fails loudly at `tree-sitter generate` time — it cannot silently misclassify at
runtime the way a dynamic-precedence heuristic could. The practical recommendation is to draft the
`idms_accept_statement` rule, run `tree-sitter generate`, and let the CLI's own conflict detector be
authoritative before reaching for `conflicts:`.

For IDMS syntax itself, the CA IDMS DML reference manual (Broadcom TechDocs, the source D-10 mandates)
gives concrete, verifiable syntax diagrams for all 14 verbs — captured below — and one real surprise:
**`BIND` is not one shape.** The manual documents both `BIND RUN-UNIT` (no record operand — a
session-establishing statement, fits D-01's `idms_session_statement` bucket cleanly) and `BIND RECORD`
(takes a `record-name` operand, normally auto-generated by `COPY IDMS SUBSCHEMA-BINDS` rather than
hand-typed). The estate's raw `BIND` counts (4631 estate-wide, 299/606 DCC files) don't distinguish
which form dominates — this is exactly the kind of thing `idms_unparsed_tail`/D-09's "measure, then
extend" principle exists to resolve, but the planner should not assume `BIND` is argument-free.

For the regeneration/measurement mechanics (IDMS-05/08), this is the first phase where `grammar.js`
actually changes, so the Phase 1 pipe (`forest-shim/refresh.sh` → `go.work` → `cobolprobe`) carries its
first real regeneration. The exact commands are transcribed below from `docs/vendoring.md` and
`docs/baseline.md` (read this session), and one cross-repo gap was found empirically: `cobolprobe`'s
`TestErrorCascade` (read this session, `~/repos/mine/GoApps/gortex/.../cascade_test.go`) currently has
injection cases for `EXEC CICS` and `SCHEMA SECTION` only — **there is no IDMS DML case today** — so
satisfying IDMS-04 requires adding one, in the gortex repo, which is outside this fork's own
separable-commit boundary (FORK-03) and needs its own coordination step in the plan.

**Primary recommendation:** implement the four node types with `idms_unparsed_tail` bounded at the
literal `.` (matching `neutralize()`'s own `[^.]*\.` statement-boundary assumption, verified this
session), attempt `prec()`-only resolution for the ACCEPT collision first and fall back to
`conflicts:`/`prec.dynamic()` only if `tree-sitter generate` itself reports the conflict as
unresolvable, and treat the differential script (D-08) plus the cobolprobe cascade/recall re-run as
two separate, sequenced end-of-phase gates — the second of which touches a different repo.

## Architectural Responsibility Map

> This repo has no browser/API/DB tiers — it is a single grammar-compilation pipeline. The table below
> substitutes this project's own layers (established in `.planning/codebase/ARCHITECTURE.md`, read this
> session) so the planner can still sanity-check "which layer owns this capability."

| Capability | Primary Layer | Secondary Layer | Rationale |
|------------|--------------|-----------------|-----------|
| 14-verb DML statement nodes (record/set capture) | Grammar Definition (`grammar.js`) | Generated Parser (`src/parser.c`, mechanical `tree-sitter generate` output) | `grammar.js` is the only hand-maintained language definition (ARCHITECTURE.md); `src/` is never hand-edited |
| ACCEPT disambiguation | Grammar Definition (`grammar.js` conflicts/prec) | — | LR/GLR resolution lives entirely in the grammar DSL, no other layer participates |
| `idms_unparsed_tail` catch-all | Grammar Definition (`grammar.js`) | — | Pure-grammar `repeat`, not the external scanner (see Pitfall 2) |
| `queries/idms.scm` extraction query | Query Layer (`queries/`) | Consumer (gortex, reads the query) | `queries/` is upstream-owned path per D-04; gortex is a pure consumer, never edits it |
| Recall / cascade measurement | Consumer Measurement Harness (`cobolprobe`, external `gortex` repo) | Delivery Pipe (`forest-shim/refresh.sh`) | `cobolprobe` owns the Go test; the pipe just has to have carried the new grammar there first |
| CI corpus-test gate | Fork-local CI (`.github/workflows/fork-checks.yml`) | — | New, `main`-only, does not touch upstream's `test.yml` (FORK-03) |
| ACCEPT zero-reclassification evidence | Fork-local tooling (root-level differ script, D-08) | — | Deliberately not CI-wired (too slow); manual, re-runnable |

## Standard Stack

**No new runtime dependencies.** This phase edits `grammar.js` (the existing DSL), regenerates with the
already-pinned `tree-sitter-cli`, and adds one new fork-local shell script plus one new fork-local CI
workflow file. There is no `npm install` of anything new.

| Tool | Version | Purpose | Status |
|------|---------|---------|--------|
| `tree-sitter-cli` | `^0.24.5` (lockfile-pinned exact `0.24.5`) | Compiles `grammar.js` → `src/parser.c`/`grammar.json`/`node-types.json` | `[VERIFIED: package.json:tree-sitter-cli, node_modules/.bin/tree-sitter --version]` — confirmed installed and runnable this session; `-i/-e` test-name filters already present at this pinned version (checked directly, see CI Workflow Mechanics below) |

### Alternatives Considered
Not applicable — no library choice exists here; the grammar DSL, the pinned CLI, and the existing
regression harness (`test/corpus/*.txt`, `run_nist_cobol85.sh`) are locked by D-02 (Phase 1) and
PROJECT.md's "no parallel test harness" constraint.

**Installation:** none required beyond what Phase 1 already set up (`npm ci` inside
`forest-shim/refresh.sh`).

## Package Legitimacy Audit

**Not applicable.** This phase introduces zero new packages in any ecosystem — it is a `grammar.js`
edit, a regeneration of already-tracked generated files, and two new fork-local files (a shell script,
a GitHub Actions YAML). The Package Legitimacy Gate is skipped per its own trigger condition ("every
phase that installs external packages").

## Architecture Patterns

### System Architecture Diagram

```
 grammar.js (edited this phase)
      │  tree-sitter generate
      ▼
 src/parser.c, src/grammar.json, src/node-types.json  (regenerated, committed)
      │  forest-shim/refresh.sh  (copy-flatten → include-rewrite → drift-check → smoke-build)
      ▼
 forest-shim/cobol/  (go.work-resolved shim, impersonates go-sitter-forest/cobol)
      │  go.work `use` in ~/repos/mine/GoApps/gortex
      ▼
 gortex / cobolprobe  ──►  probe_test.go   (grammar-alone dataItems recall)
                     ──►  neutralize_test.go (+neutralize() recall, reDML regex)
                     ──►  cascade_test.go  (TestErrorCascade — needs a new IDMS case)
                     ──►  queries/idms.scm (record/set capture, read by gortex's graph builder)

 In parallel, fork-local only:
 differ script (D-08, repo root)  ──  before/after differential parse on DCC + estate
                                       (proves zero accept_statement reclassification)
 .github/workflows/fork-checks.yml (D-11)  ──  `tree-sitter test -e '^comment$'` on push to main
```

A reader tracing "does a new IDMS ACCEPT statement reach a graph edge" follows: `grammar.js` rule →
`tree-sitter generate` → committed `src/parser.c` → `forest-shim/refresh.sh` → `forest-shim/cobol/` →
`go.work` → gortex's parse tree → `queries/idms.scm` capture → graph edge. Every arrow in that chain
was already proven to carry an edit end-to-end in Phase 1 (`forest-shim/pipe-probe.sh`, per
`docs/vendoring.md` §4) — this phase is the first time the edit at the top of the chain is a real
grammar change instead of a synthetic rename probe.

### Recommended Node Layout (grammar.js additions)

```javascript
// Added to _statement's choice() (grammar.js:1366), alongside the other ~37 *_statement entries:
$.idms_navigation_statement,   // OBTAIN, FIND
$.idms_update_statement,       // STORE, MODIFY, ERASE, CONNECT, DISCONNECT, GET
$.idms_session_statement,      // BIND, READY, FINISH, COMMIT, ROLLBACK
$.idms_accept_statement,       // ACCEPT (IDMS forms only — see "The ACCEPT Conflict")

// Shared operand rules (D-02) — named nodes, not fields, so a query matches under
// any of the four statement types regardless of nesting depth:
idms_record_name: $ => $.WORD,
idms_set_name: $ => $.WORD,
idms_unparsed_tail: $ => /* see "The idms_unparsed_tail Boundary" below */,
```

### Pattern: Operand Extraction via Named Nodes (D-02)

**What:** `idms_record_name`/`idms_set_name` are their own rules rather than `field()` labels, because
tree-sitter fields bind only to *direct* children of the declaring rule — a `record:` field on
`idms_navigation_statement` cannot reach an operand buried inside a `WITHIN`-clause sub-rule.
**Precedent in this grammar:** `select_statement` (grammar.js:423, read this session) is the closest
existing analog for "pull a named operand out of a statement" (`field('file_name', $.WORD)`), but it
uses a field because its operand sits at a fixed shallow depth. D-02 deliberately departs from that
precedent because IDMS operands do not.
**Example query (D-04, `queries/idms.scm`):**
```scheme
; Source: pattern precedented by queries/sample.scm (read this session — field-based
; capture + #eq? predicate is this repo's only existing query)
(idms_navigation_statement
  verb: (_) @verb
  (idms_record_name) @record)

(idms_navigation_statement
  (idms_set_name) @set)

(idms_accept_statement
  (idms_record_name) @record)
```

### The ACCEPT Conflict (IDMS-03, D-05)

**Verified mechanics** `[CITED: tree-sitter.github.io/tree-sitter/creating-parsers/2-the-grammar-dsl.html
and 3-writing-the-grammar.html]`:

- `prec(number, rule)` — "marks the given rule with a numerical precedence, which will be used to
  resolve LR(1) Conflicts at parser-generation time." Resolved **statically**, at `tree-sitter
  generate` time. If the grammar's states are genuinely separable by one token of lookahead, this
  succeeds deterministically and `tree-sitter generate` exits clean; if not, it fails loudly with a
  conflict error — it does not silently misparse.
- `prec.dynamic(number, rule)` — "the given numerical precedence is applied at runtime instead of at
  parser generation time. This is only necessary when handling a conflict dynamically using the
  `conflicts` field." This is the GLR path: the parser forks into multiple parse stacks when the
  ambiguity is reached, and picks the stack with the highest total dynamic precedence once both
  finish. **This is a runtime heuristic weight, not a proof** — it always produces *a* tree, and
  nothing prevents it from resolving an input tree-sitter's authors didn't anticipate to the wrong
  branch.
- `conflicts` — "an array of arrays of rule names… involved in an LR(1) conflict that is intended to
  exist in the grammar," used for **genuine** ambiguities (the docs' own example: `[x, y]` as array
  literal vs. destructuring pattern — both parses are locally valid, context alone decides).

**Why this matters for IDMS-03's "provable zero-reclassification" gate:** the ACCEPT case as described
in D-05 (`ACCEPT X FROM Y` is a complete, valid standard `accept_statement`; the IDMS form only differs
by one extra trailing token, `CURRENCY` or `DB-KEY`) is a textbook one-token-lookahead shift/reduce
situation, not a genuine two-valid-parses ambiguity — after seeing `Y`, the LR(1) parser needs to
decide *shift* (if lookahead is `CURRENCY`/`DB-KEY`, meaning "keep going, this is IDMS") vs. *reduce*
(otherwise, meaning "this is a complete standard ACCEPT"). That is exactly what `prec()`
resolves at generation time, deterministically, with a build-time failure as the fallback signal if it
doesn't.

**Recommended resolution order (planner's discretion per CONTEXT.md, but the ordering matters for the
"provable" requirement):**
1. Draft `idms_accept_statement` as its own rule, sharing the `ACCEPT $._identifier` prefix, then
   requiring `$._FROM $.idms_record_name CURRENCY` / `... DB-KEY` to complete it. Give the shorter
   (standard) completion a `prec()` and/or rely on `prec.right`/`prec.left` at the shared prefix.
2. Run `tree-sitter generate`. If it succeeds with no conflict error, this is the safer, static
   resolution — use it, and skip `conflicts:`/`prec.dynamic()` entirely.
3. Only if `tree-sitter generate` reports an unresolved conflict at this site, add exactly that
   pairing to `conflicts:` and use `prec.dynamic()` — and treat D-07/D-08's differential script as the
   *actual* proof (not the grammar's structure), since GLR + dynamic precedence is a heuristic.
4. Either way, the differential script (D-08) is mandatory regardless of which mechanism wins — it is
   the only thing that empirically proves zero reclassification against the corpus, independent of
   which tree-sitter mechanism resolved the conflict.

**Cost comparison:**

| Mechanism | Parser table size | Runtime cost | Failure mode if wrong |
|---|---|---|---|
| `prec()` only (static) | No change — same LALR table, disambiguation folded into existing states | Zero — resolved at generation time | `tree-sitter generate` errors immediately; cannot ship a silently-broken parser |
| `conflicts:` + `prec.dynamic()` (GLR) | Larger — GLR-capable states for the declared conflict set | Non-zero — every `ACCEPT … FROM WORD` forks the parse stack until the next token resolves it (2,391 occurrences across the estate, 634+1,757) | Ships and runs; a pathological input not covered by the differential could resolve to the wrong branch silently |

### The `idms_unparsed_tail` Boundary (D-03)

**Verified corroborating fact** `[VERIFIED: ~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/neutralize_test.go:24]`
— quoted verbatim, read this session:

```go
reDML = regexp.MustCompile(`(?im)^(\s*)(OBTAIN|FIND|GET|STORE|MODIFY|ERASE|CONNECT|DISCONNECT|READY|FINISH|BIND|ACCEPT|COMMIT|ROLLBACK|KEEP|IF\s+.*\s+MEMBER)\b[^.]*\.`)
```

This is the regex that already rewrites every IDMS DML verb across the *whole* estate corpus
successfully (it is the mechanism behind the 26.6% `neutralize()` ceiling D-13 measures against) — and
it models a DML statement's boundary as **"from the verb keyword to the next literal period,"**
`[^.]*\.`. That the neutralization pipeline already succeeds against 606 real `.cbl` files using this
exact boundary is strong practical evidence that IDMS DML statements, as actually written in this
domain, are conventionally one-statement-per-sentence (matching `neutralize()`'s assumption), even
though this grammar's own `_statement` choice does not *require* a trailing period on every individual
statement rule — several sibling rules (`accept_statement`, `add_statement`, `move_statement`,
`display_statement`, all read this session at grammar.js:1508, 1584, 2215, 1782) omit their own
trailing `.`, leaving period-termination to the shared `_end_statement`/`period` rule at the
`_procedure_division_statements_before_header` level (grammar.js:1291-1294, read this session).

**Recommendation:** bound `idms_unparsed_tail` the same way `neutralize()` already does — as a
`repeat` over the grammar's existing atomic leaf tokens (`$.WORD`, `$.integer`, `$._LITERAL`/string,
plus punctuation already tokenized elsewhere) that stops before the literal `.`. This is a **pure
grammar** rule, not an external-scanner token:

- **Pure grammar (recommended):** `repeat(choice($.WORD, $.integer, $._LITERAL, '(', ')', ','))` (exact
  token set TBD by the planner against what actually appears in `idms_unparsed_tail` candidates) —
  costs nothing beyond a few new LALR states, no C code, no scanner recompilation, matches this
  grammar's overwhelming convention (`scanner.c` is 207 lines and handles only whitespace/comments/
  multiline strings per `.planning/codebase/ARCHITECTURE.md`, read this session — it has never been
  extended for a "consume an operand tail" purpose in this fork's history).
- **External scanner (not recommended):** would require editing `src/scanner.c`'s hand-written C to
  track "have I seen a terminating period" state across an arbitrary token run. This is a materially
  bigger, riskier lift (new C code, new external token in `externals: $ => [...]`, recompilation of the
  scanner in every downstream consumer) for a problem the pure-grammar route already solves at zero
  marginal engineering cost. `[ASSUMED]` — general tree-sitter engineering judgment, not verified
  against a specific external-scanner tutorial for this exact "absorb-a-tail" pattern; the planner
  should still sanity-check this against whatever token set `idms_unparsed_tail` actually needs to
  admit once the option-coverage measurement (D-09) is run.

**Genuine open risk, not resolved by research:** because most `_statement` rules in this grammar (per
the citations above) don't embed their own terminating period, a period appearing after an
`idms_unparsed_tail` could, in principle, ambiguously belong either to *this* DML statement's sentence
end or to a *different* sentence boundary if IDMS DML statements are ever chained multiple-to-a-sentence
in the wild (e.g., `OBTAIN X WITHIN Y OBTAIN Z WITHIN W.` — two statements, one period). The
`neutralize()` regex's own boundary assumption (one period per DML verb occurrence) suggests this isn't
common in the corpus, but it hasn't been measured for this grammar specifically — the planner should
treat any `idms_unparsed_tail` design as provisional until validated against real fixture shapes drawn
from the manual (never the estate, per D-10).

### Anti-Patterns to Avoid
- **Site-specific record/set names anywhere in a tracked fixture** — D-10/IDMS-07 requirement; use
  invented neutral names (`CUSTOMER-REC`, `CUST-ORDER-SET`) exclusively, mirroring the manual's own
  generic placeholder style.
- **Treating GLR (`conflicts:`+`prec.dynamic`) as the default tool** — reach for it only after
  `tree-sitter generate` proves static `prec()` insufficient (see "The ACCEPT Conflict" above); this
  keeps the parser table smaller and gives a compile-time failure mode instead of a runtime one.
- **Assuming `BIND` has one shape** — see "CA IDMS DML Syntax by Verb Class" below; `BIND RUN-UNIT`
  and `BIND RECORD` have different operand shapes.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Is this ACCEPT the IDMS form or standard COBOL" | A separate preprocessing pass or regex pre-scan of the source before parsing | tree-sitter's own `prec()`/`conflicts:` mechanism, resolved inside the single grammar | A pre-scan duplicates the parser's own lookahead logic and can drift from what the grammar actually accepts; the differential script (D-08) already gives the needed proof without a second mechanism |
| Absorbing an unmodelled operand tail | A new external-scanner token / hand-written C state machine | A pure-grammar `repeat` over existing leaf tokens, bounded at the literal `.` | `scanner.c` has never needed extending for this fork's history; a grammar-only rule regenerates for free and needs no C recompilation anywhere downstream |
| CI-gating the 13 corpus fixtures while excluding one | A custom filter script, a modified `check_tests.sh`, or deleting the fixture | `tree-sitter test -e '^comment$'` — the pinned CLI's own `--exclude` regex flag | Verified this session: this flag already exists at the pinned `0.24.5` version and produces the exact behavior needed (exit 0, all other 12 fixtures still asserted) |
| Re-measuring recall from scratch | A new corpus-scanning tool | The existing `cobolprobe` (`probe_test.go`/`neutralize_test.go`) via the documented `-corpus`/`-neut-corpus` flags | PROJECT.md forbids a parallel harness; `cobolprobe` already does exactly this measurement and is the baseline of record |

**Key insight:** every "don't hand-roll" item above already has a working, in-repo tool that solves it
— the temptation in this phase is specifically to reach for heavier machinery (GLR, external scanner,
a new measurement harness) when the existing lighter mechanism (static `prec()`, pure grammar, the
pinned CLI's own flag, `cobolprobe`) already suffices and was verified this session to suffice.

## Common Pitfalls

### Pitfall 1: Reaching for `conflicts:`/`prec.dynamic()` before proving `prec()` insufficient
**What goes wrong:** The ACCEPT collision "feels" like a genuine ambiguity because two rules share a
viable prefix, so it's tempting to declare it in `conflicts:` immediately.
**Why it happens:** `conflicts:` is the mechanism most tutorials reach for first because it "just
works" without reasoning about LALR states.
**How to avoid:** Draft the rule, run `tree-sitter generate`, read its own error output. If it
generates clean, static resolution already worked — declaring `conflicts:` anyway is unnecessary and
adds GLR runtime forking cost with no benefit.
**Warning signs:** `tree-sitter generate` silently succeeding is not itself proof of correctness — the
differential script (D-08) is still mandatory either way.

### Pitfall 2: Assuming every `_statement` rule embeds its own terminating period
**What goes wrong:** Copying `select_statement`'s pattern (which does end in `'.'`) for the new DML
rules would make them require a period the estate's actual source may not always place there if two
DML verbs are chained per sentence.
**Why it happens:** `select_statement` is the only operand-extraction precedent in
`.planning/codebase/CONVENTIONS.md`, but it's from the Environment Division's SELECT clause, not the
Procedure Division's statement chain.
**How to avoid:** Check sibling `_statement` rules actually invoked from `_statement`'s choice()
(`accept_statement`, `add_statement`, `move_statement`, `display_statement` — none embed their own
period; termination is handled once, at `_procedure_division_statements_before_header`). Model the new
DML rules the same way.
**Warning signs:** A fixture with two DML statements in one sentence failing to parse as two separate
statement nodes.

### Pitfall 3: IDMS-04's `TestErrorCascade` gate has no existing IDMS case
**What goes wrong:** Assuming `TestErrorCascade` (in the external `gortex` repo) already covers IDMS
DML because CONTEXT.md's canonical references cite it as "the IDMS-04 gate."
**Why it happens:** The test function's *name* and doc comment ("when the grammar hits a construct it
does not know (EXEC CICS, IDMS DML)…") suggest IDMS coverage, but reading the actual test body (this
session, `cascade_test.go:50-80`) shows only two injected cases: `EXEC CICS SEND MAP(...)` after
paragraph 1, and a `SCHEMA SECTION` before the data division. **There is no IDMS DML statement injected
anywhere in this test today.**
**How to avoid:** The plan must add a third case (`OBTAIN`/`FIND`/etc. injected after paragraph 1,
mirroring the CICS case's shape at lines 67-71) — in the `gortex` repo, not this fork. This is a
cross-repo dependency the phase's "self-contained, separable commit" framing (FORK-03) does not cover,
since FORK-03 is scoped to *this* repo's own commits.
**Warning signs:** Treating IDMS-04 as satisfied merely because the existing `TestErrorCascade`
continues to pass — it currently can't fail on IDMS DML because it never exercises it.

### Pitfall 4: `BIND` is not a single shape
**What goes wrong:** Modeling `idms_session_statement`'s BIND arm as argument-free (matching
FINISH/COMMIT/ROLLBACK's shape) because those are its D-01 siblings.
**Why it happens:** `BIND RUN-UNIT` (session-establishing, no record operand) is the form most
front-of-mind, but the manual also documents `BIND RECORD` / `BIND record-location WITH record-name`
(binds a *specific record* to a program-storage location — normally auto-generated by
`COPY IDMS SUBSCHEMA-BINDS` rather than hand-typed, per Broadcom TechDocs, read this session).
**How to avoid:** Give the `idms_session_statement` BIND arm an *optional* record-name field/child (or
route `BIND RECORD` through `idms_update_statement` instead, if its record-bearing shape fits that
bucket better) rather than assuming BIND never takes an operand. Estate/DCC raw `BIND` counts (299/606
files, 4631 estate-wide) don't distinguish RUN-UNIT from RECORD occurrences — this is exactly what
`idms_unparsed_tail` frequency (D-09) should be used to resolve once fixtures are drafted.
**Warning signs:** A `BIND CUSTOMER-REC.` fixture (a plausible, manual-sourced construct) failing to
parse as `idms_session_statement` because the rule was written argument-free.

## Code Examples

### CA IDMS DML Syntax by Verb Class

All syntax below is transcribed from the CA IDMS 19.0 DML Reference for COBOL (Broadcom TechDocs,
`techdocs.broadcom.com/.../dml-reference-for-cobol/...`), fetched this session — `[CITED:
techdocs.broadcom.com]`, the authoritative source D-10 mandates. Record/set names shown are invented
neutral placeholders per D-10 (`CUSTOMER-REC`, `CUST-ORDER-SET`), not estate-derived.

**`idms_navigation_statement` (OBTAIN, FIND) — six documented formats, same shape for both verbs:**
```cobol
*> Format: DB-KEY
      OBTAIN CUSTOMER-REC DB-KEY IS WS-DB-KEY.
*>     syntax: [FIND|OBTAIN] [KEEP [EXCLUSIVE]] [rec-name] DB-KEY IS db-key [PAGE-INFO page-info] .

*> Format: CALC
      FIND CALC CUSTOMER-REC.
*>     syntax: [FIND|OBTAIN] [KEEP [EXCLUSIVE]] [CALC|ANY|DUPLICATE] record-name [error-expr] .

*> Format: OWNER
      FIND OWNER WITHIN CUST-ORDER-SET.
*>     syntax: [FIND|OBTAIN] [KEEP [EXCLUSIVE]] OWNER WITHIN set-name .

*> Format: WITHIN SET/AREA (also carries FIRST/LAST/NEXT/PRIOR/number)
      OBTAIN NEXT CUSTOMER-REC WITHIN CUST-ORDER-SET.
*>     syntax: [FIND|OBTAIN] [KEEP [EXCLUSIVE]] [NEXT|PRIOR|FIRST|LAST|number]
*>             [record-name] WITHIN [set-name|area-name] .

*> Format: CURRENT
      FIND CURRENT WITHIN CUST-ORDER-SET.
*>     syntax: [FIND|OBTAIN] [KEEP [EXCLUSIVE]] CURRENT [record-name|WITHIN set-name|WITHIN area-name] .
```
Record name is the `rec-name`/`record-name` operand in every format; set name is whatever follows
`WITHIN`. This is exactly the shape D-02's shared `idms_record_name`/`idms_set_name` sub-rules exist to
generalize over.

**`idms_update_statement` (STORE, MODIFY, ERASE, CONNECT, DISCONNECT, GET):**
```cobol
      STORE CUSTOMER-REC.
*>     syntax: STORE record-name .

      MODIFY CUSTOMER-REC.
*>     syntax: MODIFY record-name .

      ERASE CUSTOMER-REC ALL MEMBERS.
*>     syntax: ERASE record-name [PERMANENT MEMBERS | SELECTIVE MEMBERS | ALL MEMBERS] .

      CONNECT CUSTOMER-REC TO CUST-ORDER-SET.
*>     syntax: CONNECT record-name TO set-name .

      DISCONNECT CUSTOMER-REC FROM CUST-ORDER-SET.
*>     syntax: DISCONNECT record-name FROM set-name .

      GET CUSTOMER-REC.
*>     syntax: GET [record-name] .   (record-name optional — omitted form operates on
*>             "the record current of run unit")
```
CONNECT/DISCONNECT are the only two verbs in this class carrying BOTH a record name and a set name in
one statement — every other verb in this class carries only a record name.

**`idms_session_statement` (BIND, READY, FINISH, COMMIT, ROLLBACK):**
```cobol
      BIND RUN-UNIT.
*>     syntax: BIND RUN-UNIT [FOR subschema-name] [DBNODE nodename] [DBNAME database-name]
*>             [DICTNODE nodename] [DICTNAME dictionary-name] .   — no record operand

      BIND CUSTOMER-REC.
*>     syntax (different sub-form — see Pitfall 4): BIND record-name [TO record-location] .
*>             or: BIND record-location WITH record-name .

      READY CUST-AREA USAGE-MODE IS UPDATE.
*>     syntax: READY [area-name] [USAGE-MODE IS [PROTECTED|EXCLUSIVE] [RETRIEVAL|UPDATE]] .
*>             (area-name omitted = all areas; RETRIEVAL is the default access mode)

      FINISH TASK.
*>     syntax: FINISH [TASK] .

      COMMIT TASK ALL.
*>     syntax: COMMIT [TASK] [ALL] .   — confirmed against the dedicated COBOL page
*>             (commit-cobol.html) this session: TASK and ALL are both optional and
*>             independent, either or both may appear.

      ROLLBACK CONTINUE.
*>     syntax: ROLLBACK [TASK] [CONTINUE] .
```

**`idms_accept_statement` (ACCEPT — IDMS forms only, anchored per D-06):**
```cobol
      ACCEPT WS-DB-KEY FROM CUSTOMER-REC CURRENCY.
*>     "ACCEPT DB-KEY FROM CURRENCY" — moves the database key of the current record of
*>     run unit/record-type/set/area into program storage. Does NOT update currencies.
*>     If no currency established: 0000 to ERROR-STATUS, -1 to the db-key field.

      ACCEPT WS-DB-KEY FROM CUSTOMER-REC DB-KEY.
*>     "ACCEPT DB-KEY RELATIVE TO CURRENCY" family — the DB-KEY-anchored form (D-06's
*>     second anchor). Exact operand-tail shape not independently re-verified against the
*>     dedicated page this session; anchor keyword confirmed present.
```
General standard-COBOL `ACCEPT` (the 1,757-occurrence form this phase must leave untouched):
```
      ACCEPT WS-FIELD FROM DATE.
      ACCEPT WS-FIELD.
```
— matches the existing `accept_statement`/`_accept_body` rule (grammar.js:1508-1540, read this
session) exactly; no grammar change to this path is needed or wanted.

### `queries/idms.scm` — extraction query skeleton (D-04)
```scheme
; Source: pattern precedented by queries/sample.scm (read this session)
(idms_navigation_statement (idms_record_name) @record)
(idms_navigation_statement (idms_set_name) @set)
(idms_update_statement (idms_record_name) @record)
(idms_update_statement (idms_set_name) @set)
(idms_session_statement (idms_record_name) @record)
(idms_accept_statement (idms_record_name) @record)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.cbl` recall bar stated as "measurably above 27%" | Gap-closure fraction `(X-17,905)/14,455` on the grammar-alone axis | 2026-08-29, D-13 (this phase's own discussion) | Old bar compared a grammar-alone number to a `neutralize()`-inclusive ceiling that already covers IDMS — unsatisfiable as stated; ROADMAP.md/PROJECT.md amended per D-16 before this plan runs |
| NIST skip threshold assumed to be 12 | 11 entries, verified via direct read of `skip_tests.txt` this session | Corrected in Phase 1 | Inheriting 12 would silently permit one new regression |
| CI asserting `tree-sitter test` passes | CI (`test.yml`) has the `tree-sitter test` step **commented out** — verified by reading the file this session | Unknown — predates this fork's history | D-11's new `fork-checks.yml` is not "adding a second CI gate," it's adding the *first* one; the corpus-fixture regression net is currently unenforced |

**Deprecated/outdated:** The idea that "13/13 corpus fixtures pass" is a safe blanket claim — the
`comment` fixture has failed since before Phase 1 (pre-existing, upstream commit `4bc6ff5`); the true
baseline going into this phase is 12/13, and `tree-sitter test -e '^comment$'` (verified this session:
exit 0 with the filter, exit 1 without) is the mechanism that lets D-11's new CI gate assert against
that real baseline rather than a false 13/13 expectation.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A pure-grammar `repeat` (not an external-scanner token) is the right mechanism for `idms_unparsed_tail` | Architecture Patterns → "The idms_unparsed_tail Boundary" | If wrong, the tail absorber may need scanner.c changes after all — a materially larger, riskier lift than assumed; would require revisiting the "no new C code" cost estimate |
| A2 | The `ACCEPT DB-KEY RELATIVE TO CURRENCY` variant's exact operand-tail shape is the same DB-KEY-anchored pattern as `ACCEPT DB-KEY FROM CURRENCY` | Code Examples → `idms_accept_statement` | If the RELATIVE TO variant's trailing keyword differs from a bare `DB-KEY` anchor, D-06's "anchor on DB-KEY" rule could under- or over-match; the differential script (D-07) will surface this empirically regardless |
| A3 | `idms_unparsed_tail`'s atomic token set (`WORD`, `integer`, `_LITERAL`, plus punctuation) is sufficient without needing a new leaf-token type | Architecture Patterns → "The idms_unparsed_tail Boundary" | If some IDMS clause token doesn't already lex as one of these, the tail rule could fail to absorb it cleanly, producing an unexpected ERROR instead of an `idms_unparsed_tail` |

## Open Questions

1. **Which `BIND` sub-form(s) actually predominate in the estate/DCC corpus?**
   - What we know: the manual documents at least two shapes (`BIND RUN-UNIT`, argument-free; `BIND
     RECORD`, record-name-bearing); raw estate counts (4631 estate-wide) don't distinguish them.
   - What's unclear: whether hand-typed `BIND RECORD` occurs at meaningful volume, or whether it's
     almost always auto-generated by `COPY IDMS SUBSCHEMA-BINDS` and therefore rare in raw source.
   - Recommendation: draft both sub-forms under `idms_session_statement`, run the D-09 option-coverage
     count against DCC, and let `idms_unparsed_tail` frequency settle which shape needs priority.

2. **Resolved during this research session.** ~~Does the COBOL-specific `COMMIT` page match the
   general DML-control-statement syntax found?~~ Yes — `commit-cobol.html` fetched directly this
   session confirms `COMMIT [TASK] [ALL]`, both optional and independent. No follow-up needed.

3. **Where does the IDMS-04 `TestErrorCascade` gap get closed — same-phase or a coordinated follow-up?**
   - What we know: `TestErrorCascade` in the `gortex` repo currently has zero IDMS DML injection cases
     (verified this session); IDMS-04 explicitly names this test as its gate.
   - What's unclear: whether the plan should include a task that edits the `gortex` repo directly
     (crossing outside this fork's own git history), or whether that's tracked as a dependency/blocker
     for a human to apply in the other repo.
   - Recommendation: the plan should include an explicit task for this, clearly marked as touching a
     different repository, distinct from the FORK-03-scoped grammar commit.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `tree-sitter-cli` (pinned, via `node_modules/.bin/tree-sitter`) | Regenerating the parser, running corpus tests | ✓ `[VERIFIED: ran node_modules/.bin/tree-sitter --version this session]` | 0.24.5 | — |
| `run_nist_cobol85.sh` + `cobc` (GnuCOBOL, for `check_tests.sh` only — not invoked by the NIST runner itself) | IDMS-06's NIST gate | ✓ (script present; `cobc` not probed this session — NIST runner uses `tree-sitter parse` exit codes, not `cobc`) | — | — |
| `go` toolchain + `~/repos/mine/GoApps/gortex` checkout | IDMS-04/05/08's `cobolprobe` measurement | Not probed this session (external repo; Phase 1 already proved this path twice per `docs/vendoring.md`) | — | Re-run Phase 1's `forest-shim/refresh.sh` + `go work` sequence if the workspace link has been torn down since |
| `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` (606 `.cbl`/958 `.cpy`, corpus of record) | All recall/differential measurement | Not probed this session (path referenced in `docs/baseline.md`, presumed present from Phase 1) | — | — |

**Missing dependencies with no fallback:** none identified — everything this phase needs was either
verified present this session or was already proven present twice in Phase 1.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | tree-sitter's own corpus-test format (`test/corpus/*.txt`, source/`---`/expected-s-expression), invoked via the pinned `tree-sitter test` CLI |
| Config file | none — corpus format is convention-based, no config file (verified: `node_modules/.bin/tree-sitter test --help` this session shows no `--config` requirement beyond the optional `--config-path`) |
| Quick run command | `node_modules/.bin/tree-sitter test -i '<new-fixture-test-name-regex>'` — fast, single-fixture iteration |
| Full suite command | `node_modules/.bin/tree-sitter test -e '^comment$' && sh run_nist_cobol85.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IDMS-01 | 14 verbs parse to named nodes, no ERROR | corpus | `tree-sitter test -i '<idms fixture name>'` | ❌ Wave 0 — new `test/corpus/idms_dml.txt` (or per-cluster files) needed |
| IDMS-02 | Query captures record/set names | manual/scripted query check | `tree-sitter query queries/idms.scm <fixture>.cbl \| grep -c '@record\|@set'` | ❌ Wave 0 — `queries/idms.scm` doesn't exist yet |
| IDMS-03 | ACCEPT disambiguation, zero reclassification | corpus + differential | `tree-sitter test -i 'accept'` + the D-08 differ script | ❌ Wave 0 — both the ACCEPT-regression fixture and the differ script are new |
| IDMS-04 | Cascade parity at an IDMS DML injection | Go test (external repo) | `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v` (in `gortex`) | ❌ Wave 0 — `TestErrorCascade` has no IDMS case yet (see Pitfall 3) |
| IDMS-05/08 | Grammar-alone recall rises, tail doesn't grow, target set | Go test (external repo), corpus-gated | `go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m -corpus <DCC> -neut-corpus <DCC>` | ✓ exists (`probe_test.go`/`neutralize_test.go`), re-run needed after regeneration |
| IDMS-06 | 13 fixtures pass (comment excluded), NIST ≤ 11 skips | corpus + NIST shell script | `tree-sitter test -e '^comment$'` (exit 0, VERIFIED this session) + `sh run_nist_cobol85.sh` | ✓ both exist |
| IDMS-07 | Separable commit, no site-specific naming | process/manual (git log inspection) | none automated — manual review against FORK-03 | — |

### Sampling Rate
- **Per task commit:** `tree-sitter test -i '<touched fixture>'` (fast, single fixture)
- **Per wave merge:** `tree-sitter test -e '^comment$'` (full 12-fixture pass) + `sh run_nist_cobol85.sh`
- **Phase gate:** full suite green, PLUS the D-08 differential script run manually on both corpora,
  PLUS a `cobolprobe` re-run (recall + cascade) through the regenerated shim, before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/corpus/idms_dml.txt` (or per-cluster files, planner's discretion) — covers IDMS-01, IDMS-02
- [ ] `queries/idms.scm` — covers IDMS-02
- [ ] The D-08 differential shell script (repo root) — covers IDMS-03
- [ ] `.github/workflows/fork-checks.yml` — covers IDMS-06's CI enforcement (D-11)
- [ ] A `TestErrorCascade` IDMS-injection case in the `gortex` repo (cross-repo, see Pitfall 3) — covers IDMS-04

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | Not applicable — this is a standalone grammar/parser library, no auth surface |
| V3 Session Management | No | Not applicable |
| V4 Access Control | No | Not applicable |
| V5 Input Validation | Yes, narrowly | Not "input validation" in the web-app sense — the concern is **parser resource exhaustion**: the GLR path (`conflicts:`+`prec.dynamic()`) forks the parse stack on ambiguous input, and an adversarially-crafted or pathological COBOL source exercising the ACCEPT collision at scale could increase parse time/memory beyond the static-`prec()` path's cost. Mitigation: prefer static `prec()` resolution (see "The ACCEPT Conflict"); if GLR is unavoidable, keep the `conflicts:` set as small as possible (exactly the one collision, not a broader set) |
| V6 Cryptography | No | Not applicable — no cryptographic operations in this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| GLR state-explosion on adversarial/pathological input (unbounded `conflicts:` growth) | Denial of Service | Prefer static `prec()`/LALR resolution over `conflicts:`+`prec.dynamic()` wherever `tree-sitter generate` proves it sufficient (see "The ACCEPT Conflict"); keep any declared `conflicts:` set minimal |
| Proprietary `estate/` source leaking into a public fixture or commit | Information Disclosure | Already covered by FORK-02 (`.githooks/estate-guard.sh`, re-closed in Phase 1) — applies unchanged to any new fixture this phase adds; D-10 additionally requires every new fixture be hand-written from the manual, never an estate excerpt |

## Sources

### Primary (HIGH confidence)
None — no tool-confirmed-and-authoritative findings meeting the strict `[VERIFIED]` bar exist for
external (non-repo) claims this session; the in-repo `[VERIFIED: path:lines]` citations below are the
closest equivalent and are called out inline throughout this document.

### Secondary (MEDIUM confidence — CITED against an authoritative source)
- [Tree-sitter: Writing the Grammar](https://tree-sitter.github.io/tree-sitter/creating-parsers/3-writing-the-grammar.html) — `conflicts` field semantics, GLR exploration
- [Tree-sitter: The Grammar DSL](https://tree-sitter.github.io/tree-sitter/creating-parsers/2-the-grammar-dsl.html) — `prec`/`prec.left`/`prec.right`/`prec.dynamic` exact wording
- [FIND/OBTAIN (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/find-obtain-cobol.html) and its DB-KEY/CALC/OWNER/WITHIN-SET/CURRENT sub-pages
- [STORE (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/store-cobol.html), [ERASE (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/erase-cobol.html), [CONNECT (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/connect-cobol.html), [DISCONNECT (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/disconnect-cobol.html), [MODIFY (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/modify-cobol.html), [GET (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/get-cobol.html)
- [BIND RUN-UNIT (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/bind-run-unit-cobol.html), [BIND RECORD (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/bind-record-cobol.html), [READY (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/ready-cobol.html), [FINISH (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/finish-cobol.html), [ROLLBACK (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/rollback-cobol.html)
- [ACCEPT (COBOL)](https://techdocs.broadcom.com/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/accept-cobol.html), [ACCEPT DB-KEY FROM CURRENCY (COBOL)](https://techdocs.broadcom.com/content/broadcom/techdocs/us/en/ca-mainframe-software/database-management/ca-idms-reference/19-0/dml-reference-for-cobol/cobol-data-manipulation-language-dml-statements/accept-db-key-from-currency-cobol.html)

### In-repo, VERIFIED this session (read/ran directly)
- `grammar.js:1334-1560, 1584-1609, 2215-2233, 2831, 2957, 3423` — `_procedure_division_statement`,
  `_procedure`, `_statement`, `accept_statement`/`_accept_body`, `add_statement`, `move_statement`,
  `_ACCEPT` keyword regex
- `grammar.js:423-429` — `select_statement` (operand-extraction precedent)
- `queries/sample.scm` — the repo's only existing query, field+`#eq?` pattern
- `docs/vendoring.md`, `docs/baseline.md` — regeneration sequence, recall baseline, build order
- `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/ARCHITECTURE.md`
- `package.json` (`tree-sitter-cli: ^0.24.5`), `skip_tests.txt` (11 entries), `test/corpus/*.txt` (13
  files), `.github/workflows/test.yml` (the `tree-sitter test` step is commented out)
- `node_modules/.bin/tree-sitter --version` → `0.24.5`; `tree-sitter test --help` → `-i/-e` flags
  present; `tree-sitter test -e '^comment$'` → exit 0 (all 81 non-comment cases pass); `tree-sitter
  test` (unfiltered) → exit 1 (comment fails)
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/neutralize_test.go:16-44` — `reExec`,
  `reDML`, `reSchema`, `neutralize()`
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go:1-80` —
  `TestErrorCascade` (confirmed: no IDMS DML injection case exists)
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/README.md`

### Tertiary (LOW confidence — not independently re-verified)
- General web-search summaries of IDMS statement families (superseded in this document by the
  directly-fetched TechDocs pages wherever both exist; retained only where no dedicated page was
  fetched, e.g. the general `COMMIT`/`ROLLBACK` control-statement summary — see Open Question 2 and
  Assumption A2)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, pinned CLI version verified directly against the
  installed binary this session
- Architecture (four-node model, ACCEPT conflict mechanism, tail boundary): MEDIUM — tree-sitter
  mechanics are CITED against official docs and cross-checked against this repo's actual grammar.js
  state; the specific `idms_unparsed_tail` token set is not yet empirically validated against fixtures
- IDMS DML syntax: MEDIUM — CITED against the published manual (D-10's mandated ground truth) for all
  14 verbs, including a direct fetch confirming the COBOL-specific COMMIT clause set; one remaining
  sub-detail (the exact ACCEPT DB-KEY RELATIVE TO CURRENCY operand-tail shape) is flagged `[ASSUMED]`
  (see A2) since the differential script (D-07) will surface it empirically regardless
- Pitfalls: HIGH — Pitfall 3 (no existing IDMS case in `TestErrorCascade`) and the CI filter behavior
  (Pitfall/CI Mechanics) were confirmed by directly reading/running the actual files this session, not
  inferred

**Research date:** 2026-08-29
**Valid until:** 30 days for the tree-sitter mechanics and in-repo findings (stable); the CA IDMS manual
citations are effectively evergreen (mainframe DML syntax does not churn) but should be re-confirmed if
the fetch dates ever matter for an audit trail.
</content>
