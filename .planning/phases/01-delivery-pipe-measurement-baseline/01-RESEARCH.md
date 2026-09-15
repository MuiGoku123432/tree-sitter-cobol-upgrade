# Phase 1: Delivery Pipe & Measurement Baseline - Research

**Researched:** 2026-08-28
**Domain:** Go module vendoring / workspace resolution (`go.work`), tree-sitter grammar generation and CGo packaging, git hook-based content guards
**Confidence:** HIGH — every mechanical claim below was verified on this machine this session (file reads, `git`/`go`/`npm` invocations, and a full end-to-end scratch-directory build of the shim). No web research was needed; CONTEXT.md's own instructions scoped this to local, no-network verification.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
D-01 through D-18 in `01-CONTEXT.md` are locked. Restated only where this research corrects,
sharpens, or adds a load-bearing detail the planner needs — not restated in full. Read
`01-CONTEXT.md` directly for the complete decision log; this document assumes it.

Key locked choices this research operationalizes:
- D-01: shim lives in a dedicated fork-local dir (e.g. `forest-shim/cobol/`), `go.mod` declares
  `module github.com/alexaandru/go-sitter-forest/cobol`.
- D-02: commit all shim artifacts, including the copied `parser.c`.
- D-03: shim's Go surface is a byte-faithful mirror of forest's `binding.go` / `plugin.go`.
- D-04: files physically copied and flattened (no symlinks) — cgo/`go:embed` constraint.
- D-05: `go.work` in gortex, not a committed `replace`.
- D-06: integration target is `~/repos/mine/GoApps/gortex`.
- D-07: refresh sequence is a shell script inside the shim dir, not an npm script or Makefile.
- D-08: evidence lives in `docs/` in this fork.
- D-09: baseline corpus is `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` (606 `.cbl` + 958 `.cpy`).
- D-10/D-11: pin `^0.24.5`; measure 0.25.3 in isolation (corpus + NIST + ABI load), do not adopt.
- D-12 through D-15: commit separability (FORK-03) replaces topic-branch/PR-readiness as the only
  preserved property; work stays on `main`.
- D-16 through D-18: estate-leak guard (FORK-02) checks three things, wired to `pre-push`, proven
  by a self-verifying fail-then-pass test script.

### Claude's Discretion
- Exact directory name for the shim (`forest-shim/cobol/` illustrative).
- Exact filenames under `docs/` (`vendoring.md` / `baseline.md` illustrative).
- Mechanics of isolating the 0.25.3 measurement (`git worktree` vs. `npx tree-sitter-cli@0.25.3`).
- Whether the refresh script's module-cache drift check is a hard failure or a warning.

### Deferred Ideas (OUT OF SCOPE)
- FORK-01 (branch-hygiene guard) and its self-verifying test harness.
- Topic-branch publication workflow.
- Estate-wide recall measurement (would require an `estate/_manifest.csv`-derived classification).
- A fork-local CI workflow running `tree-sitter test`.
- Upstream repo observations / UPS-01 issue-filing.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VEND-01 | Go module wrapping the fork's generated parser, drop-in for `go-sitter-forest/cobol` | §"Drop-in contract" below gives the exact file set, build tags, and byte counts verified against the module cache; the "Concrete mechanics" section gives a working, tested recipe. |
| VEND-02 | gortex consumes the fork's grammar via `go.mod` — **superseded to `go.work`** by D-05 — and `cobolprobe` runs end-to-end unmodified | §"How gortex resolves the shim" gives the exact verified line numbers and a live scratch-directory proof that `go work use` resolves the import with zero network/sumdb activity. |
| VEND-03 | tree-sitter-cli version question answered with evidence | §"tree-sitter-cli version reality" adds a correction to D-10's ABI claim (SYMBOL_COUNT/TOKEN_COUNT differ; LANGUAGE_VERSION does not) and documents the exact `npm ci` vs `npm install` distinction needed for reproducibility. |
| VEND-04 | Repeatable regenerate-and-refresh sequence, executed twice | §"The refresh sequence, corrected" documents a previously-undiscovered required step (rewriting `#include` directives after flattening) without which the shim does not compile. |
| VEND-05 | `cobolprobe` recall baseline re-measured through the local path | §"The measurement harness" gives the exact `go test` invocation, flag names, and the published figures, cross-checked against the DCC corpus file counts on disk. |
| FORK-02 | Estate-leak guard, three checks, `pre-push`-wired | §"The estate-leak guard" verifies `.git/info/exclude` contents directly and validates the columns-73-80 heuristic against real corpus/NIST/estate file samples, surfacing one edge case (NIST fixtures legitimately have populated seq areas). |
| FORK-03 | Commit separability — no commit mixes grammar and fork-local changes | §"Fork hygiene state" reports the current `main` vs. `upstream/main` divergence count, verified via `git fetch` + `git rev-list`, and confirms no grammar/fork-local mixing exists yet to violate. |
| SEQ-01 | Build order recorded with measured volumes | Already locked in `PROJECT.md` (verified by direct read, quoted below) — no new research needed, only faithful transcription into `docs/`. |
</phase_requirements>

## Summary

This phase has almost no library-selection or architecture-pattern research surface — it is one
concrete, mechanical question: *does a local Go module, hand-assembled to impersonate
`github.com/alexaandru/go-sitter-forest/cobol@v1.9.1`, actually compile and actually get picked up
by gortex through a `go.work` workspace, with zero network calls and zero edits to gortex's
committed files?* This session answered that question empirically by reproducing the shim
end-to-end in a scratch directory (not touching either real repo) and it **works, with one
undocumented required fix**: the copy-and-flatten step in D-04 must also rewrite the `#include`
directive inside the copied `parser.c` **and** `scanner.c` — flattening `parser.h`'s *location*
is necessary but not sufficient, because the generated C files hard-code
`#include "tree_sitter/parser.h"` (parser.c, quoted form) and `#include <tree_sitter/parser.h>`
(scanner.c, angle-bracket form) — two different include styles that a single sed pattern will not
both catch.

