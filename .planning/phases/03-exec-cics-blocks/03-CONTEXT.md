# Phase 3: EXEC CICS Blocks - Context

**Gathered:** 2026-09-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Teach `grammar.js` the `EXEC CICS … END-EXEC` block so the estate's CICS commands become walkable,
named AST nodes whose **transaction**, **program**, **map** and **mapset** operands are extractable
by a tree-sitter query — and stop the block destroying the paragraphs that follow it (currently
1 of 20 survive).

**In scope:** the `EXEC CICS` block form only — command name, option list, terminator, and the four
named operand nodes. Plus two bookkeeping obligations inherited from Phase 2: re-scoping and closing
**IDMS-05**, and turning the harness's logged EXEC CICS cascade line into an assertion.

**Out of scope:** `EXEC SQL` (Phase 4), `EXEC DLI` (locked out, D4), `SCHEMA SECTION` and the other
structural IDMS constructs (locked decision D3 — preprocessing owns them, in a different
repository), Endevor `-INC`, the `site-macro`/`%`-macro language, and wiring gortex to actually read
`queries/*.scm` (see D-24 — a cross-repo change outside FORK-03).

### Amendments this discussion requires before `/gsd-plan-phase 3`

Per D-16 these land as **one docs commit before planning runs**, so `gsd-planner` and `gsd-verifier`
plan and verify against satisfiable criteria:

1. **ROADMAP Phase 3, criterion 4** — the `dataItems` axis is unsatisfiable (see D-16a below).
   Replace with the `paragraph_header` formulation.
2. **CICS-04** (REQUIREMENTS.md) — currently reads "closes the remainder of the gap" on the
   `dataItems` axis. Restate on the `paragraph_header` axis.
3. **IDMS-04** (REQUIREMENTS.md) — checkbox is stale. The harness satisfies it in full (see the
   measurement record below). Mark complete.
4. **IDMS-05** (REQUIREMENTS.md) — re-scope onto the `paragraph_header` axis per D-25/D-26.
5. **OQ-3** (ROADMAP.md, PROJECT.md, STATE.md) — restate the resolved value on the new axis.
6. **`docs/baseline.md`** — record the reconstructed Phase 1 `paragraph_header` baseline (D-26).

</domain>

<decisions>
## Implementation Decisions

### Recall criterion 4 (carried from the first discussion session)

- **D-16a:** Criterion 4's `dataItems` axis is **unsatisfiable for this phase**. Measured: 0 of the
  169 `.cbl` containing `EXEC CICS` have the construct before `PROCEDURE DIVISION`, and the cascade
  harness confirms `EXEC CICS` costs 19 of 20 paragraphs while costing **0** data items. A phase
  that fixes CICS cannot move a DATA DIVISION metric. Re-scope now, per D-16.

- **D-16b:** The replacement axis is **`paragraph_header`** — the counter at
  `neutralize_test.go:72`. Named verbatim to avoid the 42-vs-15,323 ambiguity against
  `probe_test.go:55`.

- **D-16c:** Two gates, deliberately asymmetric. **Blocking:** `TestErrorCascade`'s EXEC CICS case
  reaching 20/20 paragraphs. **Hard-on-direction / explained-on-magnitude (D-15):** the corpus
  `paragraph_header` delta.

- **D-16d:** Corpus target is the **terminal condition on this axis** — grammar-alone `.cbl`
  `paragraph_header` **>= 16,732**, closing 100% of the measured 1,409 gap. Justified because
  `SCHEMA SECTION` costs 0 paragraphs and IDMS is now grammar-native, so the paragraph gap is
  essentially all CICS.
  — **Reversibility:** one-way — this replaces ROADMAP criterion 4 and restates CICS-04 and
  IDMS-05; reverting after Phase 4 is planned against it would require re-baselining both phases.

### Node granularity

