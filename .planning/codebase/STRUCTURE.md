# Codebase Structure

**Analysis Date:** 2026-08-28

## Directory Layout

```
tree-sitter-cobol-upgrade/
├── grammar.js                 # COBOL85 grammar DSL (3800 lines) — THE PRIMARY SOURCE
├── package.json               # npm configuration; defines build steps
├── README.md                  # Project documentation
├── src/
│   ├── parser.c              # GENERATED LR(1) parser (~825K lines)
│   ├── scanner.c             # Hand-written external token scanner (207 lines)
│   ├── grammar.json          # GENERATED symbol enumeration
│   ├── node-types.json       # GENERATED node type metadata
│   └── tree_sitter/
│       └── parser.h          # Header for tree-sitter parser API
├── bindings/
│   ├── node/
│   │   ├── binding.cc        # Native Node.js module wrapper (C++)
│   │   └── index.js          # Node.js module loader
│   └── rust/
│       ├── lib.rs            # Rust FFI bindings and public API
│       └── build.rs          # Cargo build script
├── queries/
│   └── sample.scm            # Example tree-sitter query pattern
├── test/
│   ├── corpus/               # Tree-sitter format test cases (text + expected tree)
│   │   ├── comment.txt
│   │   ├── data_description.txt
│   │   ├── evaluate.txt
│   │   ├── file.txt
│   │   ├── goto.txt
│   │   ├── minimal-cobol.txt
│   │   ├── occurs.txt
│   │   ├── perform.txt
│   │   ├── pic_9.txt
│   │   ├── pic_x.txt
│   │   ├── redefines.txt
│   │   ├── select.txt
│   │   └── source-object-computer.txt
│   ├── cobol85/              # NIST COBOL85 test suite fixtures
│   │   └── src/*.CBL         # Real COBOL programs
│   ├── ocesql/               # OpenCOBOL with SQL extension tests
│   │   └── src/              # Nested COBOL + SQL samples
│   └── check_tests.sh        # Test runner script
├── sample/
│   └── a.cbl                 # Single sample COBOL file
├── .github/workflows/
│   ├── test.yml              # CI/CD test workflow
│   └── check-workflows.yml   # Workflow validation
├── .planning/
│   └── codebase/             # Documentation (this directory)
└── build/                    # Compiled artifacts (not in repo; created by npm run build)
    ├── Release/
    │   └── tree_sitter_COBOL_binding.node
    └── Debug/
        └── tree_sitter_COBOL_binding.node
```

## Directory Purposes

**Root:**
- Purpose: Project definition and top-level configuration
- Contains: Grammar definition, npm config, CI/CD workflows, build scripts
- Key files: `grammar.js`, `package.json`, `README.md`

**src/:**
- Purpose: Parser implementation (both generated and hand-written)
- Contains:
  - `parser.c` — Generated LR(1) parser (DO NOT EDIT)
  - `scanner.c` — Hand-written external token scanner (EDIT HERE for tokenization logic)
  - `grammar.json`, `node-types.json` — Generated metadata (DO NOT EDIT)
  - `tree_sitter/parser.h` — tree-sitter API header
- Key files: `parser.c` (generated), `scanner.c` (hand-written), `grammar.json` (generated)

**bindings/node/:**
- Purpose: Expose parser to Node.js
- Contains: Native module wrapper (binding.cc) and JavaScript loader (index.js)
- Key files: `binding.cc` (C++ NAN wrapper), `index.js` (module loader that falls back to Debug if Release missing)

**bindings/rust/:**
- Purpose: Expose parser to Rust via cargo and FFI
- Contains: Rust wrapper, FFI declarations, cargo build configuration
- Key files: `lib.rs` (public Rust API), `build.rs` (cargo build script compiling parser.c)

**queries/:**
- Purpose: Static query patterns over the parse tree
- Contains: Tree-sitter `.scm` query files (S-expression pattern language)
- Key files: `sample.scm` (example query showing duplicate move detection)
- Note: `highlights.scm` not present yet; would define syntax highlighting rules

