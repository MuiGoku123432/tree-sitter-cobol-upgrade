# Phase 3: EXEC CICS Blocks - Research

**Researched:** 2026-09-09
**Domain:** tree-sitter grammar authoring (LALR + keyword extraction), COBOL/CICS syntax, Go-side measurement harness
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Copied verbatim from `.planning/phases/03-exec-cics-blocks/03-CONTEXT.md` `<decisions>`:

- **D-16a:** Criterion 4's `dataItems` axis is **unsatisfiable for this phase**. Measured: 0 of the 169 `.cbl` containing `EXEC CICS` have the construct before `PROCEDURE DIVISION`, and the cascade harness confirms `EXEC CICS` costs 19 of 20 paragraphs while costing **0** data items. A phase that fixes CICS cannot move a DATA DIVISION metric. Re-scope now, per D-16.
- **D-16b:** The replacement axis is **`paragraph_header`** — the counter at `neutralize_test.go:72`. Named verbatim to avoid the 42-vs-15,323 ambiguity against `probe_test.go:55`.
- **D-16c:** Two gates, deliberately asymmetric. **Blocking:** `TestErrorCascade`'s EXEC CICS case reaching 20/20 paragraphs. **Hard-on-direction / explained-on-magnitude (D-15):** the corpus `paragraph_header` delta.
- **D-16d:** Corpus target is the **terminal condition on this axis** — grammar-alone `.cbl` `paragraph_header` **>= 16,732**, closing 100% of the measured 1,409 gap. Reversibility: one-way.
- **D-17:** **One generic `exec_cics_statement`** — `EXEC CICS` + `field('command', …)` + option list + `END-EXEC`. A deliberate departure from Phase 2's D-01 four-verb-class shape. Reversibility: costly — the node name is the contract `queries/cics.scm` reads.
- **D-18:** The command name is **`field('command', $.WORD)`**, relying on tree-sitter keyword extraction (`word: $ => $._WORD`, grammar.js:14) so `READ`, `WRITE`, `DELETE` and `RETURN` lex as `WORD` inside the block without a `conflicts:` entry. **This assumption MUST be proven by a fixture before anything is built on it** (see D-32). Fallback: `choice($.WORD, $._READ, $._WRITE, $._DELETE, $._RETURN, …)`.
- **D-19:** Unmatched block content is absorbed into a named **`cics_unparsed_tail`** node — a direct D-03 analog. Never ERROR, never silently dropped.
- **D-20:** **`END-EXEC` is a required terminator.** The trailing period is left to the existing sentence machinery. Optional/recoverable terminators were rejected.
- **D-21:** **Named nodes for the criterion-1 operands** — `cics_transaction_name` (TRANSID), `cics_program_name` (PROGRAM), `cics_map_name` (MAP) — anchored on the option keyword, mirroring D-02. Forced by a hard consumer constraint: gortex's `runQuery` does **no predicate evaluation**.
- **D-22:** Each named operand node wraps **whatever is inside the parens** — quoted literal or data name alike. **DISCLOSURE:** 30 of 33 `PROGRAM` operands are data names.
- **D-23:** **`cics_mapset_name` is added as a fourth named node**, one beyond criterion 1's three. 610 measured occurrences, 1:1 co-occurrence with `MAP`.
- **D-24:** The query ships as **`queries/cics.scm` from this fork**, mirroring D-04. Criterion 1 is demonstrated by a **fork-local test that compiles the query against a fixture and asserts the four named captures**. **FINDING:** D-04's rationale that "gortex reads it" is **not true today**.
- **D-25:** **IDMS-05 is re-scoped onto the `paragraph_header` axis** alongside CICS-04 and closed in Phase 3.
- **D-26:** Phase 3 **reconstructs** the missing Phase 1 `paragraph_header` baseline: check out the pre-Phase-2 grammar, run `forest-shim/refresh.sh`, re-run the probe.
- **D-27:** The blocking cascade gate is made real by **editing gortex's `cascade_test.go`** to assert both `pa2 == pa` and `d2 == d`. The `SCHEMA SECTION` case stays logged-only per D3.
- **D-28:** The gate injects **four representative shapes, all asserted at parity**: (a) `SEND MAP('M')`; (b) no-option `RETURN` (1,251 / 43%); (c) a bare-option form (`NOHANDLE` 1,586 / `FREEKB` 450 / `ERASE` 438); (d) a multi-line block (51 blocks).
- **D-29:** The grammar models **all four measured argument forms up front** — quoted literal (1,993), plain data name (2,041), `LENGTH OF <name>` (527), numeric literal (81). A stated departure from D-09.
- **D-30:** Acceptance rule for `cics_unparsed_tail` mirrors D-15. Blocking: no cascade. Non-blocking but mandatory: any tail at all requires a written cause naming what is in it.
- **D-31:** **The Phase 2 zero-reclassification differential runs for CICS**, as a hard gate, on both DCC and the estate per D-07.
- **D-32:** Fixtures ship as **one `test/corpus/exec_cics.txt`**, with the CICS Application Programming Reference as syntax ground truth and **invented neutral names**. **Mandatory:** a dedicated fixture proving the D-18 assumption. **Plan this first.**

Plus the six pre-planning amendments in `<domain>` (ROADMAP criterion 4, CICS-04, IDMS-04, IDMS-05, OQ-3, `docs/baseline.md`) which land as **one docs commit before planning runs** (D-16).

### Claude's Discretion

- Exact rule and node names, provided `exec_cics_statement`, `cics_transaction_name`, `cics_program_name`, `cics_map_name`, `cics_mapset_name` and `cics_unparsed_tail` are used verbatim.
- Whether the generic option is `cics_option` with `field('name')`/`field('value')` or named sub-rules, and whether bare options get a distinct node from paren options.
- Whether the option list is `repeat()` or `repeat1()` (D-28(b) means `repeat1()` would be wrong).
- Commit boundary and sequencing of the pre-planning docs amendment commit.
- Whether the reconstructed Phase 1 `paragraph_header` baseline lands as a new `docs/baseline.md` section or an amendment to §2.
- Whether the two gortex-side edits (D-27, D-28) ship as one commit or two.
- How the `cics_unparsed_tail` census is reported.
- Plan decomposition and commit sequencing within the phase, subject to FORK-03.

### Deferred Ideas (OUT OF SCOPE)

