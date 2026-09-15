# Codebase Concerns

**Analysis Date:** 2026-08-28

## Tech Debt

**Deprecated NAN binding library:**
- Issue: `bindings/node/` uses `nan` (v2.22.0) for Node.js native bindings, which is deprecated in favor of node-addon-api or Node-API
- Files: `bindings/node/binding.cc`, `binding.gyp`, `package.json` (dependency), `bindings/node/index.js`
- Impact: Limits forward compatibility with future Node.js versions; NAN maintenance is inactive; newer projects are moving to native Node-API
- Fix approach: Migrate binding to use `node-addon-api` or native Node-API; this requires rewriting `bindings/node/binding.cc` and updating `binding.gyp` to reference the new headers

**Incomplete grammar implementation:**
- Issue: Multiple `//todo` comments throughout `grammar.js` indicate unfinished features and placeholder implementations
- Files: `grammar.js` (lines 38, 50, 51, 446, 1033, 1064, 1236, 1860, 2792, 3093)
- Impact: Certain COBOL85 language constructs may not parse correctly; commented-out code suggests abandoned attempts (see line 2630-3403, entire block of comparison operators disabled)
- Fix approach: Each TODO should be prioritized based on NIST test coverage; the disabled comparison operators (lines 1983-1989) need investigation — why are they disabled?

**Large, single-file grammar:**
- Issue: `grammar.js` is 3783 lines / 104KB in a single file with numerous nested rules, multiple precedence declarations, and commented-out sections
- Files: `grammar.js`
- Impact: Difficult to maintain; hard to identify which rules interact; refactoring risks breaking precedence; test failures are hard to trace to specific rule changes
- Fix approach: Consider splitting grammar.js into modules (division-specific grammars, shared rules) if tree-sitter supports it; establish a style guide for rule organization and precedence

**Commented-out test harness:**
- Issue: CI workflow has substantial commented-out test infrastructure (lines 30-79 in `.github/workflows/test.yml`), including the actual test verification step (`check_tests.sh`)
- Files: `.github/workflows/test.yml`
- Impact: NIST test results are generated but CI doesn't fail if tests fail — shell script exit code is relied upon but CI output artifact upload is disabled; developers won't see test results in CI logs
- Fix approach: Uncomment and re-enable the artifact upload; uncomment and fix the test verification harness; ensure CI fails visibly on test failures

---

## Known Bugs

