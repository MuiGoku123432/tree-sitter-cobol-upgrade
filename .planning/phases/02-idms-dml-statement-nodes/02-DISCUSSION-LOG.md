# Phase 2: IDMS DML Statement Nodes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-29
**Phase:** 2-IDMS DML Statement Nodes
**Areas discussed:** Node shape per verb, ACCEPT containment, Coverage surface, Recall target rule

**Areas offered but not selected:** field/node naming + shipping `queries/idms.scm` (folded into
Node shape), precompiled `CALL 'IDMS'` boundary (folded into Coverage surface), fork-local CI
running `tree-sitter test` (folded into Coverage surface). All three were covered inside the
selected areas.

---

## Node shape per verb

### Q1 — How should the DML statements be shaped as nodes?

| Option | Description | Selected |
|--------|-------------|----------|
| Verb-class grouping | 4 node types with `field('verb', …)` and shared record/set operand sub-rules; ~4 query patterns; ACCEPT isolated by construction | ✓ |
| One generic node | Single `idms_dml_statement` + permissive operand repeat; smallest diff, one query pattern; node type carries no information, permissive tail can over-match | |
| 14 per-verb rules | One node type per verb; most precise; largest surface, most LR conflict risk, heavy OBTAIN/FIND duplication | |

**User's choice:** Verb-class grouping
**Notes:** Framed against the four natural operand clusters (navigation / update / session /
currency). `idms_record_name` and `idms_set_name` are the same sub-rules in every cluster regardless
of choice — the decision was only how many top-level node types wrap them.

### Q2 — How should the record and set names be exposed to a query?

| Option | Description | Selected |
|--------|-------------|----------|
| Named operand nodes | `idms_record_name` / `idms_set_name` as their own rules; depth-independent query; survives refactors | ✓ |
| Fields on the statement node | `field('record', …)` on each statement rule, matching `select_statement`'s convention; forces operands to be direct children | |
| Both — named nodes plus fields | Most forgiving for the consumer; two ways to write the same query invites drift | |

**User's choice:** Named operand nodes
**Notes:** Driven by a tree-sitter constraint surfaced during the question — `field()` binds to
direct children of the declaring rule, so a `record:` field cannot reach an operand living inside a
shared clause sub-rule.

### Q3 — What happens to a DML statement whose operand tail the grammar doesn't recognize?

| Option | Description | Selected |
|--------|-------------|----------|
| Permissive tail fallback | Unnamed catch-all; guarantees cascade elimination; coverage gaps are silent | |
| Strict — unmodeled tails ERROR | Gaps are loud; IDMS-04 becomes contingent on coverage completeness | |
| Permissive, but node-typed as incomplete | Named `idms_unparsed_tail`; cascade guarantee *and* a countable coverage metric | ✓ |

**User's choice:** Permissive, but node-typed as incomplete
**Notes:** This is what makes the later "ship narrow, measure, extend" decisions possible — it turns
coverage from a guess into a count.

### Q4 — Does Phase 2 ship the extraction query, or leave gortex to write it?

| Option | Description | Selected |
|--------|-------------|----------|
| Ship `queries/idms.scm` here | Canonical query beside the grammar that defines the node names; rename + query update in one commit; `queries/` is upstream-owned so FORK-03 holds | ✓ |
| gortex owns the query | Minimal grammar commit; a node rename here silently breaks a query over there | |
| Ship it, and assert it in a corpus test | Executable gate for IDMS-02; needs a runner script since tree-sitter's corpus format tests trees, not queries | |

**User's choice:** Ship `queries/idms.scm` here

---

## ACCEPT containment

**Premise established before the questions:** `_accept_body` (grammar.js:1513) already ends with
`seq($._FROM, field('from', choice(…, $.WORD)))`, so an IDMS `ACCEPT x FROM record CURRENCY` today
parses as a *complete valid standard ACCEPT* and then ERRORs on the dangling `CURRENCY`. The two
forms share a viable prefix and diverge only on the token after a complete parse — a shift/reduce
decision on one lookahead. With 1,757 standard vs. 634 IDMS occurrences, an over-eager rule
reclassifies standard COBOL silently.