- **D-17:** **One generic `exec_cics_statement`** — `EXEC CICS` + `field('command', …)` + option
  list + `END-EXEC`. A deliberate **departure from Phase 2's D-01** four-verb-class shape: IDMS DML
  is positional, so its verbs cluster into operand shapes; CICS is uniformly command +
  keyword-option-list, so verb classes buy nothing and leave unmeasured commands homeless. One rule
  covers all 26 measured commands and any future one with zero coverage gap.
  — **Reversibility:** costly — the node name is the contract `queries/cics.scm` reads; renaming it
  means a coordinated change with the query.

- **D-18:** The command name is **`field('command', $.WORD)`**, relying on tree-sitter keyword
  extraction (`word: $ => $._WORD`, grammar.js:14) so `READ`, `WRITE`, `DELETE` and `RETURN` — four
  existing COBOL keyword tokens and 4 of the top 6 CICS commands — lex as `WORD` inside the block
  without a `conflicts:` entry. **This assumption MUST be proven by a fixture before anything is
  built on it** (see D-32). If extraction does not apply to these regex keyword tokens, fall back to
  `choice($.WORD, $._READ, $._WRITE, $._DELETE, $._RETURN, …)`.

- **D-19:** Unmatched block content is absorbed into a named **`cics_unparsed_tail`** node — a
  direct D-03 analog. Never ERROR, never silently dropped. Guarantees CICS-03 cascade elimination
  for 100% of blocks regardless of option coverage (a missed option costs a capture, never a
  division) and makes the coverage gap countable.

- **D-20:** **`END-EXEC` is a required terminator.** The trailing period on 1,283 of 2,886 blocks is
  left to the existing sentence machinery that terminates every other `*_statement` — no special
  casing inside the node. Optional/recoverable terminators were rejected: an optional terminator on
  a `repeat(option)` body invites the parser to swallow following paragraphs, reintroducing the
  exact cascade CICS-03 exists to kill. The 2 of 2,888 occurrences with no `END-EXEC` within 2,000
  chars are treated as corpus noise to be identified during implementation, not designed around.

### Operand extraction

- **D-21:** **Named nodes for the criterion-1 operands** — `cics_transaction_name` (TRANSID),
  `cics_program_name` (PROGRAM), `cics_map_name` (MAP) — anchored on the option keyword, mirroring
  D-02. **Forced by a hard consumer constraint, not a preference:** gortex's `runQuery`
  (`internal/parser/treesitter.go:181`) iterates matches and copies captures with **no predicate
  evaluation**. A `#eq?` predicate compiles fine and is then silently ignored, so every option would
  match every capture. Predicate-based extraction fails *silently*, which is worse than failing
  loudly.
  — **Reversibility:** costly — the node names are the query contract.

- **D-22:** Each named operand node wraps **whatever is inside the parens** — quoted literal or data
  name alike. The node marks the *role*, not the lexical form.
  **DISCLOSURE:** 30 of 33 `PROGRAM` operands are data names, so the program-name capture generally
  yields a variable rather than a resolvable edge target. `TRANSID` (385/415), `MAP` (607/611) and
  `MAPSET` (607/610) are quoted literals and are resolvable in the general case. Criterion 1 is
  satisfied literally; the graph value of the program capture is thinner than the criterion implies
  and should be stated rather than discovered later.