- Wiring gortex to read `queries/*.scm` (the D-24 finding — largest deferred item; blocks the business value of Phases 2-4).
- Named nodes for the other 21 measured option names (`LENGTH`, `COMMAREA`, `RIDFLD`, `FILE`, `FROM`, `INTO`, `ABSTIME`, …).
- `SCHEMA SECTION` and the DATA DIVISION gap (locked D3 — preprocessing repo).
- `.cpy` grammar-alone recall (0%) — structural.
- Fixing the upstream `comment` corpus fixture (12/13).
- A second corpus containing `EXEC SQL` (rejected, D-14).
- FORK-01 branch-hygiene guard and topic-branch publication.
- `HANDLE CONDITION` / `HANDLE AID` / `RESP`/`RESP2` control-flow semantics.
- `EXEC SQL` (Phase 4), `EXEC DLI` (locked out, D4), Endevor `-INC`, `%`-macro language.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description (REQUIREMENTS.md:126-145) | Research Support |
|----|---------------------------------------|------------------|
| CICS-01 | Grammar parses `EXEC CICS … END-EXEC` into named nodes with accurate positions, not ERROR nodes | Architecture Patterns §"The `exec_cics_statement` shape"; `_statement` integration point verified at grammar.js:1366-1385 |
| CICS-02 | A tree-sitter query extracts transaction / program / map names as named captures | Architecture Patterns §"The query contract"; `queries/idms.scm` read verbatim as the analog; `runQuery` no-predicate constraint verified |
| CICS-03 | `TestErrorCascade` shows paragraphs after `EXEC CICS` surviving at parity (baseline 1 of 20) | Validation Architecture §Test Framework; `cascade_test.go` read in full — the exact edit site and the pre-sanctioning comment verified |
| CICS-04 | `.cbl` recall closes the gap-closure target on the grammar-alone axis — **amended to the `paragraph_header` axis per D-16a-d before planning** | Validation Architecture §Sampling Rate; `neutralize_test.go:72` counter verified; `docs/baseline.md:158-163` numbers verified |
| CICS-05 | `tree-sitter test` passes; `run_nist_cobol85.sh` gains no failure beyond the 11 in `skip_tests.txt` | Environment Availability; CI workflow read (`-e '^comment$'` exclusion) |
| CICS-06 | Self-contained commit series separable from fork-local changes (FORK-03), corpus tests included, no site-specific naming, passes FORK-02 | Common Pitfalls §"Commit separability"; Runtime State Inventory §Build artifacts |

</phase_requirements>

---

## Summary

This phase is the **third repetition of a proven mechanical pipeline**, not a novel engineering problem. Phase 2 built and exercised every piece Phase 3 needs: the `_statement` `choice()` attachment point, the named-operand-node technique, the unparsed-tail escape, the `queries/*.scm` publication path (which `forest-shim/refresh.sh` already carries into the shim), the zero-reclassification differential, the fork-local CI corpus gate, and the `refresh.sh` regenerate-and-vendor sequence. The CONTEXT.md decisions are unusually complete — every design question that normally falls to research has already been decided against measured counts.

The research therefore concentrated on **verifying CONTEXT.md's load-bearing claims against the actual repo rather than re-deciding them**, and on the one thing CONTEXT.md flags as unproven: D-18's reliance on tree-sitter keyword extraction. **That assumption is now empirically confirmed.** A live parse of `MOVE 'X' TO READ.` and `MOVE 'X' TO WRITE.` through this repo's committed parser produces clean `(WORD)` nodes with zero ERROR nodes `[VERIFIED: node_modules/.bin/tree-sitter parse, this session]`, and the generated parser declares `.keyword_capture_token = sym__WORD` with an active `ts_lex_keywords` function `[VERIFIED: src/parser.c:899312-899313]`. Keyword extraction demonstrably falls back to `_WORD` for these case-insensitive regex keyword tokens. D-32's proving fixture should still be planned first — it is cheap and it pins the behaviour against future tree-sitter-cli upgrades — but the phase's single named risk is materially lower than CONTEXT.md assumed.

Research surfaced **one pitfall CONTEXT.md does not name**: `END-EXEC` matches the `_WORD` regex exactly `[VERIFIED: grammar.js:3491]`, which means the same keyword-extraction machinery that makes D-18 work also governs whether `cics_unparsed_tail` stops at the terminator or swallows it. This is the D-19/D-20 interaction and it deserves its own fixture. Everything else — the `_statement` attachment, the tail-token vocabulary, the differ's `NODE_TYPE_REGEX` reuse hook, the four-shape cascade edit — is a direct copy of a working Phase 2 artifact.

**Primary recommendation:** Plan the D-32 keyword-extraction fixture and an `END-EXEC`-vs-tail boundary fixture as task one in the same wave, then build `exec_cics_statement` as a single rule modelled line-for-line on `idms_session_statement`'s composition style, reusing `_idms_operand_token`'s vocabulary (extended with the paren/`LENGTH OF` forms D-29 requires) for the tail.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `EXEC CICS` block recognition & node emission | Grammar definition (`grammar.js`) | — | Pure LALR shape; no lexical state needed. Phase 2 established the precedent for the analogous tail rule `[VERIFIED: 02-RESEARCH.md:341-354]` |
| Operand keyword lexing (`TRANSID`, `PROGRAM`, `MAP`, `MAPSET`) | Grammar terminal definitions (`grammar.js` `_KEYWORD` block) | — | Follows the existing case-insensitive-regex convention `[VERIFIED: grammar.js:3357,3004,3121,3381]` |
| Command-name/keyword disambiguation | tree-sitter keyword extraction (generated `parser.c`) | Explicit `choice()` arms (D-18 fallback) | `word: $ => $._WORD` is already declared and active `[VERIFIED: grammar.js:14; src/parser.c:899313]` |
| Fixed-format column handling / comments | External scanner (`src/scanner.c`) | — | Already handles columns 6, 7, 72 `[VERIFIED: src/scanner.c:48,108,118,135]`. **Phase 3 should not touch it** — see Don't Hand-Roll |
| Capture publication | `queries/cics.scm` | `forest-shim/refresh.sh` Step 3 | The shim's `//go:embed grammar.json *.scm` means the file must land inside `forest-shim/cobol/` `[VERIFIED: forest-shim/refresh.sh, Step 3 comment]` |
| Cascade parity gate | gortex `cobolprobe/cascade_test.go` | — | Cross-repo, pre-sanctioned by the file's own comment `[VERIFIED: cascade_test.go, "The EXEC CICS case is Phase 3's gate"]` |
| Recall measurement | gortex `cobolprobe/neutralize_test.go` | `docs/baseline.md` | The `paragraph_header` counter is at the `switch n.Type()` arm `[VERIFIED: neutralize_test.go, case "paragraph_header": paras++]` |
| Regression net | `tree-sitter test` + `run_nist_cobol85.sh` + `run_accept_differential.sh` | `.github/workflows/fork-checks.yml` | All three exist and run today `[VERIFIED: repo root; .github/workflows/fork-checks.yml]` |

