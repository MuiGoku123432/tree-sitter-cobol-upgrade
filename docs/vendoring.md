# Vendoring — the local delivery pipe and its toolchain posture

**Status:** Living record, updated as Phase 1 plans land
**Date:** 2026-08-29
**Repo:** `MuiGoku123432/tree-sitter-cobol-upgrade` — fork of `yutaro-sakamoto/tree-sitter-cobol` (MIT)
**Consumer:** `gortex` (Gortex Mainframe Engine)

Four things are involved here, and the relationship between them is not obvious at a
glance: upstream `yutaro-sakamoto/tree-sitter-cobol` holds the COBOL grammar; a third
party's `github.com/alexaandru/go-sitter-forest/cobol` is a Go-importable photocopy of
that grammar, re-scraped from upstream periodically; `gortex` imports that photocopy to
build its knowledge graph; and this fork, `tree-sitter-cobol-upgrade`, is where the
grammar work actually happens. Edits made in this fork cannot reach `gortex` through the
forest photocopy without both an upstream merge and a forest re-scrape — "months, or
never." That gap is what the rest of this document closes, locally, in minutes.

---

## 1. What this is

The four-way relationship again, stated as a chain: **upstream grammar → forest's
photocopy → gortex's dependency → this fork's edits.** Only the first three links exist
today; this fork's own edits do not participate in that chain at all, because nothing
downstream of upstream knows this fork exists.

This phase builds a **shim** — a Go package inside this fork that impersonates forest's
`cobol` package closely enough (same module path, same file layout, same exported
functions) that `gortex` can be pointed at it instead of the real dependency, with zero
committed changes to `gortex` itself. The consequence, in one sentence: a grammar edit
made here reaches `gortex`'s parse output the same day it is written, with no upstream
PR and no forest regeneration in the loop.

---

## 2. The shim

`forest-shim/cobol/` is a dedicated, fork-local directory — not `bindings/go/`, which
stays free for a genuine Go binding should one ever be written. Its `go.mod` declares
`module github.com/alexaandru/go-sitter-forest/cobol` (`forest-shim/cobol/go.mod:1`),
which is the entire drop-in contract: any Go module that `use`s this directory in a
workspace resolves imports of that module path to these files instead of the real
dependency.

File set (`forest-shim/cobol/`): `binding.go`, `plugin.go`, `go.mod` — a byte-faithful
mirror of forest v1.9.1's Go surface, copied from
`$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/` — plus
`alloc.h`, `array.h`, `sample.scm`, `_keep.scm` (structural filler from the same source,
required by forest's file-set contract even though `alloc.h`/`array.h` are not currently
referenced by this fork's generated `parser.h`), plus `parser.c`, `scanner.c`,
`grammar.json`, `parser.h` — this fork's own generated parser output, copied from `src/`.

The C and JSON files are **physically copied and flattened**, never symlinked. This is a
hard constraint, not a style preference: cgo compiles only `.c` files that sit in the
package directory, and Go's `//go:embed` directive refuses to follow symlinks. This fork
ships its header at `src/tree_sitter/parser.h`, while the shim needs it flat at
`parser.h`.

> ⚠ **Flattening the file's location does not rewrite the file's own `#include`.** The
> generated `parser.c` and `scanner.c` hard-code their own include path at generation
> time, and they use **two different syntaxes for the same header** — `parser.c` uses
> the quoted form `#include "tree_sitter/parser.h"`, `scanner.c` uses the angle-bracket
> form `#include <tree_sitter/parser.h>`. Moving the header file to a flat `parser.h`
> without rewriting both lines leaves the cgo build failing with `fatal error:
> 'tree_sitter/parser.h' file not found` — a single `sed` pattern only catches one of
> the two forms. `forest-shim/refresh.sh` runs both rewrites as an explicit, scripted
> step (§4); this is not incidental cleanup, the build does not compile without it.

---

## 3. Turning the pipe on and off

In `~/repos/mine/GoApps/gortex`, one command switches the pipe on:

```
go work init . /path/to/tree-sitter-cobol-upgrade/forest-shim/cobol
```

`go env GOWORK` is the one-line "is it on" check — it prints the active workspace file's
absolute path, or nothing if no workspace is active. Deleting that `go.work` file is the
way back to forest v1.9.1; recreating it switches back to this fork's shim. `gortex`'s
own `.gitignore` already lists `go.work`/`go.work.sum` (lines 23-24), so this switch
requires **zero committed changes to gortex** in either direction.

**Requirement-versus-implementation divergence, recorded explicitly.** REQUIREMENTS.md's
VEND-02 states that gortex consumes this fork's grammar "through a `go.mod` `replace`
directive." The implementation instead uses a `go.work` workspace member. Both reasons
for the divergence:

1. `gortex`'s two existing `replace` directives (`go-pointer`, `renameio`, `go.mod:361`
   and `:368`) both point at **in-tree** paths. Ours would be a relative path *outside*
   the repository — a structurally different, repo-breaking kind of `replace` that would
   fail the build on any checkout with a different directory layout, gortex's own CI
   included.
