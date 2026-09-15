# Phase 1: Delivery Pipe & Measurement Baseline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-28
**Phase:** 1-Delivery Pipe & Measurement Baseline
**Areas discussed:** Go module shape & generated artifacts, How gortex picks up the fork,
CLI bump handling (OQ-2), Guard mechanism & where guards live, plus an unplanned scope reframe on
upstreamability

---

## Go module shape & generated artifacts

### Where should the drop-in shim module live?

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated fork-local dir | e.g. `forest-shim/cobol/`. Unambiguously fork-local; leaves `bindings/go` free for a genuine binding later | ✓ |
| `bindings/go/` | Matches existing `bindings/node` + `bindings/rust` convention, but squats the path a real binding would use | |
| Repo root `go.mod` | Simplest replace target; maximum clutter and visibility | |
| You decide | Defer to planner | |

**User's choice:** Dedicated fork-local dir
**Notes:** Presented with the finding that the shim's `go.mod` must declare
`module github.com/alexaandru/go-sitter-forest/cobol` to work as a drop-in — an impersonation that
reads as dishonest in `bindings/go` and as honest in a directory named for what it is.

### Commit the copied generated artifacts, or generate them?

| Option | Description | Selected |
|--------|-------------|----------|
| Split: commit hand-written, ignore generated | `go.mod`/`binding.go`/`plugin.go`/`.scm` committed; C + `grammar.json` gitignored and materialized by the refresh script | |
| Commit everything | Clean clone builds immediately; shim diff proves propagation | ✓ |
| Ignore everything, generate the whole shim | Emit even `binding.go` from a template | |
| You decide | Defer to planner | |

**User's choice:** Commit everything
**Notes:** Chosen against the recommendation, with the cost stated up front: `src/parser.c` is
30.6 MB / 825,788 lines, so a committed copy doubles that and every regeneration writes another
~30 MB diff. Accepted deliberately in exchange for a no-prerequisite clean-clone build and a
diffable propagation check. Later reframe made the repo-size concern less consequential, since
protecting a PR diff stopped being a goal.

### Where does day-to-day grammar work happen?

| Option | Description | Selected |
|--------|-------------|----------|
| `main` is the working branch | Work on `main`; cut a topic branch and cherry-pick at publication time | ✓ |
| Topic branch is the workspace | Work on the topic branch; merge into a throwaway integration branch to measure | |
| Shim on its own branch, merged in | Long-lived shim branch; conflicts with "rebase, never merge" | |
| You decide | Defer to planner | |

**User's choice:** `main` is the working branch
**Notes:** Prompted by the observation that the shim lives on `main` but Phase 2–4 topic branches
are cut from `upstream/main` and would not contain it. The publication half of this answer was
later deferred entirely by the upstreamability reframe — see D-13.

### How faithful should the shim's Go surface be?

| Option | Description | Selected |
|--------|-------------|----------|
| Byte-faithful mirror | Copy forest's `binding.go` + `plugin.go` verbatim; drift detectable by diff | ✓ |
| Minimal — `GetLanguage()` only | Ship the one function gortex calls | |
| You decide | Defer to planner | |

**User's choice:** Byte-faithful mirror
**Notes:** Verified by inspection that gortex calls only `GetLanguage()` across five call sites,
while forest exports `GetLanguage`, `GetQuery`, and `Info`. Mirroring all three avoids a future
`undefined` error at the replace boundary.

---

## How gortex picks up the fork

### How should gortex resolve `go-sitter-forest/cobol` to the shim?

| Option | Description | Selected |
|--------|-------------|----------|
| `go.work` in gortex | Purpose-built; already gitignored in gortex; toggle is one file | ✓ |
| Committed `replace` in gortex `go.mod` | Matches existing `go-pointer`/`renameio` convention, but those are in-tree paths | |
| Scripted local replace, applied/reverted | Reversible, but leaves `go.mod` dirty while live | |
| Vendor the shim into gortex | Matches convention exactly, but duplicates 30 MB and makes the loop copy-twice | |

**User's choice:** `go.work` in gortex
**Notes:** Verified `~/repos/mine/GoApps/gortex/.gitignore` lines 23–24 already list `go.work` and
`go.work.sum`; no `go.work` exists yet. Also confirmed `~/repos/mine/GoApps/gortex` is the correct
target (it has `cobolprobe/`; `~/repos/else/gortex` does not).

