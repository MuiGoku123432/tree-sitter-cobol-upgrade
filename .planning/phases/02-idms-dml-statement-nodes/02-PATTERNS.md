# Phase 2: IDMS DML Statement Nodes - Pattern Map

**Mapped:** 2026-08-29
**Files analyzed:** 8 (4 modified upstream-owned, 2 created upstream-owned, 2 created fork-local)
**Analogs found:** 7 / 8 (1 has no in-repo analog — see "No Analog Found")

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `grammar.js` (four new `*_statement` rules + operand rules) | grammar rule (config/DSL) | transform (source text → AST) | `select_statement` + `mnemonic_name_clause` (grammar.js:423-429, 164-177) | role-match (operand-extraction shape; D-02 departs on fields vs. named nodes) |
| `grammar.js` (`idms_accept_statement` vs `accept_statement` collision) | grammar rule, conflict resolution | transform | `accept_statement` / `_accept_body` (grammar.js:1508-1540) | exact — same rule family, shared prefix |
| `grammar.js` (`idms_unparsed_tail` catch-all) | grammar rule, tail absorber | transform | none in-repo — closest structural precedent is `_add_body`'s `repeat1($._x)` choice list (grammar.js:1584-1601), but no rule in this grammar exists purely to "consume tokens to a boundary" | no analog (see below) |
| `grammar.js` (`_KEYWORD` terminals near line 2831) | config/terminal definition | transform (lexical) | the `_ACCEPT`/`_ACCESS`/`_ADD` block (grammar.js:2830-2845) | exact |
| `src/parser.c`, `src/grammar.json`, `src/node-types.json` | generated artifact | transform (mechanical) | same three files, regenerated after any prior `grammar.js` change | exact (never hand-edited; regenerate via `tree-sitter generate`) |
| `test/corpus/idms_dml.txt` (or per-cluster files) | test fixture | request-response (source → expected s-expression) | `test/corpus/evaluate.txt`, `perform.txt`, `occurs.txt` | exact |
| `queries/idms.scm` | query/config | transform (AST → captures) | `queries/sample.scm` | exact |
| differential shell script (repo root, D-08) | utility/test-runner | batch (parse-and-diff over a corpus) | `run_nist_cobol85.sh` | exact |
| `.github/workflows/fork-checks.yml` | CI config | event-driven (push to `main`) | `.github/workflows/test.yml` (must NOT be modified; sits beside it) | role-match, deliberately not touched |

## Pattern Assignments

### `grammar.js` — four new `idms_*_statement` rules (grammar rule, transform)

**Analog:** `select_statement` (grammar.js:423-429) + `mnemonic_name_clause` (grammar.js:164-177)

**Core operand-extraction pattern** (grammar.js:423-429):
```javascript
select_statement: $ => seq(
  $._SELECT,
  field('optional', optional($.OPTIONAL)),
  field('file_name', $.WORD),
  repeat($._select_clause),
  '.'
),
```

**Field-labelling precedent for choice-based operand selection** (grammar.js:164-177):
```javascript
mnemonic_name_clause: $ => choice(
  seq(
    field('crt', $.WORD),
    optional($._IS),
    $._CRT
  ),
  seq(
    field('word', $.WORD),
    optional($._IS),
    field('value', $.WORD),
    repeat($.special_name_mnemonic_on_off)
  ),
  ...
)
```

**Why this analog is only a partial fit (D-02 departs deliberately):** `select_statement` binds its operand with `field('file_name', $.WORD)` because `file_name` sits at a fixed, shallow depth — a direct child of the rule. IDMS operands (`idms_record_name`, `idms_set_name`) can sit inside a `WITHIN`-clause sub-rule several levels deep, and tree-sitter `field()` only binds direct children of the *declaring* rule, not nested descendants. D-02 therefore makes the operands their own named rules (`idms_record_name: $ => $.WORD`, `idms_set_name: $ => $.WORD`) so `(idms_record_name) @record` matches under any of the four statement types regardless of nesting — copy the *seq/choice/repeat composition style* from `select_statement`, not its `field()`-on-operand technique.