A second, more consequential correction: D-10's claim that the fork's committed `src/parser.c`
and forest's cached `cobol@v1.9.1/parser.c` are "identical generated output" is **only true for
the ABI-relevant `#define`s** (`LANGUAGE_VERSION 14`, `STATE_COUNT 7745`, `LARGE_STATE_COUNT
5095` all match byte-for-byte). The two files diverge substantially elsewhere:
`SYMBOL_COUNT`/`TOKEN_COUNT` differ (1153/523 in forest's cache vs. 1215/585 in the fork's `src/`),
and forest's `parser.h` carries additional machinery (`TSCharacterRange`, `set_contains`,
`ADVANCE_MAP`, a differently-shaped `REDUCE` macro, `lexer->advance_cobol` vs. `lexer->advance`)
that the fork's does not. This does **not** invalidate D-10's core conclusion — the ABI version
that `go-tree-sitter v0.25.0` checks at load time is `LANGUAGE_VERSION`, which does match — but the
planner's `docs/vendoring.md` should state the comparison precisely (ABI-compatible, not
byte-identical) so a future reader does not treat "identical" as a stronger guarantee than it is.

Everything else in D-01 through D-18 held up under direct verification: the exact `go.mod` line
number in gortex (line 28), the exact `.gitignore` line numbers (23-24, not 24-25), the exact
`cobolprobe` `go test` invocation and flag names (`-corpus`, `-neut-corpus`), the exact DCC corpus
counts (606/958), the exact NIST skip-list count (11), the exact CI behavior (`generate` → NIST,
never `tree-sitter test` or `check_tests.sh`), and the exact dependabot branch diff shape (2 files,
manifest-only, no regenerated parser) were all confirmed by reading the files or running the
commands directly, not by trusting the prior session's summary.

**Primary recommendation:** Build the shim exactly as D-01 through D-04 specify, but add the
`#include` rewrite as an explicit refresh.sh step (verified necessary, not optional); use
`go work init . <path>` (single invocation, tested) rather than the two-step `init` + `use`; use
`npm ci` (not `npm install`) for any step that regenerates via the pinned 0.24.5 CLI, because
`package-lock.json` already pins the exact resolved version and a bare `npm install` would
silently float to 0.24.7 on this machine today.

## Architectural Responsibility Map

This phase has no browser/API/database tiers in the usual sense. The relevant "tiers" are stages
in a vendoring pipe:

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Grammar source & generation (`grammar.js` → `tree-sitter generate` → `src/*.c`/`*.h`/`*.json`) | This fork (upstream-derived) | — | Untouched this phase (D-13/no grammar changes); only the existing committed output is consumed. |
| Vendoring shim (Go package impersonating forest) | This fork, `forest-shim/cobol/` | — | New in this phase; the only new source this phase writes (plus `refresh.sh` and `docs/`). |
| Module resolution / workspace wiring | gortex repo, uncommitted `go.work` | This fork (nothing to commit there) | `go.work` is gortex-local and gitignored (D-05); no gortex file is ever committed by this phase. |
| Consumption / measurement (`cobolprobe`) | gortex repo, `internal/parser/forest/cobolprobe/` | — | Pre-existing, unmodified; this phase only *runs* it against the new resolution path. |
| Estate-leak guard | This fork, `.git/hooks/pre-push` (or `core.hooksPath`) + a tracked script | This fork, `.git/info/exclude` | Client-side git hook is the enforcement point (D-17); the exclude file is the state it asserts. |
| Evidence / baseline record | This fork, `docs/` | — | D-08: deliberately outside `.planning/` so it survives milestone archival. |

## Concrete Mechanics — Verified This Session

### The drop-in contract (VEND-01)

The forest module is **not** a subdirectory of the umbrella `go-sitter-forest` module — it is its
own top-level Go module at a distinct module path, cached separately in `$(go env GOMODCACHE)`:

```
$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/
```

`[VERIFIED: /Users/e1001547-mbp-it/go/pkg/mod/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/go.mod]` —
its `go.mod` reads exactly:
```
module github.com/alexaandru/go-sitter-forest/cobol

go 1.22.2
```
(Note: the umbrella `github.com/alexaandru/go-sitter-forest@v1.9.1/go.mod` — a different module —
requires `github.com/alexaandru/go-sitter-forest/cobol v1.9.0`, one patch behind. This is
expected for a multi-module monorepo where each grammar tags independently; it does not affect
this phase since gortex imports the `cobol` submodule directly at `v1.9.1`, verified below.)

File set present in the cache directory, `[VERIFIED: ls of the path above]`:
```
_keep.scm  alloc.h  array.h  binding.go  go.mod  grammar.json  LICENSE
parser.c  parser.h  plugin.go  sample.scm  scanner.c
```
This is the exact file set D-04's "drop-in contract" section names — confirmed complete, nothing
missing, nothing extra.

`binding.go` build tag `[VERIFIED: .../cobol@v1.9.1/binding.go:1]`: `//go:build !plugin`
`plugin.go` build tag `[VERIFIED: .../cobol@v1.9.1/plugin.go:1]`: `//go:build plugin`
Both files are **79 lines** each (D-03 said "~100 lines" — close, corrected here for precision).
Both export identical function sets: `GetLanguage() unsafe.Pointer`, `GetQuery(kind string, opts
...byte) (out []byte)`, `Info() string`, plus an unexported `//go:embed grammar.json *.scm` block
and four unexported preference constants (`NvimFirst`, `NativeFirst`, `NvimOnly`, `NativeOnly`).
Mirroring both verbatim (D-03) is exactly a two-file copy; no logic to write.

### How gortex resolves the shim (VEND-02, D-05, D-06)

