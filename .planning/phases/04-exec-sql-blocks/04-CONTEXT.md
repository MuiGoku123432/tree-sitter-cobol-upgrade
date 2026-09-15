# Phase 4: EXEC SQL Blocks - Context

**Gathered:** 2026-09-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Teach `grammar.js` both data-division and procedure-division forms of
`EXEC SQL ... END-EXEC` so each block is a walkable named AST node, static DB2
table references are queryable with accurate spans, and unsupported SQL remains
contained rather than destroying the COBOL that follows.

**In scope:** a durable bounded extraction grammar; one generic executable SQL
statement shape; static table references and aliases; dynamic-source preservation
where clearly delimited; `BEGIN/END DECLARE SECTION` markers; `INCLUDE` directives;
query captures; cascade and differential gates; corpus and NIST regression tests.

**Out of scope:** a full DB2 SQL grammar (SQLX-01); named column, predicate,
expression, or host-variable nodes; resolving dynamic SQL to physical tables;
wiring gortex to consume `queries/*.scm`; a new recall corpus or recall target;
`EXEC DLI`; and any estate-derived fixture content.

</domain>

<decisions>
## Implementation Decisions

### SQL parsing depth

- **D-01:** Close OQ-1 and SQL-01 with a **bounded extraction grammar**, not a
  full embedded DB2 SQL grammar and not an opaque scanner-only body. The grammar
  must parse the outer block, identify the statement kind, expose named table
  references, and preserve unsupported content in a named tail. This is the
  smallest shape that satisfies nodes-for-edges without taking on SQLX-01.
  — **Reversibility:** costly — the emitted AST and `queries/sql.scm` become the
  published extraction contract; replacing them with a full grammar requires a
  coordinated query and consumer migration.
- **D-02:** Executable SQL uses one generic **`exec_sql_statement`** node with a
  statement-kind field, rather than per-verb or hybrid statement-family nodes.
  The phase needs one stable traversal shape across table-bearing and utility
  statements, not a partial SQL taxonomy.
- **D-03:** The durable Phase 4 AST contract guarantees only the block,
  statement kind, table references, table aliases, and a dynamic source where
  clearly delimited. Columns, predicates, expressions, and host variables remain
  in the unparsed tail. Full SQL is a separate capability only if a later
  consumer demonstrates the need.

### Table capture scope

- **D-04:** Capture **all static physical table references** in table-bearing
  DML and DDL: `SELECT ... FROM` and `JOIN` sources (including nested
  subqueries), `INSERT INTO`, `UPDATE`, `DELETE FROM`, `MERGE INTO`, and
  `CREATE`, `ALTER`, and `DROP TABLE`. Multiple references in one statement
  produce multiple captures; stopping at the first table is not acceptable.
- **D-05:** A qualified DB2 object such as `SCHEMA.TABLE` is one named
  **`sql_table_name`** node spanning the complete qualified name. Phase 4 does
  not split schema and table into separate nodes because the complete object
  identity is the graph-edge target.
  — **Reversibility:** costly — this node name and span are the query contract.
- **D-06:** SQL aliases are exposed as separate named **`sql_table_alias`**
  nodes. An alias must never be included in `sql_table_name`; the physical
  database object and its statement-local name remain distinct.
  — **Reversibility:** costly — consumers can depend on the separate alias
  capture and its relationship to the preceding table reference.
- **D-07:** CTE names and derived-table aliases are **not** physical-table
  captures. The grammar should traverse nested queries and capture their static
  base tables while leaving CTE names out of `@table`, preventing false
  program-to-table edges.
- **D-08:** Dynamic SQL must never label a host variable as a DB2 table. Preserve
  a clearly delimited statement source as **`sql_dynamic_source` where feasible**;
  otherwise retain it visibly in `sql_unparsed_tail`. No table edge is promised
  until a later analysis resolves the dynamic text.
- **D-18:** CTE exclusion uses **statement-scoped subtraction in the fork-local
  query gate**, not a stateful external scanner. The grammar emits structured CTE
  definitions and source candidates; verification subtracts source names matching
  CTE definitions within the same statement before asserting the physical `@table`
  set. Raw candidates are not themselves the physical-table contract. This keeps
  the parser bounded while satisfying D-07 without query predicates.
  — **Reversibility:** costly — changing to scanner-level name binding later would
  alter parser state, generated artifacts, and the verified query contract.

### Block placement and directives

- **D-09:** Support `EXEC SQL` in **both DATA DIVISION and PROCEDURE DIVISION**.
  Procedure-only support is insufficient because tracked OCESQL samples use
  `BEGIN/END DECLARE SECTION` and `INCLUDE SQLCA` before executable SQL.
- **D-10:** Data-division forms use distinct named directive nodes rather than
  overloading `exec_sql_statement`: **`exec_sql_declare_section`** for declaration
  markers and **`exec_sql_include`** for include directives. Executable SQL keeps
  the generic statement node.
  — **Reversibility:** costly — these names distinguish directive placement from
  executable SQL in the AST and query surface.
