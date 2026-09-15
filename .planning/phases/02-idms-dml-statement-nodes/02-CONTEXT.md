# Phase 2: IDMS DML Statement Nodes - Context

**Gathered:** 2026-08-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Teach `grammar.js` the **IDMS DML statements** so the estate's 14 verbs become walkable, named AST
nodes whose **record** and **set** operands are extractable by a tree-sitter query — and convert
the "rises measurably" recall bar into a concrete, allocable number (OQ-3 / IDMS-08).

**In scope:** the DML *statement* forms only (locked decision D3 — preprocessing owns the
structural IDMS constructs `IDMS-CONTROL SECTION`, `PROTOCOL.`, `SCHEMA SECTION`, `DB x WITHIN y`).
The 14 verbs measured in the estate: BIND, OBTAIN, FIND, READY, ERASE, ACCEPT, GET, STORE, FINISH,
MODIFY, CONNECT, ROLLBACK, COMMIT, DISCONNECT.

**Out of scope:** `EXEC CICS` (Phase 3), `EXEC SQL` (Phase 4), `EXEC DLI` (locked out, D4), the
already-precompiled `CALL 'IDMS' USING SUBSCHEMA-CTRL` form (see D-09), Endevor `-INC`, and the
`site-macro`/`%`-macro language.

### Amendments this discussion requires to ROADMAP.md and PROJECT.md

Three roadmap-level statements were found to be wrong during this discussion. Per D-16 they are
corrected **before** `/gsd-plan-phase 2` runs, so the planner plans against satisfiable criteria:

1. **ROADMAP Phase 2, criterion 4** — "`.cbl` recall … is measurably above 27%" compares a
   grammar-alone number against a `neutralize()`-assisted ceiling that *already includes IDMS*.
   Replace with the gap-closure formulation in D-13.
2. **ROADMAP Phase 4, criterion 5** — "`.cbl` recall meets or exceeds the target set in Phase 2"
   is unsatisfiable: the corpus of record contains **zero** `EXEC SQL`. Retire the recall clause;
   Phase 4 keeps its four other gates.
3. **OQ-3** (ROADMAP, PROJECT.md, STATE.md) — the *resolution rule* is now decided (gap-closure on
   the grammar-alone axis). The *value* is still set by Phase 2's measurement.

</domain>

<decisions>
## Implementation Decisions

### Node shape

- **D-01:** DML statements are modelled as **four verb-class node types**, not one generic node and
  not fourteen per-verb rules: `idms_navigation_statement` (OBTAIN, FIND), `idms_update_statement`
  (STORE, MODIFY, ERASE, CONNECT, DISCONNECT, GET), `idms_session_statement` (BIND, READY, FINISH,
  COMMIT, ROLLBACK), `idms_accept_statement` (ACCEPT). Each carries `field('verb', …)` and shares
  the record/set operand sub-rules. Rationale: the 14 verbs cluster into exactly these four operand
  shapes; four rules keep the query to ~4 patterns without the LR-conflict surface and OBTAIN/FIND
  duplication that 14 rules would add to a 3,783-line file.
  — **Reversibility:** costly — the node names are the contract `queries/idms.scm` and gortex's
  graph builder both read; renaming them means a coordinated change across two repos.

- **D-02:** The record and set names are **their own named rules** — `idms_record_name` and
  `idms_set_name` — not `field()` labels on the statement node. Rationale: tree-sitter fields bind
  to direct children of the declaring rule, so a `record:` field on the statement cannot reach an
  operand living inside a shared clause sub-rule. Named nodes make the query depth-independent
  (`(idms_record_name) @record` matches under any of the four statement types) and survive later
  grammar refactors without breaking the consumer's query.
  — **Reversibility:** costly — same cross-repo query contract as D-01.

- **D-03:** An operand tail the grammar does not model is **absorbed into a named
  `idms_unparsed_tail` node**, not left to ERROR and not silently swallowed. Rationale: this
  guarantees IDMS-04's cascade elimination for 100% of DML regardless of coverage gaps (a missed
  option costs an edge, never a division) *and* makes the gap countable — `idms_unparsed_tail`
  frequency across the corpus is the coverage metric that drives D-07's extension list.

