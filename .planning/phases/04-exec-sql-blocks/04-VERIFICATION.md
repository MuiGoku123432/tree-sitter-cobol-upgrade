---
phase: 04-exec-sql-blocks
status: passed
score: 7/7
verified: 2026-09-14
next_action: phase.complete
---

# Phase 4 Verification: EXEC SQL Blocks

## Goal

`EXEC SQL ... END-EXEC` blocks are walkable named AST nodes whose physical DB2 table names are directly queryable at a deliberately bounded granularity.

## Requirement Traceability

| Requirement | Evidence | Status |
|-------------|----------|--------|
| SQL-01 | `test/corpus/exec_sql.txt` records the bounded-extraction decision before implementation; SQL-05 retirement remains explicit | PASS |
| SQL-02 | Named statement, declaration, include, static DML/DDL, cursor, and PREPARE nodes; all 149 non-comment corpus assertions pass | PASS |
| SQL-03 | `queries/sql.scm` direct captures; exact gate passes 47 legacy captures, 13 D-04 table ranges, CTE subtraction, aliases, includes, and dynamic source | PASS |
| SQL-04 | Gortex `TestErrorCascade` preserves 20/20 paragraphs and data items for procedure and DATA SQL; upstream forest RED proves 1/20 failures | PASS |
| SQL-05 | Correctly retired as unmeasurable; census is accounting only and makes no recall claim | PASS (retired) |
| SQL-06 | DCC and estate differentials show zero reclassification/conversion; NIST reports 371 success, 0 fail, 11 skip | PASS |
| SQL-07 | Grammar, fork-local, shim, docs, and cross-repo changes are separated; pre-push estate guard remains installed | PASS |

## Success Criteria

1. Granularity decision documented before grammar work: verified.
2. DB2 table names returned as named query captures: verified by exact query gate and aggregate reconciliation.
3. EXEC SQL blocks parse as named nodes with accurate bounded positions: verified by corpus and query ranges.
4. Downstream paragraphs and data items survive at clean-control parity: verified at 20/20 twice.
5. Separable delivery and regression safety: verified by commit families, full corpus, NIST, shim, and cross-repo checks.

## Closing Gates

- Generation: PASS.
- Non-comment corpus: PASS, 149 assertions.
- OCESQL census: PASS, expected equals captured in every category.
- Estate census: PASS, expected equals captured in every category.
- DCC differential: 3,779 before / 3,779 after; reclassified 0, converted 0, new 0.
- Estate differential: 9,871 before / 10,115 after; reclassified 0, converted 0, new 244.
- Forest shim: PASS, all six stages and query byte identity.
- Gortex cascade: PASS twice against final shim.
- NIST: PASS, exact final line `382 tests. (Success: 371, Fail: 0, Skip: 11)`.
- Security: SECURED, threats open 0.

## Verdict

Phase 4 goal achieved. All active requirements are satisfied, the retired requirement is handled as specified, and no human verification is required.
