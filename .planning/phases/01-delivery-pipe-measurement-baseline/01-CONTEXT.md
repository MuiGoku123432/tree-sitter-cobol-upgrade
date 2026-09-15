# Phase 1: Delivery Pipe & Measurement Baseline - Context

**Gathered:** 2026-08-28
**Status:** Ready for planning

<domain>
## Phase Boundary

A grammar edit made in this fork reaches gortex's parse output the same day — no upstream merge,
no `go-sitter-forest` regeneration — plus a same-method recall baseline for later phases to
measure deltas against, plus a guard that keeps proprietary estate source out of this public fork.

**No grammar changes in this phase.** The pipe is proven with the *unmodified* grammar so that a
failure is unambiguously the pipe, not the grammar.

### What "the pipe" is, concretely

gortex imports `github.com/alexaandru/go-sitter-forest/cobol` — a Go-importable photocopy of
`yutaro-sakamoto/tree-sitter-cobol`, maintained by a third party who re-scrapes upstream
periodically. Edits in this fork cannot reach gortex through that dependency without an upstream
merge *and* a forest re-scrape ("months, or never" — SPEC §8).

This phase builds a Go package inside this fork that **impersonates** forest's `cobol` package —
same module path, same file layout, same exported functions — and wires gortex to resolve the
import to it locally. Referred to throughout as **the shim**.

### Scope reduction applied during this discussion

Phase 1 as roadmapped carried a second guard (FORK-01, branch hygiene) and a topic-branch
publication workflow, both of which exist solely to keep upstream PRs clean. The user reframed
upstream PRs as **not a goal** — "keep it PR ready if and only if it's really worth it in case I
change my mind later, but just know that it is not the goal."

Cost test applied. The load-bearing finding: **PR-readiness is recoverable on demand.** A clean
topic branch can be reconstructed at any future date by cutting from a freshly fetched
`upstream/main` and cherry-picking the grammar commits — roughly ten minutes of work. It does not
need to be *maintained* continuously to be *preserved*. The only thing not recoverable
retroactively is commit separability, and that costs nothing to keep.

Result: FORK-01 and the topic-branch workflow are **out of Phase 1** (see `<deferred>`). FORK-02
stays and is now the phase's only guard. See the amendment note in `.planning/ROADMAP.md`.

</domain>

<decisions>
## Implementation Decisions

### The shim module

- **D-01:** The shim lives in a **dedicated fork-local directory** (e.g. `forest-shim/cobol/`) —
  not `bindings/go/`, not the repo root. Its `go.mod` must declare
  `module github.com/alexaandru/go-sitter-forest/cobol` to function as a drop-in; a directory
  named for what it is makes that impersonation honest, and it leaves `bindings/go/` free for a
  genuine Go binding should one ever be written. — **Reversibility:** costly — moving it later
  means re-pointing gortex's `go.work`, rewriting the refresh script's copy targets, and
  re-establishing the `.gitignore`/exclude posture; nothing breaks silently but every artifact
  that names the path has to move together.

- **D-02:** **Commit all shim artifacts**, including the copied `parser.c` (30.6 MB / 825,788
  lines), `scanner.c`, `parser.h`, and `grammar.json`. Accepted trade-off, stated explicitly: a
  clean clone builds immediately with no prerequisite refresh step, and a shim diff proves a
  grammar edit actually propagated. Cost accepted: +30.6 MB now, and a ~30 MB diff on every
  regeneration during Phases 2–4. — **Reversibility:** reversible — switching to
  gitignore-and-generate later is a `.gitignore` edit plus one `git rm --cached`; history
  retains the blobs but nothing downstream breaks.

- **D-03:** The shim's Go surface is a **byte-faithful mirror** of forest's `binding.go` and
  `plugin.go` (both ~100 lines; only the embedded files differ). gortex today calls only
  `GetLanguage()`, but forest also exports `GetQuery()` and `Info()` — mirroring all three means a
  later gortex change can't fail as an `undefined` error at the replace boundary, which is a
  confusing place to debug. The mirror also makes drift detectable by diffing the shim against the
  module-cache copy, a check the refresh script should run.

- **D-04:** Files must be **physically copied and flattened** into the shim's package directory.
  This is a hard constraint, not a preference: cgo compiles only `.c` files sitting in the package
  directory, and `//go:embed` refuses to follow symlinks. The fork ships
  `src/tree_sitter/parser.h` while forest expects `parser.h` at the package root, and forest
  additionally ships `alloc.h` / `array.h`. That copy-and-flatten step **is** VEND-04's refresh
  sequence — it is not incidental plumbing.