---

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `tree-sitter-cli` | 0.24.5 | `generate`, `test`, `parse` | Lockfile-pinned in `package.json` devDependencies; `refresh.sh` installs via `npm ci`, never `npm install` `[VERIFIED: package.json; forest-shim/refresh.sh Step 1]` |
| Go toolchain | go1.27.1 darwin/arm64 | Runs `cobolprobe` and the shim smoke build | `[VERIFIED: go version]` |
| `github.com/alexaandru/go-sitter-forest/cobol` | v1.9.1 (module-cache drop-in target) | The interface `forest-shim/cobol/` impersonates | `refresh.sh` Step 5 diffs the shim's Go surface against this exact cache path `[VERIFIED: forest-shim/refresh.sh, FOREST_CACHE default]` |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `forest-shim/refresh.sh` | 6-step regenerate → flatten → include-rewrite → drift-check → smoke-build | After **every** `grammar.js` or `queries/*.scm` change, before any measurement |
| `run_accept_differential.sh` | `snapshot` / `compare` zero-reclassification gate, with a `NODE_TYPE_REGEX` third argument | D-31's hard gate; also the `cics_unparsed_tail` census tool (D-30) |
| `run_nist_cobol85.sh` + `skip_tests.txt` | NIST COBOL-85 regression, threshold **11** | CICS-05 |
| `test/check_tests.sh` (`npm run ct`) | Corpus fixture helper | Alongside `tree-sitter test` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pure-grammar `repeat` tail | External scanner token in `src/scanner.c` | Rejected by Phase 2 research and unchanged here: requires C, recompilation in every downstream consumer, for a problem the grammar solves free `[CITED: .planning/phases/02-idms-dml-statement-nodes/02-RESEARCH.md:341-354]` |
| Keyword extraction (D-18) | Explicit `choice($.WORD, $._READ, $._WRITE, $._DELETE, $._RETURN)` | The fallback. Costs a wider rule and possible `conflicts:` entries; only needed if the D-32 fixture fails — which the live probe suggests it will not |
| `queries/cics.scm` | Folding captures into `tags.scm` | Rejected in CONTEXT.md D-24: wrong capture vocabulary, upstream-owned path, bends FORK-03 |

**Installation:** none. **This phase installs no external packages.** All tooling is already present and lockfile-pinned.

---

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** `tree-sitter-cli@^0.24.5` and `nan@^2.22.0` are pre-existing, lockfile-pinned entries in the upstream-owned `package.json`, and FORK-02/FORK-03 forbid modifying it `[VERIFIED: package.json]`. The Go side adds no module: `cascade_test.go` edits use only stdlib plus the already-vendored forest/sitter imports `[VERIFIED: cascade_test.go import block]`.

If planning later introduces a dependency, run the legitimacy gate before adding it. As of this research: **zero packages to audit, zero `[SLOP]`, zero `[SUS]`.**

---

## Architecture Patterns

### System Architecture Diagram

```
  test/corpus/exec_cics.txt ──┐
                              │ (tree-sitter test)
  grammar.js                  │
   ├─ _statement choice ──────┤
   ├─ exec_cics_statement     │
   ├─ cics_* operand nodes    │
   └─ _KEYWORD terminals      │
          │                   │
          │ tree-sitter generate
          ▼                   │
  src/parser.c ───────────────┼──► run_nist_cobol85.sh ──► ≤11 skips (CICS-05)
  src/grammar.json            │
  src/node-types.json         │
          │                   └──► run_accept_differential.sh snapshot/compare
          │                          ├─ DCC corpus  ─┐
          │                          └─ estate/     ─┴─► 0 reclassifications (D-31)
          │                                              + cics_unparsed_tail census (D-30)
          │
          │ forest-shim/refresh.sh  (copy → flatten → sed includes → drift → go build)
          ▼
  forest-shim/cobol/{parser.c,scanner.c,grammar.json,parser.h,*.scm}
          │
          │ go.work resolution
          ▼
  gortex internal/parser/forest/cobolprobe/
          ├─ cascade_test.go  ──► TestErrorCascade  ──► 20/20 paragraphs (CICS-03, D-27/D-28)
          └─ neutralize_test.go ► paragraph_header  ──► ≥16,732 grammar-alone (CICS-04, D-16d)
                                                        │
  queries/cics.scm ──────────────────────────────────► fork-local query-compile test
                                                        (4 named captures, CICS-02, D-24)
```

Note the **two independent consumer legs**: the query leg is asserted fork-locally only, because nothing in gortex reads `cics.scm` today (D-24 finding, verified below).

### Recommended file touch set

```
grammar.js                       # exec_cics_statement + operand nodes + terminals + _statement entry
src/parser.c                     # regenerated, committed (never hand-edited)
src/grammar.json                 # regenerated, committed
src/node-types.json              # regenerated, committed
queries/cics.scm                 # new
test/corpus/exec_cics.txt        # new
forest-shim/cobol/*              # refreshed by refresh.sh
docs/baseline.md                 # Phase 1 paragraph_header reconstruction + Phase 3 delta
.planning/{REQUIREMENTS,ROADMAP,PROJECT,STATE}.md   # the pre-planning amendment commit
~/repos/mine/GoApps/gortex/.../cascade_test.go      # cross-repo, D-27/D-28
```

### Pattern 1: The `exec_cics_statement` shape

**What:** One rule, attached to the flat `_statement` `choice()`.
**When to use:** All 26 measured CICS commands.

The integration point is one line. `_statement` is a flat alphabetical `choice()` and the four IDMS entries sit at lines 1382-1385 `[VERIFIED: grammar.js:1366-1400]`:

```javascript
    _statement: $ => choice(
      $.accept_statement,
      ...
      $.exit_statement,
      $.goback_statement,
      $.goto_statement,
      $.idms_accept_statement,
      $.idms_navigation_statement,
      $.idms_session_statement,
      $.idms_update_statement,
      ...
```

Crucially, sibling `_statement` rules **do not embed a terminating period** — `move_statement` is `seq($._MOVE, $._move_body)` and termination is handled centrally `[VERIFIED: .planning/phases/02-idms-dml-statement-nodes/02-PATTERNS.md, "Boundary/termination precedent"]`. This is exactly what D-20 relies on for the 1,283 trailing periods.

The composition style to copy is `idms_session_statement` `[VERIFIED: grammar.js:2286-2330]`:

