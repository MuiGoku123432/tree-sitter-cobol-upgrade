# Testing Patterns

**Analysis Date:** 2026-08-28

## Test Framework Overview

This project uses two complementary testing approaches:

1. **Corpus Tests** - Unit tests for grammar rules using tree-sitter's built-in test format
2. **NIST COBOL-85 Conformance Tests** - Integration tests using standardized COBOL programs

Both run via command line; no Jest/Vitest. CI/CD automated via GitHub Actions.

## Corpus Tests

### Test Framework

**Runner:**
- `tree-sitter test` command (from tree-sitter CLI)
- Configured in `.github/workflows/test.yml` (step: "Run NIST COBOL85 tests")
- Also runnable locally via `npm test`

**Test Files Location:**
- `test/corpus/*.txt` directory
- 13 test files covering core COBOL features and edge cases

### Test File Format

**Structure:**
All corpus tests follow a strict three-part format:

```
====================================
Test Name
====================================

COBOL source code here
lines of valid or invalid COBOL

---

(start
  (parse_tree_as_s_expression
    (nested_nodes)
    (expected_structure)))
```

**Parts:**
1. **Header** - Single line of `=` (28+ characters) followed by test name on next line, then another `=` line
2. **Input Section** - Raw COBOL source code (actual syntax being tested)
3. **Separator** - Three dashes: `---`
4. **Expected Output** - S-expression representation of the parse tree (what tree-sitter should produce)

### Real Example: minimal-cobol.txt

```
====================================
Minimal COBOL program
====================================

       identification division.
       program-id. a.
       procedure division.
       stop run.
       stop run.

---

(start
  (program_definition
    (identification_division
      (program_name))
    (procedure_division
      (stop_statement)
      (period)
      (stop_statement)
      (period))))
```

**Key observations:**
- Input shows indentation common in legacy COBOL (column-aligned)
- Parse tree is fully normalized S-expression with named nodes
- `period` is explicit in tree (end-of-statement terminator)
- Multiple statements parsed correctly even with repetition

### Real Example: perform.txt

```
====================================
perform label FOREVER
====================================

       identification division.
       program-id. a.
       procedure division.
       perform aa forever.
       aa.

---

(start
  (program_definition
    (identification_division
      (program_name))
    (procedure_division
      (perform_statement_call_proc
        procedure: (perform_procedure
          (label
            (qualified_word
              (WORD))))
        option: (perform_option
          (FOREVER)))
      (period)
      (paragraph_header))))
```

**Key observations:**
- `field()` labels appear as `name:` syntax in S-expression output
- Nested structures show call hierarchy (perform_statement_call_proc → perform_procedure → label)
- Keyword tokens like `FOREVER` appear explicitly in tree
- Paragraph definition (`aa.`) creates `paragraph_header` node

### Coverage by Test File

| File | Focus |
|------|-------|
| `minimal-cobol.txt` | Basic program structure (identification, procedure divisions) |
| `comment.txt` | Comment handling and inline comments |
| `data_description.txt` | Data division, file section, working storage, picture clauses |
| `file.txt` | File/FD definitions and file-related clauses |
| `select.txt` | SELECT statements and file control clauses |
| `source-object-computer.txt` | Environment division computer specifications |
| `perform.txt` | PERFORM statement variations (THRU, FOREVER, labels) |
| `evaluate.txt` | EVALUATE (case/switch) statements and WHEN branches |
| `goto.txt` | GO TO and paragraph jumps |
| `pic_9.txt` | Numeric picture clauses (various formats) |
| `pic_x.txt` | Alphanumeric picture clauses |
| `occurs.txt` | OCCURS clause and array-like structures |
| `redefines.txt` | REDEFINES clause for data overlays |

### Running Corpus Tests

**Local execution:**
```bash
npm test
# or
node_modules/.bin/tree-sitter test
```

**Output:**
- Passes silently; failures print detailed diff between expected and actual parse tree
- Fails CI if any corpus test fails

**What Each Test Does:**
1. Parses COBOL source code using the grammar defined in `grammar.js`
2. Produces an S-expression parse tree
3. Compares against expected output
4. Reports pass/fail with diffs on failure

## NIST COBOL-85 Conformance Tests