### Q1 — How should the IDMS ACCEPT forms be introduced?

| Option | Description | Selected |
|--------|-------------|----------|
| Extend `_accept_body` in place | One ACCEPT node type; IDMS-ness = a required child clause; no shared-prefix conflict at all; breaks the 4-node symmetry | |
| Separate `idms_accept_statement` rule | Keeps verb-class shape, uniform query; needs explicit `conflicts:`/precedence, which is where a silent reclassification could hide | ✓ |
| Land the other 13 verbs first, ACCEPT last | Sequence within the phase; mechanism chosen on evidence; two regenerations and two measurement passes | |

**User's choice:** Separate `idms_accept_statement` rule

### Q2 — What evidence proves the 1,757 standard ACCEPTs are unaffected?

| Option | Description | Selected |
|--------|-------------|----------|
| Differential parse over the estate | Before/after, zero reclassifications, IDMS count near 634; tests all real occurrences; ~30-line reusable script | ✓ |
| Corpus fixtures + NIST only | Zero new tooling; proves the rule on the ~10 shapes you thought to write; NIST's ACCEPT coverage is unmeasured | |
| Fixtures + NIST + an estate ACCEPT census | Catches gross reclassification; single-point measurement can't distinguish correct from two cancelling errors | |

**User's choice:** Differential parse over the estate
**Notes:** Refined afterwards by measurement — DCC also holds 2,027 `ACCEPT`s / 750 `CURRENCY` /
1,042 `DB-KEY` and parses in ~18 seconds, so CONTEXT.md D-07 records running the differ on both:
DCC as the fast inner loop, the estate as the authority for SPEC-001's 1,757/634 figures.

### Q3 — Which trailing keywords anchor `idms_accept_statement`?

| Option | Description | Selected |
|--------|-------------|----------|
| SPEC's two, then extend on evidence | `CURRENCY` + `DB-KEY` only; shortfall against 634 names the missing forms | ✓ |
| Full IDMS ACCEPT tail set up front | Adds `IDMS-STATISTICS`, `PROCEDURE`, etc.; more likely to hit 634; each anchor is another capture risk, and models forms with no evidence | |
| Two anchors, and treat a shortfall as a phase gate | Makes 634 a hard acceptance number; but 634 came from naive counting, so chasing it may cost more than the edges are worth | |

**User's choice:** SPEC's two, then extend on evidence
**Notes:** Asymmetry surfaced during the question — `idms_unparsed_tail` does **not** fire for a
missed IDMS ACCEPT (it falls back to standard `accept_statement` and ERRORs), so ACCEPT's coverage
signal is the node count, not a tail count.

### Q4 — Where does the differ live, and how hard a gate is it?

| Option | Description | Selected |
|--------|-------------|----------|
| Committed fork-local script, run per family | Repo-root shell script matching `run_nist_cobol85.sh` convention; hard zero-reclassification gate; ~30 min once, free for Phases 3–4 | ✓ |
| One-off, result recorded in the phase record | Cheapest now; Phases 3–4 rebuild it; no re-verification after an upstream pull | |
| Committed script, wired into `pre-push` | Automatic enforcement at the FORK-02 choke point; a full estate parse is far too slow, and a sampled gate is weaker | |

**User's choice:** Committed fork-local script, run per family

---

## Coverage surface

**Tension stated before the questions:** PROJECT.md commits to generic dialect support, but the only
evidence of which DML forms exist is the estate — which is site-specific by definition and can never
appear in a fixture.

### Q1 — How wide should the initial option set be, per verb?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal-to-edges, then extend on the count | Model only what exposes verb + record + set; rest to `idms_unparsed_tail`; extension list is measured | ✓ |
| Manual-complete for all 14 verbs | Most defensibly generic; largest surface, most conflict risk, encodes forms with no evidence — speculative generality | |
| Full for the navigation cluster, minimal elsewhere | Concentrates effort where the set-name variation lives; two fidelity levels in one grammar is harder to reason about | |