- **D-11:** `BEGIN DECLARE SECTION` and `END DECLARE SECTION` are separate marker
  nodes around normal COBOL data descriptions. They must not wrap or consume the
  intervening declarations; existing COBOL data-item nodes remain intact and
  queryable.
- **D-12:** `EXEC SQL INCLUDE <member> END-EXEC` exposes the generic include
  member as **`sql_include_name`**. Do not hard-code only `SQLCA` and `SQLDA`.
  — **Reversibility:** costly — the named include target is part of the directive
  query contract.

### Fallback and evidence

- **D-13:** Unsupported SQL content is absorbed by a named, terminator-bounded
  **`sql_unparsed_tail`**, never an anonymous token sink and never a deliberate
  ERROR. `END-EXEC` remains required and outside the tail so following
  paragraphs and data items cannot be swallowed.
- **D-14:** The tail acceptance rule is **no cascade plus explain every observed
  tail shape**. A hard zero-tail gate is rejected because it would pull the
  phase toward the deferred full SQL grammar. The phase records a categorized
  census, and no table-bearing form may lose a required `sql_table_name` capture
  merely because other clauses remain unparsed.
- **D-15:** IBM DB2 embedded-SQL documentation is syntax authority. The measured
  489-statement estate inventory and tracked `test/ocesql/src/**/*.cbl` samples
  prioritize forms and measure coverage only. Public corpus fixtures are
  minimal, hand-written, and use invented neutral names; no estate source or
  estate-derived shape is copied into tracked files.
- **D-16:** Mandatory proof includes both sides of recovery: add representative
  SQL shapes to gortex `TestErrorCascade` with paragraph and data-item parity,
  and reuse the Phase 2 differential on DCC and estate to detect silent
  reclassification around SQL/COBOL keyword collisions. Corpus tests,
  `tree-sitter test`, NIST with exactly 11 skips, FORK-02, and FORK-03 remain
  required.
- **D-17:** The extraction query ships as **`queries/sql.scm`**, following
  `queries/cics.scm`: named-node captures, one pattern per role, and no
  predicates because gortex's current query runner does not evaluate them. The
  fork-local gate must compile the query and assert all table, alias, include,
  and feasible dynamic-source captures even though gortex does not yet read the
  query in production.

### the agent's Discretion

- Exact internal helper-rule names and precedence strategy, except the locked
  public node names above.
- Exact statement-kind representation and keyword vocabulary, provided one
  generic `exec_sql_statement` traversal shape remains.
- Whether `sql_dynamic_source` ships for all dynamic forms or only forms that
  can be delimited without widening scope; unsupported forms must remain visible
  in `sql_unparsed_tail`.
- How the table-reference grammar distinguishes CTE names from physical tables,
  provided nested physical tables are captured and CTE names are not emitted as
  `@table`.
- Fixture grouping and plan decomposition, subject to FORK-03 and the existing
  per-topic corpus convention.
- Where the mandatory tail census is recorded.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope and requirements
- `docs/spec/SPEC-001-nodes-for-edges.md` — accepted nodes-for-edges scope,
  construct volumes, per-family acceptance criteria, and locked decisions D1-D4.
- `.planning/PROJECT.md` — core value, project constraints, 49-program / 489-
  statement SQL volume, NIST threshold of 11, proprietary-estate boundary, and
  OQ-1.
- `.planning/REQUIREMENTS.md` — SQL-01 through SQL-07 and deferred SQLX-01.
- `.planning/ROADMAP.md` — Phase 4 goal and success criteria; SQL-05 recall is
  retired because DCC contains no EXEC SQL.
- `.planning/STATE.md` — inherited Phase 3 hazards, especially the tree-sitter
  CLI grammar-name cache and the current OQ-1 blocker.

### Prior-phase contracts to reuse
- `.planning/phases/03-exec-cics-blocks/03-CONTEXT.md` — D-19/D-20 bounded-tail
  and required-terminator pattern, D-21/D-24 named query contract and no-
  predicate constraint, D-27/D-28 cascade gate, D-31 differential, D-32 fixture
  discipline, and the explicit finding that gortex does not consume custom
  query files today.
- `.planning/phases/02-idms-dml-statement-nodes/02-CONTEXT.md` — D-02 named
  operand nodes, D-03 countable unparsed tail, D-07/D-08 two-corpus differential,
  D-10 published manual as syntax authority, D-14 removal of Phase 4's recall
  gate, and D-16 pre-planning correction discipline.
- `.planning/phases/01-delivery-pipe-measurement-baseline/01-CONTEXT.md` —
  vendoring path, baseline corpus, FORK-03 commit separability, and estate-leak
  rules.

### Grammar and query surface
- `grammar.js:1366-1409` — `_statement` integration point; `exec_sql_statement`
  joins the procedure-division statement choice here.
- `grammar.js:2260-2423` — completed CICS outer-block, option, named-operand,
  required-terminator, and bounded-tail precedent.
