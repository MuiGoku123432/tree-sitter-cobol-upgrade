# Phase 3: EXEC CICS Blocks - Pattern Map

**Mapped:** 2026-09-09
**Files analyzed:** 9 (5 in-fork source/fixture, 2 regenerated artifact sets, 1 doc, 1 cross-repo)
**Analogs found:** 8 / 9 (one file — the fork-local query-compile test — has **no analog**; see "No Analog Found")

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `grammar.js` (new `exec_cics_statement`, `cics_*` operands, `cics_unparsed_tail`, terminals, `_statement` entry) | grammar rule definition | transform (token stream → AST) | `grammar.js:2245-2399` (Phase 2 IDMS DML block) | **exact** |
| `queries/cics.scm` (new) | query / capture contract | declarative pattern match | `queries/idms.scm` (20 lines, read in full) | **exact** |
| `test/corpus/exec_cics.txt` (new) | test fixture | request-response (source → expected S-expression) | `test/corpus/idms_session.txt` | **exact** |
| Fork-local query-compile + capture test (CICS-02) | test | request-response | **none** — see below. Nearest structural precedent: `forest-shim/cobol/smoke_test.go` | **no analog** |
| `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/cascade_test.go` | test (cross-repo) | batch (inject → count → assert) | its own IDMS case, lines 78-99 + 115-131 | **exact (self-analog)** |
| `docs/baseline.md` (Phase 1 `paragraph_header` reconstruction) | documentation / measurement record | batch record | `docs/baseline.md` §2 (lines 22-60) and §4 (lines 150-163) | **exact (self-analog)** |
| `src/parser.c`, `src/grammar.json`, `src/node-types.json` | generated artifact | build output | `forest-shim/refresh.sh` Step 2 | **exact** |
| `forest-shim/cobol/{parser.c,scanner.c,grammar.json,parser.h,cics.scm}` | vendored artifact | build output | `forest-shim/refresh.sh` Steps 3-4 | **exact** |

---

## Pattern Assignments

### `grammar.js` — `exec_cics_statement` + operand nodes (grammar rule, transform)

**Analog:** `grammar.js:2245-2399` — the Phase 2 IDMS DML block, verbatim.

---

#### A. Integration point — the flat `_statement` `choice()`

`grammar.js:1366-1400`. Alphabetically ordered; the four IDMS entries sit at 1382-1385.
`exec_cics_statement` slots between `$.exit_statement` (1379) and `$.goback_statement` (1380)
by alphabetical order:

```javascript
    _statement: $ => choice(
      $.accept_statement,
      $.add_statement,
      $.allocate_statement,
      $.alter_statement,
      $.call_statement,
      $.cancel_statement,
      $.close_statement,
      $.continue_statement,
      $.compute_statement,
      $.delete_statement,
      $.display_statement,
      $.divide_statement,
      $.exit_statement,
      $.goback_statement,
      $.goto_statement,
      $.idms_accept_statement,
      $.idms_navigation_statement,
      $.idms_session_statement,
      $.idms_update_statement,
      $.initialize_statement,
      ...
```

**Copy exactly:** add one line, `$.exec_cics_statement,`, in alphabetical position. No other
change to this rule. Note **no sibling embeds a terminating period** — this is what D-20 relies
on for the 1,283 period-terminated blocks.

---

#### B. Rule-body composition style + measured-volume comment convention

`grammar.js:2245-2251` — the block header comment that names the phase and the decisions:

```javascript
    // IDMS DML (Phase 2, D-01). idms_record_name/idms_set_name are named
    // rules rather than field() labels (D-02) so queries/idms.scm matches
    // them at any nesting depth across all four idms_*_statement types.
    idms_navigation_statement: $ => seq(
      field('verb', choice($.FIND, $.OBTAIN)),
      $._idms_navigation_body
    ),
```

`grammar.js:2286-2299` — the `_`-prefixed private body rule, `field('verb', …)` labelling, and
the **inline measured-volume comment** justifying each modelled option:

