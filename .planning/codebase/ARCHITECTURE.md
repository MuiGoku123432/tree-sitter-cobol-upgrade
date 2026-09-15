<!-- refreshed: 2026-08-28 -->
# Architecture

**Analysis Date:** 2026-08-28

## System Overview

This is a tree-sitter grammar package for COBOL85. The system compiles a declarative grammar DSL into a high-performance parser that can parse COBOL source code into an abstract syntax tree. Consumers access this parser through language bindings (Node.js and Rust).

```text
┌─────────────────────────────────────────────────────────────┐
│                   Grammar Definition Layer                   │
│  grammar.js (3800 lines, DSL) - Declares COBOL syntax       │
│  scanner.c (207 lines, hand-written C)                       │
└────────────┬──────────────────────────────────────────────┬──┘
             │                                              │
             ▼                                              ▼
┌────────────────────────────┐                   ┌──────────────────┐
│  tree-sitter generate      │                   │  External Tokens │
│  (Compilation Step)        │                   │  (Scanner)       │
│  Produces:                 │                   │                  │
│  - parser.c (825K lines)   │                   │ - Whitespace     │
│  - grammar.json            │                   │ - Comments       │
│  - node-types.json         │                   │ - Multiline str. │
└────────────┬───────────────┘                   └──────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────────┐
│                 Parser Layer (Generated)                     │
│  src/parser.c + src/scanner.c                                │
│  Compiled C code that performs lexical & syntactic analysis  │
└────────┬────────────────────────────────┬────────────────────┘
         │                                │
         ▼                                ▼
┌──────────────────────┐        ┌──────────────────────┐
│ Node.js Binding      │        │ Rust Binding         │
│ bindings/node/       │        │ bindings/rust/       │
│ - binding.cc (C++)   │        │ - lib.rs (Rust FFI)  │
│ - index.js (module)  │        │ - build.rs           │
└──────────┬───────────┘        └──────────┬───────────┘
           │                               │
           ▼                               ▼
┌────────────────────────────────────────────────────────┐
│  Consumer Applications (Node.js or Rust)               │
│  Parse COBOL source → Abstract Syntax Tree             │
│  Query syntax tree with queries/ (highlights, etc.)    │
└────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File(s) |
|-----------|----------------|---------|
| Grammar DSL | Define COBOL syntax rules, lexical tokens, precedence | `grammar.js` |
| Scanner | Implement external lexical tokens: whitespace, comments, multiline strings | `src/scanner.c` |
| Parser (generated) | Implement LR(1) parse table and parser state machine | `src/parser.c` (generated) |
| Grammar metadata (generated) | Enumerate all grammar symbols and node types | `src/grammar.json`, `src/node-types.json` (generated) |
| Node.js binding | Expose C parser to Node.js as a native module | `bindings/node/` |
| Rust binding | Expose C parser to Rust via FFI | `bindings/rust/` |
| Query definitions | Syntax highlighting and structural queries | `queries/` |
| Test corpus | Tree-sitter format test cases | `test/corpus/*.txt` |
| COBOL85 fixtures | Real COBOL programs from NIST test suite | `test/cobol85/src/` |

## Pattern Overview

**Overall:** Single Grammar → Single Parser compilation pipeline.

This follows the standard tree-sitter grammar package pattern:
1. A grammar DSL (`grammar.js`) declares the language syntax declaratively
2. The `tree-sitter generate` command compiles the DSL into a C parser
3. Native bindings expose the parser to language runtimes (Node.js, Rust)
4. Test suites validate the parser against real and synthetic COBOL code

**Key Characteristics:**
- **Single source of truth:** `grammar.js` is the only hand-maintained language definition
- **Generated artifact:** `src/parser.c` and related files are completely derived from `grammar.js` and should never be edited by hand
- **External scanner:** Complex tokenization (comments, strings, whitespace handling) delegated to hand-written C scanner (`src/scanner.c`)
- **No application state:** Parser is stateless; each parse invocation is independent
- **Tree output only:** Parser produces concrete syntax tree; semantic analysis is caller's responsibility

## Layers

**Grammar Definition (grammar.js):**
- Purpose: Declaratively describe COBOL85 syntax using tree-sitter DSL (choice, seq, repeat, prec, etc.)
- Location: `grammar.js`
- Contains:
  - Helper functions (`sepBy`, `nonempty`)
  - External token declarations (whitespace, comments)
  - Grammar rules (identification_division, environment_division, data_division, procedure_division)
  - Precedence and associativity declarations
- Depends on: tree-sitter DSL semantics
- Used by: tree-sitter CLI to generate parser

**Scanner (src/scanner.c):**
- Purpose: Implement lexical rules that cannot be expressed in the grammar DSL (external tokens)
- Location: `src/scanner.c`
- Contains:
  - Token type enum (`TokenType`)
  - Scanner state creation/destruction
  - Whitespace detection (including COBOL column markers)
  - Comment matching (line prefix, line suffix, line comment)
  - Multiline string handling
- Depends on: tree-sitter lexer API (TSLexer)
- Used by: Parser during lexical analysis

**Parser (src/parser.c + src/tree_sitter/parser.h):**
- Purpose: Perform LR(1) parsing on the token stream to build abstract syntax tree
- Location: `src/parser.c` (generated, ~825K lines); header: `src/tree_sitter/parser.h`
- Contains:
  - LR parse tables (state machine)
  - Reduce/shift actions
  - Symbol metadata
- Depends on: Scanner output; tree-sitter parser API
- Used by: Language bindings

**Grammar Metadata (src/grammar.json, src/node-types.json):**
- Purpose: Describe all grammar symbols, node types, and field names for introspection
- Location: `src/grammar.json`, `src/node-types.json` (generated)
- Contains: Enumeration of all nonterminals, terminals, fields, and their relationships
- Depends on: Grammar rules in `grammar.js`
- Used by: Consumers for AST introspection; Rust binding embeds this

**Node.js Binding (bindings/node/):**
- Purpose: Expose the C parser as a loadable Node.js native module
- Location: `bindings/node/binding.cc`, `bindings/node/index.js`
- Contains:
  - C++ wrapper (NAN) that wraps `tree_sitter_COBOL()` function
  - JavaScript loader that tries Release/Debug builds and adds node-types.json
- Depends on: Compiled parser.c; NAN (native abstractions for Node.js)
- Used by: Node.js applications via `require('tree-sitter-cobol')`

**Rust Binding (bindings/rust/):**
- Purpose: Expose the C parser to Rust via FFI and cargo
- Location: `bindings/rust/lib.rs`, `bindings/rust/build.rs`
- Contains:
  - FFI declaration for `tree_sitter_COBOL()` C function
  - Public Rust API (`language()` function, NODE_TYPES constant)
  - Cargo build script that compiles parser.c
  - Optional inclusion hooks for queries
- Depends on: tree-sitter Rust crate (peer dependency)
- Used by: Rust applications via `tree_sitter_cobol::language()`

**Queries (queries/):**
- Purpose: Define structural patterns for syntax highlighting and other static analysis
- Location: `queries/`
- Contains:
  - `.scm` files using tree-sitter query language (S-expressions over the parse tree)
  - `highlights.scm` (if present) — maps node types to highlight groups (currently unused)
  - `sample.scm` — example query showing duplicate detection pattern
- Depends on: Node types defined in grammar
- Used by: Editor plugins and analysis tools that load this grammar

## Data Flow

### Primary Parse Request Path

1. **Entry:** Consumer calls `parser.parse(source_code)` via Node.js or Rust binding
2. **Binding dispatch** (`bindings/node/index.js` or `bindings/rust/lib.rs`):
   - Load compiled native module (contains parser.c + scanner.c)
   - Call `tree_sitter_COBOL()` C function
3. **Lexical analysis** (`src/scanner.c`):
   - Scanner tokenizes input byte stream
   - Emits external tokens: `WHITE_SPACES`, `LINE_PREFIX_COMMENT`, `LINE_SUFFIX_COMMENT`, `LINE_COMMENT`, `COMMENT_ENTRY`, `multiline_string`
   - Uses COBOL-specific rules (column positions, comment markers)
4. **Parsing** (`src/parser.c`):
   - LR parser consumes token stream
   - Executes shift/reduce actions per parse state
   - Builds concrete syntax tree (CST) bottom-up
   - Returns root `start` node containing sequence of `program_definition` nodes
5. **Output:** Consumer receives parse tree object:
   - Node type (e.g., `program_definition`, `identification_division`)
   - Field accessors (named children)
   - Child nodes (array of child nodes)
   - Source location (line, column range)

### Grammar Compilation Path (tree-sitter generate)

1. Input: `grammar.js` (3800 lines DSL)
2. tree-sitter CLI parses grammar DSL
3. Generate LR(1) parse tables
4. Output files (all overwritten on regeneration):
   - `src/parser.c` (~825K lines) — LR parse tables + state machine
   - `src/grammar.json` — Symbol enumeration
   - `src/node-types.json` — Node type metadata (used by Rust binding + introspection)

**Note:** These three outputs are **completely generated** from `grammar.js`. Never edit them by hand; edit `grammar.js` and regenerate.

### Scanner External Token Path

1. Grammar declares external tokens in `externals: $ => [...]` section
2. During parsing, whenever parser needs an external token symbol, it calls scanner
3. Scanner (`src/scanner.c`) examines lookahead and tries to match token type
4. Scanner returns token or `false` to indicate token not matched here
5. Parser continues parsing or advances input

## Key Abstractions

**Program Definition:**
- Purpose: Represents a complete COBOL program (identification division + optional environment/data/procedure divisions)
- Examples: `src/grammar.js` lines ~44-50 (program_definition rule)
- Pattern: Sequential composition of sections, each optional except identification division

**Division:**
- Purpose: High-level organizational unit in COBOL (identification, environment, data, procedure)
- Examples:
  - Identification: `src/grammar.js` ~52-73
  - Environment: `src/grammar.js` ~126-135
  - Data: `src/grammar.js` ~136-148
  - Procedure: `src/grammar.js` ~254+
- Pattern: Keyword + DIVISION + . + optional subsections

**Section:**
- Purpose: Organizational unit within a division (configuration section, input-output section, etc.)
- Examples: `src/grammar.js` ~137-165
- Pattern: Keyword + SECTION + . + optional content

**Statement:**
- Purpose: Executable unit in procedure division (move, perform, evaluate, etc.)
- Examples: Various `_statement` rules throughout `src/grammar.js`
- Pattern: Action keyword + operands + optional modifiers + period

**Qualified Word:**
- Purpose: Reference to named entity, optionally with subscripts/qualifiers (e.g., `MY-FIELD OF MY-RECORD (1)`)
- Examples: `src/grammar.js` lines for `qualified_word`, `subscript`, `in_phrase`
- Pattern: Base name + optional qualification chain

## Entry Points

**Node.js:**
- Location: `bindings/node/index.js`
- Triggers: `require('tree-sitter-cobol')`
- Responsibilities:
  - Load compiled native module from `build/Release/` or `build/Debug/`
  - Fallback to alternative build directory if first not found
  - Attach node type metadata from `src/node-types.json`

**Rust:**
- Location: `bindings/rust/lib.rs` function `language()`
- Triggers: Call `tree_sitter_cobol::language()` from Rust code
- Responsibilities:
  - Call FFI `tree_sitter_COBOL()` C function
  - Return `tree_sitter::Language` opaque handle
  - Can optionally export query constants (currently commented out)

**Parser invocation (language-agnostic):**
- The `tree_sitter_COBOL()` C function is the universal entry point
- Returns opaque `TSLanguage` pointer
- Called by both Node.js and Rust bindings
- Parser itself is invoked via tree-sitter runtime APIs (not directly by users)

## Architectural Constraints

- **Code generation:** `src/parser.c`, `src/grammar.json`, `src/node-types.json` are 100% generated from `grammar.js`. Editing them is futile and will be overwritten on next `tree-sitter generate`.

- **No mutable state:** Parser is reentrant and thread-safe. Each parse invocation is independent. No global state shared between parses.

- **External scanner required:** Complex COBOL tokenization (whitespace handling, comment detection, column rules) is delegated to `src/scanner.c` because these rules cannot be expressed in the tree-sitter grammar DSL. The scanner is stateless and called on demand.

- **Single language instance:** The C function `tree_sitter_COBOL()` returns a singleton language definition. All parsers using this language share the same parse tables and metadata.

- **Binary compatibility:** The parser is a shared library (.so / .dylib / .dll). Bindings maintain FFI compatibility across tree-sitter versions via the stable tree-sitter parser API.

- **No semantic analysis:** Parser produces syntax tree only. Type checking, variable resolution, scope analysis are caller's responsibility.

- **Column-based:** COBOL is a fixed-column language (column 1-6 reserved for labels, column 7 for comment marker, columns 8-72 for code). Scanner honors these rules.

## Anti-Patterns

### Editing Generated Files

**What happens:** Developer directly modifies `src/parser.c`, `src/grammar.json`, or `src/node-types.json`.

**Why it's wrong:** These files are completely overwritten by `tree-sitter generate`. Changes are lost on next build. Grammar definition is split across hand-maintained and generated copies, causing divergence and bugs.

**Do this instead:** Edit `src/grammar.js` only. Use `npm run build` (which calls `tree-sitter generate`) to regenerate outputs. All grammar changes flow through `grammar.js`.

### Complex Logic in Queries

**What happens:** Putting program transformation or semantic validation logic into query files (`queries/*.scm`).

**Why it's wrong:** Queries are static pattern matches over the syntax tree. They cannot encode state machines, control flow, or semantic invariants. The syntax tree alone is insufficient for anything beyond syntax highlighting or simple pattern detection.

**Do this instead:** Write queries only for syntax highlighting, basic structural patterns, or metadata extraction. Implement semantic analysis (type checking, name resolution, control flow) in post-processing code after parsing.

### Assuming Parse Success

**What happens:** Calling `parser.parse()` and assuming it returns a valid tree without error nodes.

**Why it's wrong:** The tree-sitter parser is error-tolerant and produces a tree even for invalid input. Invalid syntax is marked with `ERROR` nodes. Callers must inspect the tree for these nodes if exact validation is needed.

**Do this instead:** After parsing, walk the tree and check for `ERROR` nodes. If you need to reject invalid COBOL, filter the tree. Don't rely on parse success as a validity guarantee.

## Error Handling

**Strategy:** Error-tolerant parsing via error recovery.

Tree-sitter parsers never fail or throw exceptions. If input doesn't match any grammar rule, the parser inserts an `ERROR` node and continues. This enables:
- Incremental editing (user types incomplete code; parser recovers)
- Partial analysis (editor can analyze partially-written programs)
- Graceful degradation (malformed code produces usable syntax tree with error markers)

**Patterns:**
- Invalid syntax appears as `ERROR` node wrapping unparseable input
- Recovery consumes input up to next safe synchronization point
- Consumer must walk tree and check for `ERROR` nodes if strict validation is needed

## Cross-Cutting Concerns

**Logging:** No logging in the parser itself. Debugging is via parse tree inspection and query matches.

**Validation:** Parser performs syntax validation only (does the input match grammar?). Semantic validation (names defined, types compatible, etc.) is caller's responsibility.

**Internationalization:** COBOL keywords are case-insensitive and language-specific. The grammar handles case-insensitivity via `case_insensitive: true` in the grammar DSL (or lowercase keywords in rules). No runtime locale selection.

---

*Architecture analysis: 2026-08-28*
