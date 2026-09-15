# Context

Running notes keyed by topic, with source attribution. Includes explicitly
undecided open questions — these are NOT decisions and must not be treated as such.

---

## Topic: what this repo is
- source: docs/spec/SPEC-001-nodes-for-edges.md (§1)
- `MuiGoku123432/tree-sitter-cobol-upgrade` — a fork of `yutaro-sakamoto/tree-sitter-cobol` (MIT), created to extend the COBOL grammar with constructs a real mainframe estate contains and upstream does not parse.
- The fork sits at 0 ahead / 0 behind upstream. The revision gortex consumes today (`e99dbdc3`) IS upstream HEAD, so there is no version-bump win available. This is net-new grammar development.
- `grammar.js` is 3,783 lines and contains zero occurrences of `EXEC`, `CICS`, `SQL`, or `DLI`. Embedded-language support is greenfield.
- Consumer: `gortex` (Gortex Mainframe Engine).
- SPEC status line: "Accepted, not started". Dated 2026-08-28.

## Topic: the goal — parse vs. legible
- source: docs/spec/SPEC-001-nodes-for-edges.md (§2)
- The defining distinction, quoted: "Making these constructs **parse** is already solved, in preprocessing. Making them **legible** is not."
- gortex's `neutralize()` (currently a prototype in `cobolprobe/neutralize_test.go`) rewrites `EXEC …END-EXEC` blocks and IDMS DML statements to `CONTINUE`, preserving line count. That restores the surrounding parse and lifts data-item recall — but it destroys the statement content, which is exactly what the graph needs.
- The success condition is NOT "no ERROR nodes". It is that a CICS transaction/program/map name, a DB2 table name in an `EXEC SQL` statement, and an IDMS record name and set name in a DML verb are each reachable as named nodes.
- Those become `program → transaction`, `program → table`, `program → record/set` edges. Without them the digital twin has no data-access layer.

## Topic: the four-stage pipeline this connects to
- source: docs/spec/SPEC-001-nodes-for-edges.md (§3)
- retrieve — the retrieval repo: Endevor / FTP / TN3270 extraction from the mainframe.
- census + consolidate — the consolidation repo: `census.py`, `classify.py`, `consolidate.py` → builds the consolidated estate tree.
- decode + preprocess — the preprocessing repo: `internal/decode` (RDW, EBCDIC, reflow), `internal/normalize`; NEW preprocessing stage for `-INC` and IDMS structural constructs.
- index → graph — `gortex`: vendors this grammar, builds the knowledge graph.
- This repo supplies the parser for the COBOL leg.

## Topic: the corpus
- source: docs/spec/SPEC-001-nodes-for-edges.md (§3)
- the consolidated estate tree — 52,233 files.
- Of 3,781 COBOL members, 1,369 are compilable programs (have both `IDENTIFICATION DIVISION` and `PROCEDURE DIVISION`); the remainder are macro source and fragments.
- All §5 volume counts are measured over these 1,369 real programs.

## Topic: measured recall baseline
- source: docs/spec/SPEC-001-nodes-for-edges.md (§4), quoting `gortex/internal/parser/forest/cobolprobe/README.md`
- Measured on 1,564 files of the pilot corpus. Recall is against level-number lines counted directly from the code area.
- `.cbl` (606 files): 121,457 fields in source — grammar alone 17,905 (15%), + `neutralize()` 32,360 (27%).
- `.cpy` (958 files): 24,478 fields in source — grammar alone 0 (0%), + `neutralize()` 22,800 (93%).

## Topic: error cascade is the root cause
- source: docs/spec/SPEC-001-nodes-for-edges.md (§4)
- "The reason programs sit at 27% is error cascade, not error count." A parse error does not recover locally — it propagates to the end of its division.
- One `EXEC CICS` → 1 of 20 following paragraphs survive.
- One IDMS `SCHEMA SECTION` → 0 of 20 data items survive.
- A 5,352-line program yields only 4 ERROR nodes but just 5 of its 77 paragraphs.
- `TestErrorCascade` pins this behaviour. Each construct family removed unlocks a whole division, not one statement.

## Topic: integration gap with go-sitter-forest
- source: docs/spec/SPEC-001-nodes-for-edges.md (§3, §8)
- gortex consumes `github.com/alexaandru/go-sitter-forest/cobol v1.9.1`, which is generated from upstream and vendors `e99dbdc3`.
- Changes made in this fork cannot reach gortex through that dependency until merged upstream and the forest regenerates — "That could be months, or never."
- §8 is analysis, not measurement — the vendoring path has not been prototyped.
- Captured as REQ-local-vendoring-path in requirements.md.

## Topic: repo state verified at ingest time (2026-08-28)
- source: orchestrator verification against the working repo
- upstream remote is `yutaro-sakamoto/tree-sitter-cobol`; `origin/main` and `upstream/main` are both at `e99dbdc`, 0 ahead / 0 behind (upstream fetched 2026-08-28 13:14).
- The local `main` branch is 1 commit ahead of `upstream/main` due to the `.planning/codebase` map commit (`8a17d90`) — this is precisely the fork-hygiene constraint from §7 in action.
- upstream carries a branch `remotes/upstream/dependabot/npm_and_yarn/tree-sitter-cli-0.25.3`, directly relevant to OQ-2 below.
- 13 corpus test files exist under `test/corpus/`.

---

## OPEN QUESTIONS — explicitly NOT decided
- source: docs/spec/SPEC-001-nodes-for-edges.md (§10)

These are recorded as open. They must not be converted into decisions during
downstream planning without an explicit resolution step.

### OQ-1: Node granularity for EXEC SQL
- Full SQL grammar, or capture the statement body as an opaque token plus extracted table names?
- Full SQL is a large surface for 489 statements.
- SPEC position: "Leaning opaque-plus-extraction — needs a decision before Phase 3."
- Blocks: REQ-exec-sql-nodes.

### OQ-2: Does the CLI bump (0.24.5 → 0.25.x) break upstream's existing corpus tests?
- Unmeasured. SPEC: "Establish before building on it."
- Relevant signal found at ingest: upstream has a branch `remotes/upstream/dependabot/npm_and_yarn/tree-sitter-cli-0.25.3`, which may already carry evidence.
- Relates to: the Toolchain / ABI constraint (gortex runs `go-tree-sitter v0.25.0`).

### OQ-3: Concrete recall target
- §6 criterion 3 says only "rises measurably". A concrete number should be set once IDMS DML lands and the real slope is visible.
- Relates to: REQ-recall-improvement.

### OQ-4: Upstream appetite
- Has `@yutaro-sakamoto` expressed a position on dialect support?
- SPEC: "Worth an issue before investing in PR-shaped work."
- Relates to: the Upstreamability constraint and REQ-upstreamable-delivery.

---

## Topic: provenance of the SPEC's own numbers
- source: docs/spec/SPEC-001-nodes-for-edges.md (Provenance section)
- §5 counts were measured 2026-08-27/28 over the 1,369 real programs in a working copy of the consolidated estate tree (`-INC` already rewritten), by verb-matching in the code area (cols 8-72) on non-comment lines. The `ACCEPT` split was measured separately by operand tail.
- The `-INC` figures in §5 were measured against the earlier `cam-consolidated` tree (1,361 real programs) and are ±8 programs against the newer count; the percentages are unaffected.
- §4 figures are quoted from `gortex/internal/parser/forest/cobolprobe/README.md` and were not re-measured.
- §8 is analysis, not measurement.