```javascript
    idms_session_statement: $ => $._idms_session_body,

    _idms_session_body: $ => prec.right(choice(
      seq(
        field('verb', $.BIND),
        optional(choice($.RUN_UNIT, $.idms_record_name)),
        // BIND RUN-UNIT DBNAME <db-name>. Modelled on measured volume: the
        // D-09 tail census found this shape in 96 of 119 idms_unparsed_tail
        // records (81%). The database name is not a graph edge, so it is
        // absorbed as $.WORD rather than given its own node, matching how
        // the DB-KEY navigation format treats its operand.
        optional(seq($.DBNAME, $.WORD)),
        optional($.idms_unparsed_tail)
      ),
```

**Copy:** the header-comment form (`// EXEC CICS (Phase 3, D-17/D-19/D-21). …`), the
`field('command', …)` labelling in place of `field('verb', …)`, the `_`-prefixed private body
rule, and inline comments citing D-29's counts (1,993 quoted literal / 2,041 data name / 527
`LENGTH OF` / 81 numeric) and the option counts (1,586 `NOHANDLE` / 610 `MAPSET` / 594 `LENGTH`
/ 450 `FREEKB` / 438 `ERASE` / 415 `TRANSID` / 411 `COMMAREA` / 33 `PROGRAM`).

Also note `optional($.idms_unparsed_tail)` as the **last element of every arm** — the D-19
analog placement.

---

#### C. Named operand nodes with `prec(1, …)` — the D-21 pattern

`grammar.js:2372-2383`, comment and rules verbatim:

```javascript
    // prec(1, ...): a bare WORD immediately after a modeled verb/clause
    // token is ambiguous between reducing as this named operand or as the
    // first token of idms_unparsed_tail (both are single-token wrappers
    // around $.WORD) — tree-sitter generate reports this as a genuine
    // reduce/reduce conflict. Static precedence prefers the modeled
    // operand, per the plan's resolution order (static prec() before
    // conflicts:/prec.dynamic()); it resolved this cleanly with no
    // generator error, so no `conflicts:` entry was needed.
    idms_record_name: $ => prec(1, $.WORD),

    idms_set_name: $ => prec(1, $.WORD),
```

**Copy for all four:** `cics_transaction_name`, `cics_program_name`, `cics_map_name`,
`cics_mapset_name`. Per D-22 each wraps *whatever is inside the parens* — so the body is wider
than IDMS's bare `$.WORD`; expect `prec(1, choice($.WORD, $._LITERAL, $.integer, seq($._LENGTH,
optional($._OF), $.WORD)))` or an equivalent private `_cics_argument` rule. Keep the same
written justification for the `prec(1, …)` and keep `conflicts:` empty (currently length 0).

---

#### D. The unparsed tail — the D-19 pattern

`grammar.js:2385-2399`, verbatim:

```javascript
    // D-03: an operand tail the four formats above don't model is absorbed
    // into this named node rather than left to ERROR or silently dropped.
    // Pure grammar (no external-scanner token, per RESEARCH.md) — a repeat
    // over the grammar's own atomic leaves, bounded at the literal '.'
    // (never consumed here) the same way neutralize()'s own `[^.]*\.`
    // statement-boundary regex already does across the corpus.
    _idms_operand_token: $ => choice(
      $.WORD,
      $._LITERAL,
      '(',
      ')',
      ','
    ),

    idms_unparsed_tail: $ => repeat1($._idms_operand_token),