### How gortex resolves the shim

- **D-05:** Use **`go.work` in gortex**:
  `go work init . && go work use ../../devDeps/tree-sitter-cobol-upgrade/forest-shim/cobol`.
  Chosen because gortex's `.gitignore` already lists `go.work` and `go.work.sum` (lines 23–24), so
  the pipe requires **zero committed changes to gortex**, and toggling it on or off is creating or
  deleting one file — which makes VEND-04's "executed at least twice" trivially repeatable.
  Explicitly **not** a committed `replace` in gortex's `go.mod`: gortex's existing
  `go-pointer` / `renameio` replaces point at *in-tree* paths, whereas ours would be a relative
  path outside the repo, breaking the build for any checkout with a different layout — gortex CI
  included. — **Reversibility:** reversible — delete `go.work` and gortex is back on forest v1.9.1.

- **D-06:** The integration target is **`~/repos/mine/GoApps/gortex`**. Confirmed by inspection:
  it holds `internal/parser/forest/cobolprobe/`. The other checkout at `~/repos/else/gortex` has
  no `cobolprobe` and is not the target.

### The refresh sequence (VEND-04)

- **D-07:** A **shell script inside the shim directory** (e.g. `forest-shim/refresh.sh`) that runs
  `tree-sitter generate`, flattens `src/` into the shim package dir, diffs the Go surface against
  the module-cache copy, and reports. Groups the tooling with the thing it maintains. Explicitly
  **not** an npm script: that would edit `package.json`, an upstream-owned file that dependabot
  keeps moving — including the very CLI bump in OQ-2 — making it the worst possible place to add a
  local entry. Explicitly not a Makefile: this repo uses no make anywhere.

### Evidence and measurement

- **D-08:** Phase evidence lives in **`docs/` in this fork** (e.g. `docs/vendoring.md`,
  `docs/baseline.md`): the CLI pass/fail record (VEND-03), the twice-executed refresh log
  (VEND-04), the re-measured baseline (VEND-05), and the build order with volumes (SEQ-01).
  Chosen over `.planning/phases/01-…/` because `/gsd-complete-milestone` archives `.planning/`,
  and Phases 2–4 need to cite the baseline for their apples-to-apples delta without reaching into
  an archive.

- **D-09:** The **baseline of record is `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` only.**
  Verified present with exactly **606 `.cbl` + 958 `.cpy`**, matching the published run that
  produced 15% / 27% / 0% / 93%. Decisive counter-finding: the fork's `estate/` copy contains
  **zero `.cbl` files** (5,905 `.cpy` across 52,233 files under `endevor/`, `idms/`, `vendor/`),
  so it cannot produce a `.cbl` recall number at all without first deriving a program/copybook
  classification (likely from `estate/_manifest.csv`) — real scope VEND-05 does not ask for.
  `estate/` remains what PROJECT.md already calls it: a volume-counting input, **not** the recall
  corpus. — **Reversibility:** one-way — every Phase 2–4 delta is quoted against this baseline, so
  changing the corpus later invalidates all published deltas and forces a re-measure of every
  landed family.

### tree-sitter-cli posture (OQ-2 / VEND-03)

- **D-10:** **Pin `^0.24.5`.** Measure 0.25.3 in isolation, record pass/fail in `docs/`, revert.
  Do not adopt. Two findings drive this:
  1. The fork's committed `src/parser.c` and forest's are both `LANGUAGE_VERSION 14`,
     `STATE_COUNT 7745`, `LARGE_STATE_COUNT 5095` — **identical generated output**, differing only
     in the flattened include (`parser.h` vs `tree_sitter/parser.h`) and a dropped
     `#pragma GCC diagnostic push`. gortex's `go-tree-sitter v0.25.0` is therefore *already*
     loading a LANGUAGE_VERSION 14 parser in production today. **No bump is needed for the pipe to
     work at all** — the ABI half of VEND-03 is effectively pre-answered.
  2. Upstream's `dependabot/npm_and_yarn/tree-sitter-cli-0.25.3` branch (already fetched locally)
     is a **pure manifest bump** — `package.json` + `package-lock.json` only, **no regenerated
     `parser.c`** — sitting 1 ahead / 0 behind `upstream/main`, whose last commit is 2024-12-17.
     It carries **zero corpus evidence**. Upstream CI runs `generate` → NIST and **never runs
     `tree-sitter test`**, so even a green check there would not have covered the 13 fixtures.
     VEND-03's "check upstream for existing evidence first" is answered: nothing to inherit.

