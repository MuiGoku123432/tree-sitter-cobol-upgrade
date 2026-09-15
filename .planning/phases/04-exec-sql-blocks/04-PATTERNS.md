# Phase 4: EXEC SQL Blocks - Pattern Map

**Mapped:** 2026-09-12
**Files analyzed:** 14 likely new or modified files
**Analogs found:** 14 / 14

## File Classification

| New/Modified File | Repository | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `grammar.js` | tree-sitter-cobol-upgrade | config / parser grammar | transform | CICS and IDMS rules in `grammar.js` | exact |
| `test/corpus/exec_sql.txt` | tree-sitter-cobol-upgrade | test | transform | `test/corpus/exec_cics.txt` | exact |
| `queries/sql.scm` | tree-sitter-cobol-upgrade | config / extraction query | transform | `queries/cics.scm`, with depth pattern from `queries/idms.scm` | exact |
| `run_sql_query_capture.sh` | tree-sitter-cobol-upgrade | test / utility | batch | `run_cics_query_capture.sh` | exact |
| `run_sql_tail_census.sh` | tree-sitter-cobol-upgrade | test / utility | batch | `run_cics_query_capture.sh` for accumulated-status gating; `run_accept_differential.sh` for owned-scratch corpus walking | exact |
| `docs/sql-tail-census.md` | tree-sitter-cobol-upgrade | docs / evidence | batch | `run_accept_differential.sh` aggregate `report` lines rendered as recorded evidence | role-match |
| `.githooks/commit-separability.sh` | tree-sitter-cobol-upgrade | config / gate | batch | its own `FORKLOCAL_PATH_RE` alternation list | self-analog |
| `run_accept_differential.sh` | tree-sitter-cobol-upgrade | test / utility | batch | its existing `snapshot` parameterization | self-analog |
| `run_accept_differential_selftest.sh` | tree-sitter-cobol-upgrade | test | batch | existing six-case synthetic-inventory harness | exact |
| `src/parser.c` | tree-sitter-cobol-upgrade | generated config | transform | current generated parser | exact, generated |
| `src/grammar.json` | tree-sitter-cobol-upgrade | generated config | transform | current generated grammar JSON | exact, generated |
| `src/node-types.json` | tree-sitter-cobol-upgrade | generated config | transform | current generated node inventory | exact, generated |
| `forest-shim/cobol/parser.c` | tree-sitter-cobol-upgrade | generated provider | transform | `src/parser.c` via `forest-shim/refresh.sh` | exact, copied |
| `forest-shim/cobol/grammar.json` | tree-sitter-cobol-upgrade | generated provider | transform | `src/grammar.json` via `forest-shim/refresh.sh` | exact, copied |
| `forest-shim/cobol/sql.scm` | tree-sitter-cobol-upgrade | generated provider / query | transform | `forest-shim/cobol/cics.scm` via wildcard refresh | exact, copied |
| `.github/workflows/fork-checks.yml` | tree-sitter-cobol-upgrade | config / CI | batch | current corpus job | role-match |
| `internal/parser/forest/cobolprobe/cascade_test.go` | **gortex, cross-repo** | test | request-response parse traversal | existing CICS/IDMS cases in the same file | exact |

`forest-shim/refresh.sh`, `.githooks/estate-guard.sh`, and `.githooks/pre-push` are required integration/gate assets that current code already handles; no edit is planned. `.githooks/commit-separability.sh` IS a proven gap: its `FORKLOCAL_PATH_RE` matches only `^run_accept_differential`, so a commit mixing `queries/sql.scm` with `run_sql_query_capture.sh` or `run_sql_tail_census.sh` is reported PASS. Plan 04-02 Task 3 widens that alternative to `^run_[a-z_]*\.sh$` as a fork-local commit.

## Pattern Assignments

### `grammar.js` (parser grammar, transform)

**Analogs:** `grammar.js:1366-1409`, `grammar.js:2246-2423`, `grammar.js:2425-2579`, and data-section rules at `grammar.js:872-894,1221-1231`.

**Procedure-division registration pattern** (`grammar.js:1366-1409`):

```javascript
_statement: $ => choice(
  $.accept_statement,
  // ...
  $.exec_cics_statement,
  // ...
  $.idms_update_statement,
  // ...
  $.next_sentence_statement,
),
```

