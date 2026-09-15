# Decisions

Extracted from classified source documents. LOCKED decisions cannot be
auto-overridden by any source.

Note on provenance: these four decisions originate in a SPEC (`docs/spec/SPEC-001-nodes-for-edges.md`
§9), not an ADR. They are recorded as `locked` because the source section is titled
"Decisions already made — do not re-litigate" and carries ADR-shaped decision
statements with rationale.

---

## D1: Target is nodes-for-edges, not cascade-removal
- source: docs/spec/SPEC-001-nodes-for-edges.md (§9 D1, cross-ref §2)
- status: locked
- decision: The objective is first-class, walkable AST nodes with accurate positions for the estate's non-standard construct families — not merely the elimination of ERROR nodes.
- scope: project objective, grammar design target
- rationale: Cascade removal alone is mostly achievable in preprocessing and yields no graph content. The consumer needs statement operands preserved as nodes to emit `program → transaction`, `program → table`, and `program → record/set` edges. `neutralize()` already restores the surrounding parse by rewriting `EXEC …END-EXEC` and IDMS DML to `CONTINUE`, but it destroys the statement content.

## D2: Build on this grammar rather than adopting another parser
- source: docs/spec/SPEC-001-nodes-for-edges.md (§9 D2)
- status: locked
- decision: Extend the forked `yutaro-sakamoto/tree-sitter-cobol` grammar rather than adopting an alternative COBOL parser.
- scope: parser selection
- rationale: `cobol-rekt` (Che4z-based) was evaluated against the estate — 61% success on non-IDMS programs but 1/74 on IDMS, failing on ordinary DML tokens (`WITHIN`, `NEXT`, `CURRENT`, `ANY`, `DB-KEY`); its own IDMS fixtures are toy-level. ProLeap, Koopa, and GnuCOBOL do not attempt DML at all and are JVM/C, breaking the single-binary constraint.

## D3: IDMS DML is both a preprocessing problem and a grammar problem — do both
- source: docs/spec/SPEC-001-nodes-for-edges.md (§9 D3, cross-ref §5)
- status: locked
- decision: Preprocessing (in the preprocessing repo) handles the structural IDMS constructs; the grammar handles the DML statements.
- scope: division of responsibility between preprocessing stage and grammar
- rationale: On a real mainframe DML never reaches the COBOL compiler — the IDMS precompiler rewrites it first. Verified in the estate: the subschema punch comments out `*IDMS-CONTROL SECTION.`, `*SCHEMA SECTION.`, `*DB <SUBSCHEMA> WITHIN <SCHEMA>.`; and a program in the estate shows the statement form `MOVE <seq> TO DML-SEQUENCE / CALL 'IDMS' USING SUBSCHEMA-CTRL / IDBMSCOM (nn) / <operands>`. Only the grammar can preserve DML statement operands as nodes.

## D4: EXEC DLI is out of scope
- source: docs/spec/SPEC-001-nodes-for-edges.md (§9 D4, cross-ref §5)
- status: locked
- decision: Do not build `EXEC DLI` support. Defer.
- scope: construct family scope
- rationale: Zero occurrences of `EXEC DLI` in the estate (0 programs, 0 statements measured over 1,369 real programs).