- **D-11:** The 0.25.3 evidence is **corpus + NIST + ABI load check**: `tree-sitter test` against
  the 13 fixtures, `run_nist_cobol85.sh` against the 11-entry `skip_tests.txt` gate, and
  confirmation that the 0.25.3-generated `parser.c` loads under gortex's `go-tree-sitter v0.25.0`.
  Covers both clauses VEND-03 states plus the NIST net named in PROJECT.md's constraints. **No**
  full `cobolprobe` recall run on 0.25.3 output — that is a ~20-minute run for a bump already
  decided against.

### Fork hygiene, re-scoped

- **D-12:** **Commit separability is the one PR-preservation habit kept.** Never mix
  `grammar.js` / `test/corpus/*` edits with fork-local edits (shim, `docs/`, `.planning/`) in the
  same commit. Costs nothing — do not `git commit -a` — and it is the only property that cannot be
  recovered retroactively. Everything else about PR-readiness can be reconstructed from separable
  commits on demand. — **Reversibility:** one-way — a commit that mixes grammar and fork-local
  changes cannot be cleanly cherry-picked later without rewriting history, which is exactly the
  option this decision exists to preserve.

- **D-13:** **Work on `main`.** No topic branches cut from `upstream/main`, no cherry-picking on
  every measurement cycle. Reconstruct a publication branch only if and when a PR actually
  happens. (This supersedes the earlier in-discussion answer that `main` is the working branch
  *and* topic branches are cut at publication time — the publication half is now deferred, not
  scheduled.)

- **D-14:** **Avoid gratuitous edits to upstream-owned files** (`package.json`,
  `.github/workflows/test.yml`, `src/*` beyond regeneration) as a **soft preference, not a rule**.
  Costs ~nothing and often produces the better design anyway (see D-07). Keeps `git pull upstream`
  painless. If editing an upstream-owned file is clearly the better design, do it.

- **D-15:** **SPEC §6 criterion 6 is softened** for Phases 2–4: from "a self-contained commit on a
  topic branch, rebased on `upstream/main`" to "grammar commits stay separable from fork-local
  commits." Same option preserved, none of the per-cycle cost.

### The estate-leak guard (FORK-02) — now the phase's only guard

- **D-16:** The guard checks **three things**:
  1. Reject any `estate/` path in a staged or committed change.
  2. Assert `/estate/` is still present in `.git/info/exclude` and **absent** from `.gitignore`
     (current state verified correct: `.git/info/exclude` holds `/estate/`, `/.gortex.yaml`,
     `/.gortexignore`).
  3. Flag added COBOL lines with a **populated columns 73–80 sequence area**. This is the content
     heuristic: it catches pasted estate source, while hand-written minimal fixtures — which have
     no reason to fill the sequence area — pass cleanly. It resolves the tension that a naive
     content scan would flag the very corpus fixtures Phases 2–4 must write.

- **D-17:** Wired as a **shell script plus a `pre-push` hook**, with a one-line install step
  documented in `docs/`. `pre-push` is the last moment before proprietary source leaves the
  machine for a public remote, which is precisely the threat model. Chosen over a CI check, which
  fires only *after* the push has already reached GitHub — detection, not prevention.

- **D-18:** The guard is proven by a **self-verifying test script**: it creates two throwaway
  branches — one deliberately polluted, one clean — runs the guard against both, asserts
  fail-then-pass, and deletes them. Re-runnable, so the criterion stays proven rather than being
  true once. (ROADMAP criterion 4 asked this of two guards; it now applies to one.)

### Claude's Discretion

- Exact directory name for the shim (`forest-shim/cobol/` is illustrative, not locked).
- Exact filenames under `docs/` (`vendoring.md` / `baseline.md` are illustrative).
- Mechanics of isolating the 0.25.3 measurement — a `git worktree` on a throwaway branch, or
  `npx tree-sitter-cli@0.25.3` inside one, is planner's choice. Requirement is only that the
  working tree is left clean and the pin reverts.
- Whether the refresh script's module-cache drift check is a hard failure or a warning.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth for the project
- `docs/spec/SPEC-001-nodes-for-edges.md` — the accepted spec. §6 = the six per-family acceptance
  criteria (criterion 6 softened by D-15); §8 = the integration gap this phase closes; §9 = locked
  decisions D1–D4.