Add `$.exec_sql_statement` as a peer in `_statement`. Anchor recognition on the two-token `EXEC SQL` opening so SQL keyword additions cannot reclassify ordinary COBOL `DELETE`, `MERGE`, `ALTER`, `OPEN`, or `CLOSE` statements.

**Required outer block and bounded-tail pattern** (`grammar.js:2275-2282,2398-2423`):

```javascript
exec_cics_statement: $ => seq(
  $.EXEC,
  $.CICS,
  field('command', $.WORD),
  repeat($._cics_option),
  optional($.cics_unparsed_tail),
  $.END_EXEC
),

_cics_operand_token: $ => choice(
  $.WORD,
  $._LITERAL,
  '(',
  ')',
  ','
),

cics_unparsed_tail: $ => repeat1($._cics_operand_token),
```

Copy these invariants, not the CICS option grammar:

- `END_EXEC` is required and remains outside `sql_unparsed_tail`.
- The sentence period remains outside the SQL node.
- The tail is named, countable, and formed from bounded atomic leaves.
- Modeled SQL clauses must be interleaved with tail chunks so projection text cannot consume later `FROM`/`JOIN` anchors.
- Executable SQL remains one `exec_sql_statement` with a `kind` field.

**Named-node and precedence pattern** (`grammar.js:2321-2352,2553-2563`):

```javascript
cics_transaction_name: $ => prec(1, $._cics_argument),
cics_program_name: $ => prec(1, $._cics_argument),
cics_map_name: $ => prec(1, $._cics_argument),
cics_mapset_name: $ => prec(1, $._cics_argument),

idms_record_name: $ => prec(1, $.WORD),
idms_set_name: $ => prec(1, $.WORD),
```

Use dedicated named rules for `sql_table_name`, `sql_table_alias`, `sql_include_name`, `sql_dynamic_source`, and structured CTE definitions/source candidates. Prefer static `prec`/`prec.right` where a modeled identifier competes with the tail. Do not rely on fields alone for values that `queries/sql.scm` must match at arbitrary depth.

**Data-division sibling pattern** (`grammar.js:872-894`):

```javascript
record_description_list: $ => seq(
  repeat1(seq($.data_description, repeat1('.')))
),

working_storage_section: $ => seq(
  $._WORKING_STORAGE, $._SECTION, '.',
  repeat(seq($.data_description, repeat1('.')))
),
```

Change section content choices so `exec_sql_declare_section` and `exec_sql_include` are siblings of ordinary data descriptions. Do not wrap intervening declarations in a declaration-section node. Check both `working_storage_section` and the shared `record_description_list` used by local storage and linkage (`grammar.js:1221-1231`).

**Evidence for intended placements and forms** (`test/ocesql/src/basic/select.cbl:34-57,85-127`; coverage evidence only):

```cobol
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  DBNAME                  PIC  X(30) VALUE SPACE.
       ...
       EXEC SQL END DECLARE SECTION END-EXEC.

       EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL
               SELECT * INTO :READ-TBL FROM EMP WHERE EMP_NO > 4
           END-EXEC.
```

Do not copy OCESQL fixture text into public corpus cases. IBM Db2 documentation is syntax authority; corpus names must be invented and neutral.

---

### `test/corpus/exec_sql.txt` (test, transform)

**Analog:** `test/corpus/exec_cics.txt`.

**Fixture structure and exact-tree assertion** (`test/corpus/exec_cics.txt:1-23`):

```text
====================================
exec cics send map with literal - names invented and neutral
====================================
       identification division.
       program-id. a.
       procedure division.
       EXEC CICS SEND MAP('MENU01') END-EXEC.
---

(start
  (program_definition
    ...
      (exec_cics_statement
        (EXEC)
        (CICS)
        command: (WORD)
        ...
        (END_EXEC))
      (period))))
```

Use one focused case per durable contract or recovery hazard. Expected trees must prove named node boundaries and spans indirectly through exact nesting.

**Keyword-collision pattern** (`test/corpus/exec_cics.txt:26-75`):

```cobol
       EXEC CICS READ END-EXEC.
       EXEC CICS WRITE END-EXEC.
       EXEC CICS DELETE END-EXEC.
       EXEC CICS RETURN END-EXEC.
       READ CUSTOMER-FILE.
       WRITE CUSTOMER-REC.
```

Mirror this for SQL/COBOL collisions: put SQL verbs inside `EXEC SQL`, then ordinary COBOL statements after them and assert the latter retain their existing node types.

