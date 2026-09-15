# Phase 4: EXEC SQL Blocks - Research

**Researched:** 2026-09-12
**Domain:** Tree-sitter COBOL grammar extension for bounded IBM Db2 embedded-SQL extraction
**Confidence:** HIGH for repository integration and validation; MEDIUM for the exact bounded SQL grammar until the CTE identity spike is resolved

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

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
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SQL-01 | Close node granularity before grammar work. | D-01 already closes OQ-1 on bounded extraction; Plan 01 should record the decision and contract before implementation. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:24-35] |
| SQL-02 | Parse `EXEC SQL ... END-EXEC` into accurate named nodes, not ERROR. | Reuse the required-terminator CICS shell and add both procedure and data-division entry points. [VERIFIED: grammar.js:2275-2282] |
| SQL-03 | Query DB2 table names as named captures. | Publish `queries/sql.scm` with direct named-node captures and a fork-local executable gate. [VERIFIED: queries/cics.scm:21-30] |
| SQL-04 | Preserve following paragraphs and data items at clean-control parity. | Extend the existing 20-data-item/20-paragraph `TestErrorCascade` harness with procedure and data-placement SQL cases. [VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go:47-68,150-203] |
| SQL-05 | **Retired 2026-08-29 -- unmeasurable; do not invent a replacement recall gate.** | Preserve retirement in plans and traceability only. [VERIFIED: .planning/REQUIREMENTS.md:132-136] |
| SQL-06 | Corpus and NIST regressions pass with exactly 11 skips. | Existing scripts provide the gates; the skip file contains the verbatim non-empty values `NC205A`, `SM101A`, `SM103A`, `SM105A`, `SM107A`, `SM201A`, `SM203A`, `SM205A`, `SM206A`, `SM208A`, `SM401M`. [VERIFIED: skip_tests.txt:1-12] |
| SQL-07 | Deliver a separable, generic, estate-safe commit series. | Keep grammar/generated/corpus/query changes separate from scripts, docs, and cross-repo tests; use only invented fixtures. [VERIFIED: .planning/REQUIREMENTS.md:141-145] |
</phase_requirements>

## Summary

Implement a small SQL-aware island grammar inside the existing COBOL grammar. The outer `EXEC SQL`/`END-EXEC` boundary, statement kind, table-bearing introducers, qualified table names, aliases, directives, and safely delimited dynamic source are structured; all other SQL tokens remain in a named `sql_unparsed_tail`. This follows Tree-sitter's recommendation that grammar symbols correspond directly to recognizable constructs while keeping the grammar close to LR(1). [CITED: https://tree-sitter.github.io/tree-sitter/creating-parsers/3-writing-the-grammar.html] The existing CICS implementation proves the required-terminator and bounded-tail architecture in this repository. [VERIFIED: grammar.js:2246-2282,2398-2423]

The hard design issue is CTE identity, not ordinary SQL syntax. A CTE reference in `FROM cte_name` is lexically identical to a base table reference; a context-free Tree-sitter grammar cannot compare that identifier with an earlier CTE declaration. [ASSUMED] Therefore the first implementation plan must include a focused CTE spike. The recommended bounded solution is to emit `sql_cte_name` and source candidates internally, then have the fork-local query gate subtract CTE-definition names by statement scope before asserting `@table`; do not add query predicates, because the current gortex runner only copies captures and does not evaluate predicates. [VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/treesitter.go:179-218] This preserves D-07 behavior in the current consumer boundary without introducing a stateful SQL symbol-table scanner. [ASSUMED]

The tracked OCESQL set is useful coverage evidence, not syntax authority: this session found 30 `.cbl` files and 579 literal `EXEC SQL` occurrences, including declaration markers, generic includes, static CRUD/DDL, cursor-wrapped SELECT, and PREPARE from a host variable. [VERIFIED: test/ocesql/src/basic/select.cbl:34-57,85-127; test/ocesql/src/basic/prepare-execute.cbl:28-71; test/ocesql/src/misc/include.cbl:9-36] IBM Db2 documentation URLs were reachable only as JavaScript shells through the available fetcher, so exact production-level syntax claims below are conservatively marked `[CITED]` or `[ASSUMED]`, and plans should retain doc-linked corpus cases as executable confirmation.

