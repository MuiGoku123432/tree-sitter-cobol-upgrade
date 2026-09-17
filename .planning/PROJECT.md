# tree-sitter-cobol-upgrade — COBOL grammar: nodes for edges

## What This Is

A fork of `yutaro-sakamoto/tree-sitter-cobol` (MIT) that extends the COBOL grammar with the
non-standard construct families a real mainframe estate actually contains — IDMS DML,
`EXEC CICS`, and `EXEC SQL` — which upstream does not parse at all. It is not a rewrite and
not a vendor drop: additions are generic COBOL-dialect support, not site-specific hacks, so the
fork stays maintainable and cheap to pull upstream fixes into. Offering the work upstream is a
preserved option, **not a goal** (decision D6, 2026-08-28).

The consumer is `gortex` (Gortex Mainframe Engine), which vendors this grammar to build a
knowledge graph of the estate. This repo now owns both the parser and a separate Go preprocessing
module for the COBOL leg of a four-stage retrieve -> consolidate -> preprocess -> index pipeline.

## Core Value

Raw estate COBOL becomes a source-mapped, measurable AST whose graph-relevant identifiers remain
accurate and whose degraded parses are routed for review rather than silently trusted.

## Current Milestone: v0.26.0 Estate Parse Recovery

**Goal:** Turn raw consolidated COBOL into source-mapped parser input, measure parse quality,
route degraded files into a secure review queue, and improve recurring grammar gaps from evidence.

**Target features:**
- A standalone top-level Go module under `preprocessor/`, isolated from `forest-shim/`.
- Deterministic handling for Endevor `-INC`, IDMS structural lines, fixed-format columns, and continuations.
- Reversible source mappings from transformed coordinates to original source coordinates.
- Green/amber/red quality classification from Tree-sitter ERROR/MISSING nodes and retained structure.
- Deduplicated, provider-neutral AI review packets containing minimized evidence and no external model calls.
- A reproducible 1,369-program estate benchmark and evidence-driven residual grammar improvements.

## Requirements

### Validated

- [x] Local vendoring path — grammar changes reach gortex through the refreshed forest shim.
- [x] `EXEC CICS` blocks parse into named nodes exposing transaction / program / map operands.
- [x] `EXEC SQL` blocks parse into bounded named nodes exposing physical DB2 table names.
- [x] IDMS DML statements parse into semantically constrained named nodes exposing record, set,
  area, scope, and exact verb roles.
- [x] Standard COBOL regression gates, commit separability, and the estate-leak guard remain green.

Validated through Phase 4: EXEC SQL Blocks on 2026-09-14.

### Active

- [ ] Raw consolidated COBOL can be deterministically transformed into parser-ready source with reversible mappings.
- [ ] Every parse receives an auditable quality grade and degraded parses enter a secure review queue.
- [ ] Recurring post-preprocessing failures drive measured, regression-tested grammar improvements.

See `.planning/REQUIREMENTS.md` for the checkable form.

### Out of Scope

- **`EXEC DLI` support** — zero occurrences across the 1,369 real programs measured. Locked
  decision D4.
- **The `site-macro` / `%`-macro site preprocessor language** — not COBOL.
- **Cascade-removal as the goal** — removing ERROR nodes is mostly achievable in preprocessing
  and yields no graph content. Locked decision D1.
- **Adopting a different COBOL parser** — evaluated and rejected. Locked decision D2.
- **Anything site-specific** — a dialect the grammar can't justify generically. Kept out on
  maintainability grounds (amended 2026-08-28 from "it would make a PR unupstreamable").

## Context

**The distinction that defines this work:** making these constructs *parse* is already solved,
in preprocessing. Making them *legible* is not. gortex's `neutralize()` prototype (in
`cobolprobe/neutralize_test.go`) rewrites `EXEC … END-EXEC` blocks and IDMS DML statements to
`CONTINUE`, preserving line count. That restores the surrounding parse and lifts recall — but it
destroys the statement content, which is exactly what the graph needs.

**Measured baseline** (from `gortex/internal/parser/forest/cobolprobe/README.md`, 1,564 files of
the pilot corpus, recall against level-number lines counted directly from the code area):