### Test Framework

**Approach:**
- Shell script harness: `run_nist_cobol85.sh`
- Uses `tree-sitter parse <file>` to parse each COBOL program
- Doesn't validate compiler output; only validates that parser doesn't crash and produces a tree
- Success = exit code 0 from tree-sitter (parse completed without fatal error)

**Test Corpus:**
- Location: `test/cobol85/src/*.CBL` (382 COBOL-85 program files)
- Source: NIST standardized test suite from "ON-SITE VALIDATION, NATIONAL INSTITUTE OF STD & TECH"
- Programs test specific COBOL features per their naming convention

### Test File Naming Convention

NIST test programs follow a scheme: `[PREFIX][FEATURE_NUMBER][VARIANT].CBL`

**Examples:**
- `NC101A.CBL` - NC (NIST COBOL) prefix, feature 1, variant A
- `IC201A.CBL` - IC category, feature 2, variant A
- `SM103A.CBL` - SM category, feature 1, variant A
- `SG204A.CBL` - SG category, feature 2, variant A

**Test Categories (prefixes):**
- `NC` - Core NIST tests
- `IC` - Intermediate COBOL features
- `SM` - Special/Module features
- `SG` - Special group/advanced features

### Skip List

**File:** `skip_tests.txt`

**Current Skip List (11 tests):**
```
NC205A
SM101A
SM103A
SM105A
SM107A
SM201A
SM203A
SM205A
SM206A
SM208A
SM401M
```

**What This Means:**
- These tests are known to fail with the current grammar
- Parser either crashes, produces incorrect tree, or is fundamentally incompatible with the test
- Skipped tests are excluded from test results to avoid CI failures
- Represents a gap in COBOL-85 compliance coverage

**Example of Skipped Test:**
`NC205A.CBL` - Likely tests a feature not yet implemented (based on missing implementation comments in `grammar.js`)

### Running NIST Tests

**Local execution:**
```bash
npm run nist
# or
sh run_nist_cobol85.sh
```

**Script Flow (`run_nist_cobol85.sh`):**

```bash
# 1. Setup
for file in $(ls test/cobol85/src/*.CBL | sort); do
  FILE_NAME_BODY=$(basename $file .CBL)

  # 2. Check skip list
  cat skip_tests.txt | grep $FILE_NAME_BODY > /dev/null
  if [ $? = "0" ]; then
    TEST_SKIP_COUNTER=$((TEST_SKIP_COUNTER+1))
    continue
  fi

  # 3. Run parse
  tree-sitter parse $file > test/cobol85/result/$FILE_NAME_BODY.txt
  if [ $? = "0" ]; then
    TEST_SUCCESS_COUNTER=$((TEST_SUCCESS_COUNTER+1))
    echo "$FILE_NAME OK" | tee -a test/cobol85/summary.txt
  else
    TEST_FAIL_COUNTER=$((TEST_FAIL_COUNTER+1))
    echo "$FILE_NAME <NG>" | tee -a test/cobol85/summary.txt
  fi
  TEST_TOTAL_COUNTER=$((TEST_TOTAL_COUNTER+1))
done

# 4. Report results
echo "${TEST_TOTAL_COUNTER} tests. (Success: ${TEST_SUCCESS_COUNTER}, Fail: ${TEST_FAIL_COUNTER}, Skip: ${TEST_SKIP_COUNTER})"
exit 0 if TEST_FAIL_COUNTER == 0 else exit 1
```

**Output:**
- Parsing results written to `test/cobol85/result/*.txt` (parse trees)
- Summary written to `test/cobol85/summary.txt`
- Format: `FILENAME OK` or `FILENAME <NG>`
- Final line: `N tests. (Success: X, Fail: Y, Skip: Z)`
- Exits with code 1 if any failures, code 0 if all pass or only skips

**Sample Output:**
```
NC101A.CBL OK
NC102A.CBL OK
...
NC205A.CBL (skipped by skip_tests.txt)
...
382 tests. (Success: 371, Fail: 0, Skip: 11)
```

### Real Test File Structure

**Example from `test/cobol85/src/NC101A.CBL` (first 50 lines):**