**Tail-boundary pattern** (`test/corpus/exec_cics.txt:224-273`):

```text
exec cics unparsed tail does not absorb the terminator
...
       EXEC CICS SEND MAP('M1') 99 END-EXEC.
---
...
        (cics_unparsed_tail
          (number
            (integer)))
        (END_EXEC))
      (period))))
```

SQL corpus coverage should include:

- DATA DIVISION `BEGIN DECLARE SECTION`, ordinary data items, `END DECLARE SECTION`, and generic `INCLUDE` as sibling nodes.
- Procedure SELECT/FROM/JOIN, INSERT INTO, UPDATE, DELETE FROM, MERGE INTO, CREATE/ALTER/DROP TABLE.
- Multiple physical tables, nested subqueries, two-part and three-part names, delimited identifiers where lexer-safe, and aliases separate from table spans.
- D-18 cases: CTE-only outer source, CTE body with physical JOIN, and outer CTE plus physical table.
- Derived-table alias exclusion.
- `PREPARE ... FROM :host-variable` as `sql_dynamic_source`, never a table.
- Utility statements and unsupported content in `sql_unparsed_tail`.
- Lowercase, multiline, no optional terminator, following paragraph/data-item containment, and keyword collisions.

Remove or replace the pre-Phase-4 SQL regression case at `test/corpus/exec_cics.txt:436-458` only if its expected ERROR tree is intentionally superseded. Keep SQL cases in the new per-topic file rather than expanding the CICS fixture.

---

### `queries/sql.scm` (query config, transform)

**Analogs:** `queries/cics.scm` and `queries/idms.scm`.

**No-predicate, one-role-per-pattern convention** (`queries/cics.scm:1-8,21-30`):

```scheme
(exec_cics_statement
  command: (WORD) @command)

(cics_transaction_name) @transaction
(cics_program_name) @program
(cics_map_name) @map
(cics_mapset_name) @mapset
```

**Depth-independent named-node convention** (`queries/idms.scm:6-16`):

```scheme
(idms_navigation_statement
  (idms_set_name) @set)

(idms_update_statement
  (idms_record_name) @record)
```

Use direct named captures:

```scheme
(sql_table_name) @table
(sql_table_alias) @alias
(sql_include_name) @include
(sql_dynamic_source) @dynamic_source
```

Also expose the structured CTE-definition and source-candidate roles needed by D-18 statement-scoped subtraction. Keep each role in its own pattern and use no predicates. The raw candidate set is not the physical-table contract; `run_sql_query_capture.sh` computes the statement-scoped physical set.

---

### `run_sql_query_capture.sh` (test utility, batch)

**Analog:** `run_cics_query_capture.sh`.

**Configuration and house style** (`run_cics_query_capture.sh:27-43`):

```bash
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

TOP_DIR=${TOP_DIR:-$SCRIPT_DIR}
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/tree-sitter-cli/tree-sitter}
QUERY_FILE=${QUERY_FILE:-$TOP_DIR/queries/cics.scm}
SCRATCH_DIR=${SCRATCH_DIR:-$TOP_DIR/.cics-query-scratch}
FIXTURE=$SCRATCH_DIR/query-sample.cbl
CAPTURE_LOG=$SCRATCH_DIR/capture.log

EXPECTED_CAPTURES="command transaction program map mapset"
FAIL_COUNTER=0

report() {
    echo "$1"
}
```

Copy the explicit-status, accumulated-failure style. Use `.sql-query-scratch`, add it idempotently to `.git/info/exclude`, and never modify `.gitignore`.

**Precondition and query invocation pattern** (`run_cics_query_capture.sh:55-73,105-124`):

```bash
if [ -x "$TREE_SITTER" ]; then
    report "STEP 1 (tree-sitter binary): OK - $TREE_SITTER exists and is executable"
else
    report "STEP 1 (tree-sitter binary): FAIL - $TREE_SITTER does not exist or is not executable"
    STEP1_OK=0
fi

( cd "$TOP_DIR" && "$TREE_SITTER" query "$QUERY_FILE" "$FIXTURE" ) > "$CAPTURE_LOG" 2>&1
QUERY_STATUS=$?
...
CAPTURE_COUNT=$(grep -c "capture: .* - $CAPTURE_NAME," "$CAPTURE_LOG")
```

