# Coding Conventions

**Analysis Date:** 2026-08-28

## Overview

This codebase uses the tree-sitter grammar DSL (`grammar.js`) to define a COBOL language parser. Conventions apply to how grammar rules are structured, named, composed, and how COBOL's case-insensitive keywords are handled.

## Grammar.js DSL Conventions

### Rule Definition Pattern

```javascript
module.exports = grammar({
  name: 'COBOL',
  word: $ => $._WORD,
  externals: $ => [...],
  extras: $ => [...],
  rules: { /* all rules defined here */ }
})
```

**Key points:**
- All grammar rules are defined within the `rules` object
- The `word` rule specifies what constitutes an identifier token (`$._WORD`)
- `externals` define tokens handled by the scanner (whitespace, comments, multiline strings)
- `extras` define tokens that can appear anywhere (comments, whitespace)

### Naming Conventions

**Private Rules (Underscore Prefix):**
- Prefixed with `_` for internal/utility rules not exported to the parse tree
- Examples: `_WORD`, `_LITERAL`, `_IDENTIFICATION`, `_DIVISION`, `_configuration_paragraph`
- Used to reduce parse tree noise and group related sub-rules
- Implementation: `_configuration_paragraph: $ => choice($.source_computer_paragraph, ...)`

**Public Rules (No Prefix):**
- Exported as named nodes in the final parse tree
- User-facing grammar constructs like `program_definition`, `identification_division`, `data_division`
- Can be referenced by external tools and analyzers
- Examples: `program_definition`, `select_statement`, `perform_statement_call_proc`

**Keywords with Keyword Case Pattern:**
- Most keywords defined as case-insensitive regex: `/[kK][eE][yY][wW][oO][rR][dD]/`
- Examples: `_IDENTIFICATION`, `_DIVISION`, `_SECTION`, `_PROGRAM_ID`
- This pattern handles COBOL's case-insensitivity (IDENTIFICATION, identification, Identification all match)

**Exceptions to Regex Pattern:**
- Special keywords listed via `choice()` for explicit control:
  ```javascript
  _ZERO: $ => choice('zero', 'ZERO', 'Zero'),
  _ZEROS: $ => choice('zeros', 'ZEROS', 'Zeros', 'zeroes', 'ZEROES', 'Zeroes'),
  ```

**Clause/Sub-rule Naming:**
- Clauses follow pattern: `[operation]_clause` (e.g., `value_clause`, `picture_clause`)
- Internal variants: prefixed with `_` (e.g., `_select_clause`, `_object_clause`)
- Data structure variants: `[name]_entry`, `[name]_section` (e.g., `file_description_entry`, `working_storage_section`)

### Composition Patterns

**Sequential Composition (seq):**
- Specifies rules that must appear in order
- Used for structured divisions and multi-part statements

```javascript
identification_division: $ => seq(
  $._IDENTIFICATION, $._DIVISION, '.',
  optional(
    seq($._PROGRAM_ID, '.',
      $.program_name,
      optional(choice($.as_literal, $.is_initial, $.is_common)),
      '.'
    )
  ),
  repeat(choice($.author_section, ...))
)
```

**Alternative Composition (choice):**
- Defines mutually exclusive alternatives
- Flattens choices to reduce nesting depth where possible

```javascript
special_names_paragraph: $ => seq(
  $._SPECIAL_NAMES, '.',
  repeat(seq($.special_name, optional('.'))),
),

special_name: $ => choice(
  $.mnemonic_name_clause,
  $.alphabet_name_clause,
  $.symbolic_characters_clause,
  $.locale_clause,
  $.class_name_clause,
  ...
)
```