**Primary recommendation:** Build in four ordered slices: contract plus CTE spike; data/procedure block integration; static-table extraction plus query gate; then cascade, differential, tail census, generated artifacts, and full regression gates.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Recognize EXEC SQL boundaries and roles | Parser grammar | Generated parser | `grammar.js` owns syntax; generated `src/` materializes it. [VERIFIED: forest-shim/refresh.sh:91-119] |
| Expose table/alias/include/dynamic nodes | Parser grammar | Tree-sitter query | Named nodes are the durable AST contract; query captures publish extraction roles. [CITED: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html] |
| Preserve DATA DIVISION declarations | COBOL data grammar | SQL directive rules | Marker nodes must be siblings of existing `data_description` nodes, not wrappers. [VERIFIED: grammar.js:876-894] |
| Verify extraction | Fork-local shell gate | `queries/sql.scm` | The current production consumer does not load this custom query; executable verification belongs in the fork. [VERIFIED: queries/cics.scm:17-19] |
| Verify recovery | gortex Go test | Vendored forest shim | `TestErrorCascade` measures downstream parser behavior through the actual Go delivery path. [VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go:13-45] |
| Detect collateral reclassification | Differential script | DCC and estate corpora | The script already isolates baseline/current parsers and compares node types by path and position. [VERIFIED: run_accept_differential.sh:67-75,847-906] |

## Standard Stack

No new packages are allowed or needed.

### Core
| Tool | Version | Purpose | Why Standard Here |
|------|---------|---------|-------------------|
| `tree-sitter-cli` | `0.24.5` | Generate parser, run corpus tests and queries | Lockfile-installed project tool; executable reports `tree-sitter 0.24.5 (1a983b7e...)`. [VERIFIED: package.json:29-31; environment probe] |
| Tree-sitter grammar DSL | repository version | Define SQL island grammar and named AST nodes | Existing grammar and generated artifacts use it. [VERIFIED: grammar.js:1366-1409,2246-2579] |
| Go | `go1.27.1 darwin/arm64` | Build shim and run gortex cascade test | Existing delivery path uses Go. [VERIFIED: environment probe; forest-shim/refresh.sh:196-207] |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Apple clang | `21.0.0` | Build isolated differential helpers | Required by the reusable differential. [VERIFIED: environment probe; run_accept_differential.sh:676-706] |
| GNU `timeout` | `9.11` | Bound corpus parsing and helper builds | Required by differential execution. [VERIFIED: environment probe; run_accept_differential.sh:803-806] |
| OCESQL samples | tracked snapshot | Coverage measurement only | Inventory and parse representative embedded-SQL forms; never treat as Db2 syntax authority. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:96-101] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bounded extraction grammar | Full Db2 SQL grammar | Explicitly deferred as SQLX-01 and would expand scope to columns, predicates, and expressions. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:260-265] |
| Pure grammar plus scoped gate handling for CTE identity | Stateful external scanner | Could distinguish bound CTE names, but adds parser state, serialization, and scanner blast radius for one semantic-equality problem. [ASSUMED] Use only if the Wave 0 spike proves the bounded approach cannot meet D-07. |

**Installation:** none. Use the existing lockfile and `npm ci` only through the established refresh workflow. [VERIFIED: forest-shim/refresh.sh:57-88]

## Architecture Patterns

### System Architecture Diagram

```text
COBOL source
  -> DATA DIVISION entry point ---------------------------+
  |    -> DECLARE marker / INCLUDE / normal data item     |
  -> PROCEDURE DIVISION `_statement` entry point          |
       -> EXEC SQL outer block                            |
            -> directive? -> named include/marker         |
            -> executable -> statement kind               |
                           -> SQL clause walk              |
                           -> table name + alias captures  |
                           -> dynamic source OR tail       |
            -> required END-EXEC boundary                 |
  -> generated parser (`src/`)                            |
  -> query contract (`queries/sql.scm`)                   |
       -> fork-local capture gate                         |
  -> forest shim refresh -> gortex TestErrorCascade ------+
  -> differential + corpus + NIST + estate-leak gates
```

### Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| `grammar.js` | Outer SQL blocks, directive placement, kind field, table/alias/include/dynamic nodes, bounded tail. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:196-215] |
| `test/corpus/exec_sql.txt` | Minimal invented examples for every durable node and boundary/collision case. Path is a recommended new file. [ASSUMED] |
| `queries/sql.scm` | One direct named-node pattern per role; no predicates. [VERIFIED: queries/cics.scm:1-8,21-30] |
| `run_sql_query_capture.sh` | Compile/run query, assert multiplicity, exact spans, CTE exclusions, aliases, includes, and dynamic source. Path is a recommended CICS-derived fork-local gate. [ASSUMED] |
| `run_accept_differential.sh` | Reuse with an SQL-relevant node regex; do not create a second corpus walker. [VERIFIED: run_accept_differential.sh:17-40] |
| `forest-shim/refresh.sh` | Regenerate `src/`, copy parser and all queries into shim, rewrite includes, drift-check, build. [VERIFIED: forest-shim/refresh.sh:91-144,172-214] |
| gortex `cascade_test.go` | Assert clean-control parity for SQL in procedure and data contexts. [VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go:150-203] |