### What form should the regenerate-and-refresh sequence take?

| Option | Description | Selected |
|--------|-------------|----------|
| Shell script inside `forest-shim/` | Groups tooling with what it maintains; touches no upstream-owned file | ✓ |
| Root script + npm script alias | Mirrors `run_nist_cobol85.sh` ← `npm run nist` exactly, but edits `package.json` | |
| Makefile | Self-documenting; introduces a build system the repo doesn't use | |
| Documented steps only | Cheapest; "repeatable" becomes a human promise | |

**User's choice:** Shell script inside `forest-shim/`
**Notes:** The npm-alias option was declined because `package.json` is the file dependabot keeps
moving — including the very CLI bump under discussion in OQ-2.

### Where should the phase's evidence live?

| Option | Description | Selected |
|--------|-------------|----------|
| `docs/` in this fork | Durable; survives milestone archival so Phases 2–4 can cite the baseline | ✓ |
| `.planning/phases/01-…/` | Lives with the phase; archived at milestone completion | |
| gortex's `cobolprobe` README | Where the published table and the method already live | |
| Split by subject | Recall numbers in cobolprobe, runbook here | |

**User's choice:** `docs/` in this fork
**Notes:** Flagged at the time that FORK-01 as written only rejects `.planning/` and `docs/spec/`,
so these new paths would have needed adding to the guard. That concern was dissolved when FORK-01
itself was later deferred.

### What is the baseline of record for Phase 2–4 deltas?

| Option | Description | Selected |
|--------|-------------|----------|
| DCC only | Reproduce 15/27/0/93 on `cam-corpus-dcc/DCC`; single baseline of record | ✓ |
| DCC plus an estate-wide figure | Richer signal, but requires deriving a classification for `estate/` first | |
| You decide | Defer to planner | |

**User's choice:** DCC only
**Notes:** Presented with the decisive measurement: `cam-corpus-dcc/DCC` holds exactly 606 `.cbl`
+ 958 `.cpy`, matching the published run, while the fork's `estate/` has **zero** `.cbl` files
(5,905 `.cpy` across 52,233 files). `estate/` cannot produce a `.cbl` recall figure at all without
new scope.

---

## CLI bump handling (OQ-2)

### CLI posture for this phase and Phases 2–4?

| Option | Description | Selected |
|--------|-------------|----------|
| Pin 0.24.5, measure 0.25.3, don't adopt | Satisfies VEND-03 as measurement with zero adoption risk | ✓ |
| Bump and adopt if the corpus passes | Modernizes; edits upstream's `package.json`; splits generators across branches | |
| Bump, adopt, and offer it upstream | Near-zero-cost probe of OQ-4 upstream appetite | |
| You decide | Defer to planner | |

**User's choice:** Pin 0.24.5, measure 0.25.3, don't adopt
**Notes:** Two findings gathered before asking. (1) The fork's `src/parser.c` and forest's are both
`LANGUAGE_VERSION 14` / `STATE_COUNT 7745` / `LARGE_STATE_COUNT 5095` — identical output differing
only in the flattened include and a dropped pragma — so `go-tree-sitter v0.25.0` already loads a
LANGUAGE_VERSION 14 parser in production today and no bump is needed for the pipe. (2) Upstream's
`dependabot/npm_and_yarn/tree-sitter-cli-0.25.3` branch is a pure manifest bump — `package.json` +
`package-lock.json` only, no regenerated `parser.c`, 1 ahead / 0 behind — carrying zero corpus
evidence; and upstream CI runs `generate` → NIST, never `tree-sitter test`.

### How deep should the 0.25.3 evidence go?

| Option | Description | Selected |
|--------|-------------|----------|
| Corpus + NIST + ABI load check | Both clauses VEND-03 states, plus the NIST net in the constraints | ✓ |
| Corpus + ABI load check only | Literal minimum; skips the most consequential regression suite | |
| Add a full cobolprobe recall run | Complete answer; ~20 minutes for a bump already declined | |
| You decide | Defer to planner | |

**User's choice:** Corpus + NIST + ABI load check

---

## Scope reframe: upstreamability (unplanned, user-initiated)

The user interrupted the guard discussion to ask what was actually being forked and what
`go-sitter-forest` is, then stated: *"the forks I make will likely never make it back to the
upstream so that is not a major concern they are my personal forks."*

