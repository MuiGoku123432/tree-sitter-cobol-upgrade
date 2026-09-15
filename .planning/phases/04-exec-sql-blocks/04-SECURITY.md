---
phase: 04-exec-sql-blocks
status: secured
threats_open: 0
verified: 2026-09-14
---

# Phase 4 Security Verification

## Verdict

SECURED. All high and medium threat mitigations declared across Plans 04-01 through 04-08 are present and exercised. No open threats remain.

## Mitigations

| Boundary | Mitigation | Evidence | Status |
|----------|------------|----------|--------|
| SQL text to AST roles | Bounded grammar, required `END-EXEC`, private low-precedence tails | 149 non-comment corpus assertions; exact query gate | PASS |
| Table classification | Whole qualified names, sibling aliases, CTE subtraction, exact positive/negative captures | 47 legacy captures, 13 static table ranges, dynamic-source and alias exclusions | PASS |
| DATA DIVISION recovery | Separate declaration/include siblings preserve ordinary data descriptions | Exact corpus fixtures and 20/20 cascade parity | PASS |
| Grammar to Go shim | Scripted refresh, byte-identical query, drift check, smoke build | `forest-shim/refresh.sh` all six stages | PASS |
| Grammar repo to gortex | Cross-repo commit touches only `cascade_test.go` | gortex commit `861edf7c`; GREEN twice, upstream RED | PASS |
| Estate to report | Aggregate-only output, per-invocation scratch, unconditional cleanup | OCESQL/estate census and DCC/estate differential evidence | PASS |
| Regression evidence | Separate exit status and output capture; exact NIST line and skip allowlist | NIST exit 0; 371 success, 0 fail, 11 skip | PASS |
| Public-fork hygiene | Installed pre-push guard and separable commit families | `.githooks/pre-push` executable; `core.hooksPath` configured | PASS |

## Residual Risk

- SQL semantics remain intentionally bounded rather than complete. Unsupported content is visible in `sql_unparsed_tail`; graph-relevant table roles are independently reconciled by census.
- SQL-05 remains retired because the DCC recall corpus contains no EXEC SQL signal. No replacement recall claim is made.