- `grammar.js:2425-2579` — IDMS named operands and countable-tail precedent.
- `queries/cics.scm` — query layout, named capture style, and prohibition on
  predicates.
- `queries/idms.scm` — depth-independent named-node capture precedent.
- `test/corpus/exec_cics.txt` — closest corpus-fixture analog for block boundary,
  keyword collision, tail containment, and accurate positions.

### SQL evidence and regression net
- `test/ocesql/src/**/*.cbl` — tracked embedded-SQL sample set used for form
  inventory and coverage measurement only; not DB2 syntax authority and not a
  fixture-copy source.
- `test/ocesql/src/basic/select.cbl` — representative SELECT/FROM, INSERT INTO,
  CREATE/DROP TABLE, declaration-section, INCLUDE, and utility-statement forms.
- `test/ocesql/src/basic/update.cbl` — representative UPDATE, cursor SELECT,
  nested execution flow, and host variables.
- `test/ocesql/src/basic/delete.cbl` — representative DELETE FROM and cursor
  forms.
- `run_accept_differential.sh` — reusable snapshot/compare machinery; Phase 4
  supplies SQL-relevant node types rather than the Phase 2 default regex.
- `run_nist_cobol85.sh`, `skip_tests.txt`, `test/check_tests.sh` — existing
  regression net; exactly 11 NIST skips are allowed.
- `.github/workflows/fork-checks.yml` — fork-local corpus enforcement.
- `forest-shim/refresh.sh` — regenerate-and-refresh delivery path to gortex.
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go`
  — SQL-04 gate to extend with representative SQL shapes.
- `~/repos/mine/GoApps/gortex/internal/parser/treesitter.go` — current query
  runner copies captures but does not evaluate predicates.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `exec_cics_statement` and `cics_unparsed_tail` in `grammar.js`: proven outer
  block, required `END-EXEC`, keyword extraction, and countable fallback pattern.
- IDMS named operand rules: precedent for query-stable nodes independent of
  nesting depth.
- `queries/cics.scm`: exact style for `queries/sql.scm` and its fork-local
  capture gate.
- `run_accept_differential.sh`: accepts a caller-supplied node-type regex and was
  explicitly designed for reuse by later construct families.
- `test/ocesql/src/**/*.cbl`: broad tracked inventory of declaration, include,
  CRUD, DDL, cursor, dynamic, and utility forms.
- `forest-shim/refresh.sh`: already carries generated grammar and query files to
  the local gortex consumer.

### Established Patterns
- Add procedure SQL through `_statement`; preserve normal sentence periods
  outside the `EXEC SQL` node.
- Use case-insensitive keyword tokens and tree-sitter keyword extraction rather
  than global `EXEC` anchoring that could degrade CICS.
- Use named operand rules rather than fields hidden below helper rules.
- Keep generated `src/parser.c`, `src/grammar.json`, and `src/node-types.json` in
  sync via generation; never hand-edit generated artifacts.
- Keep grammar/corpus/query commits separable from fork-local docs, scripts, and
  cross-repo test changes.

### Integration Points
- `grammar.js` procedure statement choice for executable SQL.
- DATA DIVISION content rules around normal data descriptions for declaration
  and include directive markers.
- `queries/sql.scm` plus a fork-local capture runner.
- gortex `TestErrorCascade` for SQL paragraph and data-item parity.
- DCC and estate differential snapshots for silent reclassification detection.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly chose the durable minimal contract rather than treating
  bounded parsing as a temporary compromise. Research and planning must not
  smuggle full SQL into Phase 4 under the label of future-proofing.
- The user explicitly wants aliases captured separately and wants dynamic SQL
  sources preserved as `sql_dynamic_source` when feasible.
- The table edge must represent the physical DB2 object. CTE names, aliases, and
  dynamic host variables must not be mislabeled as physical table names.
- Existing OCESQL files are useful evidence because they already exercise both
  DATA and PROCEDURE DIVISION placements, but IBM DB2 documentation remains the
  syntax authority.

</specifics>

<deferred>
## Deferred Ideas

- **Full embedded DB2 SQL grammar (SQLX-01)** — deferred unless a consumer later
  needs columns, expressions, predicates, or richer SQL semantics.
- **Named host-variable, column, predicate, and expression nodes** — outside the
  durable Phase 4 table-edge contract.
- **Resolving dynamic SQL into physical table edges** — requires analysis of
  runtime statement text; preserving `sql_dynamic_source` is the Phase 4 limit.
- **Wiring gortex to consume `queries/idms.scm`, `queries/cics.scm`, and
  `queries/sql.scm`** — a cross-repo graph-extraction phase; the files remain
  published contracts with fork-local verification today.
- **A new EXEC SQL recall corpus or substitute recall target** — SQL-05 remains
  retired; Phase 4 keeps its other objective gates.

</deferred>

---

*Phase: 4-EXEC SQL Blocks*
*Context gathered: 2026-09-12*