2. A `go.work` `use` directive removes the module from checksum-verified resolution
   entirely, for as long as the workspace file exists — there is no `go.sum` entry to add
   or keep in sync, and nothing that can go stale from a module-cache or lockfile
   mismatch. A `replace` still participates in `go.sum` verification for the replaced
   module's own dependencies; `go.work` does not participate at all.

The requirement's *intent* — a local override that reaches gortex without an upstream
merge — is fully met. Only the mechanism named in the requirement text differs from what
is implemented, and that divergence is recorded here rather than left to silently diverge
between the two documents.

---

## 4. The refresh sequence

`forest-shim/refresh.sh` is a shell script living inside the shim directory it maintains
— deliberately **not** an npm script (that would mean editing `package.json`, an
upstream-owned file that dependabot keeps moving, including the exact CLI bump §5
measures) and **not** a Makefile (this repo uses no `make` anywhere). It runs six steps,
each individually reported to stdout and to `forest-shim/refresh.log`:

1. **Dependencies** — `npm ci` (never `npm install`: `package.json`'s `^0.24.5` range
   is wider than the lockfile's exact `0.24.5` pin, and `npm install` re-resolves against
   the range). The step's actual gate is whether `$TREE_SITTER` exists and is executable
   afterward, not `npm ci`'s own exit code — this repo's `install` script separately
   builds an unrelated native Node addon (`bindings/node/`) that fails on this machine's
   Node/V8 combination even when the lockfile-pinned `tree-sitter-cli` installs
   correctly.
2. **Generate** — `tree-sitter generate`, regenerating `src/*` from `grammar.js`.
3. **Copy-and-flatten** — `src/parser.c` → `parser.c`, `src/scanner.c` → `scanner.c`,
   `src/grammar.json` → `grammar.json`, `src/tree_sitter/parser.h` → `parser.h`, into
   `forest-shim/cobol/`.
4. **Include rewrite** — the two `sed` rewrites described in §2's callout, applied to the
   just-copied `parser.c` and `scanner.c`.
5. **Drift check** — diffs the shim's `binding.go`/`plugin.go`/`go.mod` against the
   forest module-cache copy it impersonates, to catch drift from the drop-in contract.
6. **Smoke build** — `go build ./...` inside `forest-shim/cobol/`, last, gating the
   script's own exit code so a partially-updated shim can never report success.