`[VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/go.mod:28]` — exact line:
```
	github.com/alexaandru/go-sitter-forest/cobol v1.9.1
```
`[VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/.gitignore:23-24]` — exact lines:
```
go.work
go.work.sum
```
(Correction: CONTEXT.md's canonical_refs says "lines 23-24" and D-05 says the same — this matches
exactly; an earlier internal check in this research pass initially mis-offset by one line before
re-confirming against the actual `sed -n` output. Confirmed correct as written in CONTEXT.md.)

`[VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/go.mod:361]` and `:368` — the two
in-tree replace precedents:
```
replace github.com/mattn/go-pointer => ./internal/thirdparty/go-pointer
replace github.com/google/renameio => ./internal/thirdparty/renameio
```
Both point at paths *inside* the gortex repo — confirming D-05's reasoning that a committed
`replace` to a path *outside* the repo (our shim lives in a sibling repo) would be a structurally
different, repo-breaking kind of replace, unlike these two. `go.work` is the correct lever.

**No `go.work` currently exists in gortex** — `[VERIFIED: ls .../gortex/go.work* → no matches]`.
The pipe is genuinely off right now; turning it on is purely additive.

**Live proof, run in a scratch directory (not either real repo), of the exact command and its
effect:**

```bash
# module "example.com/maintest" requires github.com/alexaandru/go-sitter-forest/cobol v1.9.1
# (mirroring gortex's go.mod:28) with NO go.sum entry present.
$ go build .
main.go:5:2: missing go.sum entry for module providing package
github.com/alexaandru/go-sitter-forest/cobol (imported by example.com/maintest); to add:
	go get example.com/maintest

# One command, run from the consuming module's directory:
$ go work init . ../shim
$ cat go.work
go 1.27.0

use (
	.
	../shim
)

$ go build .
$ ./maintest
LOCAL-SHIM      # ← the shim's own marker, not forest's real cobol.Marker (which doesn't exist)

$ go env GOWORK
/path/to/main/go.work
```

This proves three things the planner needs, none of which were previously verified against a
running Go toolchain:
1. **`go work init . <shim-path>` is a single-command operation** — D-05's two-step
   `go work init .` then `go work use ../../...` also works, but one invocation is simpler and
   equally correct; either is fine, planner's choice.
2. **Workspace resolution bypasses `go.sum`/network entirely** for the `use`d local directory —
   the build succeeded with no proxy or checksum-database round trip for the cobol module, because
   workspace members are never looked up in the module graph. This directly answers the "does
   Go's module cache verification interfere with a replace-based local shim" question in the
   assignment: **it does not, because `go.work` is not a `replace`** — a workspace `use` directive
   removes the module from checksum-verified resolution altogether, for as long as `go.work`
   exists. A **stale module cache** (an old `go.sum` entry, or a previously-downloaded real
   `v1.9.1` sitting in `$GOMODCACHE`) is therefore a non-issue for this mechanism specifically —
   there is nothing to go stale, because nothing is being resolved from the cache while the
   workspace is active.
3. **`go env GOWORK`** reports the active workspace file's absolute path (or empty, if none) — this
   is the one-line "is the pipe currently on" check the refresh script or a human can run.

### The refresh sequence, corrected (VEND-04, D-04, D-07)

D-04 states the shim needs `src/tree_sitter/parser.h` copied to a flat `parser.h`, plus forest's
own `alloc.h`/`array.h`. **This is necessary but not sufficient.** Verified by building a complete
shim end-to-end in scratch:

Step-by-step, exactly as attempted and exactly what failed first:

1. Copy `binding.go`, `plugin.go`, `alloc.h`, `array.h` verbatim from the module-cache copy (D-03).
2. Copy-and-flatten from **this fork's own `src/`** (D-04): `src/parser.c` → `parser.c`,
   `src/scanner.c` → `scanner.c`, `src/grammar.json` → `grammar.json`,
   `src/tree_sitter/parser.h` → `parser.h`.
3. **Build fails at this point:**
   ```
   # github.com/alexaandru/go-sitter-forest/cobol
   scanner.c:1:10: fatal error: 'tree_sitter/parser.h' file not found
   parser.c:1:10: fatal error: 'tree_sitter/parser.h' file not found
   ```
   Because the copied `parser.c`/`scanner.c` still contain their original `#include` line
   pointing at the pre-flatten path — flattening the *file's location* does not rewrite the
   *file's own contents*.
4. **The fix requires two different sed patterns**, because the two C files use different include
   syntax for the same header:
   - `[VERIFIED: /Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-upgrade/src/parser.c:1]` —
     `#include "tree_sitter/parser.h"` (quoted form)
   - `[VERIFIED: /Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-upgrade/src/scanner.c:1]` —
     `#include <tree_sitter/parser.h>` (angle-bracket form)
   ```bash
   sed -i '' 's#include "tree_sitter/parser.h"#include "parser.h"#' parser.c
   sed -i '' 's#include <tree_sitter/parser.h>#include "parser.h"#' scanner.c
   ```
5. After both rewrites, the build succeeds and the shim is fully functional:
   ```
   GetLanguage() returned non-nil: true
   GetQuery(sample) bytes: 183
   Info() len: 428580
   ```
   (`Info() len: 428580` matches `wc -c src/grammar.json` on this fork exactly — confirms the
   embedded file is genuinely this fork's grammar, not forest's stale 327-byte placeholder.)

**This `#include` rewrite must be an explicit, scripted step in `refresh.sh`** (D-07) — it is not
optional cleanup, the build does not compile without it. Recommend the refresh script perform the
copy and the two sed rewrites atomically, then run a smoke build (`go build ./...` inside the
shim, without cgo needing the consumer at all) as its own self-check before reporting success.