| | fields in source | grammar alone | + `neutralize()` |
|---|---|---|---|
| `.cbl` (606 files) | 121,457 | 17,905 (15%) | 32,360 (**27%**) |
| `.cpy` (958 files) | 24,478 | 0 (0%) | 22,800 (**93%**) |

**Error cascade is the root cause, not error count.** A parse error does not recover locally; it
propagates to the end of its division. One `EXEC CICS` → 1 of 20 following paragraphs survive.
One IDMS `SCHEMA SECTION` → 0 of 20 data items survive. A 5,352-line program yields only 4 ERROR
nodes but just 5 of its 77 paragraphs. `TestErrorCascade` pins this. Each family removed unlocks a
whole division, not one statement.

**Volume drives the order** (measured over the 1,369 compilable programs in
the consolidated estate tree):

| family | programs | statements |
|---|---|---|
| IDMS DML | 541 (40%) | 14,764 |
| `EXEC CICS` | 221 (16%) | 3,539 |
| `EXEC SQL` | 49 (4%) | 489 |
| `EXEC DLI` | 0 | 0 |

This is the reverse of the intuitive "EXEC CICS/SQL/DLI" framing.

**IDMS DML verb mix:** BIND 4631, OBTAIN 2939, FIND 1792, READY 1444, ERASE 714, ACCEPT 634,
GET 613, STORE 603, FINISH 550, MODIFY 384, CONNECT 200, ROLLBACK 144, COMMIT 61, DISCONNECT 53.

**The integration gap.** gortex consumes `github.com/alexaandru/go-sitter-forest/cobol v1.9.1`,
generated from upstream and vendoring `e99dbdc3` — which *is* upstream HEAD, so there is no
version-bump win available. Changes made here cannot reach gortex through that dependency until
merged upstream and the forest regenerates: "months, or never." A local vendoring path is
therefore built **first**, before any grammar work, so finished grammar work is never stranded
behind an untested delivery mechanism.

**Repo state verified 2026-08-28.** `upstream` is `yutaro-sakamoto/tree-sitter-cobol`;
`origin/main` and `upstream/main` are both at `e99dbdc`. Local `main` is 1 commit ahead solely
because of the `.planning/codebase` map commit (`8a17d90`) — the fork-hygiene constraint in
action. Upstream carries a branch `dependabot/npm_and_yarn/tree-sitter-cli-0.25.3`, directly
relevant to the CLI-bump open question. 13 corpus test files exist under `test/corpus/`.

**Local estate working copy.** A full copy of the consolidated estate tree lives at
`estate/` in this repo — the same 52,233 files, verified byte-identical by sha256 spot-check.
Measurement and preprocessing experiments run against it, not against the canonical tree, so they
can never mutate the source of truth. It is 697M on disk and excluded via `.git/info/exclude`
rather than `.gitignore`, deliberately: `.gitignore` is an upstream-tracked file, so excluding
locally keeps the fork's tracked diff at zero. FORK-02 asserts this placement.

## Constraints

- **Upstreamability (soft, amended 2026-08-28)**: Upstream PRs are **not a project goal** — this is
  a personal fork. Keep the *option* only where it costs ~nothing: grammar commits stay separable
  from fork-local commits (FORK-03), and upstream-owned files (`package.json`,
  `.github/workflows/`) are not edited gratuitously so `git pull upstream` stays painless. Generic
  dialect support over site-specific hacks still holds — on maintainability grounds, not PR
  grounds. A clean topic branch is reconstructible from separable commits on demand in minutes, so
  it is not maintained continuously. Original wording said changes "must stay rebasable onto
  upstream and offerable as clean PRs … because the only durable delivery path for this work is
  upstream acceptance" — that premise is retired; the local vendoring path (Phase 1) is the
  delivery path. Caveat from the SPEC still applies if a PR is ever attempted:
  `git rev-list --left-right --count upstream/main...origin/main` is only as truthful as the last
  `git fetch upstream`; it once read "0 behind" while 1,304 commits behind, in a sibling fork.