```javascript
    idms_session_statement: $ => $._idms_session_body,

    _idms_session_body: $ => prec.right(choice(
      seq(
        field('verb', $.BIND),
        optional(choice($.RUN_UNIT, $.idms_record_name)),
        // BIND RUN-UNIT DBNAME <db-name>. Modelled on measured volume: the
        // D-09 tail census found this shape in 96 of 119 idms_unparsed_tail
        // records (81%). ...
        optional(seq($.DBNAME, $.WORD)),
        optional($.idms_unparsed_tail)
      ),
      ...
```

Note the house conventions this demonstrates and Phase 3 must follow: `field('verb', …)` labelling, `_`-prefixed private body rules, and **inline comments citing the measured volume that justified each modelled option** — D-29's counts (1,993 / 2,041 / 527 / 81, and the option counts 1,586 / 610 / 594 / 450 / 438 / 415 / 411 / 33) belong in these comments.

### Pattern 2: Named operand nodes, not `field()`

**What:** `cics_transaction_name`, `cics_program_name`, `cics_map_name`, `cics_mapset_name` as their own rules wrapping the paren contents.
**Why:** Two independent forces, both verified.

1. **Depth.** `field()` binds only *direct children of the declaring rule*; operands nested inside an option sub-rule are unreachable `[CITED: .planning/phases/02-idms-dml-statement-nodes/02-PATTERNS.md, D-02 rationale]`. Phase 2 solved this with `idms_record_name: $ => prec(1, $.WORD)` `[VERIFIED: grammar.js:2381-2383]`.
2. **No predicates downstream.** gortex's `runQuery` iterates `cursor.Matches(...)`, copies `match.Captures` into a map, and evaluates **nothing** `[VERIFIED: ~/repos/mine/GoApps/gortex/internal/parser/treesitter.go, runQuery body — no predicate handling in the loop]`. A `#eq?` would compile and be silently ignored. D-21 is correct and non-negotiable.

Note the `prec(1, …)` on the Phase 2 operand rules — added to resolve a `WORD`-vs-`WORD` ambiguity without a `conflicts:` entry `[VERIFIED: grammar.js:2379-2381 comment]`. The CICS operand nodes will likely need the same, since they compete with the generic option-value rule for the same `$.WORD`.

### Pattern 3: The unparsed tail

`idms_unparsed_tail` is a pure-grammar `repeat1` over a small leaf vocabulary `[VERIFIED: grammar.js:2391-2399]`:

```javascript
    _idms_operand_token: $ => choice(
      $.WORD,
      $._LITERAL,
      '(',
      ')',
      ','
    ),

    idms_unparsed_tail: $ => repeat1($._idms_operand_token),
```

`cics_unparsed_tail` should mirror this. **The vocabulary already contains `(` and `)`,** which is most of what CICS needs. The bounding differs: IDMS bounds at the literal `.`; CICS bounds at `END-EXEC` — see Pitfall 2.

### Pattern 4: The query contract

`queries/idms.scm` is the exact shape to mirror `[VERIFIED: queries/idms.scm, read in full]`:

```scheme
; IDMS DML extraction query (Phase 2, D-04): record/set names + verb.
(idms_navigation_statement
  verb: (_) @verb
  (idms_record_name) @record)

(idms_navigation_statement
  (idms_set_name) @set)
```

Two conventions to carry: a leading comment naming the phase and decision, and **one pattern per capture role** rather than one pattern with alternations. Note it uses `verb: (_) @verb` — a field selector on a wildcard — which is the D-17/D-18 analog for `command: (WORD) @command`.

### Anti-Patterns to Avoid

- **Embedding a terminating `.` in `exec_cics_statement`.** That is `select_statement`'s Environment-Division shape, not the procedure-division sibling shape. Copying it breaks the 1,283 period-terminated blocks and the 1,603 that lack one.
- **`repeat1()` for the option list.** No-option `RETURN` is 1,251 blocks / 43% (D-28b). It must be `repeat()`.
- **Hand-editing `src/parser.c`, `src/grammar.json`, or `src/node-types.json`.** They are tracked generated artifacts `[CITED: .planning/codebase/ARCHITECTURE.md, per CONTEXT.md canonical refs]`.
- **Leaving `cics.scm` in `queries/` only.** `forest-shim/cobol/plugin.go` and `binding.go` declare `//go:embed grammar.json *.scm`, so a query outside the shim directory is invisible to gortex `[VERIFIED: forest-shim/refresh.sh Step 3 comment]`. `refresh.sh` already copies it — do not skip the refresh.
- **Adding a `#eq?` predicate to `cics.scm`.** Silently ignored downstream (Pattern 2).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Absorbing unmodelled CICS option content | A new external-scanner token in `src/scanner.c` | A pure-grammar `repeat` over leaf tokens, per `idms_unparsed_tail` | `scanner.c` is 207 lines and handles only whitespace/comments/columns `[VERIFIED: wc -l src/scanner.c = 207]`. Extending it means C, recompilation in every downstream consumer, and forfeiting the zero-cost regenerate path |
| Fixed-format column 6/7/72 handling for multi-line blocks | Column arithmetic anywhere in `grammar.js` | The existing external scanner | Already implemented `[VERIFIED: src/scanner.c:48,108,118,135 — get_column checks at 5, 6, 71, 72]`. Newlines and comments are `extras`, so a multi-line block is free `[VERIFIED: grammar.js:24-32]` |
| Keyword-vs-identifier arbitration for `READ`/`WRITE`/`DELETE`/`RETURN` | A `conflicts:` entry or a hand-written token precedence table | tree-sitter keyword extraction, already enabled | `word: $ => $._WORD` is declared and the generated parser sets `.keyword_capture_token = sym__WORD` `[VERIFIED: grammar.js:14; src/parser.c:899313]`. The grammar has **zero** `conflicts:` entries today `[VERIFIED: src/grammar.json, conflicts length = 0]` — keep it that way |
| Counting `cics_unparsed_tail` occurrences across the corpus | A new corpus-scanning script | `run_accept_differential.sh snapshot <DIR> <OUT> <NODE_TYPE_REGEX>` | The third argument exists specifically so a later plan can reuse it for a tail census rather than build a second harness — PROJECT.md forbids a parallel one `[VERIFIED: run_accept_differential.sh header, "NODE_TYPE_REGEX exists so a later plan (02-06) can reuse this same tool"]` |
| Cascade parity measurement | A new Go test | Extend `TestErrorCascade`'s existing clean-control / inject / count scaffolding | The `lines := strings.SplitN(proc.String(), "\n", 3)` injection idiom is already there and already used by three cases `[VERIFIED: cascade_test.go]` |

