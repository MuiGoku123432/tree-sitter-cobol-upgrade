# Phase 1: Delivery Pipe & Measurement Baseline - Pattern Map

**Mapped:** 2026-08-28
**Files analyzed:** 9 (new files/dirs this phase writes)
**Analogs found:** 6 exact/role-match / 9 total (3 have no in-repo analog; external analog used instead)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `forest-shim/cobol/binding.go` | provider (cgo language binding) | request-response (GetLanguage/GetQuery/Info) | `$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/binding.go` (external, byte-faithful mirror per D-03) | exact — must be byte-identical except embedded file contents |
| `forest-shim/cobol/plugin.go` | provider (cgo plugin variant) | request-response | same module cache path, `plugin.go` | exact |
| `forest-shim/cobol/go.mod` | config | — | same module cache path, `go.mod` | exact (module path copied verbatim, `go` directive may differ) |
| `forest-shim/cobol/parser.c`, `parser.h`, `scanner.c`, `grammar.json`, `sample.scm`, `_keep.scm`, `alloc.h`, `array.h` | config/generated (vendored build artifacts) | file-I/O (copy-and-flatten) | this fork's own `src/parser.c`, `src/scanner.c`, `src/tree_sitter/parser.h`, `src/grammar.json` (content source) + module-cache `alloc.h`/`array.h`/`sample.scm`/`_keep.scm` (structure source, forest doesn't have these generated from this fork) | role-match — two different analogs compose into one file set |
| `forest-shim/refresh.sh` | utility (shell automation) | batch (copy + sed rewrite + diff report) | `run_nist_cobol85.sh` (repo root, invoked via `npm run nist`) and `test/check_tests.sh` (invoked via `cd test && bash check_tests.sh`) | role-match — house shell-script style, not npm-wired per D-07 |
| `.githooks/pre-push` (or guard script + hook) | middleware (git guard) | event-driven (fires on `git push`) | none in-repo — no existing hook or guard script exists (`.git/hooks/` has only `pre-push.sample`) | no analog — build from RESEARCH.md's `core.hooksPath` recommendation |
| guard self-test script (D-18: fail-then-pass on two throwaway branches) | test | batch | none in-repo — closest *shape* analog is `test/check_tests.sh`'s "iterate + assert + report" loop, but it drives `cobc`, not `git` | no direct analog — reuse `check_tests.sh`'s state-machine/report style loosely |
| `docs/vendoring.md` | config/documentation | — | `docs/spec/SPEC-001-nodes-for-edges.md` | exact — only doc in the repo, sets the house style |
| `docs/baseline.md` | config/documentation | — | `docs/spec/SPEC-001-nodes-for-edges.md` | exact |

## Pattern Assignments

### `forest-shim/cobol/binding.go` and `plugin.go` (provider, request-response)

**Analog:** `$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/binding.go` and `plugin.go` — both 79 lines, differing only in the `//go:build` tag and `package` clause (`package cobol` vs `package main`).

D-03 requires a **byte-faithful mirror**. Copy verbatim, do not paraphrase. Full text of `binding.go` (identical body applies to `plugin.go` with `//go:build plugin` / `package main` substituted):

```go
//go:build !plugin

package cobol

//#include "parser.h"
//TSLanguage *tree_sitter_COBOL();
import "C"

import (
	"embed"
	"strings"
	"unsafe"
)

const (
	_ byte = iota
	NvimFirst
	NativeFirst
	NvimOnly
	NativeOnly
)

const nvimts = "nvimts__"

//go:embed grammar.json *.scm
var files embed.FS

func GetLanguage() unsafe.Pointer {
	return unsafe.Pointer(C.tree_sitter_COBOL())
}

func GetQuery(kind string, opts ...byte) (out []byte) {
	kind = strings.TrimSuffix(kind, ".scm") + ".scm"

	pref := NvimFirst
	if len(opts) > 0 {
		pref = opts[0]
	}

	var err error

	switch pref {
	case NvimFirst:
		out, err = files.ReadFile(nvimts + kind)
		if err == nil && len(out) > 0 {
			return
		}

		out, _ = files.ReadFile(kind)

		return
	case NativeFirst:
		out, err = files.ReadFile(kind)
		if err == nil && len(out) > 0 {
			return
		}

		out, _ = files.ReadFile(nvimts + kind)

		return
	case NvimOnly:
		out, _ = files.ReadFile(nvimts + kind)
		return
	case NativeOnly:
		out, _ = files.ReadFile(kind)
		return
	}

	return
}

func Info() string {
	out, err := files.ReadFile("grammar.json")
	if err != nil {
		return err.Error()
	}

	return string(out)
}
```

