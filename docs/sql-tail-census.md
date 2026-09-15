# EXEC SQL Tail Census

SQL-05 remains retired. This census is aggregate accounting, not a replacement recall metric.

| Population | Category | Statements | Tails | Expected tables | Captured tables |
|------------|----------|------------|-------|-----------------|-----------------|
| OCESQL | SELECT | 39 | 266 | 39 | 39 |
| OCESQL | INSERT | 57 | 372 | 57 | 57 |
| OCESQL | UPDATE | 5 | 40 | 5 | 5 |
| OCESQL | DELETE | 5 | 16 | 5 | 5 |
| OCESQL | MERGE | 0 | 0 | 0 | 0 |
| OCESQL | CREATE | 55 | 1008 | 55 | 55 |
| OCESQL | ALTER | 0 | 0 | 0 | 0 |
| OCESQL | DROP | 76 | 0 | 76 | 76 |
| OCESQL | PREPARE | 3 | 3 | 0 | 0 |
| OCESQL | OTHER | 339 | 667 | 24 | 24 |
| ESTATE | SELECT | 76 | 1706 | 81 | 81 |
| ESTATE | INSERT | 7 | 378 | 7 | 7 |
| ESTATE | UPDATE | 19 | 456 | 19 | 19 |
| ESTATE | DELETE | 7 | 58 | 7 | 7 |
| ESTATE | MERGE | 0 | 0 | 0 | 0 |
| ESTATE | CREATE | 0 | 0 | 0 | 0 |
| ESTATE | ALTER | 0 | 0 | 0 | 0 |
| ESTATE | DROP | 0 | 0 | 0 | 0 |
| ESTATE | PREPARE | 0 | 0 | 0 | 0 |
| ESTATE | OTHER | 381 | 3805 | 68 | 68 |

## Differential Evidence

Both comparisons used baseline `b52d880a1024cc0ff35ef1ed2a77b7b54a9cd1a9`, the parent of the commit that introduced `test/corpus/exec_sql.txt`.

```sh
SQL_NODE_REGEX='exec_sql_statement|select_statement|delete_statement|merge_statement|alter_statement|open_statement|close_statement'
SQL_TEXT_PREFILTER='(^|[^A-Za-z0-9-])(EXEC[[:space:]]+SQL|SELECT|DELETE|MERGE|ALTER|OPEN|CLOSE)([^A-Za-z0-9-]|$)'
DIFF_TMP="$(mktemp -d)" sh run_accept_differential.sh run b52d880a1024cc0ff35ef1ed2a77b7b54a9cd1a9 "$CORPUS" "$SQL_NODE_REGEX" "$SQL_TEXT_PREFILTER"
```

The fourth argument is explicit. The ACCEPT-only default selector was not used.

| Population | Discovered files | Selected files | Before | After | Reclassified | Converted | New | Timeouts |
|------------|------------------|----------------|--------|-------|--------------|-----------|-----|----------|
| DCC | 606 | 533 | 3,779 | 3,779 | 0 | 0 | 0 | 0 |
| ESTATE | 3,781 declared members / 1,369 compilable programs | 1,201 | 9,871 | 10,115 | 0 | 0 | 244 | 0 |

The estate run entered `prepare_accept_paths`' dedicated estate branch because the corpus root was repository-local `estate` and `estate/endevor` existed. Custom SQL/collision selection suppressed the recorded ACCEPT statement denominator gate; the measured estate denominator was 1,201 selected files and 17,801 matching source-text statements. The 244 new records are Phase 4 additions. No existing record was lost, converted, or retyped.

All caller-owned differential and census scratch directories were removed after their original exit statuses were captured. Only aggregate rows are retained here.

## Closing Regression Evidence

| Gate | Command | Result |
|------|---------|--------|
| Generation | `node_modules/tree-sitter-cli/tree-sitter generate` | PASS, exit 0 |
| Corpus | `node_modules/tree-sitter-cli/tree-sitter test -e '^comment$' --overview-only` | PASS, 149 non-comment assertions |
| Query | `sh run_sql_query_capture.sh` | PASS, legacy 47 captures, 13 static table ranges, dynamic source, negative identities |
| Census | `sh run_sql_tail_census.sh --verify-report docs/sql-tail-census.md` | PASS |
| Shim | `REFRESH_SKIP_INSTALL=1 sh forest-shim/refresh.sh` | PASS, all six stages |
| Shim query identity | `cmp queries/sql.scm forest-shim/cobol/sql.scm` | PASS |
| Downstream cascade | `go test ./internal/parser/forest/cobolprobe -run TestErrorCascade -count=2` in gortex | PASS |
| NIST | `sh run_nist_cobol85.sh` with captured output and separate status | PASS, exit 0 |
| Skip allowlist | exact ordered nonblank comparison of `skip_tests.txt` | PASS, 11 unique entries |
| Skip baseline | `git diff --exit-code b52d880a..HEAD -- skip_tests.txt` | PASS, unchanged |

The NIST output was captured in a per-invocation temporary file, its exit status was saved separately, and the file was removed after reading the final nonblank line. That line was exactly:

```text
382 tests. (Success: 371, Fail: 0, Skip: 11)
```

The ordered skip allowlist remains `NC205A`, `SM101A`, `SM103A`, `SM105A`, `SM107A`, `SM201A`, `SM203A`, `SM205A`, `SM206A`, `SM208A`, `SM401M`.