**Key insight:** Every temptation in this phase is to reach for heavier machinery than the problem needs. Phase 2 recorded exactly this and the pure-grammar route held. Nothing about CICS's uniform `KEYWORD(arg)` syntax is harder than IDMS's positional forms — it is strictly easier.

---

## Common Pitfalls

### Pitfall 1: `END-EXEC` matches `_WORD` — the tail can swallow the terminator

**What goes wrong:** `_WORD` is `/([0-9][a-zA-Z0-9-]*[a-zA-Z][a-zA-Z0-9-]*)|([a-zA-Z][a-zA-Z0-9-]*)/` `[VERIFIED: grammar.js:3491]`. `END-EXEC` matches the second alternative in full. If `cics_unparsed_tail` is `repeat1(choice($.WORD, ...))` and the parser state permits both `_WORD` and a new `_END_EXEC` token, the tail is a candidate consumer of the terminator.

**Why it happens:** Keyword extraction resolves this by lexing the word and then consulting `ts_lex_keywords`; the keyword token wins **when it is valid in the current parse state**. In a `repeat()` body, both are valid, and the outcome depends on tree-sitter's conflict resolution rather than on anything the author wrote.

**How to avoid:** Make it a fixture, not an assumption. Write a corpus case with an option form the grammar deliberately does not model, immediately followed by `END-EXEC`, and assert the tree shows `(cics_unparsed_tail …)` followed by the terminator — not a tail that ate it. If it fails, the standard remedies are a token precedence on the terminator, or a tail vocabulary that excludes the terminator token explicitly.

**Warning signs:** A block parses without ERROR but the following paragraph disappears — i.e. the cascade the phase exists to kill, reappearing through the escape hatch built to prevent it. `TestErrorCascade` catches this; `tree-sitter test` alone might not. `[ASSUMED — reasoning from verified regex + verified keyword-extraction mechanism; not empirically tested this session because it requires the not-yet-written rule]`

### Pitfall 2: `EXEC SQL` and `EXEC DLI` share the `EXEC` prefix

**What goes wrong:** Introducing an `_EXEC` token makes `EXEC` a keyword everywhere. `EXEC SQL` (Phase 4) and `EXEC DLI` (locked out, D4) then begin with a recognised token followed by content no rule accepts — potentially converting a clean whole-block ERROR into a partial parse plus a *worse* cascade.

**Why it happens:** The phase's own scope boundary is a grammar-level hazard: the grammar does not get to only-know-CICS once `EXEC` is a token.

**How to avoid:** Anchor the rule on the two-token sequence `EXEC CICS`, not on `EXEC` alone, and add a corpus fixture containing an `EXEC SQL` block asserting that its parse is **no worse than today's**. `neutralize()`'s own `reExec` regex already treats all three families together — `EXEC\s+(CICS|SQL|DLI)\b.*?END-EXEC` `[VERIFIED: neutralize_test.go, reExec]` — so the measurement harness will not distinguish them; only a fixture will.

**Warning signs:** DCC contains zero `EXEC SQL` (D-14), so the corpus recall number cannot detect this. The estate differential (D-31) can.

### Pitfall 3: The differential's same-row heuristic

**What goes wrong:** `run_accept_differential.sh` derives its `clean` / `trailing_error` qualifier from whether an `(ERROR ...)` node *begins on the same source row* on which the matched node *ends* `[VERIFIED: run_accept_differential.sh header]`. This rests on one-statement-per-line. A multi-line `EXEC CICS` block (D-28d, 51 occurrences) violates that assumption.

**How to avoid:** Do not use the qualifier as evidence about multi-line blocks. The `RECLASSIFIED_COUNT` tally — before-type `accept_statement` + clean → after-type anything else — is the actual hard gate and is unaffected. Choose the `NODE_TYPE_REGEX` for the CICS census deliberately, and state in the census write-up that the qualifier is row-scoped.

### Pitfall 4: `refresh.sh` Step 5 drift check will fail if the shim's Go surface is touched

**What goes wrong:** Step 5 hard-fails when `binding.go`, `plugin.go`, or `go.mod` differ from the forest module cache `[VERIFIED: forest-shim/refresh.sh Step 5]`. `REFRESH_ALLOW_DRIFT` downgrades it to a warning.

**How to avoid:** Never edit those three files. `cics.scm` reaches the shim through Step 3's `queries/*.scm` loop, which needs no Go-surface change `[VERIFIED: forest-shim/refresh.sh Step 3]`. If Step 5 fails, something went wrong — do not reach for `REFRESH_ALLOW_DRIFT` reflexively.

Also note Step 3's `rm -f` before `cp`: files arriving from forest's module-cache drop-in are 0444 and a plain `cp` over them fails. This is already handled; do not "simplify" it.

### Pitfall 5: The `comment` fixture is a standing failure

`tree-sitter test` must be invoked as `node_modules/.bin/tree-sitter test -e '^comment$'` `[VERIFIED: .github/workflows/fork-checks.yml]`. A bare `tree-sitter test` reports a pre-existing upstream failure (12/13) unrelated to this phase. Verification steps must use the exclusion or they will read as red.

### Pitfall 6: Commit separability (FORK-03 / CICS-06)

Phase 2's own verification found the criterion's wording had to be scoped carefully because a grammar-extension commit legitimately touched `grammar.js`, `test/corpus/` and `forest-shim/cobol/` while the plan's constraint named only `docs/` and `.planning/` `[VERIFIED: 02-06-SUMMARY.md:132-135]`. Phase 3's plan should state per-commit path constraints explicitly and separately for (a) the docs amendment commit, (b) the grammar commits, (c) the fork-local gate commits, (d) the cross-repo gortex commits.

### Pitfall 7: The gortex edits are a different repository

D-27 and D-28 edit `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go`. That is outside this working tree, outside FORK-03's scope, and its commits are not part of the separable grammar series. Plan them as their own tasks with their own commit convention.

---

## Runtime State Inventory