**Optionality and Repetition:**
- `optional()` - Zero or one occurrence (used extensively for COBOL's many optional clauses)
- `repeat()` - Zero or more occurrences
- `repeat1()` - One or more occurrences (used when at least one is syntactically required)

```javascript
_object_computer_entry: $ => choice(
  seq($.WORD, '.'),
  seq($.WORD, repeat1($._object_clause), '.'),
  seq(repeat1($._object_clause), '.')
)
```

### Operator Precedence

**Pattern:**
- Used with `prec.left()` and `prec.right()` to resolve conflicts
- Numeric levels indicate precedence (higher = tighter binding for binary operators)

**Arithmetic Operators:**
```javascript
add_exp: $ => prec.left(1, seq(...)),      // lowest precedence
sub_exp: $ => prec.left(1, seq(...)),
mul_exp: $ => prec.left(2, seq(...)),      // middle precedence
div_exp: $ => prec.left(2, seq(...)),
pow_exp: $ => prec.left(3, seq(...))       // highest precedence
```

**Structural Precedence:**
- Used on non-operator rules to disambiguate grammar conflicts
- `prec.right()` on top-level rules like `program_definition`, `procedure_division_content`
- `prec.left()` on recursive/accumulating patterns like block containment and records

```javascript
program_definition: $ => prec.right(seq(
  $.identification_division,
  optional($.environment_division),
  optional($.data_division),
  optional($.procedure_division),
  repeat($.end_program)
))
```

### Field Labeling

**Purpose:**
- Attaches semantic labels to sub-rules for easier AST navigation
- Not required but improves parse tree readability and IDE support

**Pattern:**
```javascript
field('label_name', rule_reference)
```

**Examples:**
```javascript
select_statement: $ => seq(
  $._SELECT,
  field('optional', optional($.OPTIONAL)),
  field('file_name', $.WORD),
  repeat($._select_clause),
  '.'
)

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

**Common field names:**
- `'word'`, `'name'` - Identifier/symbol
- `'value'` - Assigned value or RHS
- `'option'` - Optional keyword (FOREVER, VARYING, etc.)
- `'file_name'` - File reference
- `'comment'` - Comment content
- `'list'` - Repeated elements

### Helper Functions

**Existing Helpers in `grammar.js`:**

```javascript
function sepBy(pattern, separator) {
  return seq(pattern, repeat(seq(separator, pattern)))
}
```
- Creates a list of items separated by a delimiter (no trailing separator)
- Used for: `field('char_list', repeat1($.WORD))` but also with sepBy for alternations
- Example: `field('char_list', repeat1($.WORD))` in symbolic_characters_clause

```javascript
function nonempty(pattern1, pattern2) {
  return choice(
    seq(pattern1, optional(pattern2)),
    pattern2
  )
}
```
- Allows pattern1 optionally followed by pattern2, OR just pattern2
- Avoids requiring both parts
- Not widely used; most optional composition uses explicit `choice()` and `optional()`

**When to Define New Helpers:**
- Only if a pattern repeats 3+ times in the grammar
- Document the pattern clearly
- Place at the top of the file before `module.exports`

## Keyword Definition Convention

### Case-Insensitive Keyword Pattern

**Standard Pattern (Regex):**
```javascript
_IDENTIFICATION: $ => /[iI][dD][eE][nN][tT][iI][fF][iI][cC][aA][tT][iI][oO][nN]/,
_DIVISION: $ => /[dD][iI][vV][iI][sS][iI][oO][nN]/,
_SECTION: $ => /[sS][eE][cC][tT][iI][oO][nN]/,
```

**Exported Keywords (Public):**
- Capital letter version without underscore
- Used when the keyword appears in the parse tree:
```javascript
ADVANCING: $ => $._ADVANCING,
AFTER: $ => $._AFTER,
ALL: $ => $._ALL,
FD: $ => $._FD,
```

**Hyphenated Keywords:**
- Regex handles hyphens within keywords:
```javascript
_PROGRAM_ID: $ => /[pP][rR][oO][gG][rR][aA][mM]-[iI][dD]/,
_WORKING_STORAGE: $ => /[wW][oO][rR][kK][iI][nN][gG]-[sS][tT][oO][rR][aA][gG][eE]/,
```

**Commented-Out Keywords:**
- Many keywords prefixed with `//` to indicate not yet implemented or not in current scope
- Example:
```javascript
//ACCEPT: $ => $._ACCEPT,
//ACCESS: $ => $._ACCESS,
//ADD: $ => $._ADD,
```

### Multi-Word Keywords

**With Spaces (Regex with space handling):**
```javascript
_WHEN_OTHER: $ => /[wW][hH][eE][nN][ \t\n]+[oO][tT][hH][eE][rR]/,
```

**Compound Keywords (with AND/OR):**
```javascript
AND_LT: $ => /[aA][nN][dD][ \t]+(<|[lL][eE][sS][sS][ \t]+[tT][hH][aA][nN])/,
OR_EQ: $ => /[oO][rR][ \t]+(=|[eE][qQ][uU][aA][lL]([ \t]+[tT][oO])?)/,
```

## Parse Tree Structure

### Division-Level Organization

Top-level parse tree reflects COBOL's division structure:
```
start
└── program_definition
    ├── identification_division
    ├── environment_division (optional)
    ├── data_division (optional)
    └── procedure_division (optional)
```

### Clause/Clause-List Pattern

Many clauses appear as optional repeats within sections:
```javascript
configuration_section: $ => seq(
  $._CONFIGURATION, $._SECTION, '.',
  repeat($._configuration_paragraph)
),

_configuration_paragraph: $ => choice(
  $.source_computer_paragraph,
  $.object_computer_paragraph,
  $.special_names_paragraph,
  $.repository_paragraph
)
```

### Data Description Hierarchy

Nested data items with level numbers:
```
working_storage_section
└── data_description (level 77)
    ├── level_number
    ├── entry_name
    ├── picture_clause
    ├── value_clause
    └── ... (other clauses)
```

## Error Handling in Grammar

**Approach:**
- Tree-sitter is error-tolerant; partial parses are generated even for invalid syntax
- No explicit error rules; grammar focuses on valid COBOL syntax
- Malformed input produces partial parse trees with nodes marked as missing/invalid

**Comments in Grammar:**
- TODOs marked with `//todo` throughout grammar.js
- Example: `//optional($.function_definition) //todo` indicates unimplemented features
- Commented keywords indicate features deferred or not in current scope

## Literal and Number Patterns

**Literals:**
```javascript
program_name: $ => choice(
  $._WORD,
  $._LITERAL
)
```

**Numbers:**
```javascript
integer: $ => choice(
  $._UNSIGNED_INT,
  seq($._MINUS, $._UNSIGNED_INT),
  $._PLUS,
  $._UNSIGNED_INT
)
```

**Picture Clauses (Special):**
- Handled via separate internal rules: `picture_x`, `picture_9`, `picture_s9`, etc.
- Each defines a specific COBOL PIC clause pattern

---

*Convention analysis: 2026-08-28*