**test/corpus/:**
- Purpose: Tree-sitter format test cases for grammar validation
- Contains: `.txt` files, each with source code + expected parse tree (S-expression format)
- Key files: `minimal-cobol.txt` (simplest valid program), others organized by feature (comments, data definitions, statements)
- Format: Each file is a sequence of test cases separated by `====` lines. Each test case has source code, `---`, then expected parse tree.

**test/cobol85/src/:**
- Purpose: Real COBOL programs from NIST test suite (official validation corpus)
- Contains: `.CBL` files (hundreds of programs named IC*.CBL, SG*.CBL, etc.)
- Note: These are **fixtures**, not application code. Used to validate parser against real COBOL.

**test/ocesql/src/:**
- Purpose: OpenCOBOL programs with SQL extensions
- Contains: Nested directories (basic, cobol_data, sql_data, sqlca, misc) with `.cbl` files
- Note: These are **fixtures** for testing SQL dialect support.

**sample/:**
- Purpose: Quick example COBOL files
- Contains: `a.cbl` (minimal sample)
- Used by: npm scripts for quick parsing tests (e.g., `npm run t`)

**.github/workflows/:**
- Purpose: CI/CD pipeline definitions
- Contains:
  - `test.yml` — Run test suite on push/PR
  - `check-workflows.yml` — Validate workflow syntax
- Note: Workflows are not application code; they define automated testing.

**.planning/codebase/:**
- Purpose: Architecture and structure documentation
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, etc.
- Generated by: GSD codebase mapper

**build/ (not in repo):**
- Purpose: Compiled artifacts
- Contains: `.node` files (compiled bindings for Node.js), `.a` / `.so` files for Rust
- Note: Created by `npm run build`; gitignored; rebuilt on each build

## Key File Locations

**Entry Points:**

| Purpose | Path |
|---------|------|
| Grammar definition (primary source) | `grammar.js` |
| Node.js module entry | `bindings/node/index.js` |
| Rust FFI entry | `bindings/rust/lib.rs::language()` |
| Native C function | `src/parser.c::tree_sitter_COBOL()` (generated) |

**Configuration:**

| Purpose | Path |
|---------|------|
| NPM scripts and dependencies | `package.json` |
| Build metadata | `Cargo.toml` (in bindings/rust/ for Rust consumers) |
| CI/CD workflows | `.github/workflows/*.yml` |

**Core Logic:**

| Purpose | Path |
|---------|------|
| Language grammar rules | `grammar.js` (3800 lines) |
| External token scanning | `src/scanner.c` (207 lines, hand-written) |
| Generated parser state machine | `src/parser.c` (825K lines, generated) |

**Testing:**

| Purpose | Path |
|---------|------|
| Tree-sitter corpus tests | `test/corpus/*.txt` |
| Real COBOL validation | `test/cobol85/src/*.CBL` |
| SQL dialect tests | `test/ocesql/src/**/*.cbl` |
| Test runner | `test/check_tests.sh` |

**Queries:**

| Purpose | Path |
|---------|------|
| Syntax highlighting rules | `queries/highlights.scm` (not yet present) |
| Example patterns | `queries/sample.scm` |

## Naming Conventions

**Files:**

| Convention | Example |
|-----------|---------|
| Grammar DSL | `grammar.js` |
| Generated parser | `src/parser.c` |
| Hand-written scanner | `src/scanner.c` |
| Node.js binding | `bindings/node/binding.cc`, `bindings/node/index.js` |
| Rust binding | `bindings/rust/lib.rs` |
| Test corpus | `test/corpus/*.txt` (descriptive names: `comment.txt`, `evaluate.txt`) |
| COBOL fixtures | `test/cobol85/src/*.CBL` (uppercase extension; NIST naming: IC*.CBL, SG*.CBL) |
| Query files | `queries/*.scm` (tree-sitter S-expression format) |

**Directories:**

| Convention | Example |
|-----------|---------|
| Language bindings grouped by runtime | `bindings/node/`, `bindings/rust/` |
| Generated outputs in src/ | `src/parser.c`, `src/grammar.json` |
| Test fixtures by test type | `test/corpus/`, `test/cobol85/`, `test/ocesql/` |
| Queries by category | `queries/highlights.scm`, `queries/injections.scm` |