- **D-23:** **`cics_mapset_name` is added as a fourth named node**, one beyond criterion 1's three.
  In BMS the mapset is the load module and the map is a member within it, so the mapset is the
  artifact a build-graph edge points at, and `MAP` alone is ambiguous. Backed by 610 measured
  occurrences (18x `PROGRAM`'s 33) and 1:1 co-occurrence with `MAP`. Recorded explicitly as a
  scope addition rather than smuggled in.

- **D-24:** The query ships as **`queries/cics.scm` from this fork**, mirroring D-04. Criterion 1 is
  demonstrated by a **fork-local test that compiles the query against a fixture and asserts the four
  named captures** — which is what the criterion actually says.
  **FINDING:** D-04's rationale that "gortex reads it" is **not true today**. gortex's forest
  extractor requests exactly one query kind — `e.getQuery("tags")` (`extractor.go:81`) — and nothing
  reads `idms.scm` or would read `cics.scm`. Both files are a published contract with no reader.
  Folding the captures into `tags.scm` was rejected (wrong capture vocabulary, upstream-owned path,
  bends FORK-03); wiring gortex inside this phase was rejected (puts a second-repo dependency inside
  a separable-grammar-commit phase). Recorded as a deferred idea.

### 02-05 / cascade harness

- **D-25:** **IDMS-05 is re-scoped onto the `paragraph_header` axis** alongside CICS-04 and closed in
  Phase 3 — not closed as mis-specified and transferred to preprocessing. The axis was wrong for
  both requirements, not the work. Leaves no requirement dangling into the next milestone.

- **D-26:** Re-scoping IDMS-05 needs a baseline that **does not exist**. `docs/baseline.md:163`
  records the `paragraph_header` pair (15,323 → 16,732) **only at Phase 2 completion**; there is no
  Phase 1 number. Phase 3 therefore **reconstructs it**: check out the pre-Phase-2 grammar, run
  `forest-shim/refresh.sh`, re-run the probe. This gives IDMS-05 a real before/after **and**
  partitions the 1,409-item paragraph gap between what IDMS already closed and what CICS must close,
  which sharpens Phase 3's own target rather than merely rescuing a requirement.
  Supporting evidence for expecting a real IDMS rise: the harness shows an unknown procedure-division
  construct costs 19/20 paragraphs, so pre-Phase-2 IDMS DML almost certainly suppressed
  `paragraph_header`.

- **D-27:** The blocking cascade gate is made real by **editing gortex's `cascade_test.go`** to
  assert both `pa2 == pa` (paragraph parity) and `d2 == d` (data-item parity — currently already
  20/20, asserted so a paragraph fix cannot silently break the DATA DIVISION). The file's own
  comment at `cascade_test.go:110-115` pre-sanctions this as Phase 3's gate, so it is a planned
  hand-off, not an unplanned cross-repo reach. The `SCHEMA SECTION` case stays logged-only per D3.

- **D-28:** The gate injects **four representative shapes, all asserted at parity**, not the single
  `SEND MAP('M')` form the harness uses today:
  (a) paren-option `SEND MAP('M')` — the existing case;
  (b) **no-option `RETURN`** — the corpus's most common shape at 1,251 / 43% of blocks, and the form
      most likely to break a `repeat()`-based body rule;
  (c) a bare-option form, covering `NOHANDLE` 1,586 / `FREEKB` 450 / `ERASE` 438;
  (d) a multi-line block, covering the 51 blocks with nothing after `EXEC CICS` on the line.

### Coverage & tails

- **D-29:** The grammar models **all four measured argument forms up front** — quoted literal
  (1,993), plain data name (2,041), `LENGTH OF <name>` (527), numeric literal (81). A stated
  departure from D-09's two-round minimal-then-census process: the census D-09 deferred has
  effectively already run during this discussion, because CICS's uniform `KEYWORD(arg)` syntax made
  it cheap in a way IDMS's positional forms never were. Expected result: `cics_unparsed_tail` near
  zero on first measurement, which becomes the *evidence coverage is complete* rather than a to-do
  list.

- **D-30:** Acceptance rule for `cics_unparsed_tail` mirrors D-15. **Blocking:** the tail must not
  cause a cascade (guaranteed by D-19's construction, asserted by D-28's gate). **Non-blocking but
  mandatory:** if the corpus census finds any tail at all, a written cause naming what is in it goes
  on file, exactly as Phase 2 did for its 119 → 9 census. Because coverage was censused up front
  (D-29), a non-zero tail is genuinely informative — it means this discussion's measurement missed a
  form. A hard zero-tail gate was rejected: it makes the phase hostage to one exotic block, and its
  obvious escape hatch is to widen the tail rule until it stops firing, defeating its purpose.

- **D-31:** **The Phase 2 zero-reclassification differential runs for CICS**, as a hard gate, on both
  DCC and the estate per D-07. D-08 explicitly pre-paid for this ("free for Phases 3-4"). The
  collision surface is real despite `EXEC` and `CICS` having zero occurrences in `grammar.js`: D-18
  places `field('command', $.WORD)` directly adjacent to four existing COBOL keyword tokens and
  relies on keyword extraction to arbitrate. If extraction misbehaves, ordinary `READ` and `WRITE`
  statements are what break — precisely the silent reclassification the differ exists to catch.

- **D-32:** Fixtures ship as **one `test/corpus/exec_cics.txt`**, following the repo's per-topic
  convention, with the **CICS Application Programming Reference as syntax ground truth** and
  **invented neutral names** (`MAP('MENU01')`, `TRANSID('AB12')`, `PROGRAM(WS-PGM-NAME)`) — direct
  D-10 parity, nothing estate-derived crosses into a tracked file in a public repo.
  **Mandatory:** a dedicated fixture proving the D-18 assumption — that `EXEC CICS READ` / `WRITE` /
  `DELETE` / `RETURN` parse as CICS commands **and** ordinary COBOL `READ` and `WRITE` statements
  still parse correctly in the same file. This is the phase's cheapest early signal: if it fails,
  D-18 falls back to explicit arms before any other work is built on it. **Plan this first.**

### Claude's Discretion

- Exact rule and node names, provided `exec_cics_statement`, `cics_transaction_name`,
  `cics_program_name`, `cics_map_name`, `cics_mapset_name` and `cics_unparsed_tail` are used
  verbatim — they are the `queries/cics.scm` contract.
- Whether the generic option is `cics_option` with `field('name')`/`field('value')` or named
  sub-rules, and whether bare options get a distinct node from paren options.
- Whether the option list is `repeat()` or `repeat1()` (note D-28(b): no-option `RETURN` is 43% of
  blocks, so `repeat1()` would be wrong).
- Commit boundary and sequencing of the pre-planning docs amendment commit.
- Whether the reconstructed Phase 1 `paragraph_header` baseline lands as a new `docs/baseline.md`
  section or an amendment to §2.
- Whether the two gortex-side edits (D-27 assertion, D-28 shapes) ship as one commit or two.
- How the `cics_unparsed_tail` census is reported (table in `docs/baseline.md` vs. a separate note).
- Plan decomposition and commit sequencing within the phase, subject to FORK-03.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth for the project
- `docs/spec/SPEC-001-nodes-for-edges.md` — §5 the in-scope table and the CICS volume
  (221 programs / 3,539 statements in the estate); §6 the six per-family acceptance criteria;
  §9 locked decisions D1–D4 (D3 assigns `SCHEMA SECTION` to preprocessing; D4 locks out `EXEC DLI`).
- `.planning/PROJECT.md` — locked decisions D1–D6, the constraints block (NIST threshold is **11**;
  standard COBOL unharmed; proprietary estate vs. public fork), the measured baseline and volume
  tables. Open Questions table carries OQ-3.
- `.planning/REQUIREMENTS.md` lines 126–145 — CICS-01…CICS-06 in checkable form. **CICS-04 is
  amended per D-16a–d before planning; IDMS-04's checkbox and IDMS-05's axis are corrected in the
  same commit.**
- `.planning/ROADMAP.md` — Phase 3 goal and five success criteria. **Criterion 4 is amended per
  D-16a–d before planning.**
- `.planning/phases/02-idms-dml-statement-nodes/02-CONTEXT.md` — **read in full.** D-01 (verb-class
  node shape, which D-17 deliberately departs from), D-02 (named nodes over fields, which D-21
  follows), D-03 (`idms_unparsed_tail`, which D-19 mirrors), D-04 (query ships from the fork, which
  D-24 mirrors *and corrects*), D-07/D-08 (the differential and the differ script D-31 reuses),
  D-09 (minimal-to-edges, which D-29 departs from), D-10 (manual-as-ground-truth and invented
  fixture names, which D-32 follows), D-11 (fork-local CI), D-13/D-15 (the gap-closure frame and
  the direction-hard/magnitude-explained rule), D-16 (amendments land before planning).
- `.planning/phases/01-delivery-pipe-measurement-baseline/01-CONTEXT.md` — D-12…D-15, FORK-03 as the
  binding rule.

### Measurement method and the numbers this phase is held to
- `docs/baseline.md` — **the baseline of record.** §2 the exact `go test` invocation and the Phase 1
  cells. **§4** the Phase 2 delta, the written cause for the zero, and the `SCHEMA SECTION`
  attribution table (321 files / 53% contribute 213 of 17,905 items). **Line 163** is the only
  recorded `paragraph_header` pair — `15,323 → 16,732`, Phase 2 completion only, no Phase 1 number.
  That absence is what D-26 exists to fix.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/README.md` — the published method and
  the `-corpus` / `-neut-corpus` flags.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/neutralize_test.go` **line 72** — the
  `paragraph_header` counter, the axis named verbatim by D-16b. **Line 23** `reExec` — evidence that
  `neutralize()` already rewrites `EXEC` blocks, so 16,732 is the ceiling Phase 3 climbs toward.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/probe_test.go` **line 55** — the
  *other* paragraph counter (42), the one D-16b avoids.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go` — **the CICS-03
  gate.** Lines 110–115 carry the comment pre-sanctioning D-27's edit. Lines 124–131 show the
  WORKING-STORAGE case is a deliberate negative control, correctly asserted.
- `docs/vendoring.md` — the `go.work`-resolved shim at `forest-shim/cobol/` and
  `forest-shim/refresh.sh`. D-26's baseline reconstruction runs through this path.

### The consumer contract (read before designing the query)
- `~/repos/mine/GoApps/gortex/internal/parser/treesitter.go` **lines 178–200** `runQuery` — **no
  predicate evaluation.** This is the evidence for D-21.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/extractor.go` **line 81** — `e.getQuery("tags")`
  is the only query kind requested. This is the evidence for D-24's finding.
- `queries/idms.scm` — the Phase 2 query; the shape `cics.scm` follows.

### The grammar surface this phase edits
- `grammar.js:1366` — `_statement`, the flat `choice()` the four IDMS nodes were added to at lines
  1382–1385. `exec_cics_statement` attaches here.
- `grammar.js:14` — `word: $ => $._WORD`. Keyword extraction is enabled; D-18 depends on it.
- `grammar.js:3357 / 3004 / 3121 / 3381` — `_READ`, `_WRITE`, `_DELETE`, `_RETURN`. The collision
  surface D-18 and D-31 are about.
- `grammar.js:2245–2330` — the Phase 2 IDMS rules. The style, comment convention (measured volume
  cited inline), and node-naming precedent to follow.
- `grammar.js:3491` — `_WORD`.
- `.planning/codebase/CONVENTIONS.md` — `_`-prefix for private rules, `field()` labelling,
  `prec.left`/`prec.right` usage.
- `.planning/codebase/ARCHITECTURE.md` — the generate pipeline and the "never hand-edit
  `src/parser.c` / `grammar.json` / `node-types.json`" constraint.

### The regression net
- `test/corpus/*.txt` — per-topic files. `exec_cics.txt` is new (D-32).
- `run_nist_cobol85.sh` + `skip_tests.txt` — **11** entries.
- `.github/workflows/fork-checks.yml` — the fork-local CI added in Phase 2 (D-11), with the `comment`
  fixture excluded and annotated.
- `.planning/WINDOWS.md` — the open deviation for the pre-existing `comment` fixture failure.
- `.git/hooks/pre-push` + the estate-leak guard.

### Corpora
- `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` — **the corpus of record.** 606 `.cbl` + 958 `.cpy`.
- `estate/` — 697 MB, excluded via `.git/info/exclude`, **never a fixture source.** Volume-counting
  and differential input only.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`_statement` (grammar.js:1366)** — a flat `choice()`. Adding one entry is the entire
  integration; `EXEC CICS` then becomes legal anywhere a statement is (inside `IF`, `PERFORM`,
  sentences) for free.
- **The Phase 2 IDMS rules (grammar.js:2245–2330)** — a working, committed precedent for exactly
  this shape of work: named operand nodes, an unparsed-tail escape, `field('verb', …)`, and inline
  comments citing the measured volume that justified each modelled option. Follow it.
- **`queries/idms.scm`** — the file layout, comment style, and capture-naming `cics.scm` mirrors.
- **The Phase 2 differ script (D-08, repo root)** — already written, already run against the estate.
  D-31 reuses it unchanged; this is the "free for Phases 3-4" that D-08 pre-paid for.
- **`forest-shim/refresh.sh`** — the regenerate-and-refresh pipe, proven four times now, and the
  path D-26's baseline reconstruction runs through. Phase 2 taught it to carry `queries/*.scm`
  (commit `6ac7691`), so `cics.scm` reaches the shim with no pipe change.
- **`cascade_test.go`'s injection scaffolding** — the clean-control / inject / count structure D-28
  extends with three more shapes rather than rebuilding.
- **`.github/workflows/fork-checks.yml`** — Phase 2's CI now actually runs `tree-sitter test`, so
  D-32's fixtures are enforced from the moment they land. In Phase 2 this was still an assertion.

### Established Patterns
- **Case-insensitive keyword regexes** (`_ACCEPT: $ => /[aA][cC][cC][eE][pP][tT]/`) — the four new
  option-anchor keywords (`TRANSID`, `PROGRAM`, `MAP`, `MAPSET`) follow this.
- **Generated artifacts are committed** — `src/parser.c`, `src/grammar.json`, `src/node-types.json`
  are tracked; a `grammar.js` change means regenerating and committing them.
- **Measured-volume comments inline in the grammar** — Phase 2's IDMS rules cite the tail-census
  percentages that justified each option. Phase 3's option list should cite its own counts the same
  way.
- **`.gitignore` is upstream's; `.git/info/exclude` is ours** — FORK-02.
- **Per-topic corpus files** — `evaluate.txt`, `perform.txt`, `occurs.txt`, and now `exec_cics.txt`.

### Integration Points
- **`grammar.js:1366` `_statement`** — where `exec_cics_statement` attaches.
- **`grammar.js:14` `word: $ => $._WORD`** — the mechanism D-18 depends on; the highest-risk
  assumption in the phase.
- **`queries/cics.scm`** — new; the published consumer contract, currently without a reader (D-24).
- **`cobolprobe` `TestErrorCascade`** — the CICS-03 gate, edited by D-27 and D-28.
- **`cobolprobe` `neutralize_test.go:72`** — the `paragraph_header` counter criterion 4 is measured
  on.

</code_context>

<specifics>
## Specific Ideas

- **Prove the riskiest assumption first.** D-18's reliance on tree-sitter keyword extraction to keep
  `EXEC CICS READ` and a standard COBOL `READ` apart is the single load-bearing unknown in the
  phase, and D-32 makes proving it a fixture. Plan that fixture as task one. If it fails, the
  fallback (explicit arms for the four colliding verbs) is cheap — but only if nothing else has been
  built on top of the assumption yet. This is the CICS analogue of Phase 2's ACCEPT collision, and
  Phase 2 learned the same lesson the expensive way.

- **Measure before modelling, then say the measurement out loud.** Every decision here is backed by
  a count taken during this discussion, and three of them contradict what the planning documents
  said: criterion 4's axis (D-16a), D-04's claim that gortex reads the query (D-24), and the
  existence of a Phase 1 `paragraph_header` baseline (D-26). All three are recorded as findings and
  drive amendments — none were smoothed over. This is the third consecutive phase where the
  discussion falsified a prior claim; treat that as the expected outcome of doing the measurement,
  not as a sign anything is wrong.

- **Depart from precedent deliberately, and say why.** D-17 rejects D-01's verb classes and D-29
  rejects D-09's two-round census — both because CICS's uniform keyword syntax is a genuinely
  different problem from IDMS's positional forms. Consistency with Phase 2 is not itself a reason;
  the reason has to survive contact with the measurement.

- **Do not let a criterion be satisfied hollowly.** D-22 satisfies criterion 1's "program name"
  literally while recording that 30 of 33 such operands are variables. The capture exists, the edge
  mostly does not. Better said now than discovered by whoever consumes the graph.

</specifics>

<deferred>
## Deferred Ideas

- **Wiring gortex to read `queries/*.scm`** — the finding behind D-24. `idms.scm` and `cics.scm` are
  a published contract with no reader: the forest extractor requests only `getQuery("tags")`. Closing
  this means extending `GetQueryFn` to request additional kinds and teaching the COBOL extractor to
  build edges from the captures — a cross-repo change in gortex, outside FORK-03 and outside a phase
  whose deliverable is a separable grammar commit. **This is the largest single item deferred by this
  discussion and it blocks the actual business value of Phases 2–4.** Should be a named phase or a
  gortex-side milestone, not a footnote.

- **Named nodes for the other 21 measured option names** — `LENGTH` (594), `COMMAREA` (411),
  `RIDFLD` (319), `FILE` (303), `FROM` (279), `INTO` (237), `ABSTIME` (208) and the rest. Rejected
  now (D-21) because criterion 1 asks for three and hard-coding a 25-name corpus-derived vocabulary
  into a generic-dialect grammar is the site-specific-hack line PROJECT.md draws. Revisit when a
  consumer needs a specific edge kind — `FILE` and `COMMAREA` are the likeliest candidates.

- **`SCHEMA SECTION` and the DATA DIVISION gap** — 321 of 606 `.cbl` (53%) have their DATA DIVISION
  swallowed by one ERROR node, which alone over-explains the whole 14,455 `dataItems` gap. Locked
  decision D3 assigns it to preprocessing, in a different repository. Noted so nobody reads Phase
  3's `dataItems` non-movement as a failure — D-16a is precisely about this.

- **`.cpy` grammar-alone recall (0%)** — structural; copybooks have no `IDENTIFICATION DIVISION` to
  anchor a parse. Outside every phase in this milestone.

- **Fixing the upstream `comment` corpus fixture (12/13)** — still excluded rather than repaired
  (D-11). The standing exclusion should be revisited, not forgotten.

- **A second corpus containing `EXEC SQL`** — still rejected (D-14): breaks the same-corpus /
  same-method comparability `docs/baseline.md` is built on. Phase 4 has no recall signal on DCC and
  keeps its four other gates.

- **FORK-01 (branch-hygiene guard) and the topic-branch publication workflow** — still deferred from
  Phase 1. Unchanged by this discussion.

- **`HANDLE CONDITION` / `HANDLE AID` and `RESP`/`RESP2` error-handling semantics** — 1 and 21
  occurrences respectively. They parse fine as generic options under D-29; modelling their control-
  flow meaning (an implicit branch target) would be a control-flow-edge feature, not a parsing one,
  and belongs with whatever phase builds CICS control-flow edges.

</deferred>

---

*Phase: 3-EXEC CICS Blocks*
*Context gathered: 2026-09-09*