- **D-04:** The extraction query ships **from this fork** as `queries/idms.scm` — capturing
  `(idms_record_name) @record`, `(idms_set_name) @set`, and the verb. Rationale: `queries/` is an
  upstream-owned path, so the query stays inside the separable grammar commit (FORK-03), and a node
  rename lands in the same commit as its query update. gortex reads it rather than reinventing it.

### ACCEPT containment (the named regression gate)

- **D-05:** The IDMS forms get a **separate `idms_accept_statement` rule** alongside the existing
  `accept_statement` in `_statement`, **anchored on the required trailing keyword** so it can only
  win when that token is present. Rationale: preserves the D-01 four-node symmetry and keeps the
  query uniform. Planner must note the real hazard: `_accept_body` (grammar.js:1513) already ends
  with `seq($._FROM, field('from', choice(…, $.WORD)))`, so an IDMS ACCEPT *already* matches a
  complete standard ACCEPT and diverges only on the following token. The two rules share a viable
  prefix — an explicit `conflicts:` entry or precedence is required, and that resolution is exactly
  where a silent reclassification of standard COBOL could hide.
  — **Reversibility:** costly — undoing means merging the rule back into `_accept_body`, which
  changes the emitted node type and therefore `queries/idms.scm` and gortex's query.

- **D-06:** Anchor keywords are **`CURRENCY` and `DB-KEY` only** — SPEC-001's two named forms, the
  ones the 634 figure was derived from. Extend only on evidence: if the differential lands short of
  634, the shortfall names which forms are missing and they are added within this phase. Rationale:
  smallest blast radius against the 1,757 standard ACCEPTs, and no modelling of forms with no
  evidence they occur. **Note the asymmetry:** `idms_unparsed_tail` does *not* fire for a missed
  IDMS ACCEPT — an unanchored form falls back to standard `accept_statement` and ERRORs on the tail.
  For ACCEPT specifically the coverage signal is "`idms_accept_statement` count short of 634".

- **D-07 (evidence standard):** IDMS-03's "provably unaffected" means a **before/after differential
  parse**, not fixtures alone: every node that was `accept_statement` before the change is still
  `accept_statement` after — **zero reclassifications, a hard gate** — and the new
  `idms_accept_statement` count lands near 634. Run through the Phase 1 vendoring path.
  **Refinement from this discussion's measurement:** run it on **both** corpora. DCC (the corpus of
  record) holds 2,027 `ACCEPT`s / 750 `CURRENCY` / 1,042 `DB-KEY` in its 606 `.cbl` and parses in
  ~18 seconds; the estate is where the 1,757 / 634 split was originally measured (52,233 files).
  DCC is the fast inner loop, the estate is the authority for the numbers SPEC-001 quotes.

- **D-08:** The differ lives as a **committed fork-local, re-runnable shell script at repo root** —
  matching this repo's own convention (`run_nist_cobol85.sh` sits there) — invoked manually at the
  end of each family's work. Fork-local, so it never enters the separable grammar commit.
  Deliberately **not** wired into `pre-push`: a full estate parse is far too slow for that choke
  point, and a sampled gate would be a weaker guarantee than the manual full run. Costs ~30 minutes
  once, then it is free for Phases 3–4 and for re-verification after any upstream pull.

### Coverage surface

- **D-09:** Initial option set is **minimal-to-edges**: model only what is needed to expose
  `verb` + `idms_record_name` + `idms_set_name` — the `WITHIN` / `TO` / `FROM` clauses and the
  `CALC` / `OWNER` / `DB-KEY` / `FIRST` / `LAST` / `NEXT` / `PRIOR` selectors that determine which
  name is which. Everything else (usage modes, `PERMANENT` / `SELECTIVE` / `ALL`, sort keys) lands
  in `idms_unparsed_tail`. Then count tails across the corpus and extend where the volume is.
  Rationale: smallest diff, cheapest to rebase onto upstream, and the extension list is *measured*
  rather than imagined — no speculative generality.

- **D-10:** Syntax ground truth is the **published CA IDMS DML reference syntax diagrams**; the
  estate contributes **counts only** (priority ranking). Fixtures are written from the manual's own
  generic shapes with **invented neutral names** (e.g. `CUSTOMER-REC`, `CUST-ORDER-SET`). Rationale:
  the manual is what makes this "generic dialect support" rather than a site-specific hack
  (PROJECT.md constraint), and nothing estate-derived — not even a paraphrased shape — crosses into
  a tracked file in a public repo. IDMS-07's "minimal, hand-written construct, never an estate
  excerpt" is satisfied by construction.