**Typo in external scanner:**
- Symptoms: Potential parsing issues for COBOL IDENTIFICATION DIVISION comment entries containing "installation" keyword
- Files: `src/scanner.c` (line 24)
- Trigger: When comment entry contains "installlation" (misspelled with 3 L's instead of 2)
- Current state: The keyword array has `"installlation"` instead of `"installation"`, which may not match standard COBOL comment entry keywords
- Fix approach: Correct typo to `"installation"` in the `any_content_keyword` array

---

## Security Considerations

**No security policy or disclosure process:**
- Risk: No SECURITY.md or documented process for reporting security issues; active parser development means potential memory safety issues in scanner.c and generated parser.c are untracked
- Files: Root directory (missing SECURITY.md)
- Current mitigation: MIT license includes limitation of liability; external scanner uses relatively simple state machine
- Recommendations: Add SECURITY.md with responsible disclosure process; consider formal code audit of scanner.c and parser.c memory handling

**Manual C memory management in external scanner:**
- Risk: `src/scanner.c` uses raw C lexer API without bounds checking on some operations
- Files: `src/scanner.c` (lines 34-89, particularly the `start_with_word` function with manual pointer arithmetic)
- Current mitigation: Tree-sitter framework manages lexer lifetime; scanner is relatively simple (~200 lines)
- Recommendations: Add comments documenting lexer API contract; consider fuzzing against malformed COBOL files

---

## Performance Bottlenecks

**Generated parser size:**
- Problem: `src/parser.c` is 825,788 lines (31 MB), generated from grammar.js; this is typical for tree-sitter but impacts build time and binary size
- Files: `src/parser.c`, `src/grammar.json`, `src/node-types.json`
- Cause: Grammar is comprehensive COBOL85 standard; tree-sitter generates a shift-reduce parser for every rule
- Improvement path: Monitor build time; consider splitting grammar or profiling parser performance on large COBOL files

---

## Fragile Areas

**Scanner state machine edge cases:**
- Files: `src/scanner.c`
- Why fragile:
  - Variable-length arrays on stack (lines 39-40) — `char *keyword_pointer[number_of_words]` and `bool continue_check[number_of_words]` — not all C compilers support C99 VLAs well; GCC does, Clang does, but older compilers and some embedded toolchains don't
  - Hardcoded line column limits (71 for data area, 72 for suffix comments) — COBOL fixed-form format is strictly defined but any deviation causes silent parsing failures
  - Manual pointer advancement with `iswspace()` and `towupper()` locale-dependent behavior on non-ASCII COBOL source
- Safe modification: Add assertions for `number_of_words <= 16` to prevent stack overflow; consider replacing VLAs with fixed-size arrays or dynamic allocation
- Test coverage: No unit tests for scanner.c; NIST test suite indirectly tests it, but specific edge cases (malformed comments, boundary conditions at column 71-72, non-ASCII characters) are not isolated

**Precedence rules in expression parsing:**
- Files: `grammar.js` (lines 1968-1990, 2017-2049)
- Why fragile: Multiple precedence levels for arithmetic and comparison operators; commented-out comparison operators suggest prior conflicts; any grammar change to operator rules risks parsing ambiguity
- Safe modification: Before changing operator precedence, run full NIST test suite; review tree-sitter conflict report from `tree-sitter generate`
- Test coverage: No specific unit tests for operator precedence; only verified indirectly through NIST tests

---

## Scaling Limits

**Test execution scale:**
- Current capacity: 382 NIST COBOL85 tests; runtime ~seconds to minutes depending on parser complexity
- Limit: Each new grammar rule increases parser.c size; very large COBOL programs may exceed recursion limits in tree-sitter's incremental parser
- Scaling path: Profile parser performance on 10K+ line COBOL programs; consider streaming parse or incremental refresh if latency becomes issue

---

## Dependencies at Risk

**NAN (deprecated):**
- Risk: `nan` package is no longer actively maintained (last update 2024); Node.js releases break compatibility periodically
- Impact: Node.js 21+ may not work with current NAN version; npm audit flags it as deprecated
- Migration plan: Replace with `node-addon-api` (current, maintained by Node.js Foundation) — requires rewrite of `bindings/node/binding.cc`

**tree-sitter-cli version drift:**
- Risk: Package.json specifies `^0.24.5` (as of current HEAD commit e99dbdc), but newer commits have bumped to `^0.25.3`; working tree is out of sync with main
- Impact: Generated parser.c may not match latest tree-sitter features/bug fixes; build reproducibility concerns if developers clone at different times
- Mitigation: Working tree is at known commit (e99dbdc); Cargo.toml pins tree-sitter ~0.20.3 for Rust bindings (separate concern)

---

## Missing Critical Features

**No queries beyond basic highlights:**
- Problem: `queries/` directory only contains `sample.scm` (183 bytes) with minimal syntax highlighting rules; published tree-sitter packages typically include:
  - `highlights.scm` — comprehensive highlighting for all node types
  - `folds.scm` — code folding hints (function definitions, blocks)
  - `indents.scm` — indentation rules
  - `locals.scm` — local binding tracking (scope, definitions, references)
- Blocks: IDE integrations cannot provide robust syntax highlighting, folding, or smart indentation
- Fix approach: Generate query files from grammar.js node-types; prioritize highlights.scm (lowest effort, highest value)

**No binding tests:**
- Problem: `bindings/node/` has no test file; index.js has untested fallback logic (lines 7-13) for Debug vs Release builds
- Blocks: Node.js users have no verification that the binding works; build variations are untested
- Fix approach: Add `bindings/node/test.js` with basic sanity checks (load module, call parser, verify result type)

**No CONTRIBUTING.md:**
- Problem: No documented contribution process, coding standards, or commit conventions
- Blocks: External contributors cannot easily submit PRs; maintainers must infer intent from code
- Fix approach: Add CONTRIBUTING.md with: contribution workflow, grammar file style guide, test requirements before PR, commit message format

**No .editorconfig:**
- Problem: Missing editor configuration for consistent indentation/line endings
- Blocks: Different editors apply different rules; grammar.js diffs may include unintended whitespace changes
- Fix approach: Add `.editorconfig` specifying: 2-space indent for .js, 4-space for .c, LF line endings

---

## Test Coverage Gaps

**11 NIST tests are permanently skipped:**
- What's not tested: Tests NC205A, SM101A, SM103A, SM105A, SM107A, SM201A, SM203A, SM205A, SM206A, SM208A, SM401M (11 of 382 = 2.9% skip rate)
- Files: `skip_tests.txt`, `run_nist_cobol85.sh` (lines 19-24 check against skip list)
- Risk: These tests cover specific COBOL85 features that are known to fail; skipping masks incomplete grammar coverage
- Priority: **High** — should investigate each skipped test:
  - NC205A: Unknown category
  - SM101A, SM103A, SM105A, SM107A: String/character manipulation (SM=String)
  - SM201A, SM203A, SM205A, SM206A, SM208A: String operations (continuation)
  - SM401M: String/manipulation complex case
  - Need to document WHY each is skipped (missing feature, grammar conflict, known bug) and add a comment in skip_tests.txt or a separate SKIPPED_TESTS.md

**No Node.js binding tests:**
- What's not tested: The C++ binding (`bindings/node/binding.cc`) has no unit tests; only tested indirectly via the module's load path in `index.js`
- Files: No test files exist; manual testing required
- Risk: Memory leaks, crash on invalid input, version incompatibility with Node.js versions
- Priority: Medium — add smoke test for binding load and basic parse call

**No grammar rule isolation tests:**
- What's not tested: Individual grammar rules (e.g., IDENTIFICATION DIVISION, specific statement types) are not unit-tested; only integration tested via NIST suite
- Risk: A rule change that breaks a specific feature won't be caught until the full NIST suite runs
- Priority: Low–Medium — consider adding per-rule focused test fixtures if NIST coverage is insufficient

**Queries (highlighting, folding) have no test infrastructure:**
- What's not tested: `queries/sample.scm` has no regression tests; syntax highlighting rules are not validated against COBOL files
- Risk: Query file changes may silently break highlighting in downstream IDE integrations
- Priority: Medium — add query test fixtures (simple COBOL files + expected highlight/fold annotations)

---

## Repository Metadata Issues

**Inconsistent repository URLs:**
- `package.json` (line 17): `"url": "git+https://github.com/yutaro-sakamoto/tree-sitter-cobol.git"` (upstream author)
- `Cargo.toml` (line 7): `"repository": "https://github.com/tree-sitter/tree-sitter-COBOL"` (expected tree-sitter namespace)
- Impact: Confusing for users; suggests fork vs. official relationship unclear
- Fix: Align URLs; if this is the official tree-sitter-COBOL, update package.json to match Cargo.toml; if not, clarify in README.md

---

*Concerns audit: 2026-08-28*