**cgo directive to preserve exactly:** `//#include "parser.h"` and `//TSLanguage *tree_sitter_COBOL();` immediately above `import "C"` — this is the entire cgo surface; the C function name `tree_sitter_COBOL` must match the symbol this fork's generated `parser.c` exports (verify with `nm` or grep `TSLanguage *tree_sitter_COBOL` in this fork's `bindings/c/` header if present, or in `parser.c` itself).

**Exported signatures gortex depends on (signature-compatible or gortex fails to compile):**
```go
func GetLanguage() unsafe.Pointer
func GetQuery(kind string, opts ...byte) (out []byte)
func Info() string
```

**Files each `binding.go`/`plugin.go` expects to `//go:embed`:** `grammar.json` and any `*.scm` files sitting flat in the same package directory (`sample.scm`, `_keep.scm`, and optionally `nvimts__*.scm` variants — none of the latter exist in the v1.9.1 cache, so omit them).

**`go.mod` to copy** (module-cache source, verbatim module path per D-01):
```
module github.com/alexaandru/go-sitter-forest/cobol

go 1.22.2
```
(The `go` directive can be bumped to match this fork's toolchain if needed for the cgo build; the module path line must not change — that's the entire drop-in contract.)

---

### `forest-shim/cobol/parser.c`, `scanner.c`, `parser.h`, `grammar.json` (config/generated, file-I/O)

**Analog:** this fork's own `src/parser.c`, `src/scanner.c`, `src/tree_sitter/parser.h`, `src/grammar.json` — these are the *content* source (D-04: physically copied and flattened, not the module-cache versions, since the whole point is the fork's own grammar reaching gortex).

**Critical pattern — the `#include` rewrite (verified required, not optional; RESEARCH.md "Pitfall 1"):**

`src/parser.c:1` uses quoted form:
```c
#include "tree_sitter/parser.h"
```
`src/scanner.c:1` uses angle-bracket form:
```c
#include <tree_sitter/parser.h>
```

Both must be rewritten post-copy to the flattened path:
```bash
sed -i '' 's#include "tree_sitter/parser.h"#include "parser.h"#' parser.c
sed -i '' 's#include <tree_sitter/parser.h>#include "parser.h"#' scanner.c
```
Without both rewrites the cgo build fails with `fatal error: 'tree_sitter/parser.h' file not found` — this is the exact failure mode `refresh.sh` must never reintroduce.