A plain-language explanation of the four-way relationship (upstream grammar → forest photocopy →
gortex consumer → this fork) was given, along with a table of which Phase 1 requirements exist
solely to protect an upstream PR.

### How should the upstreamability requirements be handled?

| Option | Description | Selected |
|--------|-------------|----------|
| Re-scope now: drop PR machinery, keep the leak guard | Revise ROADMAP/REQUIREMENTS/PROJECT, drop FORK-01 and the topic-branch dance | |
| Keep it as written, just don't enforce it | Build the machinery, don't use it | |
| Keep rebasability, drop PR-readiness | Middle path; softens criterion 6 without rewriting locked decisions | |
| **Other (user free text)** | *"Ideally Id like to keep it pr ready if and only if its really worth it incase I change my mind later but just know that it is not the goal"* | ✓ |

**User's choice:** Free-text — keep PR-readiness only where it is genuinely worth it.

**Notes:** Resolved by applying an explicit cost test per item, on the finding that PR-readiness is
**recoverable on demand** — a clean topic branch can be reconstructed at any future date from
separable commits in about ten minutes, so it need not be maintained continuously to be preserved.

| Item | Cost to keep | Verdict |
|---|---|---|
| Commit separability (never mix grammar and fork-local edits) | ~zero | **Keep** — the only non-recoverable property |
| Topic branches + per-cycle cherry-picking | Friction every measurement loop | **Drop** |
| FORK-01 guard + self-verifying harness | Real build effort | **Drop from Phase 1** → deferred |
| Avoiding edits to upstream-owned files | ~zero, often better design anyway | **Keep as soft preference** |
| SPEC §6 criterion 6 (rebased topic branch) | — | **Soften** to "commits stay separable" |
| FORK-02 estate-leak guard | Real work, unrelated to PRs | **Keep** — public repo, proprietary source |

---

## Guard mechanism & where guards live

Reduced to FORK-02 only by the reframe above. A first batch of four questions covering both guards
was cancelled by the user mid-call and re-asked as two after the reframe.

### What should the estate-leak guard check?

| Option | Description | Selected |
|--------|-------------|----------|
| Paths + exclude assertion + sequence-area heuristic | Also flags added COBOL lines with populated cols 73–80 | ✓ |
| Paths + exclude assertion only | Mechanical, zero false positives; verbatim-quoted source passes | |
| Paths + exclude assertion + manual checklist | Honest about limits; depends on discipline | |

**User's choice:** Paths + exclude assertion + sequence-area heuristic
**Notes:** The sequence-area heuristic resolves a real tension — a naive content scan would flag
the hand-written COBOL corpus fixtures that Phases 2–4 must create. Estate source has cols 73–80
populated; hand-written minimal fixtures have no reason to fill them.

### How should it be wired so it actually fires?

| Option | Description | Selected |
|--------|-------------|----------|
| Script + `pre-push` hook, with an install step | Last moment before source leaves the machine | ✓ |
| Script only, run manually | Nothing to install; protects only when remembered | |
| Script + fork-local CI workflow | Automatic, but fires after the push already reached GitHub | |

**User's choice:** Script + `pre-push` hook, with an install step
**Notes:** CI was declined on the grounds that it detects a leak rather than preventing one.

---

## Claude's Discretion

- Exact shim directory name (`forest-shim/cobol/` illustrative).
- Exact `docs/` filenames (`vendoring.md` / `baseline.md` illustrative).
- Mechanics of isolating the 0.25.3 measurement (worktree vs `npx` pinned CLI).
- Whether the refresh script's module-cache drift check is a hard failure or a warning.

## Deferred Ideas

- FORK-01 branch-hygiene guard + harness, with two design findings retained: it must be a
  ref-taking script run from `main` (CI cannot see a topic branch cut from `upstream/main`), and it
  should allowlist the diff rather than denylist paths.
- Topic-branch publication workflow.
- Estate-wide recall measurement (needs a program/copybook classification for `estate/` first).
- A fork-local CI workflow running `tree-sitter test` — belongs with Phase 2.
- Upstream observations for OQ-4: `upstream/main` last moved 2024-12-17 and the CLI-bump PR has sat
  unmerged since; upstream also carries a `feature/fixed-format` branch.