This is not a rename phase, but it has real out-of-tree state — the vendored shim and generated artifacts — that a file-only view misses.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **None.** No database, no cache, no persisted index in this pipeline. Verified by reading the full `refresh.sh` and the probe tests — everything is file-in/file-out. | none |
| Live service config | **None.** No running service. CI is `.github/workflows/fork-checks.yml`, which is in-tree and versioned `[VERIFIED: file read]` | none |
| OS-registered state | `.git/hooks/pre-push` and `.githooks/` — the estate-leak guard, not in the tracked hook path by default `[VERIFIED: .githooks/ directory exists at repo root]` | verify the hook is installed before the first commit touching corpus-adjacent paths |
| Secrets / env vars | **None required.** `refresh.sh` reads only `TOP_DIR`, `SHIM_DIR`, `TREE_SITTER`, `FOREST_CACHE`, `REFRESH_LOG`, `REFRESH_SKIP_INSTALL`, `REFRESH_SKIP_GENERATE`, `REFRESH_ALLOW_DRIFT` — all path/toggle, all defaulted `[VERIFIED: forest-shim/refresh.sh]` | none |
| Build artifacts | **Three tracked generated files** (`src/parser.c`, `src/grammar.json`, `src/node-types.json`) **plus five vendored copies** in `forest-shim/cobol/` (`parser.c`, `scanner.c`, `grammar.json`, `parser.h`, `idms.scm`/`sample.scm`/`_keep.scm`) `[VERIFIED: ls forest-shim/cobol]`. A `grammar.js` edit that is not followed by `tree-sitter generate` + `refresh.sh` leaves gortex measuring the **old** grammar and silently reporting a null result. | run `forest-shim/refresh.sh` after every grammar or query change, before every measurement; commit the regenerated `src/` |

**The D-26 reconstruction is a deliberate, controlled version of this hazard:** it checks out the pre-Phase-2 grammar, runs `refresh.sh`, and re-measures. The plan must ensure the tree is restored and re-refreshed afterwards, or every subsequent number in the phase is measured against a stale parser.

---

## Code Examples

### The verified keyword-extraction probe (D-18 evidence)

```
$ cat kw2.cbl
       IDENTIFICATION DIVISION.
       PROGRAM-ID. T.
       PROCEDURE DIVISION.
       0001-PARA.
           MOVE 'X' TO READ.
           MOVE 'X' TO WRITE.
           STOP RUN.

$ node_modules/.bin/tree-sitter parse kw2.cbl
(start
  (program_definition
    (identification_division (program_name))
    (procedure_division
      (paragraph_header)
      (move_statement src: (string) dst: (qualified_word (WORD)))
      (period)
      (move_statement src: (string) dst: (qualified_word (WORD)))
      (period)
      (stop_statement)
      (period))))
```

Zero ERROR nodes; both bare keywords lexed as `WORD`. `[VERIFIED: node_modules/.bin/tree-sitter parse, run this session]`

### The corpus fixture format (`test/corpus/*.txt`)

Verbatim from `test/corpus/idms_session.txt` `[VERIFIED: file read]`:

```
====================================
idms session bind run-unit
====================================
       identification division.
       program-id. a.
       procedure division.
       BIND RUN-UNIT.
---

(start
  (program_definition
    (identification_division
      (program_name))
    (procedure_division
      (idms_session_statement
        verb: (BIND)
        (RUN_UNIT))
      (period))))
```

Conventions: 36 `=` characters as the header rule, a lowercase hyphen-free test name, a minimal 3-line program shell, `---` separator, then the fully-parenthesised expected tree. Note Phase 2 shipped **four** per-cluster files (`idms_accept.txt`, `idms_navigation.txt`, `idms_session.txt`, `idms_update.txt`) `[VERIFIED: ls test/corpus/]` — D-32 specifies **one** `exec_cics.txt` for Phase 3, consistent with D-17's single-rule shape.

### The cascade gate edit site

The existing EXEC CICS case and the comment pre-sanctioning the edit `[VERIFIED: cascade_test.go]`:

```go
	lines := strings.SplitN(proc.String(), "\n", 3)
	injectedProc := lines[0] + "\n" + lines[1] + "\n           EXEC CICS SEND MAP('M') END-EXEC.\n" + lines[2]
	hurt := head + data.String() + mid + injectedProc + "           STOP RUN.\n"
	e2, d2, pa2, ce2 := countAll(t, hurt)
```

```go
	// Assertions are deliberately scoped to the IDMS cases only. The EXEC CICS
	// case is Phase 3's gate and SCHEMA SECTION belongs to preprocessing per
	// locked decision D3; hard-asserting either here would fail the build on a
	// known-open problem this phase does not fix.
```

The clean control is already asserted (`if d != 20 || pa != 20 { t.Fatalf(...) }`), so D-27's `pa2 == pa` / `d2 == d` assertions slot in beside the existing IDMS ones with no scaffolding change.

### The `paragraph_header` counter (CICS-04 axis)

```go
		switch n.Type() {
		case "data_description", "data_description_entry":
			data++
		case "paragraph_header":
			paras++
		}
```

`[VERIFIED: neutralize_test.go, countKinds-equivalent walk inside TestNeutralizedParseRate]` — an **exact string match** on `paragraph_header`. Contrast `probe_test.go`, which counts `k == "paragraph" || strings.HasSuffix(k, "_paragraph")` `[VERIFIED: probe_test.go]` — a different, much smaller number. D-16b's insistence on naming the file and counter verbatim is well-founded.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `neutralize()` regex-rewrites `EXEC (CICS\|SQL\|DLI)` blocks to `CONTINUE` before parsing | The grammar parses `EXEC CICS` natively; `neutralize()` becomes redundant for CICS | This phase | 16,732 is the **ceiling** Phase 3 climbs toward, not a moving target — `reExec` already neutralises CICS in the "+neutralize" column `[VERIFIED: neutralize_test.go reExec]` |
| Four verb-class nodes (Phase 2, D-01) | One generic command node (D-17) | This phase | Deliberate departure, justified by CICS's uniform `KEYWORD(arg)` syntax |
| Two-round minimal-then-census coverage (Phase 2, D-09) | All four argument forms modelled up front (D-29) | This phase | Expected `cics_unparsed_tail` near zero on first measurement |
| `queries/*.scm` believed to be read by gortex (D-04) | Confirmed **not** read — `e.getQuery("tags")` is the only kind requested | Discovered in the Phase 3 discussion (D-24) | The query is a published contract with no reader; CICS-02 is satisfied by a fork-local compile-and-capture test |