### Pattern 1: Required outer block with bounded internals

Use a required `END_EXEC` sibling outside every body/tail. The repository's exact proven shell is:

```javascript
exec_cics_statement: $ => seq(
  $.EXEC,
  $.CICS,
  field('command', $.WORD),
  repeat($._cics_option),
  optional($.cics_unparsed_tail),
  $.END_EXEC
),
```

[VERIFIED: grammar.js:2275-2282] For SQL, preserve the shape but replace command/options with the generic SQL kind and bounded SQL body. Never make `END_EXEC` optional. [VERIFIED: grammar.js:2263-2267]

### Pattern 2: DATA DIVISION directives are siblings

`working_storage_section` currently accepts only repeated `data_description` plus periods:

```javascript
working_storage_section: $ => seq(
  $._WORKING_STORAGE, $._SECTION, '.',
  repeat(seq($.data_description, repeat1('.')))
),
```

[VERIFIED: grammar.js:876-879] Change its repeated content to a choice that admits an SQL declaration marker or include alongside the existing data-description sequence. Do not create a declaration-section wrapper. OCESQL demonstrates markers surrounding ordinary level-01/03 items and includes both before and inside a declaration section. [VERIFIED: test/ocesql/src/basic/select.cbl:34-45; test/ocesql/src/misc/include.cbl:9-26]

### Pattern 3: Clause recognizers interleaved with bounded tail chunks

