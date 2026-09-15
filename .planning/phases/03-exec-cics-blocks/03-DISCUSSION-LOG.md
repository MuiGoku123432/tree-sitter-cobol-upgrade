# Phase 3: EXEC CICS Blocks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-09 (session 2; session 1 was 2026-09-04, area "Recall criterion 4")
**Phase:** 3-exec-cics-blocks
**Areas discussed:** Recall criterion 4 (session 1), Node granularity, Operand extraction,
02-05 / cascade harness, Coverage & tails

---

## Node granularity

### Q1 — How should the EXEC CICS block be modelled as nodes?

| Option | Description | Selected |
|--------|-------------|----------|
| One generic `exec_cics_statement` | Command + option list + terminator in one rule; covers all 26 measured commands and any future one with zero coverage gap | ✓ |
| Verb-class nodes (D-01 parity) | Group commands into terminal I/O, file, program control, queue classes, mirroring Phase 2 | |
| Named for criterion-1 commands + generic rest | Named rules for SEND/RECEIVE/RETURN/XCTL/LINK, generic fallback for the other 20 | |

**User's choice:** One generic `exec_cics_statement`
**Notes:** Accepted the stated departure from Phase 2's D-01. Rationale on file: IDMS DML is
positional so its verbs cluster into operand shapes; CICS is uniformly command +
keyword-option-list, so classes buy nothing and leave unmeasured commands homeless.

### Q2 — How is the command name tokenized, given READ/WRITE/DELETE/RETURN are already COBOL keyword tokens?

| Option | Description | Selected |
|--------|-------------|----------|
| Generic `$.WORD`, rely on keyword extraction | `word: $ => $._WORD` (grammar.js:14) is set; smallest diff, no keyword-block additions | ✓ |
| Explicit keyword rules for the 26 commands | ~26 new `_CICS_*` rules; pins the vocabulary, dodges the extraction uncertainty | |
| `$.WORD` plus explicit arms for the colliding verbs | Belt-and-braces against extraction risk, asymmetric rule, possible LR conflict | |

**User's choice:** Generic `$.WORD`, rely on keyword extraction
**Notes:** The extraction assumption was flagged as unverified. This became the driver for D-32's
mandatory proof fixture and part of the justification for D-31's differential.

### Q3 — What happens to block content the option grammar does not match?

| Option | Description | Selected |
|--------|-------------|----------|
| `cics_unparsed_tail` node (D-03 analog) | Absorbed, never ERROR, never silently dropped; makes the gap countable | ✓ |
| Opaque body scanned to END-EXEC | Cheapest diff, cascade eliminated by construction, but criterion 1 becomes unsatisfiable | |
| Structural options only, no tail node | Forces full coverage but reintroduces the cascade CICS-03 exists to kill | |

**User's choice:** `cics_unparsed_tail` node
**Notes:** Direct carry-forward of Phase 2's operating principle.

### Q4 — How is the block terminator contracted?

| Option | Description | Selected |
|--------|-------------|----------|
| END-EXEC required; period handled by existing sentence rule | No special casing; the 2 unterminated occurrences treated as corpus noise | ✓ |
| END-EXEC optional (prec.right recovery) | Robust to malformed source but invites paragraph-swallowing | |
| END-EXEC required, period absorbed into the node | Unambiguous node extent, but duplicates period handling the grammar already does | |

**User's choice:** END-EXEC required; period handled by existing sentence rule
**Notes:** Measured 1,283 of 2,886 blocks carry a trailing period; 2 of 2,888 have no END-EXEC
within 2,000 chars.

---

## Operand extraction

### Q1 — How are transaction/program/map made extractable, given predicates are silently ignored?

| Option | Description | Selected |
|--------|-------------|----------|
| Named nodes for the three criterion-1 operands | Keyword-anchored, predicate-free, depth-independent; mirrors D-02 | ✓ |
| Named nodes for all 25 measured options | Maximum queryability but hard-codes a corpus-derived vocabulary | |
| Generic `cics_option` only; consumer filters in Go | Minimal grammar but splits the contract across two repos | |

**User's choice:** Named nodes for the three criterion-1 operands
**Notes:** Presented alongside a hard finding — gortex's `runQuery`
(`internal/parser/treesitter.go:181`) performs no predicate evaluation, so `#eq?` compiles and is
silently ignored. This made options 1 and 3 the only viable ones and option 1 the consistent one.

### Q2 — How should the named operand nodes treat the literal-vs-data-name split?

| Option | Description | Selected |
|--------|-------------|----------|
| One node per role, covering both forms | Node marks the role, not the form; criterion 1 satisfied literally | ✓ |
| Name nodes for literals only | Every capture resolvable, but drops 30 of 33 PROGRAM operands | |
| One node per role with a form field | More info at the query surface, field value derivable from the node itself | |