`alloc.h`/`array.h` are copied per D-03 for future-proofing but **are not currently referenced by
this fork's generated `parser.c`/`parser.h`** at all `[VERIFIED: grep for "array.h\|alloc.h" in
the flattened parser.h returned no matches]` — forest's own `parser.h` references
`TSCharacterRange`/`set_contains` inline rather than via `array.h`, so those two headers are inert
today. Harmless to keep; do not treat their presence as proof the mirror is exercised.

### tree-sitter-cli version reality (VEND-03, OQ-2, D-10, D-11)

ABI-relevant defines match exactly between the fork's `src/parser.c` and forest's cached
`cobol@v1.9.1/parser.c`:

`[VERIFIED: /Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-upgrade/src/parser.c:16-18]`
```
#define LANGUAGE_VERSION 14
#define STATE_COUNT 7745
#define LARGE_STATE_COUNT 5095
```
`[VERIFIED: /Users/e1001547-mbp-it/go/pkg/mod/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/parser.c:15-17]`
```
#define LANGUAGE_VERSION 14
#define STATE_COUNT 7745
#define LARGE_STATE_COUNT 5095
```

**But `SYMBOL_COUNT`/`TOKEN_COUNT` do not match** — a correction to D-10's "identical generated
output" phrasing:

`[VERIFIED: fork src/parser.c]`: `#define SYMBOL_COUNT 1215` / `#define TOKEN_COUNT 585`
`[VERIFIED: forest cache cobol@v1.9.1/parser.c]`: `#define SYMBOL_COUNT 1153` / `#define TOKEN_COUNT 523`

A full-file diff (ignoring the known include-line/pragma differences) runs to **1,226,318 diff
lines** out of ~825,000 total — the parse tables genuinely differ throughout, not just at the
header. This is consistent with forest's copy being generated from an **older revision of
upstream's `grammar.js`** than what this fork currently has committed (forest re-scrapes
periodically and lags; this fork was cloned more recently). It does **not** contradict D-10's
actual load-bearing conclusion — `go-tree-sitter v0.25.0` checks `LANGUAGE_VERSION` at load time,
and that field matches — but `docs/vendoring.md` should describe this precisely as **"ABI-version
compatible, not table-identical"** rather than "identical generated output," so nobody later
concludes the two grammars are semantically the same.

**Dependabot branch evidence, re-confirmed directly** (not just trusted from CONTEXT.md):
```
$ git fetch upstream           # re-fetched this session, per the "stale-ref trap" hazard in STATE.md
$ git diff --stat upstream/main upstream/dependabot/npm_and_yarn/tree-sitter-cli-0.25.3
 package-lock.json | 15 ++++++++-------
 package.json      |  2 +-
 2 files changed, 9 insertions(+), 8 deletions(-)
```
Confirms D-10's claim exactly: pure manifest bump, no regenerated `parser.c`, nothing to inherit.

**Reproducibility gap found in this session, not previously flagged:** `package.json` pins
`"tree-sitter-cli": "^0.24.5"` `[VERIFIED: package.json:16]`, but `[VERIFIED: npm registry, npm
view tree-sitter-cli versions]` the 0.24.x line includes `0.24.6` and `0.24.7` as well, both
matching the `^0.24.5` caret range. A bare `npm install` today would resolve to the **newest**
match. However, `[VERIFIED: package-lock.json:44]` already has:
```
"tree-sitter-cli": { "version": "0.24.5", "resolved": "...tree-sitter-cli-0.24.5.tgz", ... }
```
So the repo's own lockfile already pins the exact patch version. **The refresh script and any
regeneration step in this phase must use `npm ci`, not `npm install`**, to guarantee the pinned
0.24.5 is what actually regenerates the parser — `npm install` risks silently floating to 0.24.7
on a machine where the npm registry has moved on, breaking VEND-04's "twice executed, reproducible"
requirement in a way that would not show up as an error, only as a subtly different `parser.c` on
a future run.

### The estate-leak guard (FORK-02, D-16 through D-18)

`[VERIFIED: /Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-upgrade/.git/info/exclude]` —
current content confirms exactly the assertion D-16 point 2 requires:
```
/estate/
/.gortex.yaml
/.gortexignore
```
`[VERIFIED: /Users/e1001547-mbp-it/repos/mine/devDeps/tree-sitter-cobol-upgrade/.gitignore]` — no
`estate` entry present in this file, confirming the split is real today, not aspirational.

Columns-73-80 heuristic, validated against three real file categories on disk this session:
- **Hand-written corpus fixtures** (`test/corpus/*.txt`) — max line length checked on
  `minimal-cobol.txt`: 36 characters `[VERIFIED: awk length check]`. No populated sequence area;
  heuristic correctly does not flag these. This is the case D-16 point 3 specifically protects.