Do not put one greedy `sql_unparsed_tail` immediately after the kind, because SELECT projection text precedes `FROM`, and a single tail would consume the introducer before table extraction. [ASSUMED] Structure a bounded walk as repeated SQL body elements, with higher static precedence for modeled clauses and tail chunks that cannot consume `END-EXEC`. Apply `prec`/`prec.right` before adding GLR conflicts; Tree-sitter documents precedence and associativity as the standard conflict-resolution tools. [CITED: https://tree-sitter.github.io/tree-sitter/creating-parsers/3-writing-the-grammar.html#using-precedence]

Recommended table-bearing introducers and targets:

| Statement shape | Physical target/source recognized | Notes |
|-----------------|-----------------------------------|-------|
| `SELECT ... FROM t [alias]` | every `FROM` source and `JOIN` source, recursively | Parenthesized derived tables expose base tables inside; derived alias is alias-only. [CITED: https://www.ibm.com/docs/en/db2-for-zos/13.0.0?topic=queries-table-reference] |
| `INSERT INTO t` | target `t` plus sources in any nested SELECT | `INTO` is the target anchor. [CITED: https://www.ibm.com/docs/en/db2-for-zos/13.0.0?topic=statements-insert] |
| `UPDATE t` | target `t` plus nested-query sources | Alias follows target where supported. [CITED: https://www.ibm.com/docs/en/db2-for-zos/13.0.0?topic=statements-update] |
| `DELETE FROM t` | target `t` plus nested-query sources | Do not treat COBOL DELETE outside EXEC SQL as SQL. [CITED: https://www.ibm.com/docs/en/db2-for-zos/13.0.0?topic=statements-delete] |
| `MERGE INTO t` | target plus table/query source after USING | Capture all static physical names. [CITED: https://www.ibm.com/docs/en/db2-for-zos/13.0.0?topic=statements-merge] |
| `CREATE/ALTER/DROP TABLE t` | DDL object `t` | `DROP TABLE IF EXISTS` occurs in OCESQL and needs optional intervening tokens before the name. [VERIFIED: test/ocesql/src/basic/select.cbl:89-101,126-128] |

### Pattern 4: Whole qualified name, separate alias

Make `sql_table_name` wrap the entire qualified token sequence, such as `SCHEMA.TABLE`; make `sql_table_alias` a sibling. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:47-59] Model regular and delimited identifiers separately if the existing lexer permits it. Db2 names can be qualified and delimited identifiers can contain characters that ordinary COBOL `WORD` does not represent. [CITED: https://www.ibm.com/docs/en/db2-for-zos/13.0.0?topic=identifiers-sql]

### Pattern 5: Dynamic source only at explicit source positions

The tracked static example is `PREPARE st FROM :SQL-COMMAND`. [VERIFIED: test/ocesql/src/basic/prepare-execute.cbl:53-62] Capture only the source operand after a recognized dynamic introducer as `sql_dynamic_source`; never feed it through `sql_table_name`. Unknown dynamic forms remain in `sql_unparsed_tail`. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:66-70]

### Pattern 6: Query contract uses direct named captures

Tree-sitter queries match named node types directly and attach captures with `@name`. [CITED: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html] Follow the repository's one-role-per-pattern form:

```scheme
(sql_table_name) @table
(sql_table_alias) @alias
(sql_include_name) @include
(sql_dynamic_source) @dynamic_source
```

The values `sql_table_name`, `sql_table_alias`, `sql_include_name`, and `sql_dynamic_source` are quoted verbatim from D-05, D-06, D-12, and D-08. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:47-70,87-91] Do not add predicates. [VERIFIED: queries/cics.scm:4-8]

### Anti-Patterns to Avoid

- **One greedy tail after statement kind:** loses later FROM/JOIN targets. [ASSUMED]
- **Optional `END-EXEC`:** allows recovery to absorb following COBOL. [VERIFIED: grammar.js:2263-2267]
- **Global `EXEC` dispatch:** can degrade existing CICS parsing; anchor SQL on `EXEC SQL`. [VERIFIED: grammar.js:2259-2261]
- **Capturing every identifier after FROM as physical:** creates false CTE and derived-table edges. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:60-64]
- **Splitting schema and table captures:** violates the durable full-span identity contract. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:47-53]
- **Wrapping DECLARE SECTION contents:** hides or disrupts ordinary COBOL data nodes. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:82-85]
- **Hard-coding SQLCA/SQLDA:** tracked samples contain generic members such as `TEST-DATA`, `DECLARE-SECTION`, and `EXEC-SELECT`. [VERIFIED: test/ocesql/src/misc/include.cbl:9-36]
- **Using OCESQL as syntax authority:** it is PostgreSQL-oriented sample code and only a measured fixture source. [VERIFIED: test/ocesql/src/basic/select.cbl:78-99; .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:96-101]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Full SQL parsing | Expression/predicate/column grammar | Locked bounded extraction plus named tail | Full SQL is SQLX-01 and outside the edge contract. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:260-265] |
| Corpus traversal/differencing | New SQL-only walker | Parameterize/reuse `run_accept_differential.sh` | Existing helper isolates parser revisions, bounds execution, and prevents inventory writes under the repo. [VERIFIED: run_accept_differential.sh:67-105,819-836] |
| Query engine | Custom S-expression evaluator | Tree-sitter CLI query plus `queries/sql.scm` | Official query syntax already supplies direct node captures. [CITED: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html] |
| Generated parser output | Manual edits to `src/parser.c` or JSON | `tree-sitter generate` through refresh workflow | Refresh explicitly regenerates and copies the artifacts. [VERIFIED: forest-shim/refresh.sh:91-119] |
| Db2 dynamic SQL resolution | Parse runtime string values into edges | Preserve `sql_dynamic_source` only | Dynamic resolution is deferred. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:266-268] |

**Key insight:** This phase is an extraction grammar, not a SQL compiler. Every modeled rule must earn its place by producing one locked node or by protecting the `END-EXEC` boundary.

## Common Pitfalls

### Pitfall 1: CTE references are context-sensitive identities
**What goes wrong:** `FROM recent_rows` is captured as a physical table even when `recent_rows` is declared by `WITH`. [ASSUMED]
**Why it happens:** the token shape is identical to an unqualified table name; grammar position alone cannot compare identifier text. [ASSUMED]
**How to avoid:** make the first plan a falsifiable spike. Verify nested base tables, collect CTE definitions, and prove the fork-local emitted `@table` set excludes matching CTE references. If grammar-only classification cannot do this, document the minimal scoped post-query subtraction rather than pretending the AST solved name binding. [ASSUMED]
**Warning signs:** a query fixture returns both the CTE name and its base table as `@table`.