```

**Copy structure exactly** as `_cics_operand_token` / `cics_unparsed_tail`. The vocabulary
already carries `(` and `)`, which is most of what CICS needs. **The bounding differs:** IDMS
bounds at the literal `.`; CICS must bound at `END-EXEC`, and `END-EXEC` matches `_WORD`
(`grammar.js:3491`) — so the tail is a candidate consumer of the terminator. This is the
Pitfall-1 / A1 risk and must be a fixture case, not an assumption.

---

#### E. Terminal declaration convention (`TRANSID`, `PROGRAM`, `MAP`, `MAPSET`, `EXEC`, `CICS`, `END-EXEC`)

Two-part convention. Private case-insensitive regex in the `_KEYWORD` block:

```javascript
    _WRITE: $ => /[wW][rR][iI][tT][eE]/,            // grammar.js:3357
    _DELETE: $ => /[dD][eE][lL][eE][tT][eE]/,       // grammar.js:3121
    _READ: $ => /[rR][eE][aA][dD]/,                 // grammar.js:3004
    _RETURN: $ => /[rR][eE][tT][uU][rR][nN]/,       // grammar.js:3381
    _WORD: $ => /([0-9][a-zA-Z0-9-]*[a-zA-Z][a-zA-Z0-9-]*)|([a-zA-Z][a-zA-Z0-9-]*)/,  // grammar.js:3491
```

Plus a public single-line alias in the visible-token block:

```javascript
    BIND: $ => $._BIND,          // grammar.js:3540
    DBNAME: $ => $._DBNAME,      // grammar.js:3608
    ERASE: $ => $._ERASE,        // grammar.js:3663
    RUN_UNIT: $ => $._RUN_UNIT,  // grammar.js:3870
    WORD: $ => $._WORD,          // grammar.js:3968
