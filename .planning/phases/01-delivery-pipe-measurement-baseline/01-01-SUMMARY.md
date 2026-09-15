---
phase: 01-delivery-pipe-measurement-baseline
plan: 01
subsystem: infra
tags: [go-workspace, cgo, tree-sitter, vendoring, gortex]

# Dependency graph
requires: []
provides:
  - "forest-shim/cobol/ — a Go module that byte-faithfully impersonates github.com/alexaandru/go-sitter-forest/cobol@v1.9.1's file layout and exported surface, embedding THIS fork's generated parser instead of forest's"
  - "A proven, reversible go.work-based resolution path: gortex resolves the cobol import to this fork's shim with zero committed changes to gortex"
  - "A committed smoke test (smoke_test.go) that regresses if the drop-in surface or the embedded grammar ever drifts"
affects: [01-02, 01-03, 01-04, 01-05]

# Actuals (#2632)
actuals:
  tokens: 7991186
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "go work init . <path> as a single-command, uncommitted, gitignored workspace switch — bypasses go.sum/checksum verification entirely for the used local directory"
    - "Copy-and-flatten vendoring: generated build artifacts physically copied (never symlinked) into a package directory, with #include directives rewritten post-copy for cgo's flattened header expectation"

key-files:
  created:
    - forest-shim/cobol/go.mod
    - forest-shim/cobol/binding.go
    - forest-shim/cobol/plugin.go
    - forest-shim/cobol/alloc.h
    - forest-shim/cobol/array.h
    - forest-shim/cobol/sample.scm
    - forest-shim/cobol/_keep.scm
    - forest-shim/cobol/parser.c
    - forest-shim/cobol/parser.h
    - forest-shim/cobol/scanner.c
    - forest-shim/cobol/grammar.json
    - forest-shim/cobol/smoke_test.go
  modified: []

key-decisions:
  - "Followed D-01 through D-04 exactly: dedicated forest-shim/cobol/ directory, all artifacts committed including the 30.6MB parser.c, byte-faithful Go surface mirror, physical copy-and-flatten (no symlinks)"
  - "Used the single-invocation `go work init . <shim-path>` (RESEARCH.md's tested simplification) rather than the two-step init+use — functionally identical, one command"
  - "The tracer's <verify> passed with strong automated evidence (go env GOWORK non-empty, go list -m resolving into the fork, three cobolprobe tests green, zero tracked gortex changes) before Task 2 began — no human-verify checkpoint was warranted given the fully automated, reversible nature of the proof"

patterns-established:
  - "Pattern: vendored generated artifacts are physically copied and flattened, never symlinked, with a documented required #include rewrite step (this fork's src/parser.c uses the quoted include form, src/scanner.c the angle-bracket form — two different sed patterns needed)"

requirements-completed: [VEND-01, VEND-02]

coverage:
  - id: D1
    description: "forest-shim/cobol/ is a drop-in Go module for github.com/alexaandru/go-sitter-forest/cobol, embedding this fork's grammar instead of forest's"
    requirement: VEND-01
    verification:
      - kind: unit
        ref: "forest-shim/cobol/smoke_test.go#TestShimExposesForestSurface"
        status: pass
      - kind: unit
        ref: "forest-shim/cobol/smoke_test.go#TestShimEmbedsThisForksGrammar"
        status: pass
      - kind: unit
        ref: "forest-shim/cobol/smoke_test.go#TestShimMissingQueryReturnsEmpty"
        status: pass
      - kind: other
        ref: "diff -q forest-shim/cobol/binding.go $(go env GOMODCACHE)/github.com/alexaandru/go-sitter-forest/cobol@v1.9.1/binding.go"
        status: pass
    human_judgment: false
  - id: D2
    description: "gortex resolves the cobol import to this fork's shim via go.work, and cobolprobe's inline-fixture tests pass end-to-end against the unmodified grammar, with zero committed changes to gortex"
    requirement: VEND-02
    verification:
      - kind: integration
        ref: "go test ./internal/parser/forest/cobolprobe/ -run 'TestErrorCascade|TestHypothesis' -v (in ~/repos/mine/GoApps/gortex)"
        status: pass
      - kind: other
        ref: "go list -m -f '{{.Dir}}' github.com/alexaandru/go-sitter-forest/cobol resolves to forest-shim/cobol/, not GOMODCACHE"
        status: pass
      - kind: other
        ref: "git status --porcelain in gortex reports no tracked-file change after go.work is created"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-08-29
status: complete
---

# Phase 1 Plan 1: Delivery Pipe Vendoring Shim Summary

**A drop-in `forest-shim/cobol/` Go module vendors this fork's COBOL grammar and gortex resolves to it via an uncommitted `go.work`, proven end-to-end by three passing `cobolprobe` tests against the unmodified grammar.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-08-29T09:52:00Z (approx, first shell command)
- **Completed:** 2026-08-29T10:27:00Z
- **Tasks:** 2
- **Files modified:** 12 (11 vendored shim files + 1 committed test)