### Pitfall 2: The tail consumes clause anchors or the terminator
**What goes wrong:** later JOINs disappear or following COBOL paragraphs become part of SQL. [ASSUMED]
**Why it happens:** `WORD` can match SQL keywords and `END-EXEC`; lexical and parse precedence are distinct. [CITED: https://tree-sitter.github.io/tree-sitter/creating-parsers/3-writing-the-grammar.html#lexical-precedence-vs-parse-precedence]
**How to avoid:** keep `END_EXEC` required and outside the body; add corpus cases with unsupported text before FROM/JOIN and immediately before END-EXEC. Use keyword extraction and narrow tail vocabulary before lexical precedence or scanner changes. [VERIFIED: grammar.js:2398-2423]
**Warning signs:** missing `(END_EXEC)`, a tail span ending after END-EXEC, or paragraph count below clean control.

### Pitfall 3: DATA DIVISION integration destroys ordinary items
**What goes wrong:** declaration markers parse but the intervening level items vanish or become ERROR. [ASSUMED]
**Why it happens:** a marker pair is modeled as one wrapping SQL block instead of two sibling markers. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:82-85]
**How to avoid:** add marker alternatives to section content and assert both markers plus every intervening `data_description` in corpus and cascade tests.
**Warning signs:** fewer than 20 data items in the SQL data-placement cascade case.

### Pitfall 4: Keyword collisions silently reclassify COBOL
**What goes wrong:** ordinary `DELETE`, `MERGE`, `ALTER`, `OPEN`, or `CLOSE` nodes change outside SQL. [ASSUMED]
**Why it happens:** SQL keyword tokens are made globally eager or dispatch anchors on one token. [VERIFIED: grammar.js:1366-1409,2251-2261]
**How to avoid:** anchor on `EXEC SQL`, prove ordinary COBOL collision fixtures, then run before/after differential on DCC and estate with SQL and colliding COBOL node types.
**Warning signs:** nonzero clean reclassification count or new generated conflicts.

### Pitfall 5: CLI parser-name cache invalidates differential evidence
**What goes wrong:** baseline and current parses accidentally use the same compiled grammar and report false equality. [VERIFIED: .planning/STATE.md:91-94]
**Why it happens:** the CLI cache keys compiled parsers by grammar name rather than checkout path. [VERIFIED: .planning/STATE.md:91-94]
**How to avoid:** use the existing isolated compiled-helper `run` path, generating then measuring each side in order. [VERIFIED: run_accept_differential.sh:847-881]
**Warning signs:** implausibly byte-identical before/after output after a known grammar change.

### Pitfall 6: Query gate checks presence but not correctness
**What goes wrong:** one capture exists, but duplicates, aliases inside table spans, CTE names, or wrong positions pass. [ASSUMED]
**How to avoid:** assert exact capture counts and texts for multiple tables, exact full qualified-name spans, separate aliases, generic includes, dynamic source, and absence of CTE/derived aliases from tables. The CICS gate currently checks only capture-name presence, so SQL must strengthen that contract. [VERIFIED: run_cics_query_capture.sh:105-131]

## Code Examples

### Recommended outer traversal skeleton

```javascript
// Based on repository CICS shell; helper names below are internal recommendations.
exec_sql_statement: $ => seq(
  $.EXEC,
  $.SQL,
  field('kind', $.sql_statement_kind),
  repeat(choice($._sql_modelled_clause, $.sql_unparsed_tail)),
  $.END_EXEC
),
```

`exec_sql_statement` is quoted verbatim from D-02, and `sql_unparsed_tail` from D-13. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:32-35,103-107] `_sql_modelled_clause`, `SQL`, and the exact kind node are implementation recommendations and therefore `[ASSUMED]`; validate generation before locking them.

### Existing precedence pattern for named wrappers

```javascript
idms_record_name: $ => prec(1, $.WORD),
idms_set_name: $ => prec(1, $.WORD),
```

[VERIFIED: grammar.js:2553-2563] Use the same static-precedence-first discipline where table names or aliases compete with the tail.

### Query patterns

```scheme
(sql_table_name) @table
(sql_table_alias) @alias
(sql_include_name) @include
(sql_dynamic_source) @dynamic_source
```

[VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:47-70,87-91] These patterns rely only on official direct named-node capture syntax. [CITED: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html]

## OCESQL Sample Inventory and Coverage Priorities