**Not deprecated but worth noting:** `tree-sitter-cli` 0.24.5 is pinned. `refresh.sh` Step 2 explicitly reports when regenerated `src/` differs from the committed output and calls that "a finding about which tree-sitter-cli patch produced the committed src/, not a failure" `[VERIFIED: forest-shim/refresh.sh Step 2]`. Expect that line; do not treat it as a Phase 3 regression without checking whether it predates the change.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Keyword extraction will also arbitrate correctly at the `END-EXEC`-vs-`cics_unparsed_tail` boundary, preferring the terminator | Pitfall 1 | The tail swallows the terminator and the cascade returns through the escape hatch. Mitigated by making it a planned fixture rather than an assumption. **This is now the phase's highest residual risk, replacing D-18.** |
| A2 | Introducing `EXEC` as a token will not degrade `EXEC SQL` / `EXEC DLI` parses below today's whole-block ERROR | Pitfall 2 | Phase 4 inherits a worse starting position; the estate differential may show reclassifications. Mitigated by an `EXEC SQL` regression fixture. DCC cannot detect this (zero `EXEC SQL`, D-14) |
| A3 | The CICS operand nodes will need `prec(1, …)` like their IDMS counterparts, and no `conflicts:` entry | Pattern 2 | If a `conflicts:` entry is required, it is the first in the grammar (`conflicts` length is currently 0) and warrants its own written justification |
| A4 | Multi-line `EXEC CICS` blocks (51 occurrences) parse without scanner changes because newlines/comments are `extras` | Don't Hand-Roll | If fixed-format continuation lines (column 7 indicator) appear inside a block, the scanner may need attention after all — a materially larger lift. D-28(d)'s fixture is the early signal |
| A5 | The volume counts quoted throughout CONTEXT.md (2,886 blocks, 1,251 `RETURN`, 1,586 `NOHANDLE`, 610 `MAPSET`, 33 `PROGRAM`, etc.) are accurate | Standard Stack, Pattern 1 comments | They were measured during the Phase 3 discussion against the estate; **not re-measured in this research session** and not independently reproducible from this repo (estate is excluded). If a count is wrong, an inline grammar comment is wrong — cosmetic, not structural |
| A6 | The pre-Phase-2 grammar is cleanly checkoutable for the D-26 reconstruction | Runtime State Inventory | If the commit boundary is ambiguous, the reconstructed baseline is not comparable and IDMS-05 stays unresolvable. Planner should identify the exact commit before committing to D-26's method |

---

## Open Questions

1. **Which commit is "pre-Phase-2 grammar" for D-26?**
   - What we know: Phase 2's commits are listed in `02-06-SUMMARY.md` (`d29af7a`, `1e4085a`, `4faa129`, `129e7c7`) and Phase 2 touched `grammar.js` in at least two waves.
   - What's unclear: the first Phase-2 `grammar.js` commit's parent — the actual reconstruction point.
   - Recommendation: make identifying and recording that SHA an explicit early task, before the reconstruction runs. It becomes a citable constant in `docs/baseline.md`.

2. **Does the estate contain fixed-format continuation lines inside `EXEC CICS` blocks?**
   - What we know: 51 blocks have nothing after `EXEC CICS` on the line (D-28d). The scanner enforces column 72 `[VERIFIED: src/scanner.c:135]`.
   - What's unclear: whether any block relies on a column-7 continuation indicator mid-block.
   - Recommendation: cheap to answer during the D-31 estate differential; if any appear, they will surface as `cics_unparsed_tail` or ERROR and be caught by D-30's census obligation.

3. **What `NODE_TYPE_REGEX` should the D-31 differential use for CICS?**
   - What we know: the default is `accept_statement|idms_accept_statement`; the argument exists for reuse.
   - What's unclear: D-31's collision surface is `READ`/`WRITE`/`DELETE`/`RETURN`, so the regex probably needs to cover `read_statement|write_statement|delete_statement|return_statement|exec_cics_statement` — a wider snapshot than Phase 2's.
   - Recommendation: planner sets this explicitly; a snapshot scoped to `accept_statement` would not detect the reclassification D-31 exists to catch.