**User's choice:** One node per role, covering literal and data name alike
**Notes:** Accepted the disclosure that 30 of 33 PROGRAM operands are data names, so the
program-name capture generally yields a variable rather than a resolvable edge target.

### Q3 — Does MAPSET get its own named node?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — add `cics_mapset_name` as a fourth named node | Mapset is the BMS load module; 610 occurrences, 18x PROGRAM; 1:1 with MAP | ✓ |
| No — hold at criterion 1's three names | Smallest diff and smallest vocabulary; recoverable later at cross-repo cost | |

**User's choice:** Yes — add `cics_mapset_name`
**Notes:** Explicitly recorded as one node beyond criterion 1's three rather than absorbed silently.

### Q4 — Where does the query live, and how is criterion 1 demonstrated?

| Option | Description | Selected |
|--------|-------------|----------|
| `queries/cics.scm` mirroring D-04; prove via fork-local query test | Same fork, same separable commit; consumer gap recorded as a finding | ✓ |
| Fold captures into `queries/tags.scm` | Closes the consumer gap now, but wrong capture vocabulary and bends FORK-03 | |
| `cics.scm` plus wire the consumer in this phase | Closes the loop end-to-end but puts a second-repo dependency inside the phase | |

**User's choice:** `queries/cics.scm` mirroring D-04
**Notes:** Presented with the finding that D-04's "gortex reads it" rationale is not true today —
the forest extractor requests only `getQuery("tags")` (`extractor.go:81`). Consumer wiring became
the largest deferred item.

---

## 02-05 / cascade harness

### Q1 — What is IDMS-05's disposition?

| Option | Description | Selected |
|--------|-------------|----------|
| Re-scope onto the paragraph_header axis and close in Phase 3 | Honest that the axis was wrong for both requirements, not the work | ✓ |
| Close as mis-specified, transfer to preprocessing backlog | Provenance-honest but discards a rise the grammar probably delivered | |
| Leave outstanding until milestone audit | Defers at the cost of carrying a known-unsatisfiable requirement forward | |

**User's choice:** Re-scope onto the `paragraph_header` axis and close in Phase 3
**Notes:** The recommendation had been option 2; the user chose option 1, which surfaced the
baseline problem handled in Q2.

### Q2 — Given there is no Phase 1 paragraph_header baseline, how is the re-scoped IDMS-05 made measurable?

| Option | Description | Selected |
|--------|-------------|----------|
| Reconstruct the Phase 1 baseline and measure properly | Real before/after, and partitions the 1,409 gap between IDMS and CICS | ✓ |
| Close on the passing clause; fold the rise into a joint gate | No new measurement, but IDMS-05 never independently demonstrated | |
| Go back to closing it as mis-specified | Cheapest, but discards a delivered rise | |

**User's choice:** Reconstruct the Phase 1 `paragraph_header` baseline
**Notes:** Raised as a correction to Q1's premise — `docs/baseline.md:163` records the pair only at
Phase 2 completion. Counter-evidence offered: the harness shows an unknown procedure-division
construct costs 19/20 paragraphs, so pre-Phase-2 IDMS DML almost certainly suppressed the counter.

### Q3 — How is the blocking cascade gate turned from a log line into an assertion?

| Option | Description | Selected |
|--------|-------------|----------|
| Assert CICS paragraph parity and data-item parity | File's own comment pre-sanctions the edit; guards against a fix that breaks DATA DIVISION | ✓ |
| Assert paragraph parity only | Matches criterion 3's wording but leaves 20/20 data items unguarded | |
| Mirror as a fork-local fixture, do not edit gortex | Strictly single-repo but `tree-sitter test` cannot express survival counts | |

**User's choice:** Edit `cascade_test.go`; assert both
**Notes:** `cascade_test.go:110-115` explicitly names the EXEC CICS case as Phase 3's gate, so this
is a planned hand-off rather than an unplanned cross-repo reach.

### Q4 — Should the blocking cascade gate cover more than one EXEC CICS shape?

| Option | Description | Selected |
|--------|-------------|----------|
| Broaden to four representative shapes, all asserted | paren-option, no-option RETURN, bare-option, multi-line | ✓ |
| Keep one injection; cover variety in fork-local fixtures | Minimal cross-repo edit but never proves the other shapes non-cascading | |
| Add the no-option RETURN case only | Highest-value single addition at 43% of blocks | |

**User's choice:** Broaden to four representative shapes
**Notes:** The harness currently injects only `SEND MAP('M')`, a shape with one paren option, while
`RETURN` at 1,251 is 43% of blocks and often takes no options at all.