- **D-11:** Phase 2 gives the corpus gate teeth: add a **fork-local
  `.github/workflows/fork-checks.yml` on `main`** running `tree-sitter test`, with the pre-existing
  `comment` fixture **excluded and annotated** (pointer to upstream commit `4bc6ff5` and the open
  deviation in `.planning/WINDOWS.md`). Upstream's `test.yml` is not touched, so FORK-03 holds.
  Rationale: CI today runs `generate` → NIST and never runs the 13 corpus fixtures, so IDMS-06's
  gate is currently an assertion, not an enforcement — and that is exactly how the `comment`
  fixture rotted to 12/13 unnoticed. Carried forward from Phase 1's deferred list, which explicitly
  earmarked this for Phase 2. The standing exclusion must be revisited, not forgotten.

- **D-12:** The **precompiled `CALL 'IDMS' USING SUBSCHEMA-CTRL` form is out of scope**, recorded
  with its reason plus **a one-off count of how many estate programs are in precompiled form**.
  Rationale: it already parses as ordinary COBOL, causes no cascade, and is a precompiler artifact
  rather than COBOL dialect syntax — recognising it would be the clearest example of the
  site-specific hack PROJECT.md rules out. The count matters because precompiled programs will
  correctly show **zero** DML nodes, and any edge-coverage claim must be read against the right
  denominator. **Measured during this discussion: `CALL 'IDMS'` appears 0 times in DCC `.cbl`, so
  this is an estate-only concern and does not affect the recall measurement at all.**

### Recall target (criterion 4 / IDMS-08 / OQ-3)

- **D-13:** The target is a **gap-closure fraction on the grammar-alone axis**, not an absolute
  percentage: `(X − 17,905) / (32,360 − 17,905)`, where 17,905 is the Phase 1 grammar-alone `.cbl`
  `dataItems` count and 32,360 is the `+ neutralize()` count. Phase 2's measured share sets N;
  Phase 3 is held to closing the remainder. **Terminal condition: grammar-alone ≥ neutralized** —
  the point at which `neutralize()` retires. Rationale: `neutralize()` already rewrites IDMS DML
  (gortex `neutralize_test.go:24`), so 26.6% is the ceiling Phase 2 climbs toward, not a bar it
  clears. Bonus property: a ratio of two raw numerators is immune to the borrowed-denominator
  caveat `docs/baseline.md` §2 flags.
  — **Reversibility:** one-way — this replaces ROADMAP criterion 4 and retires Phase 4 criterion 5;
  once Phases 3–4 are planned against the gap-closure frame, reverting to an absolute-percentage
  gate would require re-baselining and re-verifying both phases.

- **D-14:** The 14,455-item gap is allocated **entirely across Phases 2 and 3**; **Phase 4's recall
  criterion is retired**. Rationale (measured during this discussion): DCC contains **zero**
  `EXEC SQL`, zero `SQLCODE`, zero `SQLCA`, zero `DCLGEN`, and `EXEC CICS` 2,978 ≈ `END-EXEC` 2,976
  — every EXEC block in the corpus of record is CICS. So the gap between grammar-alone and
  neutralized on DCC is attributable **entirely to IDMS + CICS**, and closes to ~zero at the end of
  Phase 3. Phase 4 keeps its four other gates (table name captured, cascade parity,
  `tree-sitter test`, NIST ≤ 11) — it simply has no recall signal available on this corpus.

- **D-15:** The number is **hard on direction, explained on magnitude**. Blocking: grammar-alone
  must rise, and `idms_unparsed_tail` must not grow. Non-blocking but mandatory: missing the
  allocated share requires a **written cause on file** naming what absorbed it. Rationale: recall on
  DCC is not purely a function of this grammar — `.cpy` grammar-alone sits at 0% because copybooks
  have no `IDENTIFICATION DIVISION` to anchor a parse, and Endevor `-INC` (61% of estate programs)
  is preprocessing's problem. Gating hard on a number the phase does not fully control invites
  redefining the number. This mirrors how Phase 1 handled its own baseline divergence: disclosed
  and explained, never adjusted away.