**Boundary/termination precedent — do NOT copy `select_statement`'s trailing `'.'`:** the sibling `_statement`-choice rules actually invoked from `_statement` (`accept_statement` grammar.js:1508, `add_statement` grammar.js:1584, `move_statement` grammar.js:1601) do **not** embed their own terminating period; termination is handled once, centrally, at `_procedure_division_statements_before_header` (grammar.js:1291-1294):
```javascript
_procedure_division_statements_before_header: $ => prec(1, seq(
  repeat($._procedure_division_statement),
  $._end_statement
)),
```
```javascript
move_statement: $ => seq(
  $._MOVE,
  $._move_body
),
```
The new `idms_*_statement` rules must follow this sibling shape (no self-terminating `.`), not `select_statement`'s Environment-Division shape.

**Integration point — `_statement`'s flat `choice()`** (grammar.js:1366-1372, showing the pattern to extend):
```javascript
_statement: $ => choice(
  $.accept_statement,
  $.add_statement,
  $.allocate_statement,
  $.alter_statement,
  $.call_statement,
  $.cancel_statement,
  ... // ~37 entries total; add the four idms_*_statement here
```

---

### `grammar.js` — `idms_accept_statement` vs. `accept_statement` collision (D-05)

**Analog:** `accept_statement` / `_accept_body` (grammar.js:1508-1540) — this is the collision site itself, not an external analog.

**Full existing rule to share a prefix with:**
```javascript
accept_statement: $ => seq(
  $._ACCEPT,
  $._accept_body,
),

_accept_body: $ => prec.right(seq(
  $._identifier,
  choice(
    seq(
      optional($.at_line_column),
      optional($.with_accp_attr),
    ),
    seq(
      $._FROM,
      field('from', choice(
        seq($.ESCAPE, $.KEY),
        $.LINES,
        $.COLUMNS,
        seq($.DATE, optional($.YYYYMMDD)),
        seq($.DAY, optional($.YYYYDDD)),
        $.DAY_OF_WEEK,
        $.TIME,
        $.COMMAND_LINE,
        $.ENVIRONMENT_VALUE,
        $.ENVIRONMENT,
        $.ARGUMENT_NUMBER,
        $.ARGUMENT_VALUE,
        $.MNEMONIC_NAME,
        $.WORD
      ))
    )
  )
)),
```
**The exact hazard (confirmed by direct read):** the `$.WORD` arm inside `field('from', choice(...))` already matches a bare IDMS record name after `FROM`. `ACCEPT WS-DB-KEY FROM CUSTOMER-REC` is a **complete, valid** `accept_statement` per this existing rule before a single character of IDMS grammar is added. The IDMS forms (`... CURRENCY` / `... DB-KEY`) diverge only on the token that follows. Per RESEARCH.md's verified tree-sitter DSL semantics, attempt `prec()`/`prec.right`/`prec.left` at the shared-prefix rule first (draft `idms_accept_statement`, run `tree-sitter generate`, let the CLI's own conflict detector decide) before reaching for `conflicts:` + `prec.dynamic()`.

---

### `grammar.js` — `_KEYWORD` terminal convention (grammar.js:2830-2845)

**Analog:** the `_ACCEPT`/`_ACCESS`/`_ADD`/`_ADDRESS`/... block, immediately confirming CONTEXT.md's cited convention:
```javascript
_WRITE: $ => /[wW][rR][iI][tT][eE]/,
_ACCEPT: $ => /[aA][cC][cC][eE][pP][tT]/,
_ACCESS: $ => /[aA][cC][cC][eE][sS][sS]/,
_ADD: $ => /[aA][dD][dD]/,
_ADDRESS: $ => /[aA][dD][dD][rR][eE][sS][sS]/,
```
Every new DML verb keyword not already defined (`_OBTAIN`, `_FIND`, `_BIND`, `_READY`, `_ERASE`, `_STORE`, `_MODIFY`, `_CONNECT`, `_DISCONNECT`, `_FINISH`, `_COMMIT`, `_ROLLBACK`, `_WITHIN`, `_CALC`, `_OWNER`, `_CURRENCY`, `_DB_KEY` — check which already exist before adding, several COBOL-standard keywords like `_DAY`, `_CURRENT` etc. likely already exist) must follow this exact case-insensitive-regex-per-character shape.