**`parser.h`, `alloc.h`, `array.h`, `sample.scm`, `_keep.scm`:** `parser.h` comes from `src/tree_sitter/parser.h` (flattened, no rewrite needed inside it per this session's verification — it does not reference `array.h`/`alloc.h`). `alloc.h`, `array.h`, `sample.scm`, `_keep.scm` have no equivalent in this fork's `src/` tree at all — copy them from the module-cache path unmodified; they are structural filler required by forest's file-set contract (D-04) even though `alloc.h`/`array.h` are currently inert (nothing includes them).

---

### `forest-shim/refresh.sh` (utility, batch)

**Analogs:** `run_nist_cobol85.sh` (repo root) and `test/check_tests.sh` (`test/`).

**House shell style extracted from `run_nist_cobol85.sh`** (full file, 43 lines):
- No shebang line present at all (first line is a variable assignment) — the repo's convention is a bare POSIX-ish script invoked via `sh run_nist_cobol85.sh` (see `package.json`'s `"nist": "sh run_nist_cobol85.sh | tee nist.txt"`), not `./script.sh`.
- No `set -e` / `set -u` anywhere — the script instead checks `$?` explicitly after each command:
```sh
$TREE_SITTER parse $file > $COBOL85_TEST_RESULT_DIR/$FILE_NAME_BODY.txt
if [ $? = "0" ]; then
    TEST_SUCCESS_COUNTER=$((TEST_SUCCESS_COUNTER+1))
    echo $(basename $file) OK | tee -a $COBOL85_TEST_RESULT_SUMMARY
else
    TEST_FAIL_COUNTER=$((TEST_FAIL_COUNTER+1))
    echo $(basename $file) "<NG>" | tee -a $COBOL85_TEST_RESULT_SUMMARY
fi
```
- Locates the tree-sitter binary via a relative path variable, not `$PATH` lookup or `npx`:
```sh
TOP_DIR=./
TREE_SITTER=$TOP_DIR/node_modules/.bin/tree-sitter
```
(RESEARCH.md flags this fails silently per-file, not upfront, if `node_modules/` is absent — `refresh.sh` should check for the binary's existence upfront and fail loudly, an improvement over this analog, not a deviation from house style.)
- Counters accumulate in plain shell integer variables (`TEST_TOTAL_COUNTER`, etc.), incremented with `$(( ... ))`.
- **Exit-code discipline:** the script's own exit code reflects aggregate pass/fail, not the last command run:
```sh
if [ ${TEST_FAIL_COUNTER} != 0 ]; then
    exit 1
else
    exit 0
fi
```
- Every report line is written via `tee -a $SUMMARY_FILE` — both to stdout and to a persisted result file — this is the pattern to replicate for `refresh.sh`'s drift-check report (write to stdout, and to a file under `docs/` or `forest-shim/`, planner's discretion per "warning vs. hard failure" open item).

**House style extracted from `test/check_tests.sh`** (full file, 67 lines):
- Shebang present: `#!/bin/bash` (the only script in the repo that declares one).
- Uses a small explicit state machine (`STATE_BEFORE_TITLE`, `STATE_PARSE_TITLE`, ... as named integer constants) to parse structured text — not directly reusable for `refresh.sh`'s copy/sed/diff task, but establishes that multi-phase shell logic in this repo is written as named-state loops, not deeply nested conditionals.
- Also accumulates a `RETURN_CODE` variable and returns it via `exit $RETURN_CODE` at the end rather than exiting early — same exit-discipline convention as `run_nist_cobol85.sh`.
- Invoked via `cd test && bash check_tests.sh` (relative-directory `cd`, not absolute paths) per `package.json`'s `"ct"` script — `refresh.sh` living inside `forest-shim/` should assume it's invoked from that directory or resolve its own directory before doing relative copies, matching this convention.

**Composite recommendation for `refresh.sh`:** shebang `#!/bin/bash` (matches the one script in the repo that has one and is closer in spirit — a maintenance tool, not a CI-invoked pass/fail gate), explicit `$?` checks (not `set -e`) to match `run_nist_cobol85.sh`'s house style, `tee`-style dual reporting, and an aggregate exit code reflecting whether the drift check found unexpected differences (hard-fail vs. warning is explicitly Claude's Discretion per CONTEXT.md).

**Required steps `refresh.sh` must perform** (RESEARCH.md, VEND-04, not optional):
1. `npm ci` (never `npm install` — the lockfile pins `tree-sitter-cli` at exactly `0.24.5`; `npm install` can float to `0.24.6`/`0.24.7` under the `^0.24.5` range in `package.json:30`).
2. `tree-sitter generate` (regenerates `src/*` from `grammar.js` — a no-op this phase since no grammar changes are made, per CONTEXT.md's explicit scope boundary).
3. Copy-and-flatten `src/parser.c` → `parser.c`, `src/scanner.c` → `scanner.c`, `src/grammar.json` → `grammar.json`, `src/tree_sitter/parser.h` → `parser.h` into `forest-shim/cobol/`.
4. Run both `sed` rewrites above on the copied `parser.c` and `scanner.c`.
5. Diff the shim's Go surface (`binding.go`, `plugin.go`, `go.mod`) against the module-cache copy at `$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/` and report drift (D-03's "check the refresh script should run").
6. Self-check: `go build ./...` inside `forest-shim/cobol/` (no cgo consumer needed) as the smoke test before reporting success.

---

### `.githooks/pre-push` guard + install step (middleware, event-driven)

**No in-repo analog exists.** State this plainly rather than forcing a fit — `.git/hooks/` currently holds only the default `pre-push.sample`, and `core.hooksPath` is unset (git default).