- The tracked tree contains 30 `.cbl` files and 579 literal `EXEC SQL` openings in this session's mechanical count. [VERIFIED: repository glob and `rg` count executed 2026-09-12]
- All 30 files contain a `BEGIN DECLARE SECTION` match, and 36 `EXEC SQL INCLUDE` forms were counted. [VERIFIED: repository `rg` count executed 2026-09-12]
- Representative static forms are directly present: SELECT/FROM, INSERT INTO, UPDATE, DELETE FROM, CREATE TABLE, and DROP TABLE. [VERIFIED: test/ocesql/src/basic/select.cbl:55-57,89-110; test/ocesql/src/basic/update.cbl:52-71,112-124; test/ocesql/src/basic/delete.cbl:52-71]
- Cursor declarations wrap SELECT (`DECLARE C1 CURSOR FOR SELECT ... FROM EMP`), so statement-kind handling must still discover nested table-bearing SQL after utility prefixes. [VERIFIED: test/ocesql/src/basic/update.cbl:65-71]
- PREPARE uses a host variable source, which is the clearest `sql_dynamic_source` target. [VERIFIED: test/ocesql/src/basic/prepare-execute.cbl:28-31,53-62]
- Generic INCLUDE members occur in both DATA and PROCEDURE DIVISION, including multiline INCLUDE. [VERIFIED: test/ocesql/src/misc/include.cbl:9-36,65-73]
- The tracked samples do not establish CTE, JOIN, MERGE, ALTER, qualified-name, or delimited-identifier coverage. [VERIFIED: targeted repository search returned no authoritative sample evidence this session] Add minimal IBM-doc-derived, neutral corpus fixtures for these mandated forms rather than copying estate shapes.

## Generated-Artifact and Commit Workflow

1. Edit `grammar.js` and corpus/query fixtures; never hand-edit generated files. [VERIFIED: forest-shim/refresh.sh:91-119]
2. Run `node_modules/tree-sitter-cli/tree-sitter generate` or the refresh script's pinned binary, then `tree-sitter test -e '^comment$'`. [VERIFIED: .github/workflows/fork-checks.yml:31-39]
3. Commit `grammar.js`, regenerated `src/parser.c`, `src/grammar.json`, `src/node-types.json`, SQL corpus, and `queries/sql.scm` as the separable grammar family. The exact generated files are established by the existing workflow and project context. [VERIFIED: forest-shim/refresh.sh:91-119; .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:188-193]
4. Keep fork-local query/differential/tail-census scripts and documentation in separate commits, and keep the gortex cascade edit in its own repository commit. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:188-193]
5. Run `forest-shim/refresh.sh`; it copies all `queries/*.scm` into the embedded shim and smoke-builds last. [VERIFIED: forest-shim/refresh.sh:122-144,196-214]
6. Run FORK-02 estate-leak and FORK-03 commit-separability gates before closure. [VERIFIED: .planning/REQUIREMENTS.md:32-49]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Unknown EXEC blocks recover as broad ERROR | Required-terminator island grammar with named bounded tail | Phase 3 in this repo | SQL should reuse proven containment mechanics. [VERIFIED: grammar.js:2246-2282,2398-2423] |
| Fields alone for deeply nested extraction | Dedicated named operand nodes and depth-independent query patterns | Phases 2-3 | SQL table and alias roles remain queryable regardless of nesting. [VERIFIED: grammar.js:2321-2346; queries/idms.scm:2-20] |
| Query file left in source directory | Refresh copies every `queries/*.scm` into embedded shim | Phase 2/3 delivery work | Published SQL query reaches the vendored package. [VERIFIED: forest-shim/refresh.sh:122-144] |

**Deprecated/outdated:**
- SQL-05 recall target: retired as unmeasurable because DCC contains no EXEC SQL. Do not replace it. [VERIFIED: .planning/REQUIREMENTS.md:132-136]
- Full Db2 SQL grammar for this phase: deferred to SQLX-01. [VERIFIED: .planning/REQUIREMENTS.md:157-160]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A pure context-free grammar cannot distinguish arbitrary CTE references by equality with earlier declarations. | Summary / Pitfall 1 | High -- D-07 needs a scoped post-query mechanism or stateful scanner. |
| A2 | Scoped subtraction of CTE names in the fork-local query gate is acceptable as the bounded D-07 implementation. | Summary | High -- user may require raw query output itself never to contain a CTE candidate. |
| A3 | Interleaved modeled clauses and tail chunks are the best grammar shape. | Pattern 3 | Medium -- generation conflicts may require a different helper decomposition. |
| A4 | A stateful external scanner has disproportionate complexity for CTE identity. | Alternatives | Medium -- spike could show it is the only contract-compliant route. |
| A5 | Recommended new paths `test/corpus/exec_sql.txt` and `run_sql_query_capture.sh` fit repository convention. | Component Responsibilities | Low -- planner may choose equivalent names. |

## Open Questions (RESOLVED)

