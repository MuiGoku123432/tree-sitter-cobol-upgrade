# Technology Stack

**Analysis Date:** 2026-08-28

## Languages

**Primary:**
- JavaScript - Used for grammar definition and Node.js bindings
- C - Parser and scanner generated from grammar; compiled via node-gyp and cc

**Secondary:**
- Rust - Standalone language bindings for tree-sitter COBOL; crate published to crates.io
- Scheme (S-expression) - Tree-sitter query files for AST selection (`.scm` format)

## Runtime

**Environment:**
- Node.js v20.10.0 (reference version in README.md; no lockfile version constraint)

**Package Manager:**
- npm 10.x+ (inferred from Node.js v20)
- Lockfile: `package-lock.json` present

## Frameworks

**Core:**
- tree-sitter v0.24.5 - Parser framework (CLI for grammar generation and testing)
  - Code generation: `tree-sitter generate` produces `src/parser.c`, `src/grammar.json`, `src/node-types.json`
  - Testing: `tree-sitter test` runs grammar test suites

**Build:**
- node-gyp - Compiles C parser to native Node.js module (invoked via npm run build)
- Cargo - Rust package manager and build system for Rust bindings

**C/C++ Compilation:**
- cc v1.0 - Build-time C compiler abstraction for compiling parser.c and scanner.c in Rust builds

## Key Dependencies

**Critical:**
- `tree-sitter-cli` ^0.24.5 (devDependency) - Grammar DSL compiler; generates parser.c and grammar.json
- `nan` ^2.22.0 (dependency) - Node.js native API bindings for C++ interop
- `tree-sitter` ~0.20.3 (Rust dependency) - Core tree-sitter parsing library for Rust crate

**Build Infrastructure:**
- `cc` 1.0 (Rust build-dependency) - Cross-platform C compiler wrapper

## Configuration

**Grammar Source:**
- `grammar.js` - Hand-written tree-sitter grammar definition (DSL, not JavaScript executed)
  - Defines COBOL85 syntax rules via `grammar()` module export
  - Includes external scanner definitions: `_WHITE_SPACES`, `_LINE_PREFIX_COMMENT`, `_LINE_SUFFIX_COMMENT`, `_LINE_COMMENT`, `comment_entry`, `_multiline_string`

**Build Configuration:**
- `binding.gyp` - Node.js gyp configuration specifies:
  - `tree_sitter_COBOL_binding` target
  - Include dirs: NaN headers + `src/`
  - C sources: `bindings/node/binding.cc`, `src/parser.c`, `src/scanner.c`
  - C standard: C99

- `Cargo.toml` - Rust package configuration:
  - Package name: `tree-sitter-COBOL`
  - Edition: 2018
  - Includes for published crate: `bindings/rust/*`, `grammar.js`, `queries/*`, `src/*`
  - Build script: `bindings/rust/build.rs` (compiles C sources via cc crate)

**Package Configuration:**
- `package.json` metadata:
  - Entry point: `bindings/node` (index.js exports native module)
  - Scripts: `test` (tree-sitter test), `build` (generate + node-gyp build), `sample`, `nist` (test runner)

## Platform Requirements

**Development:**
- Node.js 20.10.0 (preferred; README recommends `nvm use 20`)
- Python (for node-gyp, implicit)
- C compiler (via cc crate; platform-native)
- Standard build tools (make, g++/clang)

**Rust Build:**
- Rust 1.56+ (implied by edition 2018)
- Cargo (bundled with Rust)

**Production:**
- No external runtime dependencies beyond Node.js native module (self-contained binary)
- No cloud deployment specified; grammar distributed as npm package and Rust crate

## Query Language

**Tree-sitter Queries:**
- Location: `queries/sample.scm` - S-expression format for AST node matching
- Used for: Syntax highlighting, indentation rules, and code folding (when enabled in query files)
- Current state: Minimal sample query; highlights/injections/locals/tags commented out in Rust lib.rs

---

*Stack analysis: 2026-08-28*