SQL must strengthen the CICS gate. Presence-only assertions are insufficient. Assert exact capture text, count, multiplicity, source spans, and negative cases. D-18 processing must group captures by enclosing `exec_sql_statement`, subtract source candidates whose text matches that statement's CTE definitions, and then compare the exact physical `@table` set for all three CTE cases. Also assert aliases, includes, qualified-name full spans, PREPARE dynamic source, and absence of CTE names, derived aliases, and host variables from physical tables.

All fixture identifiers must be invented and neutral.

---

### `run_accept_differential.sh` (test utility, batch)

**Analog:** existing generic `snapshot` path and isolated `run` path.

**Already-correct public parameterization** (`run_accept_differential.sh:15-45,117-123,171-176`):

```bash
# snapshot <CORPUS_DIR> <OUT_FILE> [NODE_TYPE_REGEX]
DEFAULT_NODE_TYPE_REGEX='accept_statement|idms_accept_statement'

cmd_snapshot() {
    SNAP_CORPUS_DIR="$1"
    SNAP_OUT_FILE="$2"
    SNAP_NODE_TYPE_REGEX="${3:-$DEFAULT_NODE_TYPE_REGEX}"
```

Preserve backward-compatible ACCEPT defaults and the refusal to write inventories under the repository root.

**Current hard-coded gap to fix** (`run_accept_differential.sh:710-743,779-780`):

```bash
run_helper_snapshot() {
    HELPER_BIN="$1"
    HELPER_CORPUS_ROOT="$2"
    HELPER_SELECTED_PATHS="$3"
    HELPER_OUT="$4"
    ...
    "$HELPER_BIN" \
        "$HELPER_CORPUS_ROOT" "$HELPER_ONE_PATH" \
        "$HELPER_FILE_OUT" "$HELPER_STATS" "$PARSE_TIMEOUT_US" \
        '^(accept_statement|idms_accept_statement)$' >/dev/null 2>&1
    ...
    report "snapshot: corpus=$HELPER_CORPUS_ROOT node_type_regex='$DEFAULT_NODE_TYPE_REGEX' out=$HELPER_OUT"
}
```

Thread the caller-selected node regex into `cmd_run`, path selection, both `run_helper_snapshot` calls, helper invocation, and reporting. The SQL run must compare SQL nodes plus collision-sensitive COBOL node types without accidentally using the ACCEPT-only prefilter.

**Parser-cache-safe orchestration** (`run_accept_differential.sh:824-881`):

```bash
WORKTREE_DIR="$RUN_DIFF_TMP/accept-differential-worktree"
...
(cd "$TOP_DIR" && git worktree add --detach "$WORKTREE_DIR" "$RUN_BASELINE_REF")
...
(cd "$WORKTREE_DIR" && "$TREE_SITTER" generate)
...
compile_inventory_helper "$WORKTREE_DIR" "$BASELINE_HELPER"
compile_inventory_helper "$TOP_DIR" "$CURRENT_HELPER"
...
run_helper_snapshot "$BASELINE_HELPER" ... "$BEFORE_OUT"
run_helper_snapshot "$CURRENT_HELPER" ... "$AFTER_OUT"
```

Keep isolated compiled helpers. Do not switch to ordinary CLI cache-based baseline/current parsing.

---

### `run_accept_differential_selftest.sh` (test, batch)

**Analog:** existing synthetic, fast fail/pass harness.

**Scratch isolation and aggregate-result pattern** (`run_accept_differential_selftest.sh:23-33,68-97`):

```bash
ORIG_DIR="$(cd "$(dirname "$0")" && pwd)"
DIFFERENTIAL="$ORIG_DIR/run_accept_differential.sh"

SCRATCH="$(mktemp -d)"
...
trap 'rm -rf "$SCRATCH"' EXIT INT TERM
RETURN_CODE=0

report_case() {
    NUM="$1"; DESC="$2"; EXPECT="$3"; CODE="$4"
    OBSERVED=FAIL
    [ "$CODE" -eq 0 ] && OBSERVED=PASS
    ...
}
```

Add focused proof that a caller-supplied SQL node regex reaches the isolated helper path and appears in reporting, while the omitted argument still uses the ACCEPT default. Keep fixtures synthetic and outside the repository. Do not weaken the existing six compare cases.

---

### `src/parser.c`, `src/grammar.json`, `src/node-types.json` (generated artifacts, transform)