1. **Can D-07 be met by raw AST/query output without semantic name subtraction?** — **RESOLVED:** No raw-output guarantee is required. Per D-18, the grammar emits structured CTE definitions and source candidates, and the fork-local query gate performs statement-scoped subtraction before asserting physical tables.
   - What we know: CTE declaration and reference identifiers have the same lexical form; query predicates are prohibited and not evaluated by gortex. [VERIFIED: queries/cics.scm:4-8; /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/treesitter.go:179-218]
   - What's unclear: whether a bounded grammar decomposition can classify every mandated mix of CTE and physical sources without identifier equality.
   - Recommendation: Wave 0 spike three cases: CTE-only outer source, CTE body with physical JOIN, and outer query joining a CTE to a physical table. Require exact `@table` sets before proceeding.

2. **Which additional dynamic forms are safely delimited?** — **RESOLVED:** Guarantee PREPARE source first. Other dynamic forms remain visible in the tail unless implementation evidence proves a safe delimiter, as D-08 permits.
   - What we know: PREPARE `statement-name FROM :host-variable` is tracked and clear. [VERIFIED: test/ocesql/src/basic/prepare-execute.cbl:53-62]
   - What's unclear: whether estate inventory contains immediate execution or descriptor forms worth modeling.
   - Recommendation: guarantee PREPARE source first; categorize all other observed dynamic shapes into the tail census, as D-08 permits.

3. **Exact Db2 identifier breadth needed now** — **RESOLVED:** Test two-part, three-part, and delimited identifiers during the first grammar slice. Support each form that does not require broad COBOL lexer changes; document any evidenced lexer boundary rather than widening global tokens.
   - What we know: D-05 requires a complete qualified span; IBM supports regular and delimited SQL identifiers. [CITED: https://www.ibm.com/docs/en/db2-for-zos/13.0.0?topic=identifiers-sql]
   - What's unclear: whether three-part names and delimited identifiers occur in measured inputs.
   - Recommendation: include neutral two-part, three-part, and delimited-name corpus cases if the lexer can support them without broad COBOL token changes; otherwise record a bounded, evidenced limitation.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Node.js | generator/tests | yes | `v24.20.0` | none needed |
| npm | lockfile install | yes | `11.19.0` | none needed |
| tree-sitter CLI | generate/test/query | yes | `0.24.5` | use direct `node_modules/tree-sitter-cli/tree-sitter`, not cache-ambiguous path |
| Go | shim/cascade | yes | `go1.27.1 darwin/arm64` | none needed |
| C compiler | differential helper | yes | Apple clang `21.0.0` | none needed |
| GNU timeout | bounded differential | yes | `9.11` | none needed |

[VERIFIED: environment probe executed 2026-09-12]

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none.

## Validation Architecture

Nyquist validation is enabled because `.planning/config.json` does not set `workflow.nyquist_validation` to `false`. [VERIFIED: .planning/config.json:1-27]

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Tree-sitter corpus runner `0.24.5`, shell gates, Go `testing` |
| Config file | `package.json`; `.github/workflows/fork-checks.yml`; gortex Go package |
| Quick run command | `node_modules/tree-sitter-cli/tree-sitter test -e '^comment$'` |
| Full suite command | corpus test, SQL query gate, DCC+estate differential, `sh run_nist_cobol85.sh`, gortex `go test ./internal/parser/forest/cobolprobe -run TestErrorCascade`, refresh, FORK-02, FORK-03 |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SQL-01 | Bounded contract recorded before grammar | documentation gate | review D-01 contract in context/research/plan | yes |
| SQL-02 | Both placements parse; tail bounded; nodes/spans accurate | corpus | `node_modules/tree-sitter-cli/tree-sitter test -e '^comment$'` | no -- Wave 0 SQL corpus |
| SQL-03 | Exact table/alias/include/dynamic captures and CTE exclusions | integration | `sh run_sql_query_capture.sh` | no -- Wave 0 gate |
| SQL-04 | 20/20 paragraph and 20/20 data parity | Go integration | `go test ./internal/parser/forest/cobolprobe -run TestErrorCascade -v` in gortex | harness yes; SQL cases no |
| SQL-05 | Retired/unmeasurable | no test | none; assert no recall task is planned | not applicable |
| SQL-06 | Corpus and NIST remain green with 11 skips | regression | `sh run_nist_cobol85.sh` | yes |
| SQL-07 | Estate safety and commit separability | policy/script | existing FORK-02/FORK-03 gates | yes |

### Sampling Rate
- **Per grammar task commit:** generate, targeted SQL corpus, SQL query gate.
- **Per wave merge:** all non-comment corpus fixtures plus refresh smoke build.
- **Phase gate:** full suite above, tail census explained, DCC and estate differential clean, exactly 11 NIST skips, gortex cascade parity, FORK-02 and FORK-03 green.

### Wave 0 Gaps
- [ ] `test/corpus/exec_sql.txt` -- block placement, all mandated table-bearing forms, nested subqueries, qualified names, aliases, CTE exclusions, dynamic source, and terminator containment. [ASSUMED path]
- [ ] `queries/sql.scm` -- published direct-capture contract. [VERIFIED path/value: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:117-123]
- [ ] `run_sql_query_capture.sh` -- exact text/count/span and negative-capture assertions. [ASSUMED path]
- [ ] Differential parameterization -- current `run` helper hard-codes ACCEPT node regex at lines 739-743 despite the public `snapshot` accepting a regex. Extend the run path rather than merely passing a regex that it ignores. [VERIFIED: run_accept_differential.sh:739-743,789-906]
- [ ] SQL tail census output location and categories -- decide in Plan 01, then make every observed tail shape explained rather than requiring zero. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:108-113]
- [ ] gortex SQL cascade cases -- add procedure SELECT/unsupported-tail and DATA DECLARE/INCLUDE adjacency cases against the immutable 20/20 control. [VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go:150-203]