- `.planning/PROJECT.md` — locked decisions D1–D5, constraints, measured baseline table, volume
  table. **Note:** its "Upstreamability (hard)" constraint is softened by D-12 through D-15.
- `.planning/REQUIREMENTS.md` — VEND-01…05, FORK-01 (**deferred by this discussion**), FORK-02,
  SEQ-01 in checkable form.
- `.planning/ROADMAP.md` — Phase 1 goal and five success criteria; criterion 4 amended to one
  guard.

### The consumer and the measurement method
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/README.md` — the published
  15% / 27% / 0% / 93% table, the exact `go test` invocation with its `-corpus` / `-neut-corpus`
  flags, and the error-cascade explanation. **This is the method VEND-05 must reproduce.**
- `~/repos/mine/GoApps/gortex/internal/parser/forest/cobolprobe/probe_test.go`,
  `cascade_test.go`, `neutralize_test.go`, `hypo_test.go` — the four tests; all call
  `cobolforest.GetLanguage()` and nothing else.
- `~/repos/mine/GoApps/gortex/go.mod` — line 28 pins
  `github.com/alexaandru/go-sitter-forest/cobol v1.9.1`; lines 355–368 show the existing
  in-tree `replace` precedent (`go-pointer`, `renameio`).
- `~/repos/mine/GoApps/gortex/.gitignore` lines 23–24 — `go.work`, `go.work.sum` already ignored.

### The drop-in contract to mirror
- `$(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/` — the layout to
  mirror: `binding.go` (build tag `!plugin`), `plugin.go` (build tag `plugin`), `parser.c`,
  `parser.h`, `scanner.c`, `grammar.json`, `sample.scm`, `_keep.scm`, `alloc.h`, `array.h`,
  `go.mod` declaring `module github.com/alexaandru/go-sitter-forest/cobol`.

### This fork's existing surface
- `.planning/codebase/STACK.md` — toolchain: `tree-sitter-cli ^0.24.5` devDependency, node-gyp,
  Cargo, `binding.gyp`, `Cargo.toml`.
- `.planning/codebase/TESTING.md` — the existing regression net: `test/corpus/*.txt` (13 files,
  format documented), `run_nist_cobol85.sh`, `skip_tests.txt` (11 entries), `test/check_tests.sh`,
  and the fact that CI runs `generate` → NIST and **not** `tree-sitter test`.
- `src/parser.c` — `LANGUAGE_VERSION 14`, `STATE_COUNT 7745`, `LARGE_STATE_COUNT 5095`.
- `.git/info/exclude` — holds `/estate/`, `/.gortex.yaml`, `/.gortexignore`. FORK-02's assertion
  target.

### Git refs (already fetched, no network needed)
- `upstream/dependabot/npm_and_yarn/tree-sitter-cli-0.25.3` — the OQ-2 evidence check. Verified: a
  pure manifest bump, no regenerated parser, no corpus evidence.
- `upstream/main` @ `e99dbdc` (2024-12-17) — also `origin/main`; the fork is 0 ahead / 0 behind on
  grammar content.

### Corpus
- `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` — 606 `.cbl` + 958 `.cpy`. The VEND-05 baseline
  corpus.
- `estate/` (697 MB, excluded via `.git/info/exclude`) — 0 `.cbl`, 5,905 `.cpy`, 52,233 files
  under `endevor/`, `idms/`, `vendor/`, plus `_manifest.csv`. Volume-counting input only.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`run_nist_cobol85.sh` + `skip_tests.txt` + `test/corpus/*.txt`** — the regression net already
  exists and PROJECT.md forbids inventing a parallel harness. VEND-03's measurement reuses both
  suites as-is.
- **Forest's `binding.go` / `plugin.go` in the module cache** — the shim's Go surface is a copy of
  these, not new code. Nothing to design.
- **`src/parser.c` as already committed** — already `LANGUAGE_VERSION 14`, i.e. already
  ABI-compatible with what gortex loads. The shim's first build needs no regeneration at all;
  regeneration is only needed once `grammar.js` changes in Phase 2.
- **gortex's `go-pointer` / `renameio` replaces** — precedent for drop-in substitution in gortex,
  though ours uses `go.work` rather than a committed `replace` (D-05).

### Established Patterns
- **Shell script at repo root invoked by an npm script** (`run_nist_cobol85.sh` ← `npm run nist`)
  is the repo's convention for tooling. D-07 deliberately breaks the npm-script half to avoid
  editing `package.json`; the shell-script half is kept.
- **`bindings/<lang>/`** is the repo's convention for language bindings (`node`, `rust`). The shim
  deliberately does **not** use it (D-01) because it is not a binding for this grammar — it
  impersonates a third party's module.
- **Generated artifacts are committed** — `src/parser.c`, `src/grammar.json`,
  `src/node-types.json`, `src/scanner.c`, `src/tree_sitter/parser.h` are all tracked upstream.
  D-02 follows that existing convention rather than departing from it.
- **`.gitignore` is upstream's; `.git/info/exclude` is ours.** The split is deliberate and
  FORK-02 asserts it.

### Integration Points
- **`cobolforest.GetLanguage()`** — the entire API surface gortex uses. Verified across all five
  call sites (four in `cobolprobe/`, one in `forest/dump_kinds_test.go`).
- **`go.work` in `~/repos/mine/GoApps/gortex`** — the single switch that turns the pipe on or off.
- **`forest-shim/cobol/` ← `src/`** — the copy-and-flatten boundary; `tree_sitter/parser.h` →
  `parser.h`, plus forest's `alloc.h` / `array.h`.
- **`pre-push` hook in this fork** — where FORK-02 fires.

</code_context>

<specifics>
## Specific Ideas

- **"Explain what we are doing simple."** The user was unclear what `go-sitter-forest` is and
  wanted the fork relationship stated plainly. Downstream agents should assume the four-way
  relationship (upstream grammar → forest photocopy → gortex consumer → this fork) is not
  self-evident and name it explicitly in any doc they write. `docs/vendoring.md` should open with
  that explanation, not with commands.

- **"The forks I make will likely never make it back to the upstream — they are my personal
  forks."** Direct quote. Treat upstream contribution as a preserved option, never as a
  requirement, and never as a reason to add per-cycle cost.

- **"Ideally I'd like to keep it PR ready *if and only if it's really worth it* in case I change
  my mind later, but just know that it is not the goal."** Direct quote. The operative test for
  any future PR-related work: does keeping this option cost ~nothing? If yes, keep it. If it costs
  real effort, drop it — it can be reconstructed on the day it is needed.

</specifics>

<deferred>
## Deferred Ideas

- **FORK-01 (branch-hygiene guard) and its self-verifying test harness** — deferred out of Phase 1
  by the cost test above. Rejects `.planning/` / `docs/spec/` paths on a topic branch cut from a
  freshly fetched `upstream/main`. Zero value while upstream PRs are not a goal; roughly 20
  minutes to write on the day one is. Two design findings worth keeping if it is ever built:
  1. It must be a **ref-taking script invoked from `main`**, not CI — a topic branch cut from
     `upstream/main` cannot contain a workflow added on `main`, so a CI guard can never run on the
     branch it is meant to check.
  2. It should **allowlist the diff** (only `grammar.js`, `test/corpus/*`, `src/*` may differ from
     `upstream/main`) rather than denylist paths. A denylist's failure mode is exactly "someone
     added a fork-local path and forgot to update the guard" — and the guard silently stops
     protecting. An allowlist is self-maintaining and would have caught `forest-shim/`,
     `docs/vendoring.md`, and `docs/baseline.md` automatically.

- **Topic-branch publication workflow** — cutting from a freshly fetched `upstream/main` and
  cherry-picking grammar commits. Deferred, not dropped: D-12's commit separability keeps it a
  ten-minute job whenever it is wanted.

- **Estate-wide recall measurement** — would require deriving a program/copybook classification
  for `estate/` (0 `.cbl` extensions; likely from `estate/_manifest.csv`) before any `.cbl` recall
  number is possible. Not needed for VEND-05. Revisit only if DCC stops being representative.

- **A fork-local CI workflow running `tree-sitter test`** — CI currently runs `generate` → NIST and
  never runs the 13 corpus fixtures, so IDMS-06's corpus gate is manual. A
  `.github/workflows/fork-checks.yml` on `main` would automate it without touching upstream's
  `test.yml`. Belongs with Phase 2, where the corpus gate first has teeth.

- **Upstream repo observations** (not scheduled, noted for OQ-4 if it is ever revisited):
  `upstream/main`'s last commit is 2024-12-17 and the CLI-bump PR has sat unmerged since — the
  project looks dormant, which is itself evidence about upstream appetite. Upstream also carries a
  `feature/fixed-format` branch, potentially relevant to COBOL column handling.

</deferred>

---

*Phase: 1-Delivery Pipe & Measurement Baseline*
*Context gathered: 2026-08-28*