**Correction to CONTEXT.md's cited commented-out marker convention:** a direct grep of `grammar.js` for the `//KEYWORD: $ => $._KEYWORD` commented-out-export pattern (CONTEXT.md's cited "`//ACCEPT: $ => $._ACCEPT,` marker convention") found **no live matches** in the current file — `.planning/codebase/CONVENTIONS.md` documents this pattern as an example (lines 246-253) but it may describe an earlier grammar.js state or a convention that has since been resolved (all such keywords now either exported live or removed). Treat this as an illustrative, not currently-verifiable, convention — do not assume a `//ACCEPT:`-style line exists at grammar.js:2831 to uncomment; verify directly before writing a plan task that references it.

---

### `test/corpus/idms_dml.txt` (or per-cluster files) — fixture (test, request-response)

**Analog:** `test/corpus/evaluate.txt` — full source/`---`/expected-s-expression convention, read in full:
```
====================================
evaluate when
====================================
       identification division.
       program-id. a.
       procedure division.
       evaluate 1
       when 1
         go to aa
       end-evaluate.
       aa.
---

(start
  (program_definition
    (identification_division
      (program_name))
    (procedure_division
      (evaluate_header
        (evaluate_subject
          (expr
            (number
              (integer)))))
      (when
        (expr
          (number
            (integer))))
      (goto_statement
        to: (label
          (qualified_word
            (WORD))))
      (END_EVALUATE)
      (period)
      (paragraph_header))))
```
Each fixture case is delimited by a `====...====` title line, the raw COBOL source, a `---` separator, then the exact expected s-expression tree (field names shown as `label:`). New IDMS fixtures must follow this exact structure, one case per verb-format combination (per D-09's minimal-to-edges option set), using invented neutral names (`CUSTOMER-REC`, `CUST-ORDER-SET`) per D-10 — never estate-derived names.

---

### `queries/idms.scm` — extraction query (query/config, transform)

**Analog:** `queries/sample.scm` — the repo's only existing query, full contents:
```scheme
(
  (move_statement
     src: (_)
     dst: (qualified_word) @first-dst)
  .
  (move_statement
     src: (_)
     dst: (qualified_word) @second-dst)
  (#eq? @first-dst @second-dst)
)
```
This demonstrates the repo's only precedented query idiom: field-based capture (`src:`, `dst:`) plus a `#eq?` predicate comparing two captures. D-04's `idms.scm` departs from the field-based capture style (since D-02 uses named nodes, not fields, for the operands) but should still follow the surrounding `.scm` file conventions — one query per statement-shape, `@name`-suffixed captures. No `#eq?`-style predicate is needed for `idms.scm` since it is pure extraction, not a cross-statement comparison.

**Downstream delivery path (read, not edited, by this fork):** `forest-shim/cobol/sample.scm` mirrors `queries/sample.scm` inside the shim directory, confirming `queries/` is carried through to `forest-shim/cobol/` (and from there to gortex) by the existing `forest-shim/refresh.sh` pipe — `idms.scm` will need the same carry-through, but no changes to `refresh.sh` itself are indicated by CONTEXT.md. Note: `forest-shim/cobol/_keep.scm` exists but is **empty** (0 bytes) — it is a placeholder/marker file, not a pattern source.

---

### Differential shell script (repo root, D-08) — utility (batch)

**Analog:** `run_nist_cobol85.sh` (full file, 43 lines) — the exact convention this script must match (committed, re-runnable, shell, repo root):
```bash
TOP_DIR=./
COBOL85_TEST_SRC_DIR=$TOP_DIR/test/cobol85/src
COBOL85_TEST_RESULT_SUMMARY=$TOP_DIR/test/cobol85/summary.txt
COBOL85_TEST_RESULT_DIR=$TOP_DIR/test/cobol85/result
TREE_SITTER=$TOP_DIR/node_modules/.bin/tree-sitter
SKIP_TEST_CASES_FILE=$TOP_DIR/skip_tests.txt

rm -f $COBOL85_TEST_RESULT_SUMMARY
mkdir -p ./test/cobol85/result
rm -f $COBOL85_TEST_RESULT_DIR/*.txt
TEST_TOTAL_COUNTER=0
TEST_SUCCESS_COUNTER=0
TEST_FAIL_COUNTER=0
TEST_SKIP_COUNTER=0
for file in $(ls $COBOL85_TEST_SRC_DIR/*.CBL | sort); do
    FILE_NAME=$(basename $file)
    FILE_NAME_BODY=$(basename $file .CBL)

    cat $SKIP_TEST_CASES_FILE | grep $FILE_NAME_BODY > /dev/null
    if [ $? = "0" ]; then
        TEST_SKIP_COUNTER=$((TEST_SKIP_COUNTER+1))
        TEST_TOTAL_COUNTER=$((TEST_TOTAL_COUNTER+1))
        continue
    fi

    $TREE_SITTER parse $file > $COBOL85_TEST_RESULT_DIR/$FILE_NAME_BODY.txt
    if [ $? = "0" ]; then
        TEST_SUCCESS_COUNTER=$((TEST_SUCCESS_COUNTER+1))
        echo $(basename $file) OK | tee -a $COBOL85_TEST_RESULT_SUMMARY
    else
        TEST_FAIL_COUNTER=$((TEST_FAIL_COUNTER+1))
        echo $(basename $file) "<NG>" | tee -a $COBOL85_TEST_RESULT_SUMMARY
    fi
    TEST_TOTAL_COUNTER=$((TEST_TOTAL_COUNTER+1))
done
echo "${TEST_TOTAL_COUNTER} tests. (Success: ${TEST_SUCCESS_COUNTER}, Fail: ${TEST_FAIL_COUNTER}, Skip: ${TEST_SKIP_COUNTER})" | tee -a $COBOL85_TEST_RESULT_SUMMARY

if [ ${TEST_FAIL_COUNTER} != 0 ]; then
    exit 1
else
    exit 0
fi
```
Pattern to copy: top-of-file variable block naming paths, a per-file loop invoking `$TREE_SITTER <subcommand>` and redirecting output, a running counter tally, a final summary `echo` + `tee`, and a nonzero exit code on any failure. The differ script's job differs (before/after diff on two parses of the same corpus rather than a single-parse pass/fail count) but the shape — path variables, per-file loop, tallied counters, summary line, exit-code gate — is this repo's established idiom for a corpus-wide shell harness. **Constraint on this file's own construction:** it must never read, copy, or embed `estate/` or `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` file *contents* into the script itself — only invoke the CLI against those paths as arguments (as `run_nist_cobol85.sh` does with `test/cobol85/src`, a tracked, non-proprietary directory).

---

### `.github/workflows/fork-checks.yml` — CI config (event-driven)

**Analog referenced but NOT to be copied verbatim — must sit beside, not replace:** `.github/workflows/test.yml` (full file read, 80 lines). Confirmed by direct read: the `tree-sitter test` step is present in commented-out form only:
```yaml
          #- name: Run tests
          #  run: node_modules/.bin/tree-sitter test
```
and the whole file otherwise runs `npm install` → `tree-sitter generate` → `sh run_nist_cobol85.sh` on every push/PR, gated behind a `check-workflows` job. **This confirms RESEARCH.md's finding directly:** CI today asserts NIST parses cleanly but does **not** run the 13 corpus fixtures at all — the commented-out step is inert. `fork-checks.yml` is therefore not "adding a second gate" but "adding the first one" for `tree-sitter test`. It must be a new, separate file — D-11 explicitly forbids uncommenting/editing `test.yml` itself (FORK-03: that file is upstream-owned). The new file should trigger only on `main` (unlike `test.yml`'s `push`/`pull_request`), and its `tree-sitter test` invocation must use `-e '^comment$'` (verified this session per RESEARCH.md: exit 0 with the filter vs. exit 1 without) to exclude the pre-existing, upstream-rooted `comment` fixture failure, with a comment pointing at upstream commit `4bc6ff5` and `.planning/WINDOWS.md`.