**Follow RESEARCH.md's verified recommendation:** use `core.hooksPath` pointing at a tracked `.githooks/` directory (not a raw `.git/hooks/pre-push` copy), so the hook script is committed, diffable, and reviewable — same rationale D-17 already gives for choosing `pre-push` over CI (visibility). One-line install per clone:
```sh
git config core.hooksPath .githooks
```

**The three checks the guard script must implement (D-16), each independently verified this session:**
1. Reject any `estate/` path in staged/committed diff — `git diff --cached --name-only` (or the pre-push equivalent walking the ref range git passes on stdin) grepped for a leading `estate/`.
2. Assert `.git/info/exclude` still contains `/estate/` and `.gitignore` does not contain an `estate` entry — confirmed current state exactly matches this requirement:
```
# .git/info/exclude (verified content)
/estate/
/.gortex.yaml
/.gortexignore
```
   (`.gitignore` has no `estate` line — verified.)
3. Flag added COBOL lines with a populated columns 73-80 sequence area — **must scope to diff-added lines only** (`git diff` `+`-prefixed lines), never a whole-file scan. RESEARCH.md's verified edge case: NIST fixtures under `test/cobol85/src/*.CBL` are 80-column fixed-format and legitimately carry a populated sequence area (sampled `SQ230A.CBL`: identifier `SQ2304.2` at columns 73-80) — a full-file scan would false-positive on any future edit to an existing NIST fixture. Hand-written `test/corpus/*.txt` fixtures (sampled `minimal-cobol.txt`: max line length 36 chars) have no populated sequence area and correctly pass. Comment this scoping decision directly in the guard script so a future editor does not "simplify" it into a full-file scan (RESEARCH.md's explicit warning).

**Known, accepted limitation to document in `docs/vendoring.md`:** `git push --no-verify` bypasses any client-side hook by design; no server-side backstop is in scope this phase.

---

### Guard self-test script (D-18) (test, batch)

**No direct analog** — the closest *shape* is `test/check_tests.sh`'s iterate-and-assert loop, but that drives `cobc`, not `git` branch operations. Build fresh: create two throwaway branches (one with an `estate/`-path or sequence-area-polluted commit, one clean), run the guard against each, assert fail-then-pass, delete both branches afterward. Re-runnable — do not leave branches behind on either success or failure (use a trap/cleanup, matching the general shell-scripting care RESEARCH.md's Security Domain section calls for: quote all paths, avoid `eval` on diff content since the guard processes arbitrary staged file paths).

---

### `docs/vendoring.md`, `docs/baseline.md` (documentation)

**Analog:** `docs/spec/SPEC-001-nodes-for-edges.md` — the only existing file under `docs/`.

**Structural conventions extracted:**
- Title line: `# SPEC-NNN — <short description>` — for `docs/vendoring.md`/`docs/baseline.md`, drop the `SPEC-NNN` numbering (these are not spec documents) but keep the single `#`-level title followed immediately by a metadata block.
- Metadata block immediately under the title, bold-labeled, one per line, no table:
```markdown
**Status:** Accepted, not started
**Date:** 2026-08-28
**Repo:** `MuiGoku123432/tree-sitter-cobol-upgrade` — fork of `yutaro-sakamoto/tree-sitter-cobol` (MIT)
**Consumer:** `gortex` (Gortex Mainframe Engine)
```
- Numbered `##` section headings (`## 1. What this repo is`, `## 2. The goal`, ...) — sections are numbered, not just titled. `docs/vendoring.md`/`docs/baseline.md` should follow the same numbered-`##` convention.
- Horizontal rules (`---`) separate major sections.
- Tables used for measured/quantitative data (see the recall baseline table, §4, and the family/programs/statements table, §5) — `docs/baseline.md`'s pass/fail records (VEND-03) and the re-measured recall figures (VEND-05) should use the same GitHub-flavored-markdown table format, not prose.
- Blockquote callouts (`> ⚠ ...`) used for load-bearing warnings that must not be missed — e.g. the estate-exclusion warning at line 74-78. `docs/vendoring.md` should use the same `> ⚠` convention for its `--no-verify` bypass limitation and the "ABI-compatible, not table-identical" correction (RESEARCH.md Pitfall 5).
- Prose paragraphs stay short (2-4 sentences), wrapped at roughly 90-100 characters per line (visually consistent in the source file — not a hard 80-col wrap).
- Citations to evidence are inline and specific — e.g. "From `gortex/internal/parser/forest/cobolprobe/`, measured on 1,564 files" — not vague ("measured previously"). `docs/vendoring.md`/`docs/baseline.md` should cite exact file paths and line numbers the same way RESEARCH.md does (e.g. `go.mod:28`, `.gitignore:23-24`).
- Opens with plain-language framing before any command/table (SPEC-001 §1 "What this repo is" before any technical table) — matches CONTEXT.md's explicit instruction that `docs/vendoring.md` "should open with that explanation, not with commands."

