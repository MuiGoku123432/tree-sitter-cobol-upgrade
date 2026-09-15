# SPEC-001 — COBOL grammar: nodes for edges

**Status:** Accepted, not started
**Date:** 2026-08-28
**Repo:** `MuiGoku123432/tree-sitter-cobol-upgrade` — fork of `yutaro-sakamoto/tree-sitter-cobol` (MIT)
**Consumer:** `gortex` (Gortex Mainframe Engine)

---

## 1. What this repo is

A fork of `yutaro-sakamoto/tree-sitter-cobol`, created to extend the COBOL grammar
with constructs a real mainframe estate contains and upstream does not parse.

It is **not** a rewrite and **not** a vendor drop. Changes must stay rebasable onto
upstream and offerable as clean PRs — the grammar is MIT and the additions are
generic COBOL dialect support, not site-specific hacks.

The fork sits at **0 ahead / 0 behind** upstream. The revision gortex consumes
today (`e99dbdc3`) **is** upstream HEAD, so there is no version-bump win available.
This is net-new grammar development.

`grammar.js` is 3,783 lines and contains **zero** occurrences of `EXEC`, `CICS`,
`SQL`, or `DLI`. Embedded-language support is greenfield.

---

## 2. The goal

Make the estate's non-standard construct families parse into **first-class,
walkable AST nodes with accurate positions**, so the consumer can emit graph edges
from them.

The distinction that defines this work:

> Making these constructs **parse** is already solved, in preprocessing.
> Making them **legible** is not.

gortex's `neutralize()` (currently a prototype in `cobolprobe/neutralize_test.go`)
rewrites `EXEC …END-EXEC` blocks and IDMS DML statements to `CONTINUE`, preserving
line count. That restores the surrounding parse and lifts data-item recall — but it
**destroys the statement content**, which is exactly what the graph needs.

So the success condition is *not* "no ERROR nodes". It is:

- a CICS transaction / program / map name is reachable as a named node
- a DB2 table name in an `EXEC SQL` statement is reachable as a named node
- an IDMS record name and set name in a DML verb are reachable as named nodes

Those become `program → transaction`, `program → table`, `program → record/set`
edges. Without them the digital twin has no data-access layer.

---

## 3. What this connects to

This repo supplies the **parser for the COBOL leg** of a four-stage pipeline:

| stage | repo | responsibility |
|---|---|---|
| retrieve | the retrieval repo | Endevor / FTP / TN3270 extraction from the mainframe |
| census + consolidate | the consolidation repo | `census.py`, `classify.py`, `consolidate.py` → builds the consolidated estate tree |
| decode + preprocess | the preprocessing repo | `internal/decode` (RDW, EBCDIC, reflow), `internal/normalize`; **new** preprocessing stage for `-INC` and IDMS structural constructs |
| index → graph | `gortex` | vendors this grammar, builds the knowledge graph |

**Corpus:** the consolidated estate tree — 52,233 files. Of 3,781 COBOL
members, **1,369 are compilable programs** (have both `IDENTIFICATION DIVISION` and
`PROCEDURE DIVISION`); the remainder are macro source and fragments.

**Local working copy:** a full copy lives at `estate/` in this repo — same 52,233
files, verified byte-identical by sha256 spot-check. Work against it, not against the
canonical tree, so preprocessing experiments never mutate the source of truth.

> ⚠ **`estate/` is proprietary production source and this fork is PUBLIC on GitHub.**
> It is excluded via `.git/info/exclude` (not `.gitignore`, so the upstream PR diff
> stays at zero). Never `git add -f` it, never relocate it inside a tracked path, and
> never quote estate source verbatim into a commit message, issue, or upstream PR.
> Grammar test fixtures must be minimal, hand-written constructs — not estate excerpts.

**How gortex consumes the grammar today:** `github.com/alexaandru/go-sitter-forest/cobol v1.9.1`,
which vendors upstream `e99dbdc3`. See §8 — this is a real integration blocker.

---

## 4. Why — the measured baseline

From `gortex/internal/parser/forest/cobolprobe/`, measured on 1,564 files of the pilot
pilot corpus. Recall is against level-number lines counted directly from the code area:

| | fields in source | grammar alone | + `neutralize()` |
|---|---|---|---|
| `.cbl` (606 files) | 121,457 | 17,905 (15%) | 32,360 (**27%**) |
| `.cpy` (958 files) | 24,478 | 0 (0%) | 22,800 (**93%**) |