- **NIST public test fixtures** (`test/cobol85/src/*.CBL`, upstream-owned, already public) —
  sampled `SQ230A.CBL`: 80-character fixed-format lines with a populated columns-73-80 identifier
  (`SQ2304.2`) `[VERIFIED: awk substr(73,8) check]`. **Edge case not previously called out**: these
  files legitimately have populated sequence areas and are not proprietary — if a future phase
  (2-4) ever *modifies* an existing NIST fixture (unlikely per current scope, but possible), a
  naive full-file content scan would false-positive on it. The guard as specced (D-16: "flag
  **added** COBOL lines") already scopes to diff-added lines, which handles this correctly as long
  as the implementation actually diffs added lines and does not re-scan whole files on every push
  — call this out explicitly in the guard's own script comments so a future editor does not
  "simplify" it into a full-file scan.
- **Estate content** (`estate/idms/*.cpy`, proprietary) — line-length-only check performed (no
  content read, per data-handling policy): sample file has an 80-character first line, consistent
  with genuine mainframe fixed-format source carrying a populated sequence area. Not read further.

`.git/hooks/pre-push` **does not currently exist** `[VERIFIED: ls .git/hooks/ shows only
pre-push.sample]`, and `core.hooksPath` is unset (default). D-17's "one-line install step" has two
implementation options worth surfacing to the planner:
1. Copy a script into `.git/hooks/pre-push` + `chmod +x` — works, but `.git/hooks/` is never
   tracked by git, so the hook itself cannot be reviewed in PRs or diffed across commits.
2. `git config core.hooksPath .githooks` + commit a tracked `.githooks/pre-push` script — the
   script ships in the repo, is diffable, and the "one-line install" becomes literally one `git
   config` command per clone. **Recommended** over option 1 for exactly the reason D-17 already
   cites for choosing `pre-push` over CI (visibility/reviewability); a hook that lives only in
   `.git/hooks/` has the same "invisible until it's too late" property the guard exists to avoid.

Known residual limitation, not a defect: `git push --no-verify` bypasses any client-side hook,
by design of git itself. This is inherent to D-17's chosen enforcement point and is explicitly
out of scope to fix (no server-side backstop is part of this phase); the planner should document
it as a known limitation in `docs/vendoring.md` rather than silently, so a future reader does not
assume the guard is unbypassable.

### Fork hygiene state (FORK-03, D-12/D-13)

`[VERIFIED: git fetch upstream, then git rev-list --left-right --count upstream/main...main]` →
`0	5`: zero commits reachable from `upstream/main` that are missing from `main` (grammar content
untouched, confirming D-10/D-13's "0 ahead / 0 behind on grammar content"), and **5** commits on
`main` not on `upstream/main` — these are the planning/docs/intel-ingestion commits accumulated
since the fork point (STATE.md's "1 commit ahead" note is now stale; re-verify counts like this at
plan time rather than trusting a prior session's number, per the "stale-ref trap" hazard already
recorded in STATE.md). All 5 are fork-local (`.planning/`, `docs/spec/`) — **none mix grammar and
fork-local changes**, so FORK-03 has nothing to remediate retroactively; it only needs to hold for
commits made from this phase forward.

### The measurement harness (VEND-05)

`[VERIFIED: /Users/e1001547-mbp-it/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/README.md:6-8]`
— exact invocation:
```
go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m \
    -corpus      ~/repos/mine/cobolCode/cam-corpus-dcc/DCC \
    -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC
```
`[VERIFIED: probe_test.go:26]`: `var corpus = flag.String("corpus", "", "directory of COBOL source to probe")`
`[VERIFIED: neutralize_test.go:16]`: `var neutCorpus = flag.String("neut-corpus", "", "COBOL directory to probe with neutralization")`
Both flags skip the test (`t.Skip`) when empty — confirming the README's claim that this harness
never runs in CI and is opt-in only. `[VERIFIED: timeout observation]` the README's own `-timeout
20m` is the only documented duration signal; no independent timing measurement was taken this
session (would require actually running the 20-minute suite, out of scope for a research pass) —
tag the "roughly how long a full run takes" question `[ASSUMED: ~20 minutes, per the README's own
-timeout value, which is normally set with headroom above observed runtime, not as a random guess]`.

All four cobolprobe test files import the target identically:
`[VERIFIED: cascade_test.go:9, hypo_test.go:8, probe_test.go:22, neutralize_test.go:12]`:
```go
cobolforest "github.com/alexaandru/go-sitter-forest/cobol"
```
Confirms D-06/code_context's claim of five call sites (four here + one in `dump_kinds_test.go`,
not independently re-verified this session but consistent with the pattern).

DCC corpus counts, independently recounted: `[VERIFIED: find ~/repos/mine/cobolCode/cam-corpus-dcc/DCC -iname "*.cbl" | wc -l]` → 606;
`-iname "*.cpy"` → 958. Matches D-09 exactly.

### Local regression net (referenced by VEND-03, reused unmodified per Out-of-Scope table)

- `test/corpus/*.txt` — **13 files** `[VERIFIED: ls test/corpus/]`:
  `comment.txt, data_description.txt, evaluate.txt, file.txt, goto.txt, minimal-cobol.txt,
  occurs.txt, perform.txt, pic_9.txt, pic_x.txt, redefines.txt, select.txt,
  source-object-computer.txt`.
- `skip_tests.txt` — **11 non-blank entries** `[VERIFIED: cat skip_tests.txt]`:
  `NC205A, SM101A, SM103A, SM105A, SM107A, SM201A, SM203A, SM205A, SM206A, SM208A, SM401M`.
  Matches STATE.md's corrected count of 11 (not the SPEC's originally-wrong 12) exactly.
- `run_nist_cobol85.sh` — reads `$COBOL85_TEST_SRC_DIR/*.CBL`, greps each basename against
  `skip_tests.txt`, runs `node_modules/.bin/tree-sitter parse` on the rest, tallies
  success/fail/skip, `exit 1` if any fail `[VERIFIED: full script read]`. Requires
  `node_modules/.bin/tree-sitter` to exist — i.e. `npm ci` (see above) must run first.
- `test/check_tests.sh` — parses `test/corpus/*.txt`'s title/source/expected-S-expression
  blocks and runs `cobc -fsyntax-only` on each extracted source snippet to confirm the *fixture
  itself* is valid COBOL, independent of the grammar `[VERIFIED: full script read]`. **Requires
  GnuCOBOL (`cobc`) — not installed on this machine** `[VERIFIED: which cobc → not found]`. Not
  required by any Phase 1 success criterion (VEND-03's tests are `tree-sitter test` + NIST + ABI
  load, not `check_tests.sh`), but flag as an environment gap for Phases 2-4, which add new corpus
  fixtures and may want fixture-validity checking.
- `.github/workflows/test.yml` — confirmed CI runs `npm install` → `tree-sitter generate` →
  `run_nist_cobol85.sh` only; the `check_tests.sh` and `tree-sitter test` steps are present in the
  file but **commented out** `[VERIFIED: full workflow file read]` — matches
  `.planning/codebase/TESTING.md`'s claim exactly.

## Package Legitimacy Audit

No new external packages are introduced by this phase. The only package involved is the existing
`tree-sitter-cli` devDependency, already pinned in `package.json`/`package-lock.json` before this
phase began; this phase's only npm-related action is running the existing pin via `npm ci`, and
(as a throwaway spike, D-10/D-11) briefly using `tree-sitter-cli@0.25.3` in an isolated worktree or
via `npx`, which is reverted, not adopted.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|--------------|---------|-------------|
| tree-sitter-cli | npm | ~10 yrs (tree-sitter project) | very high (core dev tool of the tree-sitter ecosystem) | github.com/tree-sitter/tree-sitter | OK | Pre-existing pin, not newly added — no audit action needed beyond confirming the version exists on the registry, done above via `npm view`. |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

## Common Pitfalls

### Pitfall 1: Flattening the file location without rewriting the file's own `#include`
**What goes wrong:** copy `src/parser.c`/`src/scanner.c`/`src/tree_sitter/parser.h` into the shim
package root and the cgo build fails with `fatal error: 'tree_sitter/parser.h' file not found`.
**Why it happens:** the generated C files hard-code their own include path at generation time;
moving the *target* file does not change what the *source* file asks for.
**How to avoid:** `refresh.sh` must sed-rewrite both include forms — `#include
"tree_sitter/parser.h"` (parser.c) and `#include <tree_sitter/parser.h>` (scanner.c) — to
`#include "parser.h"`, verified necessary in this session's scratch build (§"The refresh sequence,
corrected").
**Warning signs:** a fresh `go build` of the shim (or of anything importing it) fails at the cgo
compile step, not at Go compile or link — the error names a C header, not a Go symbol.

### Pitfall 2: `npm install` floating past the pinned tree-sitter-cli patch version
**What goes wrong:** `refresh.sh` (or a human) runs `npm install` to get `node_modules/.bin/tree-sitter`,
and gets 0.24.7 instead of the lockfile's pinned 0.24.5, producing a subtly different `parser.c` on
a later run than an earlier one — silently breaking VEND-04's reproducibility requirement.
**Why it happens:** `package.json`'s `^0.24.5` range is wider than the lockfile's exact pin;
`npm install` re-resolves against the range, `npm ci` does not.
**How to avoid:** always use `npm ci` in the refresh script and in any documented regeneration
step; never `npm install` for this purpose (fine for a first-time clone bootstrap, wrong for a
"reproduce the same output twice" requirement).
**Warning signs:** `node_modules/tree-sitter-cli/package.json`'s version field does not match
`package-lock.json`'s pinned version.

### Pitfall 3: A `replace`-based mental model applied to `go.work`
**What goes wrong:** treating `go.work` like a `replace` directive and worrying about `go.sum`
drift, stale checksums, or `GONOSUMDB`/`GOFLAGS` settings interfering with the local shim.
**Why it happens:** `replace` and workspace `use` solve a similar problem but through different
mechanisms; `replace` still participates in `go.sum` verification for the replaced module's own
dependencies, `use` removes the module from resolution entirely for as long as the workspace file
exists.
**How to avoid:** verified this session that a `go.work`-based build succeeds without any `go.sum`
entry for the shimmed module and without any network activity for it — there is nothing to keep in
sync. The only thing that can go wrong is forgetting to delete `go.work` (leaving the pipe "on"
when a clean-forest build was intended) — check with `go env GOWORK`, not by inspecting `go.sum`.
**Warning signs:** none, if using workspace mode as designed — this pitfall is almost entirely
"don't overthink the module-cache angle for this specific mechanism."

### Pitfall 4: A `pre-push` hook that lives only in `.git/hooks/`
**What goes wrong:** the guard is implemented and works, but is not reviewable, not tracked, and
silently fails to propagate to a fresh clone.
**Why it happens:** `.git/hooks/` is never part of a git checkout; only `pre-push.sample` ships
with a fresh `.git` init.
**How to avoid:** use `core.hooksPath` pointing at a tracked directory (e.g. `.githooks/`) so the
hook script itself is committed, diffable, and the "one-line install" is a single `git config`
invocation documented in `docs/`.
**Warning signs:** `git config --get core.hooksPath` returns empty and `.git/hooks/pre-push` is not
executable — the guard is installed on one machine only.

### Pitfall 5: Treating "identical generated output" as "identical grammar"
**What goes wrong:** a future reader of `docs/vendoring.md` concludes the fork's grammar and
forest's vendored copy are semantically the same parser, when in fact `SYMBOL_COUNT`/`TOKEN_COUNT`
differ by roughly 5-11% (§"tree-sitter-cli version reality" above) — forest's copy is generated
from an older revision of upstream's grammar.
**Why it happens:** the ABI-relevant defines (`LANGUAGE_VERSION`, `STATE_COUNT`,
`LARGE_STATE_COUNT`) happen to match, which looks like full identity at a glance.
**How to avoid:** state the finding precisely in `docs/vendoring.md` as "ABI-compatible, not
table-identical" — the distinction matters if anyone later diffs the two files expecting a small
diff and gets a 1.2-million-line one.
**Warning signs:** none functional (the pipe still works); this is purely a documentation-accuracy
risk.

### Pitfall 6: `run_nist_cobol85.sh` silently no-ops without `npm ci` first
**What goes wrong:** `TREE_SITTER=$TOP_DIR/node_modules/.bin/tree-sitter` — if `node_modules`
doesn't exist (confirmed absent on this machine right now), the script fails per-file rather than
with one clear upfront error, producing a confusing wall of "Fail" lines that look like grammar
regressions rather than a missing-binary problem.
**How to avoid:** the refresh/measurement sequence documented in `docs/` should run `npm ci`
as its first step, unconditionally, before any `tree-sitter generate`/`parse`/`test` invocation.
**Warning signs:** every NIST test reports fail, not just the 11 already-known skips.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | `tree-sitter generate`, `npm ci`, `run_nist_cobol85.sh` | ✓ | v24.20.0 | — |
| npm | package install | ✓ | 11.19.0 | — |
| `node_modules/` (project-local) | `run_nist_cobol85.sh`, `test/check_tests.sh`'s npm script | ✗ (not yet installed) | — | Run `npm ci` first; no fallback needed, this is a one-time setup step this phase must include. |
| Go toolchain | shim build, `go.work`, `cobolprobe` | ✓ | go1.27.0 darwin/arm64 | — |
| CGO | compiling `parser.c`/`scanner.c` (both this fork's and the shim's) | ✓ | CGO_ENABLED=1 | — |
| GnuCOBOL (`cobc`) | `test/check_tests.sh` only | ✗ | — | Not required by any Phase 1 criterion; document as a gap for Phases 2-4 if fixture-validity checking is wanted there. |
| Rust/Cargo | `bindings/rust/` (unrelated to this phase) | ✓ | 1.98.0 | — |
| git worktree | isolating the 0.25.3 spike measurement | ✓ (standard git feature, main worktree confirmed present) | — | — |

**Missing dependencies with no fallback:** none blocking Phase 1.
**Missing dependencies with fallback:** `node_modules/` — resolved by `npm ci` as a Wave 0-equivalent
setup step; GnuCOBOL — deferred, not needed this phase.

## Validation Architecture

This phase's "tests" are measurement/proof scripts, not a conventional unit-test suite — there is
no `pytest`/`jest`/`vitest` framework here. The existing regression net (`tree-sitter test` against
`test/corpus/*.txt`, `run_nist_cobol85.sh`) plus the new `cobolprobe` recall run plus a new
guard-verification script constitute the full validation surface for this phase.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `tree-sitter test` (built into `tree-sitter-cli`, reads `test/corpus/*.txt`) + `go test` (for `cobolprobe` and any future shim unit checks) |
| Config file | none — `tree-sitter test` auto-discovers `test/corpus/`; `go test` needs no config |
| Quick run command | `node_modules/.bin/tree-sitter test` (~seconds, 13 fixtures) |
| Full suite command | `sh run_nist_cobol85.sh` (~under a minute, 606-ish local files not involved — this is the public NIST suite) + the 20-minute `cobolprobe` run (opt-in, not part of "full suite" in the CI sense) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VEND-01 | Shim compiles and exposes `GetLanguage()`/`GetQuery()`/`Info()` matching forest's signatures | build+smoke | `cd forest-shim/cobol && go build .` then a tiny `go run` smoke driver (verified pattern in this research; add as a committed smoke test, e.g. `forest-shim/cobol/smoke_test.go`, or reuse `cobolprobe`'s own tests as the smoke check) | ❌ Wave 0 — no smoke test file exists yet in the shim dir (it doesn't exist yet) |
| VEND-02 | gortex resolves the import to the local shim, unmodified grammar, `cobolprobe` runs end-to-end | integration | `cd ~/repos/mine/GoApps/gortex && go work init . <shim-path> && go test ./internal/parser/forest/cobolprobe/ -run TestErrorCascade -v` (a fast subset test, not the full 20-min recall run) | ✅ (test file exists; workspace file does not, created transiently) |
| VEND-03 | 0.25.3 spike: corpus + NIST + ABI load pass/fail recorded | manual-only spike | isolate via `git worktree add ../ts-0.25.3-spike` + `npx --package tree-sitter-cli@0.25.3 tree-sitter generate` + `node_modules/.bin/tree-sitter test` + `sh run_nist_cobol85.sh`, record pass/fail in `docs/`, then delete the worktree | ✅ underlying commands exist; the spike itself is new, one-time |
| VEND-04 | Refresh sequence executed twice, both times reaching the same conclusion (shim reflects fork's current `src/`) | manual+scripted, run twice | `forest-shim/refresh.sh` (new script, this phase) executed once, then again after a no-op change, diffed | ❌ Wave 0 — `refresh.sh` doesn't exist yet |
| VEND-05 | Recall figures reproduced: `.cbl` 15%/27%, `.cpy` 0%/93% | measurement, opt-in | `go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m -corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC` | ✅ test file exists; only the workspace-pointed shim is new |
| FORK-02 | Guard rejects `estate/` paths and populated-seq-area added lines; passes on clean input; `.git/info/exclude` assertion holds | self-verifying script, fail-then-pass | new script (D-18) that creates two throwaway branches, runs the guard, asserts fail-then-pass, cleans up | ❌ Wave 0 — guard script and its self-test don't exist yet |
| FORK-03 | No commit mixes grammar and fork-local changes | manual discipline + optional `git diff --stat` spot check per commit | `git show --stat <commit>` inspected for both `grammar.js`/`test/corpus/*` **and** `forest-shim/**`/`docs/**`/`.planning/**` paths in the same commit → should never co-occur | N/A — process check, not a script |
| SEQ-01 | Build order + volumes recorded verbatim in `docs/` | documentation transcription | none — copy the already-locked table from `PROJECT.md` into `docs/` | N/A |

### Sampling Rate
- **Per task commit:** for shim work, `go build ./...` in the shim dir (fast); for guard work, the
  fail-then-pass self-test script (fast, seconds).
- **Per wave merge:** `node_modules/.bin/tree-sitter test` + `sh run_nist_cobol85.sh` (fast, under a
  minute combined) to confirm no regression to the existing net; the 20-minute `cobolprobe` recall
  run is a phase-gate item, not a per-wave one, given its cost.
- **Phase gate:** all of VEND-01 through VEND-05, FORK-02, FORK-03, SEQ-01 evidenced in `docs/`
  before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `forest-shim/cobol/` — does not exist yet; VEND-01's entire deliverable.
- [ ] `forest-shim/refresh.sh` — does not exist yet; VEND-04's entire deliverable.
- [ ] A guard script + its self-verifying fail-then-pass test (D-18) — does not exist yet;
  FORK-02's entire deliverable.
- [ ] `docs/vendoring.md`, `docs/baseline.md` (or planner-chosen names) — `docs/` currently
  contains only `docs/spec/`; these are net-new.
- [ ] `node_modules/` — run `npm ci` before any step that shells out to `tree-sitter` or reads
  `node_modules/.bin/tree-sitter`.

## Security Domain

This phase's only security-relevant surface is FORK-02 (preventing proprietary source from
reaching a public remote) and does not touch authentication, session management, or user input
validation in the conventional web-app sense.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth surface in this phase. |
| V3 Session Management | No | N/A. |
| V4 Access Control | No | N/A. |
| V5 Input Validation | Marginal | The estate-leak guard is itself a content-validation control over what enters a commit — treat its own script with normal shell-scripting care (quote paths, avoid `eval` on diff content) since it processes arbitrary staged/committed file paths and content. |
| V6 Cryptography | No | N/A. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Proprietary/regulated source (`estate/`) leaking into a public GitHub fork | Information Disclosure | FORK-02: pre-push content guard + `.git/info/exclude` (not `.gitignore`, keeping the upstream PR diff at zero) — already the phase's design. Note per the org's data-handling guidance: `estate/` content must never be quoted verbatim in any artifact this research or the eventual plan produces, including commit messages and `docs/` files — this research pass complied by checking only file names/line-lengths for estate samples, never printing estate file contents. |
| Git hook bypass (`--no-verify`) | Tampering | Documented residual limitation (Pitfall/Common Pitfalls above); no server-side backstop is in scope for this phase — acceptable given the explicit phase boundary, but should be recorded, not silently assumed away. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `cobolprobe`'s full 20-minute recall run actually takes "roughly" 20 minutes, inferred from the test's own `-timeout 20m` flag rather than a timed run performed this session | "The measurement harness" | Low — if it runs longer, the flag itself would need raising, which is a one-line, low-risk change; if much shorter, no impact on planning at all. |
| A2 | `find_clones`/no other hidden call sites beyond the 5 named in code_context (4 in `cobolprobe`, 1 in `dump_kinds_test.go`) — the 5th was not independently re-verified this session, only the 4 in `cobolprobe/` were | "The measurement harness" | Low — even if a 6th call site exists, it does not change how the shim or `go.work` mechanism works; only affects completeness of an inventory, not correctness of the plan. |

**If this table is empty:** N/A — two low-risk items logged above; everything else in this document
was verified directly this session via `Read`/`Bash` (file reads, `git`, `go`, `npm`, and a live
scratch-directory build), not carried forward from CONTEXT.md without re-checking.

## Open Questions

1. **Exact wording for `docs/vendoring.md`'s ABI-compatibility claim**
   - What we know: `LANGUAGE_VERSION`/`STATE_COUNT`/`LARGE_STATE_COUNT` match; `SYMBOL_COUNT`/
     `TOKEN_COUNT` do not (see Pitfall 5).
   - What's unclear: whether the planner wants the corrected wording folded directly into D-10's
     existing bullet, or added as a footnote/appendix in `docs/vendoring.md`.
   - Recommendation: fold it in — a future reader should never encounter the stronger, slightly
     inaccurate "identical" claim without the correction alongside it.

2. **`.git/hooks/pre-push` copy vs. `core.hooksPath` + tracked script**
   - What we know: both work mechanically; only the latter is diffable/reviewable/tracked.
   - What's unclear: D-17 only says "a shell script plus a pre-push hook, with a one-line install
     step" — it does not pick between the two mechanisms.
   - Recommendation: use `core.hooksPath` (Claude's Discretion territory per CONTEXT.md's existing
     discretion list on hook wiring specifics); flagged here as a recommendation, not a blocker.

---

## Sources

### Primary (HIGH confidence — verified this session via direct tool use)
- Local filesystem reads (`Read` tool) and shell inspection (`Bash`: `cat`, `ls`, `find`, `wc`,
  `grep`, `diff`, `awk`, `sed`) of: this fork's `package.json`, `package-lock.json`, `.gitignore`,
  `.git/info/exclude`, `src/parser.c`, `src/scanner.c`, `src/tree_sitter/parser.h`,
  `test/corpus/*.txt`, `skip_tests.txt`, `run_nist_cobol85.sh`, `test/check_tests.sh`,
  `.github/workflows/*.yml`, `.planning/PROJECT.md`.
- Direct reads of `~/repos/mine/GoApps/gortex/go.mod`, `.gitignore`,
  `internal/parser/forest/cobolprobe/{README.md,probe_test.go,cascade_test.go,neutralize_test.go,hypo_test.go}`.
- Direct reads of the Go module cache:
  `$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/{go.mod,cobol@v1.9.1/*}`.
- `git` commands run directly in this fork: `git remote -v`, `git fetch upstream`, `git log`,
  `git rev-list --left-right --count`, `git diff --stat` against the dependabot branch.
- `go`/`npm` commands run directly: `go env`, `go version`, `go build`, `go work init`,
  `npm view tree-sitter-cli versions/version`, in a scratch directory that mirrored the real
  shim's file layout to prove the build/resolution mechanics end-to-end.

### Secondary (MEDIUM confidence)
- None — this research pass used no web search or documentation-provider fetch; the assignment
  explicitly scoped it to local, no-network verification, and everything needed was reachable on
  disk.

### Tertiary (LOW confidence)
- A2 above (the 5th `cobolforest.GetLanguage()` call site in `dump_kinds_test.go`, not
  independently re-opened this session).

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no new libraries selected this phase; this is a mechanics-verification
  research pass, not a stack-selection one.
- Architecture (shim mechanics, `go.work` resolution, refresh sequence): HIGH — proven with a
  working end-to-end scratch build, not just read from documentation.
- Pitfalls: HIGH — six pitfalls, five of which were directly reproduced or directly observed on
  this machine (the `#include` failure, the `npm install`/`npm ci` lockfile mismatch, the missing
  `node_modules`, the missing `cobc`, the absent `pre-push` hook); only the git-hook-bypass pitfall
  is stated from general git knowledge rather than reproduced.

**Research date:** 2026-08-28
**Valid until:** Effectively indefinite for the mechanical findings (Go workspace semantics and
git hook behavior are stable, long-standing features), but re-verify file line numbers
(`go.mod:28`, `.gitignore:23-24`) at plan time if any commits land in gortex between now and
execution — those are exact-line citations into a repo this project does not control.