**Analog:** the current generated set; generation is owned by `forest-shim/refresh.sh:91-119`.

```bash
( cd "$TOP_DIR" && "$TREE_SITTER" generate )
...
cp "$TOP_DIR/src/parser.c" "$SHIM_DIR/parser.c"
cp "$TOP_DIR/src/grammar.json" "$SHIM_DIR/grammar.json"
```

Never edit these files manually. Generate after grammar changes and commit generated changes with `grammar.js`, `test/corpus/exec_sql.txt`, and `queries/sql.scm` in the grammar-family commit. `src/node-types.json` must expose every locked public SQL node; `src/grammar.json` must reflect the SQL rules and `_statement`/data-section entry points.

---

### `forest-shim/cobol/parser.c`, `forest-shim/cobol/grammar.json`, `forest-shim/cobol/sql.scm` (vendored provider, transform)

**Analog:** wildcard copy in `forest-shim/refresh.sh:111-144`.

```bash
cp "$TOP_DIR/src/parser.c" "$SHIM_DIR/parser.c"
cp "$TOP_DIR/src/grammar.json" "$SHIM_DIR/grammar.json"

SCM_COPIED=""
for SCM_FILE in "$TOP_DIR"/queries/*.scm; do
    if [ -f "$SCM_FILE" ]; then
        rm -f "$SHIM_DIR/$(basename "$SCM_FILE")"
        cp "$SCM_FILE" "$SHIM_DIR/$(basename "$SCM_FILE")"
        ...
    fi
done
```

No `refresh.sh` edit is expected. Run it to materialize parser/grammar/query copies. `sql.scm` is automatically embeddable because both Go surfaces use the existing wildcard (`forest-shim/cobol/binding.go:25-26`, `plugin.go:25-26`):

```go
//go:embed grammar.json *.scm
var files embed.FS
```

Do not alter `binding.go`, `plugin.go`, or `go.mod`; refresh's drift check requires them to match the forest module cache.

---

### `.github/workflows/fork-checks.yml` (CI config, batch)

**Analog:** current corpus job (`.github/workflows/fork-checks.yml:22-39`).

```yaml
- name: Install lockfile-pinned dependencies
  run: |
    npm_status=0
    npm ci || npm_status=$?
    if ! test -x node_modules/.bin/tree-sitter; then
      echo "tree-sitter-cli is unavailable after npm ci (exit ${npm_status})" >&2
      exit 1
    fi

- name: Generate parser
  run: node_modules/.bin/tree-sitter generate

- name: Run non-comment corpus fixtures
  run: node_modules/.bin/tree-sitter test -e '^comment$'
```

If the SQL query gate is added to CI, place it after generation and corpus testing and invoke `bash run_sql_query_capture.sh`. Preserve the standing comment-fixture exclusion exactly. Do not put estate or cross-repo gates in GitHub CI.

---

### `internal/parser/forest/cobolprobe/cascade_test.go` (cross-repo test, parse traversal)

**Repository:** `/Users/e1001547-mbp-it/repos/mine/GoApps/gortex`

**Analog:** existing `TestErrorCascade` CICS/IDMS cases in the same file.

**Parser setup and recursive counters** (`cascade_test.go:13-45`):

```go
func countAll(t *testing.T, src string) (errs, dataItems, paras, commentEntry int) {
	p := sitter.NewParser()
	defer p.Close()
	p.SetLanguage(sitter.NewLanguage(cobolforest.GetLanguage()))
	tree, err := p.ParseCtx(context.Background(), nil, []byte(src))
	if err != nil || tree == nil {
		t.Fatalf("parse: %v", err)
	}
	defer tree.Close()
	var walk func(n *sitter.Node)
	walk = func(n *sitter.Node) {
		if n.IsError() { errs++ }
		switch n.Type() {
		case "data_description", "data_description_entry":
			dataItems++
		case "paragraph_header":
			paras++
		}
		for i := 0; i < int(n.ChildCount()); i++ { walk(n.Child(i)) }
	}
	walk(tree.RootNode())
	return
}
```

**Immutable control and injection pattern** (`cascade_test.go:51-70,150-163`):

