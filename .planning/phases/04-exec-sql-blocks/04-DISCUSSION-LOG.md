# Phase 4: EXEC SQL Blocks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-09-12
**Phase:** 4-EXEC SQL Blocks
**Areas discussed:** SQL parsing depth, table capture scope, block placement, fallback and evidence

---

## SQL Parsing Depth

### Granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Bounded extraction grammar | Parse the outer block and only enough SQL structure to identify statement kind and table references; preserve the rest in a named tail. | Yes |
| Full SQL grammar | Model complete embedded DB2 SQL syntax now. | No |
| Opaque body plus scanner | Keep SQL text opaque and extract names outside the AST. | No |

### Statement shape

| Option | Description | Selected |
|--------|-------------|----------|
| One generic SQL node | `exec_sql_statement` with statement kind and named table-reference children. | Yes |
| DML family nodes | Separate SELECT/INSERT/UPDATE/DELETE/DDL nodes. | No |
| Hybrid nodes | Named table-bearing families plus a generic fallback node. | No |

### Named structure

| Option | Description | Selected |
|--------|-------------|----------|
| Kind and tables only | Name statement kind and table references; leave other SQL in the tail. | Yes |
| Add host variables | Also expose host-variable references. | No |
| Add columns and aliases | Expose broader partial-SQL structure. | No; aliases were selected separately under table capture scope. |

### Contract posture

| Option | Description | Selected |
|--------|-------------|----------|
| Durable minimal contract | Full SQL remains SQLX-01 only if a consumer needs it. | Yes |
| Migration foundation | Structure Phase 4 primarily for later full-SQL evolution. | No |
| Full SQL expected next | Treat bounded parsing as temporary. | No |

**User's choice:** Bounded extraction grammar, one generic node, kind and tables only, durable minimal contract.
**Notes:** This closes OQ-1 before grammar work begins as SQL-01 requires.

---

## Table Capture Scope

### Covered forms

| Option | Description | Selected |
|--------|-------------|----------|
| All static table-bearing DML/DDL | SELECT/FROM/JOIN, INSERT, UPDATE, DELETE, MERGE, CREATE/ALTER/DROP, including multiple references. | Yes |
| Core CRUD only | SELECT, INSERT, UPDATE, DELETE only. | No |
| Single-table only | Capture only the first target. | No |

### Qualified names

| Option | Description | Selected |
|--------|-------------|----------|
| One named table-reference node | Capture `SCHEMA.TABLE` as one complete object identity. | Yes |
| Schema and table children | Split qualification into separate nodes. | No |
| Table segment only | Drop the schema qualifier. | No |

### Aliases

| Option | Description | Selected |
|--------|-------------|----------|
| Delimit only | Use aliases only to end the table-name span. | No |
| Capture aliases too | Add a separate named alias node. | Yes |
| Include alias in table node | Merge alias into object identity. | No |

### Dynamic SQL

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve dynamic source | No false table edge; use `sql_dynamic_source` where feasible. | Yes |
| Capture host variable as table | Label the variable as a DB2 object. | No |
| Reject dynamic SQL | Leave dynamic forms unsupported. | No |

### CTEs and nested queries

| Option | Description | Selected |
|--------|-------------|----------|
| Capture physical tables only | Traverse nested queries; exclude CTE names from table edges. | Yes |
| Capture every FROM name | Treat CTEs and physical tables alike. | No |
| Top-level only | Ignore nested physical tables. | No |

**User's choice:** Capture all static physical tables, whole qualified names, separate aliases, dynamic sources where feasible, and nested base tables without CTE false positives.
**Notes:** User phrased dynamic behavior as: "preserve dynamic source if you can ideally with an sql_dynamic_source node if possible."

---

## Block Placement

### Supported divisions

| Option | Description | Selected |
|--------|-------------|----------|
| Both placements | Support DATA DIVISION directives and PROCEDURE DIVISION executable SQL. | Yes |
| Procedure only | Support only table-bearing executable statements. | No |
| Data declarations only | Support only precompiler declaration constructs. | No |

### Directive shape

| Option | Description | Selected |
|--------|-------------|----------|
| Distinct directive nodes | Separate declare-section and include nodes from executable SQL. | Yes |
| Generic SQL node everywhere | Use one node for declarations, includes, and statements. | No |
| Treat as extras | Skip directive structure. | No |

### Declaration section

| Option | Description | Selected |
|--------|-------------|----------|
| Markers around normal COBOL items | BEGIN/END are separate nodes; declarations remain ordinary COBOL AST. | Yes |
| Wrapper around declarations | One SQL node contains COBOL declarations. | No |
| Opaque section | SQL consumes markers and declarations. | No |

### INCLUDE target

| Option | Description | Selected |
|--------|-------------|----------|
| Named include target | Expose a generic include member node. | Yes |
| Directive only | Parse INCLUDE without its target. | No |
| Only SQLCA and SQLDA | Hard-code standard members. | No |

**User's choice:** Both divisions, distinct directive nodes, normal COBOL declarations between markers, and a named generic include target.
**Notes:** OCESQL tracked samples demonstrate that procedure-only integration would leave real files structurally broken.

---

## Fallback and Evidence

### Unsupported content

| Option | Description | Selected |
|--------|-------------|----------|
| Named bounded tail | Preserve unsupported SQL in `sql_unparsed_tail` before required `END-EXEC`. | Yes |
| Anonymous token sequence | Consume unsupported text invisibly. | No |
| Hard parse failure | Reject forms outside the bounded grammar. | No |

### Evidence authority

| Option | Description | Selected |
|--------|-------------|----------|
| DB2 docs plus measured samples | IBM DB2 syntax is authority; estate and OCESQL prioritize and measure. | Yes |
| OCESQL suite as authority | Treat tracked PostgreSQL-oriented samples as the contract. | No |
| Estate census only | Model only observed site forms. | No |

### Tail gate

| Option | Description | Selected |
|--------|-------------|----------|
| No cascade; explain every tail | Categorize tails and preserve all required table captures. | Yes |
| Zero tails required | Expand until every measured form is fully modelled. | No |
| Tail count informational | Record only a total. | No |

### Regression proof

| Option | Description | Selected |
|--------|-------------|----------|
| Cascade plus differential | Assert SQL recovery in gortex and detect silent COBOL reclassification on both corpora. | Yes |
| Cascade only | Test recovery without differential evidence. | No |
| Differential only | Test reclassification without direct cascade parity. | No |

**User's choice:** Named bounded tail, DB2 docs as authority, categorized non-zero tails allowed, and both cascade and differential proofs mandatory.
**Notes:** Fixtures remain minimal, invented, and non-estate-derived under FORK-02 and SQL-07.

---

## the agent's Discretion

- Internal helper rules, precedence, exact statement-kind representation, fixture grouping, plan decomposition, and census-report location.
- Exact feasible coverage for `sql_dynamic_source`, provided unsupported dynamic forms remain visible and never become false table captures.

## Deferred Ideas

- Full DB2 SQL grammar and deeper SQL semantic nodes (SQLX-01).
- Runtime resolution of dynamic SQL to physical tables.
- Wiring gortex to consume the custom IDMS, CICS, and SQL query files.
- A replacement recall corpus or Phase 4 recall metric.