- **Fork hygiene (amended 2026-08-28)**: `.planning/`, `docs/`, and the vendoring shim are
  fork-local. Day-to-day work happens on `main`; topic branches are no longer cut per-cycle. The
  binding rule is FORK-03 — never mix `grammar.js` / `test/corpus/*` edits with fork-local edits in
  one commit — which keeps a clean PR branch reconstructible without maintaining one.
- **Proprietary estate vs. a public fork (hard)**: `estate/` is proprietary production source and this
  fork is **public on GitHub**. Never `git add -f` it, never relocate it inside a tracked path, and
  never quote estate source verbatim into a commit message, issue, or upstream PR. It stays
  excluded via `.git/info/exclude` — not `.gitignore` — so the upstream PR diff stays at zero.
  **Grammar test fixtures must be minimal, hand-written constructs, not estate excerpts.** This
  binds every phase: the estate is a measurement input, never a fixture source.
- **Toolchain / ABI**: The grammar builds with `tree-sitter-cli ^0.24.5` (a devDependency —
  `npm install`, no global install). gortex runs `go-tree-sitter v0.25.0`. A CLI bump may be
  required to regenerate a compatible `parser.c`, and that edits upstream's own build config —
  verify before assuming.
- **Regression threshold**: The NIST COBOL-85 suite via `run_nist_cobol85.sh` must gain no
  failures beyond the **11** already in `skip_tests.txt` (NC205A, SM101A, SM103A, SM105A, SM107A,
  SM201A, SM203A, SM205A, SM206A, SM208A, SM401M). The SPEC originally said 12; that was verified
  wrong and corrected. Inheriting 12 would silently permit one new regression.
- **Existing regression net**: Build on `test/corpus/*.txt` (13 files), `run_nist_cobol85.sh`,
  `skip_tests.txt`, and `test/check_tests.sh`. Do not invent a parallel harness.
- **Standard COBOL unharmed**: Naive verb matching finds 2,391 `ACCEPT`s in the estate; only 634
  are IDMS (`ACCEPT … FROM … CURRENCY`, `… DB-KEY`) and **1,757 are standard COBOL**. The grammar
  must disambiguate on the operand tail, never on the verb alone. This is a required regression
  gate, not an edge case — an over-eager rule silently breaks ordinary COBOL.
- **License**: MIT, inherited from upstream. Keep it.
- **Preprocessor placement**: The Go preprocessor lives in a top-level `preprocessor/` module in
  this repository. It must not alter the drop-in API or module identity of `forest-shim/cobol`.
- **Source fidelity**: Original source is read-only. Every transformation preserves a reversible
  generated-to-original coordinate map; silent semantic rewrites are prohibited.
- **Review privacy**: Review records contain hashes, metrics, normalized signatures, and minimized
  synthetic or redacted context. Raw estate source is never sent to an external model by default.
- **Milestone history**: Formal v0.25.0 archive/tag closeout was intentionally skipped on
  2026-09-17 to continue delivery. Existing Phase 1-4 artifacts remain in `.planning/phases/`.

## Success Metric

SPEC §6's six acceptance criteria, applied per construct family. A family is done when **all**
hold:

1. **Cascade gone** — `TestErrorCascade` in `cobolprobe` shows paragraphs and data items after the
   construct surviving at parity with a file that lacks it.
2. **Nodes named** — a tree-sitter query extracts the identifying operand (CICS
   transaction/program/map, DB2 table, IDMS record + set) as a named capture.
3. **Recall moves** — `.cbl` recall in `cobolprobe` rises on the **grammar-alone** axis, measured
   on the same corpus with the same method, closing a stated fraction of the gap between
   grammar-alone (17,905 `dataItems`) and `+ neutralize()` (32,360). Terminal condition:
   grammar-alone >= neutralized, i.e. `neutralize()` retires. *Amended 2026-08-29 from "rises
   measurably from the 27% neutralized baseline" — `neutralize()` already rewrites IDMS DML
   (gortex `cobolprobe/neutralize_test.go:24`), so 26.6% is the ceiling this work climbs toward,
   not a bar it clears. The resolution rule for OQ-3 is decided
   (`.planning/phases/02-idms-dml-statement-nodes/02-CONTEXT.md` D-13); the value is set by Phase 2's
   measurement. Phase 4 has no recall obligation — the corpus of record contains zero `EXEC SQL`
   (D-14).*