```go
for i := 1; i <= 20; i++ {
	fmt.Fprintf(&data, "       01  WS-FIELD-%02d          PIC X(10).\n", i)
}
for i := 1; i <= 20; i++ {
	fmt.Fprintf(&proc, "       %04d-PARA.\n           MOVE 'X' TO WS-FIELD-01.\n", i)
}
...
if d != 20 || pa != 20 {
	t.Fatalf("clean control moved: got %d data items and %d paragraphs, want 20 and 20", d, pa)
}
```

**Independent parity assertions** (`cascade_test.go:166-203`):

```go
if pa2 != pa {
	t.Errorf("EXEC CICS paren-option after para 1 cascaded: got %d paragraphs, want %d (clean control)", pa2, pa)
}
if d2 != d {
	t.Errorf("EXEC CICS paren-option after para 1 cascaded: got %d data items, want %d (clean control)", d2, d)
}
```

Add representative SQL cases against the same immutable 20/20 control:

- Procedure SQL with a table-bearing statement and unsupported tail, followed by all remaining paragraphs.
- DATA DIVISION declaration markers around ordinary items and INCLUDE adjacent to data items, preserving all 20 data items and all 20 paragraphs.

Use invented neutral identifiers. Assert each SQL shape independently, not against the prior injected shape. This file is cross-repo and must be committed separately in gortex after the refreshed shim is available.

---

### `run_sql_tail_census.sh` / `docs/sql-tail-census.md` (test utility + evidence, batch)

**Analogs:** `run_cics_query_capture.sh` for status accumulation; `run_accept_differential.sh` for owned-scratch corpus traversal and aggregate-only reporting.

**Status accumulation** (`run_cics_query_capture.sh:27-43,105-133`): copy `FAIL_COUNTER`, explicit per-command status checks, and `report()`; no `set -e`.

**Owned scratch and fail-closed denominators** (`run_accept_differential.sh:629-674`): `mktemp`-based scratch owned and removed by the invocation, `find`-based enumeration, an explicit refusal when zero files are selected, and reporting of `discovered_files`/`selected_files` counts only.

**Per-file deadline and aggregate-only output** (`run_accept_differential.sh:710-786`): per-file parser deadline via `$WALL_TIMEOUT_BIN`, periodic progress lines, and a final aggregate line carrying counts and no source text. `docs/sql-tail-census.md` renders exactly these aggregates; it never contains corpus identifiers or paths.

---

### `.githooks/commit-separability.sh` (gate config, batch)

**Analog:** its own alternation list at line 18.

```sh
FORKLOCAL_PATH_RE='^forest-shim/|^docs/|^\.planning/|^\.githooks/|^run_accept_differential|^\.github/workflows/fork-checks\.yml$'
```

Replace only the `^run_accept_differential` alternative with `^run_[a-z_]*\.sh$`. Leave `GRAMMAR_PATH_RE`, the per-commit loop, and the reporting format byte-identical. Prove the change fail-first against a synthetic mixed commit in a throwaway repository.

## Shared Patterns

### Required terminator and recovery containment

**Source:** `grammar.js:2263-2282,2398-2423`

**Apply to:** SQL grammar, SQL corpus, query gate, cascade test.

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

`END_EXEC` is mandatory and outside the fallback. Following periods, data descriptions, and paragraph headers belong to COBOL, not the SQL block.

### Named extraction nodes, not field-only or predicate-based matching

**Sources:** `grammar.js:2321-2352`; `queries/cics.scm:4-8,21-30`; `queries/idms.scm:2-20`.

**Apply to:** table, alias, include, dynamic-source, CTE-definition, and source-candidate nodes.

```scheme
(cics_transaction_name) @transaction
(cics_program_name) @program
```

Gortex's current query runner does not evaluate predicates. Queries must use direct named-node captures.

### D-18 statement-scoped CTE subtraction

**Source analogs:** no prior semantic subtraction implementation; compose the direct-capture query pattern with the exact-assertion shell-gate pattern.

**Apply to:** `grammar.js`, `queries/sql.scm`, `run_sql_query_capture.sh`.

- Grammar emits structured CTE definitions and source candidates.
- Query captures those roles without predicates.
- Gate groups by enclosing `exec_sql_statement` and subtracts candidate names equal to CTE-definition names in that statement only.
- The resulting set, not raw candidates, is asserted as physical `@table` output.
- Include the three locked spike cases before broad SQL grammar work.

### Shell error handling

**Sources:** `run_cics_query_capture.sh:19-22,39-43,105-133`; `forest-shim/refresh.sh:19-24,196-214`.