---

## Shared Patterns

### Shell-script exit discipline
**Source:** `run_nist_cobol85.sh` (repo root) and `test/check_tests.sh` (`test/`)
**Apply to:** `forest-shim/refresh.sh` and the guard/self-test scripts
```sh
# Accumulate a result across a loop, exit reflects the aggregate, not the last command:
if [ ${TEST_FAIL_COUNTER} != 0 ]; then
    exit 1
else
    exit 0
fi
```
No script in this repo uses `set -e`/`set -u`; all use explicit `$?` checks after each command that can fail. New scripts should match this rather than introducing `set -e` for the first time.

### Sequence-area / added-lines scoping
**Source:** RESEARCH.md's verified sampling of `test/cobol85/src/SQ230A.CBL` (columns 73-80 populated, legitimate) vs. `test/corpus/minimal-cobol.txt` (36-char lines, no sequence area)
**Apply to:** the FORK-02 guard only — the single most consequential design constraint in this phase: scope the columns-73-80 check to diff-*added* lines, never whole-file content, or NIST fixtures will false-positive.

### `.git/info/exclude` vs `.gitignore` split
**Source:** verified current state of both files (quoted above)
**Apply to:** FORK-02's assertion check (D-16 point 2) and any documentation in `docs/vendoring.md` explaining why `estate/` lives in `.git/info/exclude` rather than `.gitignore` (keeps the upstream PR diff at zero, per SPEC-001 line 74-78's own stated rationale).

### `docs/` numbered-heading, blockquote-warning house style
**Source:** `docs/spec/SPEC-001-nodes-for-edges.md`
**Apply to:** `docs/vendoring.md`, `docs/baseline.md`

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `.githooks/pre-push` (guard script) | middleware | event-driven | No git hook exists anywhere in this repo (`.git/hooks/` has only the stock `.sample` file); build per RESEARCH.md's `core.hooksPath` recommendation, not from an in-repo shape. |
| Guard self-test script (D-18) | test | batch | No script in this repo drives `git branch`/`git push` operations; closest shape (`check_tests.sh`'s iterate+assert+report loop) drives `cobc`, not `git` — reuse only the reporting convention, not the git logic. |
| `forest-shim/cobol/alloc.h`, `array.h`, `sample.scm`, `_keep.scm` | config (vendored filler) | file-I/O | This fork's `src/` tree has no equivalent files at all; these must be copied unmodified from the module-cache path with no in-repo content to compare against. |

## Metadata

**Analog search scope:** repo root (`run_nist_cobol85.sh`, `package.json`, `.gitignore`, `.git/info/exclude`), `test/` (`check_tests.sh`, `corpus/*.txt`, `cobol85/src/*.CBL`), `src/` (`parser.c`, `scanner.c`, `tree_sitter/parser.h`, `grammar.json`), `docs/spec/` (`SPEC-001-nodes-for-edges.md`), `.git/hooks/` (confirmed empty of real hooks), plus the external module cache at `$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/` (all files) per CONTEXT.md's explicit instruction that this is the authoritative analog for the shim.
**Files scanned:** 12 (6 in-repo, 6 in the external module cache/gortex checkout referenced by RESEARCH.md and re-confirmed here)
**Pattern extraction date:** 2026-08-28
**Note on `estate/`:** no file under `estate/` was read, quoted, or excerpted, per the organization's data-handling policy and CONTEXT.md's explicit constraint — only file-name/line-length observations already present in RESEARCH.md were cited, no new estate reads were performed by this pass.