**User's choice:** Minimal-to-edges, then extend on the count

### Q2 — Where does the syntax ground truth come from, and how are fixtures written?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual defines syntax, estate ranks priority | CA IDMS DML reference diagrams define the grammar; estate contributes counts only; fixtures use invented neutral names | ✓ |
| Manual only | Cleanest separation; would model the manual's ordering rather than the measured 4,631 BIND / 2,939 OBTAIN reality | |
| Estate-observed shapes, abstracted | Highest first-pass hit rate; a paraphrased site form is still site-derived, and describing shapes in a public phase record edges toward disclosure | |

**User's choice:** Manual defines syntax, estate ranks priority

### Q3 — Does Phase 2 give the corpus gate teeth?

| Option | Description | Selected |
|--------|-------------|----------|
| Fork-local CI workflow, comment fixture skipped with a pointer | `fork-checks.yml` on `main`; upstream `test.yml` untouched; IDMS-06 becomes enforced; ~20 min plus an exclusion to revisit | ✓ |
| Keep it manual, run it in the plan | Zero infrastructure; the gate protects only the phase that remembers — which is how the comment fixture rotted unnoticed | |
| CI workflow, and fix the comment fixture first | No standing exclusion; unbounded upstream bug, and puts a non-IDMS change inside a separable-IDMS-commit phase | |

**User's choice:** Fork-local CI workflow, comment fixture skipped with a pointer
**Notes:** Carried forward from Phase 1's deferred list, which explicitly earmarked this for Phase
2. STATE.md records the pre-existing 12/13 failure (`comment` fixture, upstream `4bc6ff5`,
`.planning/WINDOWS.md`), so the workflow would go red on day one without the exclusion.

### Q4 — How should the precompiled `CALL 'IDMS'` form be handled?

| Option | Description | Selected |
|--------|-------------|----------|
| Out of scope, with a counted footnote | Excluded + reason + a count of precompiled-form estate programs, so node counts read against the right denominator | ✓ |
| Out of scope, noted only | Zero cost; a later "why do these programs have no record edges" question has no answer on file | |
| In scope — recognize the `CALL 'IDMS'` idiom | Edges from precompiled programs; a vendor calling convention in ordinary COBOL — the clearest site-specific hack PROJECT.md rules out | |

**User's choice:** Out of scope, with a counted footnote
**Notes:** Measurement afterwards showed `CALL 'IDMS'` appears **0** times in DCC `.cbl` — the
footnote is an estate-only concern and does not affect recall at all.

---

## Recall target rule

**Two premises checked before the questions.** (1) The recall corpus *is* IDMS-representative —
DCC's 606 `.cbl` carry `BIND` in 299 files (49%), `OBTAIN` in 233, `READY` in 302, comparable to
the estate's 40%. (2) **Criterion 4 compares against the wrong axis** — gortex
`neutralize_test.go:24`'s `reDML` already rewrites all 14 IDMS verbs to `CONTINUE`, so the 26.6%
neutralized baseline is a ceiling Phase 2 climbs toward, not a bar it clears. Grammar-alone after
IDMS-only work will very likely land *below* 26.6%, since neutralize also fixes the 169 DCC files
containing `EXEC CICS` — criterion 4 would read as a failure while the work succeeded.

### Q1 — What rule sets the recall target?

| Option | Description | Selected |
|--------|-------------|----------|
| Gap-closure fraction on the grammar-alone axis | `(X − 17,905) / 14,455`; terminal condition grammar-alone ≥ neutralized; measures the axis the work moves; one ROADMAP amendment | ✓ |
| Absolute grammar-alone floor per family | Simplest to check; a flat per-family floor is unachievable for Phase 4 (49 programs / 489 statements) by construction | |
| Keep 27%, measure the neutralized path | No roadmap change; near-tautological — the figure barely moves whatever the grammar does | |
| Report both axes, defer the target to Phase 3 | Most evidence before committing; defers a deliverable IDMS-08 and criterion 4 both require here | |