## Accomplishments
- Built `forest-shim/cobol/`: a byte-faithful mirror of `go-sitter-forest/cobol@v1.9.1`'s Go surface (`binding.go`, `plugin.go`, `go.mod`, `alloc.h`, `array.h`, `sample.scm`, `_keep.scm`) plus this fork's own generated parser output (`parser.c`, `scanner.c`, `parser.h`, `grammar.json`), copied and flattened per D-04, with both `#include` forms rewritten to the flattened header
- Wired `~/repos/mine/GoApps/gortex` via a single `go work init . <shim-path>` — proven to add zero committed bytes to gortex (`git status --porcelain` empty) and to be a one-file, reversible switch (deleting `go.work` reverts `go list -m -f '{{.Dir}}'` to the GOMODCACHE path; recreating it restores the fork path)
- Ran gortex's `cobolprobe` inline-fixture tests (`TestErrorCascade`, `TestHypothesisIdentificationParagraphs`, `TestHypothesisIDMS`) through the shim end-to-end against the **unmodified** grammar — all three pass, proving the pipe itself, not a grammar change, is what's under test
- Added a committed `smoke_test.go` in the shim package that fails loudly if the drop-in surface regresses or the embedded grammar is ever swapped back to forest's 327-byte placeholder

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end "a grammar edit in this fork is what gortex parses with"** - `0373e64` (feat)
2. **Task 2: Pin the drop-in contract with a committed shim smoke test** - `47df3e4` (test)

**Plan metadata:** pending (this commit)

## Files Created/Modified
- `forest-shim/cobol/go.mod` - Drop-in module identity, `module github.com/alexaandru/go-sitter-forest/cobol`
- `forest-shim/cobol/binding.go` - cgo language binding, byte-faithful mirror of forest v1.9.1
- `forest-shim/cobol/plugin.go` - plugin-tagged variant of the same surface
- `forest-shim/cobol/alloc.h`, `array.h` - structural filler from forest's file-set contract (currently inert — not referenced by this fork's generated `parser.h`)
- `forest-shim/cobol/sample.scm`, `_keep.scm` - embedded query files / placeholder
- `forest-shim/cobol/parser.c` - this fork's generated parse tables, flattened and include-rewritten
- `forest-shim/cobol/parser.h` - this fork's `tree_sitter/parser.h`, flattened to the package root
- `forest-shim/cobol/scanner.c` - this fork's external scanner, flattened and include-rewritten
- `forest-shim/cobol/grammar.json` - this fork's grammar, embedded and surfaced by `Info()`
- `forest-shim/cobol/smoke_test.go` - committed regression pin on the drop-in contract

## Decisions Made
- Followed D-01 through D-04 exactly as specified — no deviation on directory placement, file-set completeness, or the byte-faithful mirror requirement
- Used the single-invocation `go work init . <shim-path>` (RESEARCH.md's tested, simpler alternative to the two-step `init` + `use`) — functionally equivalent, planner's choice was left open
- Treated the tracer task's built-in feedback gate as satisfied by the fully automated, reversible `<verify>` evidence (three green cobolprobe tests, confirmed resolution path, zero tracked gortex diff, and a demonstrated one-file on/off switch) rather than pausing for a human-verify checkpoint — nothing in the gate required human judgment beyond what the automated checks already proved

## Deviations from Plan

None - plan executed exactly as written. Both tasks' full acceptance-criteria sets (file existence, byte-diffs against the module cache, build/test exit codes, `git status --porcelain` emptiness) were verified explicitly and passed on the first attempt with no fix-up required.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The `go.work` created in `~/repos/mine/GoApps/gortex` is intentionally uncommitted and gitignored on gortex's side (lines 23-24 of its `.gitignore`); it is a local, machine-specific switch, not a shared setup step.

## Next Phase Readiness

- The vendoring pipe is proven and switched on (`go.work` present in gortex) — plans 02-05 in this phase (fork hygiene guard, refresh automation, docs, and the re-measured `cobolprobe` recall baseline) can now build on a working local delivery mechanism rather than an untested one
- `forest-shim/refresh.sh` (plan 03) still needs to script the copy + two `sed` rewrites this plan performed manually, plus the module-cache drift diff on `binding.go`/`plugin.go`/`go.mod`
- No blockers identified for subsequent plans in this phase

## Self-Check: PASSED

- All 12 key files verified present on disk with `[ -f ]`
- Both commit hashes (`0373e64`, `47df3e4`) verified present via `git log --oneline --all`
- All acceptance criteria for both tasks re-run and confirmed PASS (byte-diffs, build exit codes, test output, `git status --porcelain` emptiness in both repos)
- Plan-level `<verification>` re-run: `go build ./... && go test ./... -v` in the shim (0), `go env GOWORK`/`go list -m`/`cobolprobe` tests in gortex (all pass), gortex `git status --porcelain` empty, and the delete/recreate `go.work` round-trip confirmed the one-file switch and left `go.work` recreated (required by later plans)

---
*Phase: 01-delivery-pipe-measurement-baseline*
*Completed: 2026-08-29*
