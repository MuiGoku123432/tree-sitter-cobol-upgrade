# Requirements

Extracted from classified source documents. One entry per requirement.

---

## REQ-idms-dml-nodes
- source: docs/spec/SPEC-001-nodes-for-edges.md (§2, §5)
- description: Parse IDMS DML statements into named AST nodes such that the IDMS record name and set name in a DML verb are reachable as named nodes.
- acceptance: A tree-sitter query extracts IDMS record + set as named captures. `TestErrorCascade` in `cobolprobe` shows paragraphs and data items after the construct surviving at parity with a file that lacks it.
- scope: IDMS DML statements
- priority: FIRST — largest family by volume. 541 of 1,369 real programs (40%), 14,764 statements.
- verb mix (statement counts): BIND 4631, OBTAIN 2939, FIND 1792, READY 1444, ERASE 714, ACCEPT 634, GET 613, STORE 603, FINISH 550, MODIFY 384, CONNECT 200, ROLLBACK 144, COMMIT 61, DISCONNECT 53

## REQ-exec-cics-nodes
- source: docs/spec/SPEC-001-nodes-for-edges.md (§2, §5)
- description: Parse `EXEC CICS` blocks into named AST nodes such that the CICS transaction name, program name, and map name are reachable as named nodes.
- acceptance: A tree-sitter query extracts CICS transaction/program/map as named captures. Cascade eliminated per `TestErrorCascade`.
- scope: `EXEC CICS … END-EXEC` blocks
- priority: SECOND. 221 of 1,369 real programs (16%), 3,539 statements.

## REQ-exec-sql-nodes
- source: docs/spec/SPEC-001-nodes-for-edges.md (§2, §5)
- description: Parse `EXEC SQL` blocks into named AST nodes such that the DB2 table name is reachable as a named node.
- acceptance: A tree-sitter query extracts the DB2 table name as a named capture. Cascade eliminated per `TestErrorCascade`.
- scope: `EXEC SQL … END-EXEC` blocks
- priority: THIRD. 49 of 1,369 real programs (4%), 489 statements.
- open question: node granularity is NOT decided — see context.md OQ-2 (`sql-node-granularity`). Must be decided before this requirement is built.

## REQ-scope-ordering-by-volume
- source: docs/spec/SPEC-001-nodes-for-edges.md (§5)
- description: Implement the construct families in volume order — IDMS DML (541 programs / 14,764 statements) → EXEC CICS (221 / 3,539) → EXEC SQL (49 / 489). EXEC DLI is excluded entirely (0 / 0, per locked decision D4).
- acceptance: Phase sequencing follows this ordering.
- scope: delivery sequencing
- note: The SPEC explicitly flags that this is the REVERSE of the intuitive "EXEC CICS/SQL/DLI" framing. The ordering is derived from measured volume, not from familiarity.

## REQ-accept-disambiguation
- source: docs/spec/SPEC-001-nodes-for-edges.md (§5 grammar design note, §6 criterion 5)
- description: The grammar must disambiguate the `ACCEPT` verb on the operand tail, never on the verb alone. `ACCEPT` is both a standard COBOL verb and an IDMS DML verb.
- acceptance: Standard COBOL `ACCEPT` continues to parse correctly. Of 2,391 naive `ACCEPT` matches in the estate, only 634 are IDMS (`ACCEPT … FROM … CURRENCY`, `… DB-KEY`); 1,757 are standard COBOL and must be unaffected. The SPEC requires this be covered by a regression test.
- scope: `ACCEPT` verb, IDMS DML, standard COBOL
- note: The SPEC states explicitly — "treat this as a required regression test, not an edge case." An over-eager `ACCEPT` rule will silently break ordinary COBOL.

## REQ-cascade-elimination
- source: docs/spec/SPEC-001-nodes-for-edges.md (§4, §6 criterion 1)
- description: For each construct family, eliminate the parse-error cascade in which a single error propagates to the end of its division.
- acceptance: `TestErrorCascade` in `cobolprobe` shows paragraphs and data items after the construct surviving at parity with a file that lacks it.
- scope: error recovery, all in-scope construct families
- measured baseline: one `EXEC CICS` → 1 of 20 following paragraphs survive; one IDMS `SCHEMA SECTION` → 0 of 20 data items survive; a 5,352-line program yields only 4 ERROR nodes but just 5 of its 77 paragraphs.

## REQ-recall-improvement
- source: docs/spec/SPEC-001-nodes-for-edges.md (§4, §6 criterion 3)
- description: `.cbl` data-item recall in `cobolprobe` must rise measurably from the 27% neutralized baseline, measured on the same corpus with the same method.
- acceptance: Measurable rise above 27% for `.cbl`. Baseline: `.cbl` (606 files) 121,457 fields in source — grammar alone 17,905 (15%), + `neutralize()` 32,360 (27%). `.cpy` (958 files) 24,478 fields — grammar alone 0 (0%), + `neutralize()` 22,800 (93%).
- scope: cobolprobe recall measurement
- open question: no concrete numeric target is set — see context.md OQ-3 (`recall-target`).

## REQ-local-vendoring-path
- source: docs/spec/SPEC-001-nodes-for-edges.md (§8)
- description: Build a local vendoring path so grammar changes can be tested end-to-end in gortex BEFORE any upstream PR lands. A small Go module wrapping this fork's generated `parser.c`, wired into gortex via a `go.mod` `replace` directive, mirroring the `go-sitter-forest/cobol` package layout (`binding.go`, `parser.c`, `parser.h`, `scanner.c`, `grammar.json`).
- acceptance: gortex can consume this fork's grammar locally without waiting on upstream merge + forest regeneration.
- scope: integration, gortex consumption, go-sitter-forest/cobol
- note: The SPEC flags this as needing its own phase — "Plan this explicitly. Discovering it at integration time would strand finished grammar work behind an untested delivery mechanism." gortex today consumes `github.com/alexaandru/go-sitter-forest/cobol v1.9.1`, which vendors upstream `e99dbdc3`; changes here cannot reach gortex through that dependency until merged upstream and regenerated — "months, or never."

## REQ-upstreamable-delivery
- source: docs/spec/SPEC-001-nodes-for-edges.md (§6 criterion 6, §7)
- description: Each construct family's change must ship as a self-contained commit on a topic branch, rebased on `upstream/main`, with corpus tests, containing no site-specific naming.
- acceptance: Topic branch cut from `upstream/main`; rebased not merged; corpus tests included; no site-specific naming; no `.planning/` or `docs/spec/` content in the branch.
- scope: delivery mechanics, fork hygiene
