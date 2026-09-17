---
gsd_state_version: 1.0
milestone: v0.26.0
milestone_name: Estate Parse Recovery
status: planning
last_updated: "2026-09-17T17:52:57.047Z"
last_activity: 2026-09-17
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-17)

**Core value:** Raw estate COBOL becomes a source-mapped, measurable AST whose graph-relevant
identifiers remain accurate and whose degraded parses are routed for review rather than silently
trusted.
**Current focus:** Defining v0.26.0 Estate Parse Recovery requirements and roadmap

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-09-17 — Milestone v0.26.0 started

## Performance Metrics

**Velocity:**

- Total plans completed: 25
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 7 | - | - |
| 02 | 6 | - | - |
| 03 | 4 | - | - |
| 04 | 8 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 35min | 2 tasks | 12 files |
| Phase 01 P02 | 40min | 3 tasks | 4 files |
| Phase 01 P03 | 32min | 3 tasks | 2 files |
| Phase 01 P04 | 15min | 2 tasks | 1 files |
| Phase 01 P05 | 6min | 2 tasks | 1 files |
| Phase 01-delivery-pipe-measurement-baseline P06 | 35min | 3 tasks | 2 files |
| Phase 01 P07 | 55min | 3 tasks | 3 files |
| Phase 02 P01 | 38min | 3 tasks | 10 files |
| Phase 02 P02 | 18min | 2 tasks | 4 files |
| Phase 02 P03 | 874min | 3 tasks | 8 files |
| Phase 02 P04 | 1280min | 3 tasks | 8 files |
| Phase 04 P03 | 11min | 3 tasks | 2 files |
| Phase 04 P02 | 9h 38m | 3 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Locked at ingest:

- D1 — Target is nodes-for-edges, not cascade-removal (SPEC §9)
- D2 — Build on this grammar rather than adopting another parser (SPEC §9)
- D3 — IDMS DML is both a preprocessing problem and a grammar problem; do both (SPEC §9)
- D4 — `EXEC DLI` is out; zero occurrences in the estate (SPEC §9)
- D5 — The local vendoring path goes first, before any grammar work (this session, user-confirmed)
- [Phase 01]: 01-01: go.work is a one-file, reversible switch — deleting it reverts gortex to forest v1.9.1 (GOMODCACHE path); recreated after verification since later plans need the pipe on — Proven empirically: go list -m -f '{{.Dir}}' round-tripped between the fork's shim path and GOMODCACHE path as go.work was deleted and recreated
- [Phase 01]: 01-02: scratch-repo self-test's estate/ pollution fixture needed git add -f — The scratch repo's own .git/info/exclude deliberately mirrors this fork's live /estate/ posture, so a plain git add of an estate/ path is refused by git itself; -f is required to construct the deliberately-polluted test fixture, and does not touch this fork's real exclusion posture
- [Phase 01]: 01-03: npm ci's own top-level install script (unrelated native Node addon) can fail on a given toolchain even after successfully installing the lockfile-pinned tree-sitter-cli - refresh.sh gates Step 1 on $TREE_SITTER's actual presence, not npm ci's exit code — VEND-04 only depends on the tree-sitter-cli binary being the pinned version and being executable, not on this repo's unrelated node-gyp native-binding build succeeding
- [Phase 01]: 01-03: regenerating with the pinned tree-sitter-cli 0.24.5 does not reproduce the committed src/parser.c byte-for-byte (SYMBOL_COUNT/TOKEN_COUNT 1153/523 vs committed 1215/585, matching forest's cached copy instead) - a genuine finding, not a failure; committed src/ was left untouched and this is recorded for docs/vendoring.md (plan 04) — VEND-04's 'twice executed, reproducible' requirement is about the refresh script's own idempotence, not about matching the committed src/ byte-for-byte; the committed src/ is preserved via git checkout -- src/ and REFRESH_SKIP_GENERATE=1
- [Phase 01]: 01-04: tree-sitter-cli 0.24.5 to 0.25.3 bump is ruled out as the cause of the committed src/parser.c's SYMBOL_COUNT/TOKEN_COUNT divergence (both regenerate to 1153/523 identically); which CLI version produced the committed 1215/585 file remains unidentified — Both CLI versions measured agree with each other and with forest v1.9.1's cache; grammar.js and src/parser.c were last touched together in the same fork commit (c7a36d7), ruling out simple staleness - recorded in docs/vendoring.md as an open question rather than a guessed conclusion
- [Phase 01]: 01-05: cobolprobe recall re-measured through the local vendoring path came out numerically identical to the previously published forest v1.9.1 figures (17,905/32,360 .cbl, 0/22,800 .cpy) despite the recorded SYMBOL_COUNT/TOKEN_COUNT (1215/585 vs 1153/523) grammar-lineage difference — Recorded as observed, not reconciled, per the phase's transparency prohibition; this run's numbers are declared the baseline of record for Phases 2-4 regardless of the numeric agreement, since they were measured through this fork's own grammar lineage
- [Phase 01]: 01-06: hardened estate-guard self-test to assert WHICH check failed (CR-05), added 6 regression cases (CR-01/02a/02b/03/04/04b), recorded RED evidence transcript as 01-07's falsifiable target — Used require_check_fail alone (not paired with report_case) for new cases to keep FAIL-line count 1:1 per case, satisfying the exactly-6 acceptance gate
- [Phase 01]: Fixed CR-01/CR-02/CR-03/CR-04 in estate-guard.sh (per-commit walk, NUL-delimited enumeration, fail-closed error handling, remote-scoped new-branch bound) and wired the self-test into pre-push (WR-13); FORK-02 restored to complete. — 01-06's committed RED evidence proved the guard's self-test discriminates a broken guard from a working one; this plan is the GREEN half that fixes the guard itself without touching the self-test.
- [Phase 02]: 02-01: idms_unparsed_tail admits WORD/_LITERAL/punctuation only (no bare integer, already reachable via _LITERAL->number->integer) — avoids a second reduce/reduce path to the same terminal
- [Phase 02]: 02-01: static prec(1,...) on idms_record_name/idms_set_name resolved the FIND CURRENT WORD reduce/reduce conflict against idms_unparsed_tail with no conflicts: entry needed — plan's mandated resolution order (static prec before conflicts:/prec.dynamic)
- [Phase 02-02]: ACCEPT inventories use relative path plus start position and a clean or trailing_error qualifier; error-bearing trees remain inputs because they define intended IDMS conversions. — This makes zero-reclassification evidence satisfiable without hiding the roughly 634 expected prefix-plus-ERROR conversions.
- [Phase 02-02]: Commit separability classifies queries, test/idms, differential scripts, and only fork-checks.yml, with explicit per-commit and empty-input reports. — FORK-03 must detect every Phase 2 path without misclassifying upstream-owned workflows.
- [Phase 02-03]: BIND models both RUN-UNIT and optional record-name forms rather than assuming one estate shape. — The published IDMS syntax supports both and raw frequency counts do not distinguish them.
- [Phase 02-03]: Update and session classes reuse the exact 02-01 record, set, and unparsed-tail nodes; static prec.right generated without a conflicts entry. — One stable operand contract keeps deterministic queries and downstream graph extraction aligned.
- [Phase 02-04]: The DB-KEY trailing anchor was removed after an estate census found zero occurrences; CURRENCY is the single required anchor, optionally preceded by NEXT, PRIOR or OWNER. — The vendor manual and the estate agree: DB-KEY is a target identifier, not an anchor. Plan 02-04's own evidence clause authorised the change.
- [Phase 02-04]: The 634 acceptance figure was restated as 631 rather than pursued. — 634 derived from the same disproved DB-KEY split; hitting it would have meant tuning the grammar toward a number resting on a bad assumption.
- [Phase 02-04]: 12 qualifier-omitted reclassifications accepted against the literal zero-tolerance gate, recorded as a deviation. — CURRENCY is a reserved word and is declared as a mnemonic 0 times across 1,369 programs, so no valid standard reading exists; all 5 affected files carry all 7 independent IDMS markers.
- [Phase 02-04]: The ACCEPT collision resolved with static LALR — no conflicts entry, no prec.dynamic. — The grammar's structure is itself evidence of containment, not only the differential, and no GLR forking cost is paid on the 2,391 estate ACCEPT occurrences.
- [Phase 03-01]: D-18 keyword extraction CONFIRMED — `field('command', $.WORD)` arbitrates READ/WRITE/DELETE/RETURN inside `EXEC CICS` with no `conflicts:` entry; the explicit `choice()` fallback was NOT needed. — Proven by fixture (`test/corpus/exec_cics.txt`, D-32 proof case), not by argument: all four colliding words parse as `exec_cics_statement` while ordinary COBOL READ/WRITE still parse as `read_statement`/`write_statement`, zero ERROR nodes, `grammar.json` conflicts length 0.
- [Phase 03-01]: The estate has ZERO fixed-format continuation lines inside `EXEC CICS` blocks (0 across 3,726 blocks in 267 files, 2,837 of them multi-line). — Closes RESEARCH A4/OQ-2: `src/scanner.c` stays untouched and plan 03-02 needs no scope escalation. This was the phase's largest latent scope risk.
- [Phase 03-01]: Pre-Phase-2 grammar baseline SHA is `5a3a8679a12a0bf3fd970fce90f606a5a09dc042` (parent of 44ce5df). — RESEARCH A6's ambiguous-boundary warning discharged by proof rather than choice: the history-simplified alternative `c7a36d7` is byte-identical on `grammar.js`, and the baseline carries zero `idms_`/`exec_cics` rules. Citable constant for 03-04's D-26 reconstruction.
- [Phase 03-01]: D-31 differential `NODE_TYPE_REGEX` is `read_statement|write_statement|delete_statement|return_statement|exec_cics_statement`. — Phase 2's `accept_statement` default would inventory zero relevant records and report a green gate over an unmeasured surface. Pitfall 3 recorded: the clean/trailing_error qualifier rests on a same-row heuristic that 76% of blocks violate, so `RECLASSIFIED_COUNT` is the hard gate and the qualifier split is NOT evidence about multi-line blocks.

- [Phase 03-02]: RESEARCH Pitfall 1 / A1 SETTLED — END-EXEC is consumed as the terminator and is a SIBLING of cics_unparsed_tail, never inside it. — Keyword extraction arbitrates it; neither of the two pre-authorised remedies (token precedence on the terminator, tail vocabulary exclusion) was needed. This was the phase's highest residual risk.
- [Phase 03-02]: Subscripted data names modelled (54 of 7,971 args, 0.68%); comma arguments left open (4, 0.05%). — Opposite calls, both census-led: subscripts produced a MISSING ')' defect, while the comma ERROR is provably contained (3 of 3 paragraph_headers survive) and closing it needs a lexical precedence on `integer`, whose regex /[+-]?[0-9,]+/ wrongly matches a bare comma.
- [Phase 03-02]: EXEC SQL is NOT degraded but NOT byte-identical — the ERROR span and empty procedure_division are unchanged; recovery now matches EXEC and inserts a MISSING _CICS. — Load-bearing for Phase 4: the corpus of record has zero EXEC SQL, so the recall number structurally cannot detect a degradation there.
- [Phase 03-02]: HAZARD for any future baseline differential (incl. 03-04's D-31 run): the tree-sitter CLI caches compiled parsers by grammar NAME, not path. — Generating a second checkout's grammar silently repoints the shared parser; an initial EXEC SQL baseline comparison returned a false IDENTICAL for this reason. Generate-then-measure, per side, in that order. Also avoid node_modules/.bin/tree-sitter, which resolves the grammar through node_modules.
- [Phase 04]: 04-03: custom selection is active when either the node regex or text prefilter differs from its ACCEPT default
- [Phase 04]: 04-03: estate runs always retain 3781/1369 structural checks, while the 2391 statement gate applies only to default ACCEPT selection
- [Phase 04]: 04-03: --no-prefilter selects every source file admitted by the existing extension filter

### Pending Todos

None yet.

### Blockers/Concerns

**Open questions carried into execution** — these are open, not decided:

- **OQ-1** — `EXEC SQL` node granularity (full SQL grammar vs. opaque body plus table-name
  extraction). Gates Phase 4; it is that phase's own criterion 1. The SPEC leans
  opaque-plus-extraction but does not decide — do not treat the lean as the decision.

- **OQ-2** — Does the tree-sitter-cli 0.24.5 → 0.25.x bump break upstream's corpus tests?
  Unmeasured. Answered as a spike inside Phase 1 (criterion 3). Upstream carries
  `dependabot/npm_and_yarn/tree-sitter-cli-0.25.3`, which may already hold evidence. Matters
  because gortex runs `go-tree-sitter v0.25.0`.

- **OQ-3** — Concrete `.cbl` recall target. **RESOLVED 2026-09-04, RE-SCOPED 2026-09-09.** Rule
  (decided 2026-08-29): a gap-closure fraction on the **grammar-alone** axis. Value: **Phase 3
  closes 100% of the measured 1,409-item `paragraph_header` gap — grammar-alone `.cbl`
  `paragraph_header` >= 16,732**, the counter in `cobolprobe/neutralize_test.go` (named verbatim
  to disambiguate it from the different, much smaller counter in `probe_test.go`).
  *The prior `dataItems >= 18,772` value was withdrawn 2026-09-09 per Phase 3 D-16a: 0 of the 169
  `.cbl` containing `EXEC CICS` have the construct before `PROCEDURE DIVISION`, and the cascade
  harness measures `EXEC CICS` costing 19 of 20 paragraphs while costing 0 data items — a phase
  that fixes CICS cannot move a DATA DIVISION metric.* Phase 2's own
  measured share on the old axis was **0**: the DATA DIVISION is gated at `SCHEMA SECTION` in 53%
  of the corpus, which locked decision D3 assigns to preprocessing. The terminal condition
  grammar-alone >= neutralized on `dataItems` is the programme-level end state, not Phase 3's
  gate; on the `paragraph_header` axis, >= 16,732 IS the terminal condition (D-16d). The old bar ("rises measurably
  from the 27% neutralized baseline") is retired: `neutralize()` already rewrites IDMS DML
  (gortex `cobolprobe/neutralize_test.go:24`), so 26.6% is a ceiling, not a bar. Phase 4's recall
  gate is retired outright — DCC contains zero `EXEC SQL`. See `docs/baseline.md` §4 and
  `.planning/phases/02-idms-dml-statement-nodes/02-CONTEXT.md` D-13, D-14, D-15.

- **OQ-4** — Upstream appetite for dialect support. Worth an issue to `@yutaro-sakamoto` before
  investing in PR-shaped work. Tracked as v2 UPS-01; cheap, may be done opportunistically at any
  time.

**Standing hazards:**

- **Proprietary estate in a public fork.** `estate/` is 697M of proprietary production source and this
  fork is public on GitHub. Excluded via `.git/info/exclude` (deliberately not `.gitignore`, so the
  upstream PR diff stays at zero). Never `git add -f` it, never relocate it inside a tracked path,
  never quote estate source verbatim into a commit message, issue, or PR. Grammar test fixtures
  must be minimal, hand-written constructs — the estate is a measurement input, never a fixture
  source. Guarded by FORK-02 in Phase 1.

- **Fork hygiene.** Local `main` is currently 1 commit ahead of `upstream/main` solely because of
  the `.planning/codebase` map commit (`8a17d90`). Planning lives on `main` only; grammar work goes
  on topic branches cut from `upstream/main`. Guarded by FORK-01 in Phase 1.

- **The `ACCEPT` ambiguity is a regression gate, not an edge case.** **631** IDMS `ACCEPT`s (not
  634 — see below) out of 2,391 statement-start `ACCEPT`s. Disambiguate on the operand tail, never
  on the verb alone. An over-eager rule silently breaks ordinary COBOL. Contained in 02-04 by a
  required `CURRENCY` anchor, resolved statically by the generator with no `conflicts:` entry.

- **The 634 figure and the `DB-KEY` anchor were disproved in 02-04 — do not reuse them.** An estate
  census over all 2,391 statement-start `ACCEPT`s found **zero** forms anchored on a trailing
  `DB-KEY`; it appears only as a target identifier. Every IDMS form ends in `CURRENCY`, optionally
  preceded by a `NEXT`, `PRIOR` or `OWNER` relative selector. The reproducible count is **631**.
  SPEC-001 §5 and `docs/baseline.md` still quote 634 and have not been amended.

- **Estate ACCEPT coverage is rule coverage, not realised coverage.** 02-04 proved 631/631
  documented forms are recognised *when reachable*, via an isolated statement census. The full-file
  estate run recognises only **141**, because 792 of 836 files carry upstream parse errors from
  unrelated constructs. Do not quote 631 as realised estate conversions. Raising full-file reach is
  a separate concern and is not an ACCEPT problem.

- **NIST threshold is 11, not 12.** `skip_tests.txt` holds 11 non-empty entries (NC205A, SM101A,
  SM103A, SM105A, SM107A, SM201A, SM203A, SM205A, SM206A, SM208A, SM401M). The SPEC originally said
  12; that was verified wrong and corrected. Inheriting 12 would silently permit one new
  regression. Do not reintroduce 12.

- **Stale-ref trap.** `git rev-list --left-right --count upstream/main...origin/main` is only as
  truthful as the last `git fetch upstream`. It once read "0 behind" while 1,304 commits behind, in
  a sibling fork. Always re-fetch before trusting a count.

- 01-03: node_modules/.bin/tree-sitter test reports 1 pre-existing failure (comment fixture, 12/13 pass) unrelated to VEND-04 - reproduces against the committed src/parser.c untouched, fixture last edited in upstream commit 4bc6ff5, CI has this step commented out. Out of scope for Phase 1 (no grammar changes, D-13). Recorded in .planning/WINDOWS.md as an open deviation.

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Scope | `EXEC DLI` support | Locked out (D4) — zero occurrences | 2026-08-28 ingest | v1 |
| Upstream | PR acceptance + forest regeneration (UPS-02) | Outside our control | 2026-08-28 ingest | v1 |
| Scope | Full SQL grammar for `EXEC SQL` bodies (SQLX-01) | Contingent on OQ-1 | 2026-08-28 ingest | v1 |

## Session Continuity

Last session: 2026-09-14T12:59:47.669Z
Stopped at: Completed 04-02-PLAN.md
Resume file: None
Next: Execute 02-05-PLAN.md