**The reason programs sit at 27% is error cascade, not error count.** A parse error
does not recover locally — it propagates to the end of its division:

- one `EXEC CICS` → **1 of 20** following paragraphs survive
- one IDMS `SCHEMA SECTION` → **0 of 20** data items survive
- a 5,352-line program yields only 4 ERROR nodes but just **5 of its 77** paragraphs

`TestErrorCascade` pins this behaviour. Fixing the cascade is therefore high-leverage:
each construct family removed unlocks a whole division, not one statement.

---

## 5. Scope

### In scope — measured over the 1,369 real programs

| family | programs | statements | note |
|---|---|---|---|
| **IDMS DML** | 541 (40%) | 14,764 | largest by far — do this first |
| **`EXEC CICS`** | 221 (16%) | 3,539 | |
| **`EXEC SQL`** | 49 (4%) | 489 | |
| **`EXEC DLI`** | **0** | **0** | **absent from this estate — defer, do not build** |

IDMS DML verb mix (statement counts):

```
BIND 4631   OBTAIN 2939   FIND 1792   READY 1444   ERASE 714
ACCEPT 634  GET 613       STORE 603   FINISH 550   MODIFY 384
CONNECT 200 ROLLBACK 144  COMMIT 61   DISCONNECT 53
```

> **Grammar design note — `ACCEPT` is ambiguous.** It is both a standard COBOL verb
> and an IDMS DML verb. Naive verb matching counts 2,391 `ACCEPT`s, but only **634**
> are IDMS (`ACCEPT … FROM … CURRENCY`, `… DB-KEY`); **1,757 are standard COBOL**.
> The grammar must disambiguate on the operand tail, never on the verb alone.
> An over-eager `ACCEPT` rule will silently break ordinary COBOL — treat this as a
> required regression test, not an edge case.

Ordering follows the volume: **IDMS DML → EXEC CICS → EXEC SQL.** Note this is the
reverse of the intuitive "EXEC CICS/SQL/DLI" framing.

### Out of scope — handled by preprocessing in the preprocessing repo

| construct | volume | why not here |
|---|---|---|
| Endevor `-INC <MEMBER>` | 837 of 1,361 programs (61%) | not COBOL at all; a site include directive. Rewrite `-INC NAME` → `       COPY NAME.`, padded to col 72 with the sequence area (cols 73-80) preserved. 12,819 statements across 1,639 files; 2 unmatched. |
| `IDMS-CONTROL SECTION`, `PROTOCOL.`, `SCHEMA SECTION`, `DB x WITHIN y` | structural | the real IDMS precompiler **comments these out** — see §9 D3. A preprocessor should do the same. |

Also out of scope: the `site-macro`/`%`-macro site preprocessor language, and anything
site-specific that would make a PR unupstreamable.

---

## 6. Acceptance criteria

A family is done when **all** of these hold:

1. **Cascade gone** — `TestErrorCascade` in `cobolprobe` shows paragraphs and data
   items after the construct surviving at parity with a file that lacks it.
2. **Nodes named** — a tree-sitter query extracts the identifying operand
   (CICS transaction/program/map, DB2 table, IDMS record + set) as a named capture.
3. **Recall moves** — `.cbl` recall in `cobolprobe` rises measurably from the 27%
   neutralized baseline, measured on the same corpus with the same method.
4. **No regressions** — `tree-sitter test` (corpus fixtures) passes, and the NIST
   COBOL-85 suite via `run_nist_cobol85.sh` gains no failures beyond the 11 already
   listed in `skip_tests.txt`.
5. **Standard COBOL unharmed** — specifically, the `ACCEPT` ambiguity above.
6. **Upstreamable** — the change is a self-contained commit on a topic branch,
   rebased on `upstream/main`, with corpus tests, containing no site-specific naming.

---

## 7. Constraints