4. **No regressions** — `tree-sitter test` passes, and NIST COBOL-85 gains no failures beyond the
   11 in `skip_tests.txt`.
5. **Standard COBOL unharmed** — specifically the `ACCEPT` ambiguity.
6. **Separably delivered** *(softened 2026-08-28 from "Upstreamable")* — a self-contained commit
   or series that touches no fork-local path, with corpus tests, containing no site-specific
   naming. A rebased topic branch is reconstructible from this on demand; producing one is not
   required per-family.

## Key Decisions

<decisions>

**D1 — Target is nodes-for-edges, not cascade-removal.** LOCKED.
The objective is first-class, walkable AST nodes with accurate positions for the estate's
non-standard construct families — not merely the elimination of ERROR nodes.
*Rationale:* Cascade removal alone is mostly achievable in preprocessing and yields no graph
content. The consumer needs statement operands preserved as nodes to emit
`program → transaction`, `program → table`, and `program → record/set` edges. `neutralize()`
already restores the surrounding parse by rewriting `EXEC … END-EXEC` and IDMS DML to `CONTINUE`,
but it destroys the statement content.
*Source:* SPEC-001 §9 D1, cross-ref §2.

**D2 — Build on this grammar rather than adopting another parser.** LOCKED.
Extend the forked `yutaro-sakamoto/tree-sitter-cobol` grammar rather than adopting an alternative
COBOL parser.
*Rationale:* `cobol-rekt` (Che4z-based) was evaluated against the estate — 61% success on
non-IDMS programs but **1/74 on IDMS**, failing on ordinary DML tokens (`WITHIN`, `NEXT`,
`CURRENT`, `ANY`, `DB-KEY`); its own IDMS fixtures are toy-level. ProLeap, Koopa, and GnuCOBOL do
not attempt DML at all and are JVM/C, breaking the single-binary constraint.
*Source:* SPEC-001 §9 D2.

**D3 — IDMS DML is both a preprocessing problem and a grammar problem; do both.** LOCKED.
Preprocessing (in the preprocessing repo) handles the structural IDMS constructs; the grammar
handles the DML statements.
*Rationale:* On a real mainframe DML never reaches the COBOL compiler — the IDMS precompiler
rewrites it first. Verified in the estate: the subschema punch
comments out `*IDMS-CONTROL SECTION.`, `*SCHEMA SECTION.`, `*DB <SUBSCHEMA> WITHIN <SCHEMA>.`; and
a program in the estate shows the statement form `MOVE <seq> TO DML-SEQUENCE / CALL 'IDMS' USING
SUBSCHEMA-CTRL / IDBMSCOM (nn) / <operands>`. Only the grammar can preserve DML statement
operands as nodes.
*Source:* SPEC-001 §9 D3, cross-ref §5.

**D4 — `EXEC DLI` is out.** LOCKED.
Do not build `EXEC DLI` support. Defer.
*Rationale:* Zero occurrences in the estate — 0 programs, 0 statements measured over 1,369 real
programs.
*Source:* SPEC-001 §9 D4, cross-ref §5.

**D5 — The local vendoring path goes first, before any grammar work.** (This session.)
SPEC §8's integration gap is addressed in Phase 1, ahead of IDMS DML.
*Rationale:* Prove the `go.mod` `replace` delivery pipe with the unmodified grammar while it is
cheap, rather than discovering it at integration time and stranding finished grammar work behind
an untested delivery mechanism — §8's own warning. After vendoring, the SPEC's volume ordering
holds: IDMS DML → EXEC CICS → EXEC SQL.