## Shared Patterns

### Case-insensitive keyword regex
**Source:** `grammar.js:2830-2845` (`_WRITE`, `_ACCEPT`, `_ACCESS`, `_ADD`, `_ADDRESS`, ...)
**Apply to:** every new IDMS DML verb/clause keyword terminal.
```javascript
_ACCEPT: $ => /[aA][cC][cC][eE][pP][tT]/,
```

### No self-terminating period on `_statement`-choice members
**Source:** `move_statement` (grammar.js:1601-1605), `add_statement` (grammar.js:1584-1587) — termination centralized at `_procedure_division_statements_before_header` (grammar.js:1291-1294).
**Apply to:** all four new `idms_*_statement` rules — do not append `'.'` inside the rule itself.

### Named-node operand extraction (not `field()`) for deeply-nested operands
**Source:** D-02's departure from `select_statement`'s `field('file_name', $.WORD)` shallow-depth pattern.
**Apply to:** `idms_record_name`, `idms_set_name` — defined as their own rules (`idms_record_name: $ => $.WORD`), referenced as plain children wherever they occur in any of the four statement rules, at any depth.

### Corpus fixture format
**Source:** `test/corpus/evaluate.txt`, `perform.txt`, `occurs.txt` — title / source / `---` / s-expression.
**Apply to:** `test/corpus/idms_dml.txt` (or per-cluster split, planner's discretion).

### Generated artifacts are committed, never hand-edited
**Source:** `.planning/codebase/ARCHITECTURE.md` (cited in CONTEXT.md; not re-quoted here since it is a project doc, not a code file) — `src/parser.c`, `src/grammar.json`, `src/node-types.json`.
**Apply to:** any commit touching `grammar.js` must include a `tree-sitter generate` regeneration of these three files in the same commit.

## No Analog Found

| File/Rule | Role | Data Flow | Reason |
|---|---|---|---|
| `idms_unparsed_tail` catch-all rule | grammar rule, tail absorber | transform | Searched `grammar.js` for any rule whose purpose is "consume an arbitrary token run up to a statement boundary" (i.e., a generic catch-all). None exists. The closest structural neighbor is `_add_body`'s `repeat1($._x)`/`repeat1($.arithmetic_x)` choice lists (grammar.js:1584-1601) and the `_x` rule's own recursive-choice shape (grammar.js:1601 onward), but both enumerate *specific* semantic alternatives (`_LENGTH`, `_ADDRESS`, literals, identifiers) rather than acting as an unbounded absorber. `scanner.c` (the external scanner, `forest-shim/cobol/scanner.c` in the vendored copy) is confirmed by `.planning/codebase/ARCHITECTURE.md` to handle only whitespace/comments/multiline strings — it has never been extended for an "absorb-a-tail" purpose in this fork's history. This absence is itself the finding: `idms_unparsed_tail` will be a **new grammar idiom** for this codebase, not a copy of an existing pattern. RESEARCH.md's own recommendation (a pure-grammar `repeat(choice($.WORD, $.integer, $._LITERAL, '(', ')', ','))` bounded at the literal `.`) should be treated as a from-first-principles design, validated against drafted fixtures, not as "matching an existing rule." |

## Metadata

**Analog search scope:** `grammar.js` (full-file targeted greps + 6 non-overlapping `sed`/`Read` ranges: lines 415-435, 1285-1350, 1360-1372, 1500-1545, 1580-1615, 2210-2240, 2820-2845), `queries/` (`sample.scm`), `forest-shim/cobol/` (`_keep.scm`, `sample.scm` presence only), `test/corpus/*.txt` (directory listing + `evaluate.txt` full read), `run_nist_cobol85.sh` (full read), `.github/workflows/test.yml` and `check-workflows.yml` (directory listing + `test.yml` full read), `.planning/codebase/CONVENTIONS.md` (full read).
**Files scanned:** ~14 distinct files/ranges, 3-5 strong analogs per new-file group (stopped per early-stopping rule).
**Pattern extraction date:** 2026-08-29
**Excluded from search per task constraint:** `estate/`, `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` — not read, quoted, or paraphrased.