4. **One commit or two for the gortex-side edits?** Left to discretion in CONTEXT.md; noted here only because the two edits (D-27 assertion, D-28 shapes) have different failure modes — D-28 can be landed and observed logging before D-27 turns it into a hard gate, which is the safer sequence.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `tree-sitter-cli` | generate / test / parse | ✓ | 0.24.5 | — |
| Go toolchain | `cobolprobe`, shim smoke build | ✓ | go1.27.1 darwin/arm64 | — |
| DCC corpus (`~/repos/mine/cobolCode/cam-corpus-dcc/DCC`) | CICS-04 recall, D-31 differential | ✓ | 606 `.cbl` / 958 `.cpy` | — |
| gortex repo (`~/repos/mine/GoApps/gortex`) | D-26, D-27, D-28, CICS-03, CICS-04 | ✓ | `cobolprobe/` present with all four test files | — |
| forest module cache (`go-sitter-forest/cobol@v1.9.1`) | `refresh.sh` Step 5 drift check | ✓ (implied — Phase 2's refresh ran green) | v1.9.1 | `REFRESH_ALLOW_DRIFT=1` downgrades to warning |
| `estate/` | D-31 estate-side differential | ✓ | 697 MB, git-excluded | — |
| `node-gyp` native build | `npm run build` only | ⚠ may fail on toolchain | — | `refresh.sh` explicitly does not gate on it; gates on `$TREE_SITTER` being executable instead `[VERIFIED: refresh.sh Step 1 comment]` |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `node-gyp` (already handled by `refresh.sh`'s design).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework (grammar) | `tree-sitter test` (tree-sitter-cli 0.24.5) |
| Framework (measurement) | Go `testing`, in the gortex repo |
| Config file | `package.json` (`"test": "tree-sitter test"`); fixtures in `test/corpus/*.txt` |
| Quick run command | `node_modules/.bin/tree-sitter test -e '^comment$'` |
| Full suite command | `node_modules/.bin/tree-sitter test -e '^comment$' && sh run_nist_cobol85.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CICS-01 | `EXEC CICS … END-EXEC` yields named nodes, no ERROR | unit (corpus) | `node_modules/.bin/tree-sitter test -e '^comment$'` | ❌ Wave 0 — `test/corpus/exec_cics.txt` |
| CICS-01 | D-18 keyword-extraction proof: `EXEC CICS READ/WRITE/DELETE/RETURN` **and** ordinary COBOL `READ`/`WRITE` in one file | unit (corpus) | same | ❌ Wave 0 — same file, dedicated case (D-32, plan first) |
| CICS-01 | `END-EXEC` vs `cics_unparsed_tail` boundary | unit (corpus) | same | ❌ Wave 0 — same file (Pitfall 1 / A1) |
| CICS-01 | `EXEC SQL` no-regression | unit (corpus) | same | ❌ Wave 0 — same file (Pitfall 2 / A2) |
| CICS-02 | Four named captures compile and fire against a fixture | unit (fork-local) | new fork-local test compiling `queries/cics.scm` | ❌ Wave 0 — new (D-24) |
| CICS-03 | Paragraph + data-item parity after `EXEC CICS`, four shapes | integration | `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v` | ✅ exists — edit per D-27/D-28 |
| CICS-04 | Grammar-alone `.cbl` `paragraph_header` >= 16,732 | integration (corpus) | `go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m -neut-corpus <DCC>` | ✅ exists (`neutralize_test.go`) |
| CICS-04 | Phase 1 `paragraph_header` baseline reconstruction | manual-then-recorded | checkout pre-Phase-2 → `forest-shim/refresh.sh` → same probe command | ✅ tooling exists; the sequence is new (D-26) |
| CICS-05 | NIST no new failures beyond 11 | integration | `sh run_nist_cobol85.sh` | ✅ exists |
| CICS-05/D-31 | Zero reclassifications, DCC + estate | integration | `./run_accept_differential.sh snapshot <DIR> <OUT> <REGEX>` then `compare <BEFORE> <AFTER>` | ✅ exists — needs a CICS-appropriate `NODE_TYPE_REGEX` (Open Q3) |
| CICS-06 | Commit separability | manual | `git show --stat` per commit against declared path constraints | manual-only — FORK-03 is a review property, not automatable here |

### Sampling Rate

- **Per task commit:** `node_modules/.bin/tree-sitter test -e '^comment$'` (seconds)
- **Per wave merge:** `tree-sitter test -e '^comment$'` + `forest-shim/refresh.sh` + `go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v`
- **Phase gate:** the above plus `sh run_nist_cobol85.sh`, the full `-neut-corpus` probe (20m timeout), and both differential runs (DCC + estate) green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/corpus/exec_cics.txt` — covers CICS-01, and carries the four mandatory early-signal cases (D-32 keyword proof, `END-EXEC` boundary, `EXEC SQL` no-regression, multi-line)
- [ ] `queries/cics.scm` + a fork-local query-compile/capture test — covers CICS-02
- [ ] `cascade_test.go` edits (D-27 assertions, D-28 four shapes) — covers CICS-03
- [ ] The exact `NODE_TYPE_REGEX` for the CICS differential — covers D-31
- [ ] The pre-Phase-2 commit SHA for D-26

No framework installation is needed — both frameworks are present and already running in CI.

---

## Security Domain

This phase produces a parser grammar, not a network- or user-facing service. Most ASVS categories are structurally inapplicable.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | **yes** | The grammar *is* the input validator. The relevant control is that malformed input degrades gracefully (a bounded `cics_unparsed_tail`) rather than producing unbounded backtracking or a pathological parse. `repeat()` over leaf tokens is linear |
| V6 Cryptography | no | — |
| V14 Configuration / supply chain | **yes** | `npm ci` against the committed lockfile, never `npm install` — already enforced by `refresh.sh` Step 1 and CI `[VERIFIED: forest-shim/refresh.sh; .github/workflows/fork-checks.yml]`. No new dependencies this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Proprietary estate source leaking into a public fork | Information Disclosure | `.git/info/exclude` for `estate/`; the pre-push estate-leak guard; `run_accept_differential.sh`'s explicit refusal to write an inventory under the repo root `[VERIFIED: run_accept_differential.sh header, "Estate guard (T-02-02)"]`; D-32's invented-neutral-names rule for every fixture |
| Site-specific naming baked into a generic-dialect grammar | (project constraint, not STRIDE) | CICS-06 / FORK-02; D-21 explicitly rejects hard-coding a 25-name corpus-derived option vocabulary |
| Pathological parse input causing unbounded work | Denial of Service | Bounded `repeat()` tail; no external-scanner loop added |

---

## Sources

### Primary (HIGH confidence)

- **This repository, read directly this session:** `grammar.js` (lines 10-32, 1366-1400, 2240-2400, 3004, 3121, 3357, 3381, 3485-3495), `src/grammar.json`, `src/parser.c` (62042, 899312-899313), `src/node-types.json`, `src/scanner.c`, `package.json`, `queries/idms.scm`, `test/corpus/idms_session.txt`, `test/corpus/` listing, `forest-shim/refresh.sh` (all 6 steps), `forest-shim/cobol/` listing, `run_accept_differential.sh` (header), `.github/workflows/fork-checks.yml`, `docs/baseline.md:155-175`, `.planning/config.json`
- **gortex repository, read directly this session:** `internal/parser/forest/cobolprobe/cascade_test.go` (full), `neutralize_test.go` (1-90), `probe_test.go` (40-70), `internal/parser/treesitter.go` (`runQuery`), `internal/parser/forest/extractor.go` (75-90)
- **Live tool execution:** `node_modules/.bin/tree-sitter parse` on two scratch fixtures (keyword-extraction probe), `tree-sitter --version`, `go version`, DCC corpus presence check
- **Planning artifacts:** `03-CONTEXT.md` (full), `.planning/REQUIREMENTS.md:100-160`, `.planning/ROADMAP.md` Phase 3, `02-PATTERNS.md`, `02-RESEARCH.md` (scanner findings), `02-06-SUMMARY.md`

### Secondary (MEDIUM confidence)

- CONTEXT.md's estate-derived volume counts (2,886 blocks; per-option and per-argument-form tallies). Measured during the Phase 3 discussion; taken as given here, not re-measured — see A5.
- CICS Application Programming Reference as syntax ground truth (D-32). Not consulted directly this session; the phase's syntax model is driven by CONTEXT.md's measured census rather than by the manual.

### Tertiary (LOW confidence)

- Reasoning about tree-sitter's keyword-extraction resolution *inside a `repeat()` body* (Pitfall 1 / A1) is mechanism-derived, not empirically tested — the rule does not exist yet. This is the one place a fixture must replace reasoning.

### Explicitly not consulted

No web search, no Context7, no package registry lookups. This phase adds no external dependency and every question that mattered was answerable from the repo, the sibling repo, or a live parse. `[VERIFIED: no external fetch performed this session]`

---

## Metadata

**Confidence breakdown:**

- Standard stack: **HIGH** — every tool verified present and versioned by direct execution; nothing new is introduced
- Architecture: **HIGH** — every pattern is a verbatim read of a working, committed Phase 2 artifact in this repo
- Pitfalls: **MEDIUM-HIGH** — Pitfalls 2-7 verified against file contents; Pitfall 1 is mechanism-derived from a verified regex and a verified generated-parser setting, but not yet empirically reproduced
- D-18 (the phase's named risk): **HIGH** — empirically confirmed by live parse; downgraded from CONTEXT.md's "highest-risk assumption"
- Volume counts: **MEDIUM** — inherited from the discussion, not re-measured (A5)

**Research date:** 2026-09-09
**Valid until:** 2026-10-09 (30 days — the stack is pinned and the repo is the source of truth; the only invalidating events are a `tree-sitter-cli` bump or a gortex-side `cobolprobe` refactor)