- **D-16:** The ROADMAP / PROJECT amendments listed in `<domain>` land **now, as a docs commit
  before `/gsd-plan-phase 2` runs** — not as a task inside Phase 2's plan. Rationale: `gsd-planner`
  and `gsd-verifier` both read ROADMAP.md directly; planning a phase against a criterion already
  known to be unmeasurable produces tasks built to satisfy it.

### Claude's Discretion

- Exact rule and node names within the four verb classes (`idms_navigation_statement` etc. are the
  agreed shape; final spelling is planner's, provided `idms_record_name` / `idms_set_name` /
  `idms_unparsed_tail` are used verbatim since they are the query contract).
- Fixture file layout under `test/corpus/` — one `idms_dml.txt` vs. per-cluster files vs. a separate
  file isolating the ACCEPT regression gate. Repo convention is per-topic files.
- The conflict-resolution mechanism for D-05 (explicit `conflicts:` entry vs. `prec` vs.
  `prec.dynamic`) — provided the zero-reclassification differential passes.
- The differ script's name, language, and output format; whether it takes a corpus path argument.
- How `idms_unparsed_tail` counts are reported at phase end (table in `docs/baseline.md` vs. a
  separate note).
- Plan decomposition and commit sequencing within the phase, subject to FORK-03.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth for the project
- `docs/spec/SPEC-001-nodes-for-edges.md` — §5 the in-scope table, the IDMS verb mix, and the
  ACCEPT ambiguity note (2,391 naive / 634 IDMS / 1,757 standard); §6 the six per-family acceptance
  criteria; §9 locked decisions D1–D4. **§6 criterion 3's "rises measurably" is superseded for
  Phase 2 by D-13 above.**
- `.planning/PROJECT.md` — locked decisions D1–D6, the constraints block (NIST threshold is **11**,
  not 12; standard COBOL unharmed; proprietary estate vs. public fork), the measured baseline table
  and the volume table. Open Questions table carries OQ-3.
- `.planning/REQUIREMENTS.md` lines 73–104 — IDMS-01…IDMS-08 in checkable form.
- `.planning/ROADMAP.md` — Phase 2 goal and five success criteria. **Criteria 4 (Phase 2) and 5
  (Phase 4) are amended per D-16 before planning.**
- `.planning/phases/01-delivery-pipe-measurement-baseline/01-CONTEXT.md` — D-12…D-15 (fork hygiene
  re-scoped, upstream PRs not a goal, FORK-03 is the binding rule), and the deferred-ideas list
  whose "fork-local CI workflow running `tree-sitter test`" item is folded in here as D-11.

### Delivery pipe and measurement method (Phase 1 output — read before measuring anything)
- `docs/vendoring.md` — the `go.work`-resolved shim at `forest-shim/cobol/`, the
  `forest-shim/refresh.sh` regenerate-and-refresh sequence, and the open question about which CLI
  produced the committed `src/parser.c` (1215/585 vs. 1153/523).
- `docs/baseline.md` — **the baseline of record.** §2 has the exact `go test` invocation, the
  measured cells (`.cbl` 606 files, 17,905 grammar-alone / 32,360 neutralized against a borrowed
  121,457 denominator; `.cpy` 0 / 22,800), and the explicit caveat that the denominators were not
  re-derived. D-13's gap-closure ratio is built from the two numerators, not the denominator.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/README.md` — the published method
  and the `-corpus` / `-neut-corpus` flags.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/neutralize_test.go` **lines 23–24**
  — `reExec` and `reDML`. **This is the evidence for D-13:** `reDML` already rewrites OBTAIN, FIND,
  GET, STORE, MODIFY, ERASE, CONNECT, DISCONNECT, READY, FINISH, BIND, ACCEPT, COMMIT, ROLLBACK,
  KEEP to `CONTINUE`. Note `reDML` matches *any* `ACCEPT` line, standard COBOL included.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go` — `TestErrorCascade`,
  the IDMS-04 gate.

### The grammar surface this phase edits
- `grammar.js:1366` — `_statement`, the flat `choice()` of ~37 `*_statement` rules the four new
  node types are added to.
- `grammar.js:1508–1513` — `accept_statement` and `_accept_body`. **The collision site.** The
  `$.WORD` arm of the `FROM` choice already matches an IDMS record name.
- `grammar.js:1334–1347` — `_procedure_division_statement` and `_procedure`, which reach `_statement`.
- The keyword block around `grammar.js:2831` (`_ACCEPT`) — the
  `_KEYWORD: $ => /[kK][eE][yY].../` case-insensitive regex convention new DML verbs must follow.
