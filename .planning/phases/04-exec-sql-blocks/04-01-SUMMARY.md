---
phase: 04-exec-sql-blocks
plan: 01
subsystem: grammar
tags: [tree-sitter, cobol, exec-sql, cte, query]

requires:
  - phase: 03-exec-cics-blocks
    provides: "EXEC block anchoring, required END-EXEC boundary, named-tail pattern, generated/vendored workflow"
provides:
  - "Bounded exec_sql_statement SELECT grammar"
  - "Named table, alias, CTE definition and source-candidate roles"
  - "Exact EXEC SQL corpus cases including CTE, nested, delimited, multiline, collision and containment shapes"
  - "Predicate-free queries/sql.scm with statement-scoped raw captures"
affects: [04-02, 04-04, 04-05, 04-06]

actuals:
  tokens: 46000
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Bounded extraction grammar with required terminator outside named tail"
    - "Raw table candidates plus statement ranges for downstream CTE subtraction"

key-files:
  created:
    - test/corpus/exec_sql.txt
    - queries/sql.scm
  modified:
    - grammar.js
    - src/parser.c
    - src/grammar.json
    - src/node-types.json
    - test/corpus/exec_cics.txt

key-decisions:
  - "D-01: use a bounded extraction grammar, not a full DB2 grammar"
  - "D-05/D-06: whole qualified table names are one node; aliases are sibling nodes"
  - "D-18: publish raw source candidates and CTE definitions separately; physical-table subtraction remains statement-scoped in 04-02"

requirements-completed: [SQL-01, SQL-02, SQL-03, SQL-05, SQL-07]

coverage:
  - id: D1
    description: "EXEC SQL SELECT parses as one bounded named statement with required END_EXEC"
    requirement: SQL-02
    verification:
      - kind: unit
        ref: "test/corpus/exec_sql.txt; tree-sitter test -e '^comment$'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Table, alias, CTE definition and source-candidate roles are directly queryable"
    requirement: SQL-03
    verification:
      - kind: integration
        ref: "queries/sql.scm against .cics-query-scratch/sql-04-01-query.cbl"
        status: pass
    human_judgment: false
  - id: D3
    description: "Ordinary COBOL collision verbs retain their existing node types"
    requirement: SQL-07
    verification:
      - kind: unit
        ref: "test/corpus/exec_sql.txt#exec sql empty source utility and cobol keyword collisions"
        status: pass
    human_judgment: false

duration: 90min
completed: 2026-09-13
status: complete
---

# Phase 4 Plan 01: EXEC SQL Grammar Tracer Summary

**A bounded EXEC SQL SELECT path now parses into stable named AST roles and publishes statement-scoped raw captures for exact downstream filtering.**

## Accomplishments

- Added `exec_sql_statement` beside `exec_cics_statement`, anchored only on `EXEC SQL` with required `END_EXEC` outside the body.
- Added named SQL roles for complete qualified table spans, sibling aliases, CTE definitions/names, nested queries, raw source candidates and bounded unparsed tokens.
- Added exact corpus coverage for basic SELECT, three CTE shapes, adjacent same-name CTE statements, nested sources, three-part and delimited names, lowercase/multiline input, unsupported tail content, utility SQL and ordinary COBOL collision verbs.
- Published `queries/sql.scm` with direct `statement`, `table`, `alias`, `cte_definition` and `source_candidate` captures and no predicates.
- Kept `src/grammar.json` conflicts length at zero.

## Task Commits

1. **Task 1 RED fixtures** — `595b966` (`test(04-01): add failing EXEC SQL corpus cases`)
2. **Task 1 GREEN grammar/generated artifacts** — `a0ecf02` (`feat(04-01): add bounded exec sql select grammar`)
3. **Task 2 query contract** — `9102afc` (`feat(04-01): publish exec sql capture contract`)

## Verification

- Full non-comment tree-sitter corpus suite: exit 0.
- No `ERROR` or `MISSING` node appears in `exec_sql.txt` expected trees.
- Query compilation: exit 0.
- Focused valid COBOL query fixture emits 3 statement ranges, 6 tables/source candidates, 2 aliases and 2 CTE definitions.
- `queries/sql.scm` contains no predicates and no include/dynamic-source roles reserved for later plans.
- Generated grammar conflicts: 0.

## Deviations and Recovery

### Fixed-format CTE fixture correction

The four CTE RED fixtures initially placed complete SQL statements beyond fixed-format column 72. The COBOL external scanner correctly treated the suffix as `_LINE_SUFFIX_COMMENT`, making the outer query invisible to the grammar. The statements were wrapped across fixed-format-safe lines without changing SQL semantics. This is a fixture defect correction, not a grammar relaxation.

### Phase 3 regression fixture updated

The Phase 3 `EXEC SQL` no-regression case in `test/corpus/exec_cics.txt` legitimately improves from one top-level ERROR to a bounded `exec_sql_statement`; only that expected tree changed.

### Interrupted executor recovery

Two executor subagents stopped returning completion signals after partially editing the 32 MB generated parser. Recovery used an isolated worktree under `$TMPDIR/opencode`, preserving RED commit `595b966`, validating the minimized grammar and corpus there, and copying already-generated artifacts into the live checkout once. OpenCode's watcher still reacted to the copy, so Task 1 was committed immediately before continuing. No unrelated planning/runtime changes were staged.

## Prohibition Compliance

- No scanner added.
- No query predicate added.
- No column/expression semantic nodes added.
- Fixtures are invented and neutral; no estate source text appears.
- SQL-05 remains retired with no replacement recall metric.
- All implementation commits touch grammar-family paths only.