**User's choice:** Gap-closure fraction on the grammar-alone axis
**Notes:** A ratio of two raw numerators sidesteps `docs/baseline.md` §2's borrowed-denominator
caveat entirely.

### Q2 — How is the fraction allocated, and what happens to Phase 4's recall criterion?

**Additional measurement before the question:** DCC contains **zero** `EXEC SQL`, `SQLCODE`,
`SQLCA`, and `DCLGEN`; `EXEC CICS` 2,978 ≈ `END-EXEC` 2,976, so every EXEC block in the corpus of
record is CICS. The 14,455-item gap is therefore attributable entirely to IDMS + CICS and closes at
the end of Phase 3. ROADMAP Phase 4 criterion 5 is unsatisfiable on this corpus.

| Option | Description | Selected |
|--------|-------------|----------|
| Allocate 2+3 to ~100%; retire Phase 4's recall gate | Phase 4 keeps its four other gates; one ROADMAP amendment, no new tooling | ✓ |
| Same, but give Phase 4 an estate-measured substitute | Every phase stays gated on a number; a second measurement surface, not comparable to the DCC baseline | |
| Source a second corpus containing `EXEC SQL` | Most uniform; breaks the same-corpus/same-method rule Phase 1 fought for, forcing a full re-baseline | |

**User's choice:** Allocate 2+3 to ~100%; retire Phase 4's recall gate

### Q3 — How hard a gate is the number for Phase 3?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard on direction, explained on magnitude | Blocking: grammar-alone rises, `idms_unparsed_tail` doesn't grow. Mandatory but non-blocking: a written cause for a magnitude miss | ✓ |
| Hard numeric gate | Unambiguous; a miss caused by copybook resolution or `-INC` preprocessing would block correct grammar work | |
| Recorded expectation only | Zero process cost; reproduces the exact weakness that opened OQ-3 | |

**User's choice:** Hard on direction, explained on magnitude
**Notes:** Explicitly mirrors how Phase 1 handled its own baseline divergence — disclosed and
explained, never adjusted away.

### Q4 — When do the ROADMAP / PROJECT amendments land?

| Option | Description | Selected |
|--------|-------------|----------|
| Amend now, before planning | Planner and verifier both read ROADMAP.md directly; ~10 minutes | ✓ |
| Amend as the final task of Phase 2's plan | Criterion and value land together; planner spends the phase planning against uncorrected text | |
| Record in CONTEXT.md only | Zero edits to shared docs; ROADMAP stays wrong for the verifier at phase end | |

**User's choice:** Amend now, before planning

---

## Claude's Discretion

- Exact rule/node spelling within the four verb classes (`idms_record_name`, `idms_set_name`,
  `idms_unparsed_tail` are fixed — they are the query contract).
- Fixture file layout under `test/corpus/`.
- The conflict-resolution mechanism for the ACCEPT rule (`conflicts:` vs. `prec` vs. `prec.dynamic`).
- The differ script's name, language, output format, and whether it takes a corpus path argument.
- How `idms_unparsed_tail` counts are reported at phase end.
- Plan decomposition and commit sequencing, subject to FORK-03.

## Deferred Ideas

- Full manual-complete IDMS DML option coverage (LRF verbs, usage modes, sort keys) beyond what the
  measured tail counts justify.
- Recognising the precompiled `CALL 'IDMS'` form as IDMS nodes.
- Fixing the upstream `comment` corpus fixture rather than excluding it.
- A second corpus containing `EXEC SQL`.
- An estate-measured substitute metric for Phase 4.
- Wiring the ACCEPT differ into `pre-push`.
- `.cpy` grammar-alone recall (0%) — structural, outside this milestone.
- FORK-01 branch-hygiene guard and the topic-branch publication workflow — unchanged from Phase 1.