- `.planning/codebase/CONVENTIONS.md` — the authoritative guide to those conventions: `_`-prefix for
  private rules, `field()` labelling (`select_statement` is the model for operand extraction),
  `prec.left` / `prec.right` usage, when to add a helper.
- `.planning/codebase/ARCHITECTURE.md` — the generate pipeline and the "never hand-edit
  `src/parser.c` / `grammar.json` / `node-types.json`" constraint.

### The regression net (do not build a parallel one — PROJECT.md constraint)
- `test/corpus/*.txt` — 13 files, source / `---` / expected s-expression format. `evaluate.txt`,
  `perform.txt`, `occurs.txt` show the per-topic file convention.
- `run_nist_cobol85.sh` + `skip_tests.txt` — **11** entries (NC205A, SM101A, SM103A, SM105A,
  SM107A, SM201A, SM203A, SM205A, SM206A, SM208A, SM401M). Not 12.
- `test/check_tests.sh`.
- `.planning/WINDOWS.md` — the open deviation recording the pre-existing `comment` fixture failure
  (12/13), which D-11's CI workflow must exclude.
- `.git/hooks/pre-push` + the estate-leak guard and its self-test (Phase 1, FORK-02) — still the
  last gate before anything reaches the public remote.

### Corpora
- `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` — **the corpus of record.** 606 `.cbl` + 958 `.cpy`.
  Measured during this discussion (counts only, no content): `BIND` in 299 `.cbl` files (49%),
  `OBTAIN` 233, `READY` 302, `STORE` 182, `MODIFY` 189, `ERASE` 146, `CONNECT` 139, `DISCONNECT`
  108, `FINISH` 450, `COMMIT` 63, `ROLLBACK` 82; `ACCEPT` 2,027 occurrences / 457 files,
  `CURRENCY` 750, `DB-KEY` 1,042; `EXEC CICS` 2,978 / 169 files; `EXEC SQL` **0**;
  `CALL 'IDMS'` **0**.
- `estate/` — 697 MB, excluded via `.git/info/exclude`, **public repo, never a fixture source**.
  Volume-counting and differential input only.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`_statement` (grammar.js:1366)** — a flat `choice()`. Adding four entries is the entire
  integration; DML then becomes legal anywhere a statement is (inside `IF`, `PERFORM`, sentences)
  for free.
- **`select_statement` (grammar.js:423) and `mnemonic_name_clause`** — the repo's existing pattern
  for exactly this problem: pulling a named operand out of a statement
  (`field('file_name', $.WORD)`). D-02 uses named nodes rather than fields, but these are the
  precedent for how operand extraction reads in this grammar.
- **`run_nist_cobol85.sh` at repo root** — the convention D-08's differ script follows (shell script
  at root). PROJECT.md forbids inventing a parallel harness; the differ is a *new* measurement, not
  a duplicate of an existing one.
- **The Phase 1 pipe** — `forest-shim/refresh.sh` → `go.work` → `cobolprobe`. Already proven twice.
  Phase 2 is the first phase where `grammar.js` actually changes, so this is the first regeneration
  the pipe carries.
- **`queries/sample.scm`** — `queries/` already exists and forest's drop-in layout carries
  `sample.scm` / `_keep.scm` through to gortex, so D-04's `idms.scm` has a delivery path.

### Established Patterns
- **Case-insensitive keyword regexes** (`_ACCEPT: $ => /[aA][cC][cC][eE][pP][tT]/`) — every new DML
  verb keyword follows this. Note many keywords sit commented out (`//ACCEPT: $ => $._ACCEPT,`),
  the repo's marker for "declared but not exported as a node".
- **Generated artifacts are committed** — `src/parser.c`, `src/grammar.json`, `src/node-types.json`
  are tracked. A `grammar.js` change means regenerating and committing them, and that regeneration
  is exactly what `docs/vendoring.md`'s open CLI question is about (committed 1215/585 vs. 1153/523
  from both measured CLI versions). Planner should expect the committed `src/` to change shape on
  first regeneration and should treat that as the already-recorded open question, not a new defect.
- **`.gitignore` is upstream's; `.git/info/exclude` is ours** — asserted by FORK-02.
- **Per-topic corpus files** — `evaluate.txt`, `perform.txt`, `occurs.txt`.