- **Upstreamability is a hard constraint.** Rebase, don't merge. `git rev-list --left-right --count upstream/main...origin/main` is only as truthful as the last `git fetch upstream` — it once read "0 behind" while 1,304 commits behind, in a sibling fork.
- **Fork hygiene vs. planning artifacts.** `.planning/` and `docs/spec/` are fork-local and must never appear in an upstream PR. Keep grammar changes on topic branches cut from `upstream/main`; planning lives on `main` only.
- **Toolchain / ABI.** The grammar builds with `tree-sitter-cli ^0.24.5` (a devDependency — `npm install`, no global install needed). gortex runs `go-tree-sitter v0.25.0`. A CLI bump may be required to regenerate a compatible `parser.c`, and that edits upstream's own build config — verify before assuming.
- **License.** Upstream is MIT. Keep it.
- **Regression net already exists** — `test/corpus/*.txt`, `run_nist_cobol85.sh`, `skip_tests.txt` (11 known-failing), `test/check_tests.sh`. Build on it; don't invent a parallel harness.

---

## 8. Integration gap — needs its own phase

gortex consumes `go-sitter-forest/cobol`, which is **generated from upstream**.
Changes made here cannot reach gortex through that dependency until they are merged
upstream and the forest regenerates. That could be months, or never.

So end-to-end testing needs a local vendoring path *before* any PR lands: a small Go
module wrapping this fork's generated `parser.c`, wired into gortex via a `go.mod`
`replace` directive, mirroring the `go-sitter-forest/cobol` package layout
(`binding.go`, `parser.c`, `parser.h`, `scanner.c`, `grammar.json`).

**Plan this explicitly.** Discovering it at integration time would strand finished
grammar work behind an untested delivery mechanism.

---

## 9. Decisions already made — do not re-litigate

- **D1 — Target is nodes-for-edges, not cascade-removal.** Cascade removal alone is
  mostly achievable in preprocessing and yields no graph content. (§2)
- **D2 — Build on this grammar rather than adopting another parser.** Evaluated
  `cobol-rekt` (Che4z-based) against the estate: 61% success on non-IDMS programs but
  **1/74 on IDMS**, failing on ordinary DML tokens (`WITHIN`, `NEXT`, `CURRENT`, `ANY`,
  `DB-KEY`). Its own IDMS fixtures are toy-level. ProLeap, Koopa, and GnuCOBOL do not
  attempt DML at all and are JVM/C, breaking the single-binary constraint.
- **D3 — IDMS DML is a preprocessing problem *and* a grammar problem, and we do both.**
  On a real mainframe DML never reaches the COBOL compiler; the IDMS precompiler
  rewrites it first. Verified in the estate: the subschema punch
  (`the subschema punch`) comments out `*IDMS-CONTROL SECTION.`, `*SCHEMA SECTION.`,
  `*DB <SUBSCHEMA> WITHIN <SCHEMA>.`, and a program in the estate shows the statement form
  `MOVE <seq> TO DML-SEQUENCE / CALL 'IDMS' USING SUBSCHEMA-CTRL / IDBMSCOM (nn) / <operands>`.
  Preprocessing handles the *structural* constructs (§5); the grammar handles the
  *statements*, because only the grammar can preserve their operands as nodes.
- **D4 — `EXEC DLI` is out.** Zero occurrences in the estate.

---

## 10. Open questions

1. **Node granularity for `EXEC SQL`.** Full SQL grammar, or capture the statement
   body as an opaque token plus extracted table names? Full SQL is a large surface for
   489 statements. Leaning opaque-plus-extraction — needs a decision before Phase 3.
2. **Does the CLI bump (0.24.5 → 0.25.x) break upstream's existing corpus tests?**
   Unmeasured. Establish before building on it.
3. **Recall target.** §6 says "rises measurably" — a concrete number should be set
   once IDMS DML lands and we can see the real slope.
4. **Upstream appetite.** Has `@yutaro-sakamoto` expressed a position on dialect
   support? Worth an issue before investing in PR-shaped work.

---

## Provenance

Counts in §5 were measured on 2026-08-27/28 over the 1,369 real programs in a working
copy of the consolidated estate tree (`-INC` already rewritten), by verb-matching
in the code area (cols 8-72) on non-comment lines. The `ACCEPT` split was measured
separately by operand tail. The `-INC` figures in §5 were measured against the earlier
`cam-consolidated` tree (1,361 real programs) and are ±8 programs against the newer
count; the percentages are unaffected.

§4 figures are quoted from `gortex/internal/parser/forest/cobolprobe/README.md` and
were not re-measured here.

§8 is analysis, not measurement — the vendoring path has not been prototyped.