### Continue-or-advance checkpoint

Asked whether to continue with commit-scope, baseline-recording, and commit-splitting questions.
**User's response (free text):** *"What ever you thing is best do we have enough?"*
**Interpretation and action:** Judged the three remaining items to be bookkeeping and sequencing
rather than decisions that could go multiple ways. Recorded them under Claude's Discretion in
CONTEXT.md and advanced to the final area. Reflected this back to the user before proceeding.

---

## Coverage & tails

### Q1 — What option-argument forms does the initial grammar model?

| Option | Description | Selected |
|--------|-------------|----------|
| Model all four measured forms up front | Literal, data name, LENGTH OF, numeric; census already effectively run | ✓ |
| Minimal-to-edges then extend (strict D-09) | Parity with Phase 2's process at the cost of a known-needed second round | |
| One opaque argument token | Total coverage by construction but pushes re-lexing to the consumer | |

**User's choice:** Model all four measured argument forms up front
**Notes:** A stated departure from D-09. Measured: quoted literal 1,993, plain data name 2,041,
`LENGTH OF` 527, numeric literal 81; zero subscripts, zero `SET(ADDRESS OF …)`.

### Q2 — What is the acceptance rule for `cics_unparsed_tail`?

| Option | Description | Selected |
|--------|-------------|----------|
| Census reported with written cause; non-blocking on count | Mirrors D-15's direction-hard / magnitude-explained rule | ✓ |
| Hard gate at zero tails | Strongest guarantee but hostage to one exotic block; escape hatch defeats the node | |
| Hard gate at a percentage threshold | Tolerates outliers but the threshold is arbitrary and unmeasured | |

**User's choice:** Census reported with written cause required; non-blocking on count
**Notes:** Because coverage was censused up front, a non-zero tail is informative rather than
expected noise.

### Q3 — Does the Phase 2 zero-reclassification differential run for CICS?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — reuse the Phase 2 differ, zero reclassifications as a hard gate | D-08 pre-paid for it; D-18's keyword-extraction assumption needs verifying against real code | ✓ |
| No — no collision surface; rely on `tree-sitter test` and NIST | Saves ~30 min but leaves the D-18 assumption unverified | |
| Run it, but non-blocking | Softening a gate Phase 2 held for a weaker collision would be a step backwards | |

**User's choice:** Yes — hard gate, both corpora per D-07
**Notes:** The collision surface is `field('command', $.WORD)` sitting adjacent to `_READ`,
`_WRITE`, `_DELETE`, `_RETURN`.

### Q4 — What fixtures does this phase ship, and where?

| Option | Description | Selected |
|--------|-------------|----------|
| One `exec_cics.txt`, D-10 parity, plus a mandatory keyword-extraction fixture | Per-topic convention; manual as ground truth; invented neutral names | ✓ |
| Per-command-family fixture files | Localizes failures but re-imports the taxonomy D-17 rejected | |
| Fixtures weighted by measured command frequency | Reflects real usage but under-tests the rare forms most likely to be wrong | |

**User's choice:** One `exec_cics.txt` plus the mandatory keyword-extraction fixture
**Notes:** That fixture is the phase's cheapest early signal and is flagged in CONTEXT.md to be
planned as task one.

---

## Claude's Discretion

- Exact rule and node names, provided the six contract names are used verbatim.
- Whether the generic option uses `field()` labels or named sub-rules; whether bare options get a
  distinct node from paren options.
- Whether the option list is `repeat()` or `repeat1()`.
- Commit boundary and sequencing of the pre-planning docs amendment commit.
- Whether the reconstructed Phase 1 `paragraph_header` baseline lands as a new `docs/baseline.md`
  section or an amendment to §2.
- Whether the two gortex-side edits ship as one commit or two.
- How the `cics_unparsed_tail` census is reported.
- Plan decomposition and commit sequencing within the phase, subject to FORK-03.

## Deferred Ideas

- Wiring gortex to read `queries/*.scm` — the largest deferred item; blocks the business value of
  Phases 2–4.
- Named nodes for the other 21 measured option names (`LENGTH`, `COMMAREA`, `RIDFLD`, `FILE`, …).
- `SCHEMA SECTION` and the DATA DIVISION gap — preprocessing, per locked decision D3.
- `.cpy` grammar-alone recall (0%) — structural.
- Fixing the upstream `comment` corpus fixture (12/13) — still excluded per D-11.
- A second corpus containing `EXEC SQL` — still rejected per D-14.
- FORK-01 branch-hygiene guard and the topic-branch publication workflow.
- `HANDLE CONDITION` / `HANDLE AID` and `RESP`/`RESP2` control-flow semantics.