```cobol
000100 IDENTIFICATION DIVISION.                                         NC1014.2
000200 PROGRAM-ID.                                                      NC1014.2
000300     NC101A.                                                      NC1014.2
000400****************************************************************  NC1014.2
000500*                                                              *  NC1014.2
000600*    VALIDATION FOR:-                                          *  NC1014.2
000700*                                                              *  NC1014.2
000800*    "ON-SITE VALIDATION, NATIONAL INSTITUTE OF STD & TECH.    ".NC1014.2
000900*                                                              *  NC1014.2
001000*    "COBOL 85 VERSION 4.2, Apr  1993 SSVG                      ".NC1014.2
001100*                                                              *  NC1014.2
001200****************************************************************  NC1014.2
001300*                                                              *  NC1014.2
001400*      THIS PROGRAM TESTS THE FORMAT 1 MULTIPLY STATEMENT...    *  NC1014.2
001500*      IN LEVEL 1.  ALL COMBINATIONS OF OPTIONAL PHRASES...     *  NC1014.2
...
003300 ENVIRONMENT DIVISION.                                            NC1014.2
003400 CONFIGURATION SECTION.                                           NC1014.2
003500 SOURCE-COMPUTER.                                                 NC1014.2
003600     Linux.                                                       NC1014.2
003700 OBJECT-COMPUTER.                                                 NC1014.2
003800     Linux.                                                       NC1014.2
003900 INPUT-OUTPUT SECTION.                                            NC1014.2
004000 FILE-CONTROL.                                                    NC1014.2
004100     SELECT PRINT-FILE ASSIGN TO "report.log".                    NC1014.2
004300 DATA DIVISION.                                                   NC1014.2
004400 FILE SECTION.                                                    NC1014.2
004500 FD  PRINT-FILE.                                                  NC1014.2
004600 01  PRINT-REC PICTURE X(120).                                    NC1014.2
004800 WORKING-STORAGE SECTION.                                         NC1014.2
004900 77  WRK-DS-18V00                PICTURE S9(18).                  NC1014.2
```

**Key observations:**
- Uses traditional COBOL fixed-form format (columns 1-72 for code, 73+ for reference)
- Extensive comments documenting what feature is being tested
- Standard COBOL program structure (IDENTIFICATION, ENVIRONMENT, DATA, PROCEDURE divisions)
- Reference numbers in rightmost columns (e.g., `NC1014.2`)

## CI/CD Integration

### GitHub Actions Workflow

**File:** `.github/workflows/test.yml`

**Triggers:**
- On every push to any branch
- On every pull request

**Test Steps:**
```yaml
- name: npm install
  run: npm install

- name: Generating a parser
  run: |
    node_modules/.bin/tree-sitter init-config
    node_modules/.bin/tree-sitter generate

- name: Run NIST COBOL85 tests
  run: sh run_nist_cobol85.sh
```

**What happens:**
1. Install dependencies (`tree-sitter-cli` from package.json)
2. Generate parser from `grammar.js` (produces `src/parser.c`, `src/grammar.json`)
3. Run NIST tests via shell script (exit code determines pass/fail)

**Failure Behavior:**
- If any step fails (non-zero exit code), workflow fails and blocks merge
- NIST test script returns 1 if any test fails (excluding skips)
- No separate corpus test step in CI (corpus tests can be run locally via `npm test`)

### Sample Workflow Run Output

```
Run npm install
added X packages in Y seconds

Run Generating a parser
Outputs to /src/parser.c, /src/grammar.json

Run NIST COBOL85 tests
NC101A.CBL OK
NC102A.CBL OK
...
382 tests. (Success: 371, Fail: 0, Skip: 11)
✓ Workflow passed
```

## Test Execution Commands

### npm Scripts

**File:** `package.json`

| Script | Command | Purpose |
|--------|---------|---------|
| `npm test` | `tree-sitter test` | Run corpus tests locally |
| `npm run nist` | `sh run_nist_cobol85.sh` | Run NIST COBOL-85 suite locally |
| `npm run build` | `tree-sitter generate && node-gyp build` | Regenerate parser and compile bindings |
| `npm run sample` | `tree-sitter parse test/cobol85/src/SG204A.CBL` | Parse a single sample file |
| `npm run t` | `tree-sitter parse a.cbl` | Quick parse of local `a.cbl` |
| `npm run c` | `cobc -fsyntax-only a.cbl` | Validate local `a.cbl` with GnuCOBOL compiler |
| `npm run ct` | `cd test && bash check_tests.sh` | Run custom test suite (not automated in CI) |