**Apply to:** SQL query gate and differential changes.

```bash
FAIL_COUNTER=0
command
STATUS=$?
if [ "$STATUS" != "0" ]; then
    FAIL_COUNTER=$((FAIL_COUNTER+1))
fi
...
exit 1  # when FAIL_COUNTER != 0
```

Do not introduce `set -e` or `set -u`. Check each fallible command explicitly and drive the final exit from accumulated failures.

### Generated and vendored artifact flow

**Source:** `forest-shim/refresh.sh:91-144,172-214`.

**Apply to:** `src/*` and `forest-shim/cobol/*` outputs.

1. Generate from `grammar.js`.
2. Copy generated parser/grammar and every `queries/*.scm` into the shim.
3. Rewrite flattened include paths.
4. Preserve Go surface drift checks.
5. Smoke-build last.

### Estate safety and fork separation

**Sources:** `.githooks/estate-guard.sh:4-18,40-45`; `.githooks/commit-separability.sh:4-17`; `.githooks/pre-push:59-109`.

**Apply to:** all fixtures, scripts, generated files, and commits.

```sh
GRAMMAR_PATH_RE='^grammar\.js$|^test/corpus/|^test/idms/|^queries/|^src/'
FORKLOCAL_PATH_RE='^forest-shim/|^docs/|^\.planning/|^\.githooks/|^run_accept_differential|^\.github/workflows/fork-checks\.yml$'
```

- Public fixtures are hand-written with neutral names.
- Corpus-derived inventories and differential scratch data stay outside the repository.
- Keep grammar/generated/corpus/query changes separate from scripts, docs, workflow, and shim changes.
- Keep the gortex test change in the gortex repository's own commit.

### Regression gates

**Sources:** `.github/workflows/fork-checks.yml:31-39`; `run_nist_cobol85.sh:15-41`; `skip_tests.txt:1-12`.

- Generate before corpus tests.
- Run `tree-sitter test -e '^comment$'`.
- NIST must finish with zero failures and exactly 11 skips: `NC205A`, `SM101A`, `SM103A`, `SM105A`, `SM107A`, `SM201A`, `SM203A`, `SM205A`, `SM206A`, `SM208A`, `SM401M`.
- Run SQL query capture, DCC and estate differential, refresh smoke build, gortex `TestErrorCascade`, FORK-02, and FORK-03.

## Existing Files That Should Usually Not Be Modified

| File | Why it matters | Expected action |
|---|---|---|
| `forest-shim/refresh.sh` | Already generates, wildcard-copies all queries, drift-checks, and smoke-builds. | Run it; do not edit unless wildcard delivery fails. |
| `forest-shim/cobol/binding.go` | `//go:embed grammar.json *.scm` already includes `sql.scm`. | No edit. |
| `forest-shim/cobol/plugin.go` | Same wildcard embedding as binding. | No edit. |
| `.githooks/estate-guard.sh` | Existing FORK-02 enforcement covers public-fixture safety. | Run it; no SQL-specific change. |
| `.githooks/commit-separability.sh` | Path families are correct in shape but the fork-local family misses the new root-level `run_*.sh` gates. | Widen `FORKLOCAL_PATH_RE` once in 04-02 Task 3; change nothing else. |
| `.githooks/pre-push` | Already invokes both guards. | No edit. |
| `run_nist_cobol85.sh` | Existing regression runner is sufficient. | Run it and verify exactly 11 skips. |
| `skip_tests.txt` | Locked 11-item baseline. | Do not change. |
| `test/ocesql/src/**/*.cbl` | Coverage evidence only, not public fixture source or syntax authority. | Read/measure only. |

## No Analog Found

No target file lacks a usable repository analog. The only novel behavior is D-18 statement-scoped CTE subtraction, but it is deliberately composed from existing named-node query and fork-local shell-gate patterns rather than introducing a scanner or a new runtime dependency.

## Metadata

**Analog search scope:** `grammar.js`, `test/corpus/`, `queries/`, root shell gates, `forest-shim/`, `.github/workflows/`, `.githooks/`, tracked OCESQL samples, and gortex `internal/parser/forest/cobolprobe/`.

**Primary analog files read:** 18

**Pattern extraction date:** 2026-09-12

**Cross-repo boundary:** `/Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go` is not part of tree-sitter-cobol-upgrade. Update and validate it only in the gortex repository, after refreshing the local forest shim.