Overridable environment variables: `TOP_DIR`, `SHIM_DIR`, `TREE_SITTER`, `FOREST_CACHE`,
`REFRESH_LOG`, `REFRESH_SKIP_INSTALL`, `REFRESH_SKIP_GENERATE`, `REFRESH_ALLOW_DRIFT`
(downgrades step 5's drift check from a hard failure to a warning).

**Two-run reproducibility evidence (plan 01-03).** `refresh.sh` was run twice
consecutively with `REFRESH_SKIP_GENERATE=1` after settling: shasums of `parser.c`,
`scanner.c`, `parser.h`, and `grammar.json` were identical across both runs, and
`git status --porcelain forest-shim/cobol` was empty afterward both times. A third,
fault-injected run (`TREE_SITTER=/nonexistent/tree-sitter`) exited non-zero and left the
shim byte-identical to its committed state, proving the script fails safely rather than
partially applying.

**Propagation proof (`forest-shim/pipe-probe.sh`, plan 01-03).** One deterministically
chosen top-level `grammar.js` rule was renamed (`start` → `start_pipe_probe`),
`refresh.sh` was run, and `gortex`'s `TestDumpGrammarKinds/cobol` output was captured
before and after: the renamed node (`start_pipe_probe`) appeared, and the old name
(`start`) disappeared. The rename was then fully reverted (`git checkout -- grammar.js
src/`, plus explicit removal of the untracked `src/tree_sitter/alloc.h`/`array.h` that
`git checkout` cannot remove) and gortex's output returned to its pre-probe baseline. This
is the proof that `grammar.js → tree-sitter generate → src/ → refresh.sh →
forest-shim/cobol/ → go.work → gortex parse output` is a chain that actually carries an
edit end to end, with the unmodified grammar otherwise.

Dependencies are installed from the lockfile only (`npm ci`), never re-resolved against
the version range (`npm install`) — the latter risks silently floating past the pinned
patch version on a machine where the npm registry has moved on, breaking reproducibility
across two runs in a way that shows up as a subtly different `parser.c`, not an error.

---

## 5. tree-sitter-cli posture

Answers OQ-2 / VEND-03: does the `tree-sitter-cli` 0.24.5 → 0.25.x bump break upstream's
corpus tests, and does the CLI that generates `parser.c` produce a parser gortex's
`go-tree-sitter v0.25.0` actually loads? Measured 2026-08-29 in a detached `git worktree`
(`../ts-0253-spike`, removed after measurement), never in the main working tree.

### Step 0 — checking upstream for existing evidence first

`git fetch upstream`, then:

```
$ git diff --stat upstream/main upstream/dependabot/npm_and_yarn/tree-sitter-cli-0.25.3
 package-lock.json | 15 ++++++++-------
 package.json      |  2 +-
 2 files changed, 9 insertions(+), 8 deletions(-)
```

`upstream/main`'s last commit is `2024-12-17`. The dependabot branch is a pure two-file
manifest bump — no regenerated `parser.c`, no corpus evidence. There is nothing to
inherit; the measurement below had to be performed.

### Measurement table

Baseline (0.24.5, same worktree, as a same-run control) and the 0.25.3 spike, both
against this fork's unmodified `grammar.js`:

| Check | 0.24.5 (control, same worktree) | 0.25.3 (spike) | Verdict |
|---|---|---|---|
| `tree-sitter test` (13 corpus fixtures) | 12/13 pass (`comment` fails — pre-existing, see below) | 12/13 pass (identical single failure) | **PASS** — no new regression |
| `run_nist_cobol85.sh` (skip-list gated) | 382 tests: 371 success, 0 fail, 11 skip | 382 tests: 371 success, 0 fail, 11 skip | **PASS** — identical result, 11-entry skip list respected |
| ABI load (`cobolprobe` against a shim built from the spike's generated output) | — | `go test ./internal/parser/forest/cobolprobe/ -run 'TestErrorCascade\|TestHypothesis' -v` → all 3 tests PASS | **PASS** — the 0.25.3-generated `parser.c` loads under gortex's `go-tree-sitter v0.25.0` |

The `comment` fixture failure is a pre-existing, out-of-scope defect in the currently
committed `grammar.js`/`test/corpus/comment.txt` pairing (recorded in `.planning/WINDOWS.md`;
see plan 01-03's summary) — it reproduces identically under both CLI versions and against
the committed `src/parser.c` untouched. The true corpus baseline this measurement compares
against is **12/13, not 13/13**, and 0.25.3 introduces no new failure beyond it.

### Generated-output `#define`s

Captured from `src/parser.c` after `tree-sitter generate` in the spike worktree, compared
against the currently committed values (main tree, `src/parser.c:16-20`) and against
forest v1.9.1's cached copy:

| `#define` | Committed (main tree) | forest v1.9.1 cache | 0.24.5-regenerated (plan 01-03) | 0.25.3-regenerated (this spike) |
|---|---|---|---|---|
| `LANGUAGE_VERSION` | 14 | 14 | 14 | 14 |
| `STATE_COUNT` | 7745 | 7745 | 7745 | 7745 |
| `LARGE_STATE_COUNT` | 5095 | 5095 | 5095 | 5095 |
| `SYMBOL_COUNT` | **1215** | 1153 | 1153 | 1153 |
| `TOKEN_COUNT` | **585** | 523 | 523 | 523 |

**ABI-version compatible, not table-identical.** `LANGUAGE_VERSION 14`, `STATE_COUNT 7745`,
and `LARGE_STATE_COUNT 5095` — the fields `go-tree-sitter v0.25.0` actually checks
at load time — match byte-for-byte across every column above. `SYMBOL_COUNT`/`TOKEN_COUNT`
do not: both regenerations (0.24.5 and 0.25.3) agree with each other and with forest
v1.9.1's cached copy (1153/523), and both disagree with what this fork currently has
committed (1215/585). A full-file diff between the committed `src/parser.c` and either
regeneration runs past a million lines — the parse tables genuinely differ throughout,
not just at the header — so nobody should read "the ABI matches" as "the two files are
the same generated output."

> ⚠ **What this measurement settles, and what it does not.** Since 0.25.3 reproduces
> 0.24.5's regenerated output exactly, the 0.24.5→0.25.3 bump itself is **not** what
> separates the committed `src/parser.c` from a fresh regeneration — this rules out a
> version-specific codegen difference between the two CLI versions this project has
> actually measured. It does **not** identify which CLI version *did* produce the
> committed file. Corroborating evidence: on this fork's `main` branch, `grammar.js` and
> `src/parser.c` were both last touched in the same commit (`c7a36d7`, "Expose comment
> nodes (#19)"), and `git diff --stat upstream/main -- grammar.js src/` is empty — this
> content is upstream's own, not fork-edited, and the two files were committed together
> rather than independently drifting apart. That rules out the simplest form of "grammar.js
> was edited after parser.c was last generated" (they were never touched separately on
> this fork). It is consistent with the committed `parser.c` having been generated by some
> tree-sitter-cli version other than 0.24.5 or 0.25.3 — but no such earlier version was
> installed or measured, so that specific attribution is **not established by evidence**
> and is recorded here as an open question, not a conclusion.

**Decision (D-10), unaffected by this measurement:** the pin stays at the `^0.24.5` caret
range. 0.25.3 was measured — identical corpus result, identical NIST result, and it loads
correctly under gortex's ABI — and is **not adopted**. There is no positive reason to
bump: the pinned 0.24.5 already produces ABI-compatible output, and `LANGUAGE_VERSION` is
what `go-tree-sitter v0.25.0` checks at load time, and it matches in every regeneration
measured, at every CLI version tried.

---

## 6. The estate-leak guard

`.githooks/estate-guard.sh` (FORK-02, D-16) runs three checks on every invocation:

1. **Reject any `estate/` path** in the changed set — staged, a commit range, or git's
   `pre-push` stdin ref-update protocol.
2. **Assert the exclusion posture** — `.git/info/exclude` still declares `/estate/`, and
   `.gitignore` does not. This check runs unconditionally, even on an empty change, so an
   empty diff can never produce a vacuous pass.
3. **Flag added COBOL lines whose columns 73-80 sequence area is populated** — the
   content heuristic that catches pasted mainframe source. Content byte 73 of a fixed-format
   COBOL line sits at byte 74 of the raw `+`-prefixed diff line; `SEQ_AREA_FIRST_BYTE`
   pins that offset in one place so the two can never silently drift apart
   (`.githooks/estate-guard.sh`).

This check is **scoped to diff-added lines only, never a whole-file scan** — the public
NIST fixtures under `test/cobol85/src/` are legitimate 80-column fixed-format source with
populated sequence areas, and a full-file scan would false-positive on any future edit to
one of them. Hand-written `test/corpus/*.txt` fixtures have no populated sequence area at
all and correctly pass either way. This scoping decision is commented directly in the
guard script so a future editor does not "simplify" it into a full-file scan.

**Install (once per clone):**

```
git config core.hooksPath .githooks
```

The hook script itself lives in a tracked, diffable `.githooks/` directory rather than an
untracked `.git/hooks/` copy — reviewable in the same way `pre-push` was chosen over a CI
check in the first place (visibility before the source leaves the machine, not after).
The exclusion entries themselves (`/estate/`, `/.gortex.yaml`, `/.gortexignore`,
`/forest-shim/refresh.log`) live in the repo-local `.git/info/exclude`, never in the
tracked `.gitignore` — that keeps the upstream diff at zero, the same rationale
SPEC-001 already gives for the split.

The guard is proven by a re-runnable, fail-then-pass self-test
(`.githooks/estate-guard-selftest.sh`, D-18) that builds a scratch repo under `mktemp -d`,
exercises polluted and clean fixtures against it, and asserts the guard fails on the
former and passes on the latter — never against a branch in this fork itself, since a
branch here carrying an `estate/` path would create exactly the git object the guard
exists to prevent.

---

## 7. Known limitations

> ⚠ **`git push --no-verify` bypasses this hook entirely, by git's own design.** This is
> a client-side hook; there is no server-side backstop in scope for this phase. Anyone
> pushing with verification disabled skips both the estate-leak guard and the
> commit-separability check. This is a known, accepted limitation of the chosen
> enforcement point (D-17), not a defect to silently assume away.

`alloc.h` and `array.h` are carried in `forest-shim/cobol/` for file-set fidelity with
forest's drop-in contract, but are referenced by nothing in this fork's currently
generated `parser.c`/`parser.h`. Their presence proves the file set is complete; it does
not prove they are exercised.

The `comment` corpus fixture (`test/corpus/comment.txt`) fails `tree-sitter test` against
the currently committed `grammar.js`, independent of anything in this document — see §5's
measurement table. This affects the truthfulness of "13/13 corpus fixtures pass" as a
blanket claim anywhere else in this fork's documentation; the true baseline is 12/13,
recorded in `.planning/WINDOWS.md` as an open, out-of-scope deviation (no grammar changes
in Phase 1, per this phase's own domain boundary).