```

**Copy both halves,** alphabetically placed in each block. Note `_RUN_UNIT` / `RUN_UNIT` — the
hyphenated-keyword naming precedent for `END-EXEC` → `_END_EXEC` / `END_EXEC`.

---

#### F. Keyword extraction — the D-18 mechanism (do not add `conflicts:`)

`grammar.js:10-32`:

```javascript
module.exports = grammar({
  name: 'COBOL',
  word: $ => $._WORD,
  externals: $ => [
    $._WHITE_SPACES,
    ...
  ],

  extras: $ => [
    $._WHITE_SPACES,
    $._LINE_PREFIX_COMMENT,
    $._LINE_SUFFIX_COMMENT,
    $._LINE_COMMENT,
    $._LINE_COMMENT_ALIAS,
    $.copy_statement,
    $.comment,
  ],
```

`word: $ => $._WORD` (line 14) is the D-18 mechanism. Newlines/comments as `extras` (lines
24-32) are why multi-line blocks (D-28d) are free with no scanner change.

---

### `queries/cics.scm` (new) (query, declarative pattern match)

**Analog:** `queries/idms.scm` — 20 lines, reproduced in full:

```scheme
; IDMS DML extraction query (Phase 2, D-04): record/set names + verb.
(idms_navigation_statement
  verb: (_) @verb
  (idms_record_name) @record)

(idms_navigation_statement
  (idms_set_name) @set)

(idms_update_statement
  (idms_record_name) @record)

(idms_update_statement
  (idms_set_name) @set)

(idms_session_statement
  (idms_record_name) @record)

; ACCEPT stays hidden, so this single-verb statement node identifies the verb.
(idms_accept_statement
  (idms_record_name) @record) @verb
```

**Conventions to carry verbatim:**
1. Leading `;` comment naming the phase and the decision — `; EXEC CICS extraction query (Phase 3, D-24): …`
2. **One pattern per capture role**, not one pattern with alternations.
3. Field selector on a wildcard — `verb: (_) @verb` — is the direct analog for
   `command: (_) @command` under D-17/D-18.
4. Blank line between patterns; `;` comment above any pattern needing justification.
5. **No `#eq?` / no predicates of any kind** — gortex's `runQuery` evaluates none
   (`~/repos/mine/GoApps/gortex/internal/parser/treesitter.go:178-200`); a predicate compiles
   and is then silently ignored.

Expected shape (four named captures per D-21/D-23):

```scheme
(exec_cics_statement command: (_) @command)
(exec_cics_statement (cics_transaction_name) @transaction)
(exec_cics_statement (cics_program_name) @program)
(exec_cics_statement (cics_map_name) @map)
(exec_cics_statement (cics_mapset_name) @mapset)
```

---

### `test/corpus/exec_cics.txt` (new) (test fixture, request-response)

**Analog:** `test/corpus/idms_session.txt:1-38`, verbatim (two complete cases so the
inter-case separator is visible):

```
====================================
idms session bind run-unit
====================================
       identification division.
       program-id. a.
       procedure division.
       BIND RUN-UNIT.
---

(start
  (program_definition
    (identification_division
      (program_name))
    (procedure_division
      (idms_session_statement
        verb: (BIND)
        (RUN_UNIT))
      (period))))

====================================
idms session bind record
====================================
       identification division.
       program-id. a.
       procedure division.
       BIND CUSTOMER-REC.
---

(start
  (program_definition
    (identification_division
      (program_name))
    (procedure_division
      (idms_session_statement
        verb: (BIND)
        (idms_record_name
          (WORD)))
      (period))))
```

**Exact format rules to copy:**
- Header rule: **36 `=` characters** (not 35, not 40), on the line before and after the name.
- Test name: lowercase, space-separated, no hyphens (`exec cics send map`).
- Program shell: 3 lines, 7 leading spaces — `identification division.` / `program-id. a.` /
  `procedure division.`
- Statement body indented to column 8 (7 spaces) for area-A, or 11 spaces inside a paragraph.
- `---` on its own line as the separator.
- **One blank line** after `---`, then the fully-parenthesised expected tree, 2-space indent per
  level.
- **Two blank lines** between the end of one case's tree and the next `====` header.
- Field labels appear in the expected tree as `verb: (BIND)` → for CICS, `command: (WORD)`.

**Naming per D-32:** invented neutral names only — `MAP('MENU01')`, `TRANSID('AB12')`,
`PROGRAM(WS-PGM-NAME)`. Same rule the cross-repo analog states inline at `cascade_test.go:79-80`.

**Note:** Phase 2 shipped four per-cluster files (`idms_accept.txt`, `idms_navigation.txt`,
`idms_session.txt`, `idms_update.txt`). D-32 specifies **one** `exec_cics.txt` for Phase 3.

---

### `~/repos/mine/GoApps/gortex/.../cobolprobe/cascade_test.go` (test, cross-repo)

**Analog:** the file's own IDMS case, which is the exact template for the four new CICS shapes.

**The existing EXEC CICS case (`cascade_test.go:65-71`)** — shape (a) of D-28, already present:

```go
	// Inject an unknown construct after the FIRST paragraph. If recovery is
	// local, the remaining 19 paragraphs still parse.
	lines := strings.SplitN(proc.String(), "\n", 3)
	injectedProc := lines[0] + "\n" + lines[1] + "\n           EXEC CICS SEND MAP('M') END-EXEC.\n" + lines[2]
	hurt := head + data.String() + mid + injectedProc + "           STOP RUN.\n"
	e2, d2, pa2, ce2 := countAll(t, hurt)
	t.Logf("%-34s errs=%-3d data=%-3d paras=%-3d commentEntry=%d", "EXEC CICS after para 1", e2, d2, pa2, ce2)
```

**The IDMS injection pattern to copy for shapes (b), (c), (d) (`cascade_test.go:78-85`)** —
note the `const` for the statement, the invented-names disclaimer, and the reuse of `lines`:

```go
	// IDMS DML, injected in exactly the place the EXEC CICS case injects, so
	// the two are directly comparable. All record and set names below are
	// invented and neutral - nothing is derived from any real estate.
	const idmsStmt = "           OBTAIN FIRST CUSTOMER-REC WITHIN CUST-ORDER-SET.\n"
	injectedProcIDMS := lines[0] + "\n" + lines[1] + "\n" + idmsStmt + lines[2]
	hurt3 := head + data.String() + mid + injectedProcIDMS + "           STOP RUN.\n"
	e4, d4, pa4, ce4 := countAll(t, hurt3)
	t.Logf("%-34s errs=%-3d data=%-3d paras=%-3d commentEntry=%d", "IDMS DML after para 1", e4, d4, pa4, ce4)
```

**Recovery summary block (`cascade_test.go:95-99`)** — add one `t.Logf` line per new shape:

```go
	t.Log("")
	t.Logf("recovery after EXEC CICS : %d/%d paragraphs, %d/%d data items", pa2, pa, d2, d)
	t.Logf("recovery after SCHEMA SEC: %d/%d paragraphs, %d/%d data items", pa3, pa, d3, d)
	t.Logf("recovery after IDMS DML  : %d/%d paragraphs, %d/%d data items", pa4, pa, d4, d)
	t.Logf("recovery IDMS DML in data: %d/%d paragraphs, %d/%d data items", pa5, pa, d5, d)
```

**The comment pre-sanctioning D-27's edit (`cascade_test.go:101-113`)** — the executor **must
amend this comment** since it currently says the EXEC CICS case is *not* asserted:

```go
	// --- IDMS-04 gate ---
	//
	// Assertions are deliberately scoped to the IDMS cases only. The EXEC CICS
	// case is Phase 3's gate and SCHEMA SECTION belongs to preprocessing per
	// locked decision D3; hard-asserting either here would fail the build on a
	// known-open problem this phase does not fix.

	// The clean control anchors every parity comparison below. Without this,
	// a regression that lowered the baseline would make a broken parity check
	// look green.
	if d != 20 || pa != 20 {
		t.Fatalf("clean control moved: got %d data items and %d paragraphs, want 20 and 20", d, pa)
	}
```

**The parity-assertion pattern to copy verbatim (`cascade_test.go:115-122`)** — D-27 wants
exactly this shape for each of the four CICS shapes, asserting both `pa` and `d`:

```go
	// IDMS DML injected after paragraph 1 must not cascade: every following
	// paragraph and every data item survives at parity with the clean control.
	if pa4 != pa {
		t.Errorf("IDMS DML after para 1 cascaded: got %d paragraphs, want %d (clean control)", pa4, pa)
	}
	if d4 != d {
		t.Errorf("IDMS DML after para 1 cascaded: got %d data items, want %d (clean control)", d4, d)
	}
```

**The WORKING-STORAGE negative control (`cascade_test.go:124-131`)** — asserts an error is still
reported, not parity. Leave unchanged; it is the precedent for how a "must still fail" case is
written if Phase 3 adds one:

```go
	// Negative control. OBTAIN is a procedural DML verb, so it is invalid
	// inside WORKING-STORAGE and must NOT parse there - the IDMS statements
	// attach to the procedure-division statement set only. Parity here would
	// mean the grammar had started accepting invalid COBOL, so the gate asserts
	// the error is still reported rather than asserting recovery.
	if e5 == 0 {
		t.Errorf("IDMS DML in WORKING-STORAGE parsed without error: procedural DML is not valid in the DATA DIVISION and must still be reported")
	}
```

**The counter under measurement (`cascade_test.go:31-38`)** — `paragraph_header` is an exact
string match; this is D-16b's axis:

```go
		switch n.Type() {
		case "data_description", "data_description_entry":
			dataItems++
		case "paragraph_header":
			paras++
		case "comment_entry":
			commentEntry++
		}
```

**Do not change `countAll`.** All four D-28 shapes reuse it.

---

### `docs/baseline.md` (documentation, batch record)

**Analog:** the file's own §2 and §4. Two recording formats to copy.

**§2 invocation block (`docs/baseline.md:31-38`)** — the exact command form to cite for the
D-26 reconstruction:

```
Exactly `gortex/internal/parser/forest/cobolprobe/README.md`'s documented command, run
2026-08-29:

```
go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m \
    -corpus      ~/repos/mine/cobolCode/cam-corpus-dcc/DCC \
    -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC
```
```

**§4 measured-cells table (`docs/baseline.md:153-161`)** — the row-per-phase table format, and
**line 160-161 is the verbatim-log-line convention** the reconstruction must follow:

```markdown
### Measured cells

| ext | files | clean | clean% | dataItems (grammar-alone) | dataItems (+ neutralize) |
|-----|-------|-------|--------|---------------------------|--------------------------|
| `.cbl` (Phase 1) | 606 | 13 | 2% | 17,905 | 32,360 |
| `.cbl` (Phase 2) | 606 | 13 | 2% | **17,905** | **32,360** |
| `.cpy` (Phase 2) | 958 | 0 | 0% | 0 | 22,800 |

Verbatim: `probe_test.go:141`: `.cbl 606 13 2% 17905 42`;
`neutralize_test.go:139`: `.cbl 606 | 13 -> 14 | 17905 -> 32360 | 15323 -> 16732`.
```

**Line 161 is the only recorded `paragraph_header` pair** — `15,323 -> 16,732`, Phase 2
completion only. That absence of a Phase 1 number is precisely what D-26 exists to fix. The
reconstruction record must (a) cite the pre-Phase-2 SHA as a citable constant, (b) reproduce the
§2 invocation verbatim, (c) add a `paragraph_header` column or a parallel table with the same
`Verbatim: <file>:<line>: <raw log line>` attestation form.

**§4 gap-closure fraction block (`docs/baseline.md:165-175`)** — the arithmetic-shown-inline
convention for the D-16d gap-closure claim:

```markdown
### Gap-closure fraction

Using the §2 constants verbatim — 17,905 grammar-alone and 32,360 neutralized, gap 14,455:

```
(X − 17,905) / (32,360 − 17,905) = (17,905 − 17,905) / 14,455 = 0
```

**Phase 2's measured share of the gap is 0.** D-15's written-cause requirement therefore fires.

### Written cause: the DATA DIVISION is gated at SCHEMA SECTION
```

Copy this exact shape for the `paragraph_header` axis: `(X − 15,323) / (16,732 − 15,323)`, gap
1,409, plus a `### Written cause: …` section if D-15/D-30 fires.

---

### Regenerated + vendored artifacts (`src/*`, `forest-shim/cobol/*`)

**Analog:** `forest-shim/refresh.sh` — one command, six steps. What it actually does:

| Step | Lines | Action | Failure mode |
|------|-------|--------|--------------|
| 1 | 57-89 | `cd $TOP_DIR && npm ci`. **The `npm ci` exit code is NOT the gate** — the gate is `[ -x "$TREE_SITTER" ]` (line 78). Aborts the whole script with `exit 1` if the binary is missing. | node-gyp failure is tolerated by design |
| 2 | 91-109 | `cd $TOP_DIR && "$TREE_SITTER" generate`. Then `git status --porcelain src/`; a non-empty diff is reported as **informational, not a failure** (line 104) | generate non-zero → `FAIL_COUNTER++` |
| 3 | 111-148 | `cp` of `src/parser.c`, `src/scanner.c`, `src/grammar.json`, `src/tree_sitter/parser.h` into `$SHIM_DIR`; then a loop over `"$TOP_DIR"/queries/*.scm` doing **`rm -f` before `cp`** (lines 131-141) | `rm -f` first is mandatory: module-cache files arrive 0444 and plain `cp` fails |
| 4 | 150-170 | Two `sed -i ''` rewrites — `include "tree_sitter/parser.h"` → `include "parser.h"` in `parser.c`, and the angle-bracket form `<tree_sitter/parser.h>` in `scanner.c`. Then greps to confirm neither path survives | one sed pattern catches only one form |
| 5 | 172-194 | `diff -q` of `binding.go`, `plugin.go`, `go.mod` against `$FOREST_CACHE` (default `$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1`) | hard FAIL unless `REFRESH_ALLOW_DRIFT` set. **Never edit those three files** |
| 6 | 196-207 | `cd "$SHIM_DIR" && go build ./...` — **last, and the exit code gates the whole run** | half-updated shim can never report success |

**The `cics.scm` publication path is Step 3's loop, lines 131-141, verbatim:**

```bash
SCM_COPIED=""
for SCM_FILE in "$TOP_DIR"/queries/*.scm; do
    if [ -f "$SCM_FILE" ]; then
        rm -f "$SHIM_DIR/$(basename "$SCM_FILE")"
        cp "$SCM_FILE" "$SHIM_DIR/$(basename "$SCM_FILE")"
        if [ $? != "0" ]; then
            COPY_OK=0
        else
            SCM_COPIED="$SCM_COPIED $(basename "$SCM_FILE")"
        fi
    fi
done
```

**No pipe change is needed** — dropping `queries/cics.scm` in place is sufficient; `refresh.sh`
carries it to the shim, where `//go:embed grammar.json *.scm` (`forest-shim/cobol/binding.go:25`)
picks it up.

**Regeneration/sync sequence for the planner:**
1. Edit `grammar.js` and/or add `queries/cics.scm`.
2. `node_modules/.bin/tree-sitter test -e '^comment$'` (fast, per-task).
3. `forest-shim/refresh.sh` — regenerates `src/`, vendors into `forest-shim/cobol/`, smoke-builds.
4. Commit the regenerated `src/parser.c`, `src/grammar.json`, `src/node-types.json` **and** the
   refreshed `forest-shim/cobol/{parser.c,scanner.c,grammar.json,parser.h,cics.scm}`.
5. Only then run any gortex-side measurement — `go.work` resolves the shim
   (`~/repos/mine/GoApps/gortex/go.work` `use` list includes
   `/Users/.../tree-sitter-cobol-upgrade/forest-shim/cobol`), so a skipped refresh means gortex
   silently measures the **old** grammar.

**Never hand-edit** `src/parser.c`, `src/grammar.json`, `src/node-types.json`, or anything under
`forest-shim/cobol/`.

---

## Shared Patterns

### Test invocation (the `comment` fixture exclusion)
**Source:** `.github/workflows/fork-checks.yml:34-39`
**Apply to:** every corpus verification step in every plan.

```yaml
      # The comment fixture has failed since before Phase 1. It is an upstream
      # bug in a file this fork never touched, last edited at upstream commit
      # 4bc6ff5. The open deviation is recorded in .planning/WINDOWS.md. This
      # standing exclusion must be revisited rather than silently forgotten.
      - name: Run non-comment corpus fixtures
        run: node_modules/.bin/tree-sitter test -e '^comment$'
```

A bare `tree-sitter test` reads red on a pre-existing failure. **Always** `-e '^comment$'`.
CI also runs `node_modules/.bin/tree-sitter generate` (line 32) before testing — so a plan that
adds fixtures without regenerating still gets caught in CI.

### Invented-neutral-names rule (estate-leak guard)
**Source:** `cascade_test.go:79-80`
**Apply to:** `test/corpus/exec_cics.txt`, `queries/cics.scm` comments, all cascade-test shapes.

```go
	// the two are directly comparable. All record and set names below are
	// invented and neutral - nothing is derived from any real estate.
```

Write this disclaimer inline wherever an estate-shaped construct is reproduced in a tracked file.

### Shell-script house style
**Source:** `forest-shim/refresh.sh:19-24`
**Apply to:** any new fork-local script.

```bash
# House style, matching run_nist_cobol85.sh and test/check_tests.sh: no
# `set -e`/`set -u` anywhere in this repo's scripts — every command that can
# fail is followed by an explicit `$?` check, integer counters accumulate a
# result, and the aggregate exit code reflects that counter, not the last
# command run. Every report line is dual-written to stdout and to
# $REFRESH_LOG via `tee -a`.
```

### `.git/info/exclude`, never `.gitignore` (FORK-02)
**Source:** `forest-shim/refresh.sh:45-55`
**Apply to:** any new untracked artifact this phase produces (e.g. a census output file).

```bash
# Declare the refresh log untracked via the repo-local exclude file, never
# .gitignore: .gitignore is upstream-owned, and D-14 keeps fork-local entries
# out of it so `git pull upstream` stays painless — the same split that
# already holds the /estate/ exclusion. Idempotent: safe to run every time.
EXCLUDE_FILE="$TOP_DIR/.git/info/exclude"
if [ -f "$EXCLUDE_FILE" ]; then
    grep -qF '/forest-shim/refresh.log' "$EXCLUDE_FILE" > /dev/null 2>&1
    if [ $? != "0" ]; then
        echo '/forest-shim/refresh.log' >> "$EXCLUDE_FILE"
    fi
fi
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Fork-local test that compiles `queries/cics.scm` and asserts the four named captures (CICS-02, D-24) | test | request-response | **No test in this repo compiles a tree-sitter query.** The fork contains exactly three Go files — `forest-shim/cobol/{binding.go, plugin.go, smoke_test.go}` — and `smoke_test.go` only asserts `GetQuery()` returns non-empty **bytes**; it never parses or executes a query. `grep` for `NewQuery` / `QueryCursor` across the fork returns nothing. |

**Nearest structural precedent — `forest-shim/cobol/smoke_test.go:14-32`:**

```go
//go:build !plugin

package cobol

import (
	"encoding/json"
	"testing"
)

// TestShimExposesForestSurface pins the drop-in contract (VEND-01, D-03): the shim
// must expose the same three functions forest's binding.go exposes, with the same
// behavior, so a later gortex change cannot fail as an undefined symbol at the
// resolution boundary.
func TestShimExposesForestSurface(t *testing.T) {
	if GetLanguage() == nil {
		t.Fatal("GetLanguage() returned nil, want non-nil unsafe.Pointer")
	}

	sample := GetQuery("sample")
	if len(sample) == 0 {
		t.Fatal("GetQuery(\"sample\") returned empty, want non-empty bytes")
	}
	...
```

**Conventions this precedent establishes and the new test should follow:** `//go:build !plugin`
tag, `package cobol`, one `Test…` func per contract property, a doc comment naming the
requirement ID and the decision (`(VEND-01, D-03)`), and `t.Fatalf` with a `got X, want Y` message.

**Hard constraint the planner must resolve:** `forest-shim/cobol/go.mod` is **63 bytes with zero
dependencies**:

```
module github.com/alexaandru/go-sitter-forest/cobol

go 1.22.2
```

and `refresh.sh` Step 5 (lines 172-194) **hard-fails** if `go.mod` differs from the forest module
cache. A Go query-compile test placed in `forest-shim/cobol/` therefore **cannot add a
tree-sitter Go binding dependency** without breaking the drift check. Two viable routes, planner
must pick one:
- **(a) CLI-based, no Go dep** — `node_modules/.bin/tree-sitter query` exists in the pinned
  0.24.5 CLI (`tree-sitter --help`: `query  Search files using a syntax tree query`). A shell
  test in repo root, house-style per `refresh.sh`, invoking
  `node_modules/.bin/tree-sitter query queries/cics.scm <fixture.cbl>` and grepping the output
  for the four capture names. **No Go, no go.mod change, no drift risk.** Recommended.
- **(b) Go test outside the shim** — a new module elsewhere in the fork with its own `go.mod`
  depending on a tree-sitter Go binding. Adds a dependency to a phase whose research states
  "this phase installs no external packages," and adds a second Go module to the fork.

---

## Metadata

**Analog search scope:** `grammar.js`, `queries/`, `test/corpus/`, `forest-shim/`, `.github/workflows/`, `docs/`, all `*.go` in the fork; cross-repo `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/`
**Files scanned:** 16 read directly; full-repo `grep`/`find` for Go test analogs
**Pattern extraction date:** 2026-09-09