### Manual Test Runs

**Parse a single file:**
```bash
tree-sitter parse test/cobol85/src/NC101A.CBL
# Output: S-expression parse tree to stdout
```

**Parse and save output:**
```bash
tree-sitter parse test/cobol85/src/NC101A.CBL > parse_result.txt
```

**Run only corpus tests:**
```bash
npm test
# tree-sitter scans test/corpus/*.txt and validates each one
```

## Test Coverage

### Corpus Test Coverage

**What's tested:**
- Grammar rule coverage: 13 corpus files test major COBOL language features
- Parse tree structure: Each corpus test validates output node names, field labels, and hierarchy
- Edge cases: Comments, minimal programs, repeated statements

**What's NOT explicitly tested:**
- Semantic validation (type checking, scope checking)
- Runtime behavior
- Compiler warnings/errors
- Performance characteristics

### NIST Test Coverage

**What's tested:**
- 371 real COBOL-85 programs (from standardized test suite)
- Covers language features across different complexity levels
- Includes file I/O, arithmetic, control flow, data descriptions
- Tests proper parsing without crashes

**What's NOT tested:**
- Code execution (parser only, no runtime)
- Semantic correctness (tree structure alone doesn't validate logic)
- 11 known-failing tests excluded via skip list

**Coverage Gaps (Skipped Tests):**
- 11 NIST tests currently fail (listed in `skip_tests.txt`)
- Represent incomplete feature coverage in the grammar
- Blocking issues noted in `grammar.js` with `//todo` comments

## Test Quality Patterns

### Corpus Test Pattern

**Minimal valid case:**
```
====================================
Test Name
====================================

       identification division.
       program-id. a.
       [feature being tested]

---

(start (program_definition ...))
```

**Multiple variants in one file:**
- Many corpus files contain 2-4 test cases separated by headers
- Each variant shows different usage of the same feature

### NIST Test Pattern

**Standard program structure:**
- Header comments describing what's being tested
- Full IDENTIFICATION, ENVIRONMENT, DATA, PROCEDURE divisions
- Real file I/O and complex logic
- Tests integration of multiple features

**Failure modes:**
- If parser crashes: test marked as failed
- If parse tree is incorrect: test passes (parser doesn't validate semantics)
- If skip list matches: test skipped (not counted as failure)

## Debugging Test Failures

### Corpus Test Failure

**Symptom:** `npm test` fails with diff output

**Example failure output:**
```
✗ [test/corpus/file.txt] file-section

Expected:
  (start (program_definition (identification_division ...)))

Actual:
  (start (program_definition (identification_division ...)))
  [diff showing mismatch]
```

**Debug steps:**
1. Open `test/corpus/[file].txt` and locate failing test case (multiple per file)
2. Review the COBOL input section (before `---`)
3. Review the expected output (after `---`)
4. Run: `tree-sitter parse <sample_file>` to see actual output
5. Compare parse trees to identify which grammar rule is wrong
6. Check `grammar.js` for the matching rule and fix it

### NIST Test Failure

**Symptom:** `npm run nist` fails with `<NG>` in output summary

**Example failure output:**
```
NC205A.CBL <NG>
382 tests. (Success: 371, Fail: 1, Skip: 11)
```

**Debug steps:**
1. Identify the failing test file: `test/cobol85/src/NC205A.CBL`
2. Check if it's a known failure: `grep NC205A skip_tests.txt`
   - If found, add to skip list: `echo NC205A >> skip_tests.txt`
   - Otherwise, investigate the parse error
3. Run parse to see error: `tree-sitter parse test/cobol85/src/NC205A.CBL`
4. Review COBOL source and identify what feature causes parser failure
5. Check `grammar.js` for missing rule or conflict
6. Update grammar and regenerate: `npm run build`
7. Re-run NIST tests: `npm run nist`

---

*Testing analysis: 2026-08-28*