## Security Domain

This is a static parser phase with no authentication, session, access-control, cryptographic, database-connection, or SQL-execution behavior. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:7-20]

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No runtime identity boundary. [VERIFIED: phase boundary cited above] |
| V3 Session Management | no | No sessions. [VERIFIED: phase boundary cited above] |
| V4 Access Control | no | No authorization decisions. [VERIFIED: phase boundary cited above] |
| V5 Input Validation | yes | Treat COBOL/SQL source as untrusted parse input; require bounded parse time, required terminator, no execution, and ERROR/MISSING/cascade assertions. [CITED: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html#the-error-node] |
| V6 Cryptography | no | No cryptographic operation. [VERIFIED: phase boundary cited above] |

### Known Threat Patterns for Parser Stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Proprietary estate content enters public fixtures/logs | Information Disclosure | Keep inventories outside repo, use invented fixtures, run estate-leak gate. [VERIFIED: run_accept_differential.sh:41-45,100-105] |
| Pathological SQL causes excessive parse time | Denial of Service | Existing per-file 5-second parser deadline and differential wall timeouts. [VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/treesitter.go:13-14,81-89; run_accept_differential.sh:85-89] |
| Malformed block absorbs later COBOL | Tampering of extracted graph | Required END-EXEC, bounded tail, exact cascade parity. [VERIFIED: grammar.js:2263-2267] |
| Dynamic host variable mislabeled as table | Spoofing / data-integrity error | Separate dynamic source or tail; never `@table`. [VERIFIED: .planning/phases/04-exec-sql-blocks/04-CONTEXT.md:66-70] |

## Sources

### Primary (HIGH confidence)
- Repository `grammar.js`, `queries/cics.scm`, `queries/idms.scm`, corpus, scripts, generated-artifact workflow, OCESQL samples, requirements, roadmap, state, and phase context -- opened in this session.
- gortex `internal/parser/forest/cobolprobe/cascade_test.go` and `internal/parser/treesitter.go` -- opened in this session.
- Tree-sitter official grammar guide -- grammar structure, precedence, lexical precedence, keyword extraction.
- Tree-sitter official query syntax -- direct named-node and field captures, ERROR/MISSING nodes.

### Secondary (MEDIUM confidence)
- IBM Db2 for z/OS 13 documentation topic URLs -- SELECT/table references, DML/DDL statements, identifiers, PREPARE, host declarations, and SQLCA. The available fetcher returned the IBM application shell rather than full article text, so implementation must verify syntax through the linked pages during execution.

### Tertiary (LOW confidence)
- CTE context-sensitivity analysis and recommended scoped subtraction mechanism -- marked `[ASSUMED]` and assigned to a Wave 0 spike.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- installed versions and repository workflow directly verified.
- Architecture: HIGH except CTE identity -- existing patterns and integration points directly verified; CTE solution needs spike.
- Db2 syntax breadth: MEDIUM -- official IBM topics identified, but this environment could not extract their rendered article bodies.
- Pitfalls: HIGH for terminator/cache/data-placement/query-runner hazards; MEDIUM for CTE mitigation.

**Research date:** 2026-09-12
**Valid until:** 2026-10-12 for repository findings; recheck IBM documentation if Db2 syntax scope changes.