## Where to Add New Code

**Add a new COBOL grammar rule:**
- Edit: `src/grammar.js` (find the relevant division section, add rule)
- Regenerate: `npm run build` (calls `tree-sitter generate`)
- Test: Add test case to `test/corpus/*.txt`

**Add a new external token (scanner token):**
- Edit: `src/scanner.c` (add enum value, implement matching logic)
- Update: `grammar.js` externals list to reference new token
- Rebuild: `npm run build`

**Add syntax highlighting rules:**
- Create or edit: `queries/highlights.scm` (tree-sitter query language)
- Reference node types from `src/node-types.json`
- Uncomment in `bindings/rust/lib.rs` to export query constant

**Add a new test case:**
- Create: `test/corpus/feature_name.txt`
- Format: Source code + `---` + expected parse tree (S-expression)
- Run: `npm test` to validate

**Add Node.js-specific logic:**
- Edit: `bindings/node/index.js` (module loader)
- Recompile: `npm run build`

**Add Rust-specific logic:**
- Edit: `bindings/rust/lib.rs` (public API)
- Rebuild: Rust consumers call `cargo build`

**Extend the test suite:**
- For syntax coverage: Add `.txt` file to `test/corpus/`
- For real-world validation: Add `.CBL` file to `test/cobol85/src/` or `.cbl` to `test/ocesql/src/`
- Run: `npm run ct` to execute all tests

## Special Directories

**src/ (parser artifacts):**
- Purpose: Compiled parser and metadata
- Generated: Yes (by `tree-sitter generate`)
- Committed: Yes (binary parser.c is committed for distribution)
- Action on change: Regenerate via `npm run build`; commit generated files
- Hand-editable: Only `src/scanner.c` (external tokens); never edit `parser.c`, `grammar.json`, `node-types.json`

**build/ (compiled bindings):**
- Purpose: Native module artifacts
- Generated: Yes (by `node-gyp build` and Rust cargo)
- Committed: No (gitignored)
- Action on change: Rebuild via `npm run build` or `cargo build`
- Note: Must rebuild for each Node version and platform

**test/corpus/ (syntax validation):**
- Purpose: Grammar test suite (tree-sitter standard format)
- Generated: No (manually written test cases)
- Committed: Yes
- Action on change: Add new `.txt` files for grammar coverage; run `npm test` to validate
- Format: Each file contains one or more test cases with source code and expected parse tree

**test/cobol85/ and test/ocesql/ (fixture validation):**
- Purpose: Real COBOL programs for integration testing
- Generated: No (public test suites + contributed samples)
- Committed: Yes (these are the official NIST corpus and OpenCOBOL samples)
- Action on change: Run `npm run nist` to validate against entire NIST suite; update test runner if needed
- Note: Do not modify fixture files; they are canonical references

**queries/:**
- Purpose: Query patterns and metadata
- Generated: No (manually authored)
- Committed: Yes
- Action on change: Add `.scm` files for new query types (highlights, injections, locals, tags)

## Development Workflow

**When making a grammar change:**

1. Edit `src/grammar.js` (add/remove/modify rules)
2. Run `npm run build` (regenerates `src/parser.c`, `src/grammar.json`, `src/node-types.json`)
3. Add test case to `test/corpus/` to validate new syntax
4. Run `npm test` to check all tests pass
5. Run `npm run nist` to validate against NIST suite
6. Commit both `grammar.js` and regenerated files

**When making a scanner change:**

1. Edit `src/scanner.c` (modify token matching logic)
2. Update `grammar.js` externals if adding new tokens
3. Run `npm run build`
4. Run `npm test`
5. Commit changes

**When testing a COBOL program:**

1. Place `.cbl` or `.CBL` file in `sample/` directory
2. Run `npm run sample` to parse it
3. Inspect output in `out.txt`
4. Use `npm run c` to compile with cobc (GNU COBOL reference compiler) for validation

---

*Structure analysis: 2026-08-28*