**D6 — Upstream PRs are not a goal; PR-readiness is preserved only where free.** (This session,
2026-08-28.)
Stated by the user: "the forks I make will likely never make it back to the upstream so that is not
a major concern they are my personal forks", and "ideally I'd like to keep it PR ready if and only
if it's really worth it in case I change my mind later but just know that it is not the goal".
*Rationale:* PR-readiness is **recoverable on demand** — a clean topic branch can be reconstructed
from separable commits in about ten minutes at any future date, so it need not be maintained
continuously to be preserved. Applying that test: commit separability (FORK-03) is kept because it
costs nothing and is the only non-recoverable property; FORK-01's branch-hygiene guard and the
per-cycle topic-branch workflow are deferred because they cost real effort for zero present value;
FORK-02's estate-leak guard is unaffected and becomes Phase 1's only guard, since a public repo
holding 697 MB of proprietary source is a risk independent of PRs.
*Consequence:* Phase 1 loses one workstream. SPEC §6 criterion 6 is softened for all families.
*Source:* Phase 1 discussion; `.planning/phases/01-delivery-pipe-measurement-baseline/01-CONTEXT.md`.

</decisions>

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| D1 — nodes-for-edges, not cascade-removal | Cascade removal yields no graph content | — Pending |
| D2 — extend this grammar, not another parser | cobol-rekt scored 1/74 on IDMS; alternatives are JVM/C and skip DML | — Pending |
| D3 — IDMS DML is preprocessing AND grammar | Only the grammar preserves statement operands as nodes | — Pending |
| D4 — `EXEC DLI` out | Zero occurrences in the estate | — Pending |
| D5 — vendoring path first | Avoids stranding finished grammar work behind an untested pipe | — Pending |
| D6 — upstream PRs not a goal; keep PR-readiness only where free | PR-readiness is recoverable on demand from separable commits; FORK-01 cost real effort for zero present value | — Applied to Phase 1 |
| D7 — colocate preprocessing as an isolated Go module | Parser and source transformations evolve against the same measured corpus while the forest shim stays a drop-in parser module | — Pending v0.26.0 |
| D8 — classify parse quality instead of binary success | Tree-sitter always returns a tree; ERROR/MISSING ranges and retained structure determine whether output is trusted, warned, or quarantined | — Pending v0.26.0 |
| D9 — AI review is provider-neutral and offline by default | Proprietary source must not leave the machine; this milestone exports minimized review packets but invokes no external model | — Pending v0.26.0 |

## Open Questions

Carried as **open**. These are not decisions and must not be treated as such.

| ID | Question | Blocks | Current lean |
|----|----------|--------|--------------|
| OQ-1 | Node granularity for `EXEC SQL` — full SQL grammar, or opaque statement body plus extracted table names? | Phase 4 (`EXEC SQL`) | **RESOLVED 2026-09-14.** Bounded extraction grammar: named statement/directive nodes and graph-relevant table/include/dynamic-source roles; unsupported SQL remains visible in `sql_unparsed_tail`. |
| OQ-2 | Does the `tree-sitter-cli` 0.24.5 → 0.25.x bump break upstream's existing corpus tests? Unmeasured. | Phase 1 (vendoring) | Upstream carries branch `dependabot/npm_and_yarn/tree-sitter-cli-0.25.3`, which may already carry evidence. Measure as a spike inside Phase 1. |
| OQ-3 | Concrete recall target. §6 criterion 3 says only "rises measurably". | Phase 3 gating (Phase 4's recall gate retired, D-14) | **RESOLVED 2026-09-04, RE-SCOPED 2026-09-09, MET 2026-09-11.** Reconstructed Phase 1 `paragraph_header` = 9,187; IDMS closed 6,136 to reach 15,323; CICS closed the remaining 1,409-item target and reached 18,234, exceeding the terminal 16,732 target by 1,502 (206.6% residual closure). The prior `dataItems >= 18,772` value remains withdrawn because CICS cannot move that axis. See `docs/baseline.md` §§5-6. |
| OQ-4 | Upstream appetite — has `@yutaro-sakamoto` expressed a position on dialect support? | PR-shaped investment | Worth an issue before investing in PR-shaped work. |

---
## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Move validated requirements to Validated.
2. Move invalidated requirements to Out of Scope with the reason.
3. Add newly discovered requirements and durable decisions.
4. Update context and constraints when measured evidence changes them.

**After each milestone:**
1. Review the full project description and core value.
2. Audit active and out-of-scope requirements.
3. Record shipped capabilities, remaining gaps, and decision outcomes.

---
*Last updated: 2026-09-17 for v0.26.0 Estate Parse Recovery*