### Integration Points
- **`grammar.js:1366` `_statement`** — where the four node types attach.
- **`grammar.js:1513` `_accept_body`** — the ambiguity site; the only place standard COBOL is at
  risk.
- **`queries/idms.scm`** — the new consumer contract; gortex reads it.
- **`.github/workflows/fork-checks.yml`** — new, fork-local, `main`-only (D-11).
- **`cobolprobe` `TestErrorCascade`** — the IDMS-04 gate, run through the Phase 1 pipe.

</code_context>

<specifics>
## Specific Ideas

- **Coverage is measured, not guessed.** The same posture was chosen three times independently —
  `idms_unparsed_tail` (D-03), "SPEC's two anchors then extend on evidence" (D-06), and
  "minimal-to-edges then extend on the count" (D-09). Downstream agents should treat "ship narrow,
  measure the gap, extend where the volume is" as the phase's operating principle, not as three
  separate decisions.

- **Cost-tested process, not blanket rigor.** Consistent with Phase 1's D-12…D-15: keep the cheap
  non-recoverable bits (the differ script, the CI workflow — both reusable across Phases 3–4), skip
  the expensive ones (`pre-push` estate parsing, fixing an upstream fixture bug inside an IDMS
  phase). Every option in this discussion was weighed with its cost stated.

- **Say what was measured, including when it contradicts the plan.** Three prior-doc claims were
  falsified during this discussion (neutralize already covers IDMS; DCC has no `EXEC SQL`; Phase 4's
  recall gate is unsatisfiable). All three are recorded as findings and drive amendments — none were
  smoothed over. This matches Phase 1's handling of its own baseline divergence and D-15's
  "explained on magnitude" rule.

</specifics>

<deferred>
## Deferred Ideas

- **Full manual-complete IDMS DML option coverage** — usage modes, `PERMANENT` / `SELECTIVE` /
  `ALL`, sort keys, LRF verbs (`KEEP`, `RETURN`, `IF … MEMBER`), and the verbs outside the estate's
  14. Not dropped: D-09 extends into this territory *within Phase 2* wherever
  `idms_unparsed_tail` counts justify it. What is deferred is modelling forms with no measured
  occurrence.

- **Recognising the precompiled `CALL 'IDMS'` form as IDMS nodes** — out per D-12. Would be a
  vendor calling convention expressed in ordinary COBOL, not COBOL dialect syntax. Revisit only if
  a consumer needs edges from already-precompiled programs and accepts the site-specificity.

- **Fixing the upstream `comment` corpus fixture (12/13)** — excluded rather than repaired per
  D-11. It is an upstream bug in a file this fork did not touch (last edited at `4bc6ff5`),
  unbounded in size, and repairing it would put a non-IDMS change inside a phase whose deliverable
  is a separable IDMS commit. The standing exclusion should be revisited, not forgotten.

- **A second corpus containing `EXEC SQL`** — rejected for now (D-14): a new corpus breaks the
  same-corpus / same-method comparability `docs/baseline.md` is built on, which Phase 1 worked hard
  to establish. Revisit only if Phase 4 needs a recall signal it cannot otherwise obtain.

- **An estate-measured substitute metric for Phase 4** (`EXEC SQL` node / table-capture counts over
  the 49 programs / 489 statements) — considered and not taken, since Phase 4 already carries four
  gates. Kept here because it is the obvious fallback if Phase 4's remaining criteria turn out to be
  too weak.

- **Wiring the differ into `pre-push`** — rejected on cost (D-08): a full estate parse is far too
  slow for that choke point, and a sampled gate would be weaker than the manual full run. Revisit
  only if a reclassification ever slips through the manual gate.

- **`.cpy` grammar-alone recall (0%)** — copybooks have no `IDENTIFICATION DIVISION` to anchor a
  parse, so the grammar yields nothing for them standalone; `neutralize()` gets 93%. Structural, not
  an IDMS problem, and outside every phase in this milestone. Noted so nobody reads the 0% as a
  Phase 2 failure.

- **FORK-01 (branch-hygiene guard) and the topic-branch publication workflow** — still deferred from
  Phase 1. Unchanged by this discussion.

</deferred>

---

*Phase: 2-IDMS DML Statement Nodes*
*Context gathered: 2026-08-29*
