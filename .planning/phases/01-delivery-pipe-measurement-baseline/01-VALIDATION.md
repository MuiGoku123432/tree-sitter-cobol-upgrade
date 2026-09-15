---
phase: 1
slug: delivery-pipe-measurement-baseline
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-28
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `01-RESEARCH.md` § Validation Architecture. The Per-Task Verification Map is
> populated by `/gsd-validate-phase` once PLAN.md task IDs exist.

**Framing:** this phase's "tests" are measurement and proof scripts, not a conventional unit-test
suite. There is no pytest/jest/vitest here. The validation surface is the existing regression net
(`tree-sitter test` over `test/corpus/*.txt`, `run_nist_cobol85.sh`) plus the new `cobolprobe`
recall run plus a new self-verifying guard script.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `tree-sitter test` (built into tree-sitter-cli, reads `test/corpus/*.txt`) + `go test` (for `cobolprobe` and shim smoke checks) |
| **Config file** | none — `tree-sitter test` auto-discovers `test/corpus/`; `go test` needs no config |
| **Quick run command** | `node_modules/.bin/tree-sitter test` |
| **Full suite command** | `node_modules/.bin/tree-sitter test && sh run_nist_cobol85.sh` |
| **Estimated runtime** | ~60 seconds (quick: seconds, 13 fixtures) |

**Prerequisite:** `npm ci` — not `npm install`. `package.json` pins `^0.24.5` but the registry now
carries 0.24.6/0.24.7; only `package-lock.json` holds the exact resolved 0.24.5. Any step that
shells out to `tree-sitter` or reads `node_modules/.bin/tree-sitter` must be preceded by `npm ci`
(RESEARCH.md Pitfall 2, Pitfall 6).

**Excluded from "full suite":** the `cobolprobe` recall run (~20 min) is a **phase-gate** item, not
a per-wave one. Running it per wave would violate the max-feedback-latency budget below.

---

## Sampling Rate

- **After every task commit:** shim work → `go build ./...` in the shim dir; guard work → the
  fail-then-pass self-test script. Both are seconds.
- **After every plan wave:** `node_modules/.bin/tree-sitter test && sh run_nist_cobol85.sh` —
  confirms no regression to the existing net.
- **Before `/gsd-verify-work`:** full suite green, plus VEND-01…05, FORK-02, FORK-03, SEQ-01 each
  evidenced in `docs/`.
- **Max feedback latency:** 60 seconds (the 20-minute recall run is explicitly exempt and gated to
  phase-end).

---

## Per-Task Verification Map

*Refreshed 2026-08-28 against the finished PLAN.md set (5 plans, 4 waves). The `❌ W0` placeholders
this table carried while it was seeded from RESEARCH.md are now resolved by concrete tasks — the
files still do not exist on disk, but they are no longer unowned gaps: each has a plan task that
creates it with its own acceptance criteria.*

| Req ID | Behavior | Covering plan | Test Type | Automated Command | Coverage |
|--------|----------|---------------|-----------|-------------------|----------|
| VEND-01 | Shim compiles and exposes `GetLanguage()` / `GetQuery()` / `Info()` matching forest's signatures | `01-01` (tracer; smoke test in task 2) | build+smoke | `go build .` in the shim dir + committed smoke test | ✅ owned |
| VEND-02 | gortex resolves the import to the local shim; `cobolprobe` runs end-to-end | `01-01` | integration | `go work` wiring + cobolprobe inline-fixture tests | ✅ owned |
| VEND-03 | 0.25.3 spike: corpus + NIST + ABI load recorded pass/fail | `01-04` | manual-only spike | detached `git worktree`, exact-pinned CLI, revert | ✅ owned |
| VEND-04 | Refresh sequence executed repeatedly, same conclusion each time | `01-03` (task 1) | scripted, run 3× | `forest-shim/refresh.sh` — idempotence + fault injection | ✅ owned |
| VEND-05 | Recall re-measured through the pipe | `01-05` (task 1) | measurement, phase-gate | full `cobolprobe` run, ~20 min | ✅ owned |
| FORK-02 | Guard rejects `estate/` paths and populated-seq-area added lines; passes clean; `.git/info/exclude` assertion holds | `01-02` (tasks 1-2) | self-verifying fail-then-pass script | `.githooks/estate-guard-selftest.sh` in a scratch repo | ✅ owned |
| FORK-03 | No commit mixes grammar and fork-local changes | `01-02` (task 3) | scripted check | `.githooks/commit-separability.sh` | ✅ owned |
| SEQ-01 | Build order + volumes recorded verbatim in `docs/` | `01-05` (task 2) | documentation transcription | grep assertion on `docs/baseline.md` | ✅ owned |

**Dimension 8 re-application (independent, by gsd-plan-checker, 2026-08-28):** every task carries an
`<automated>` verify; no watch-mode flags; no run of 3 consecutive tasks without automated verify.
No blocking gap found. That verification is the basis for `nyquist_compliant: true` above.
`status:` remains `draft` — flipping it to `validated` is `/gsd-validate-phase`'s call, not this
seeding pass's.

**One sanctioned latency exception:** plan `01-05` task 1 embeds the ~20-minute `cobolprobe` recall
run in its `<automated>` verify, exceeding the 60s budget below. This is deliberate — VEND-05's
measurement cannot be made faster, and the sampling contract designates it a phase-gate item rather
than routine sampling. Recorded so a future reviewer does not read it as an accidental slow task.

---

## Wave 0 Requirements

- [ ] `npm ci` — `node_modules/` must exist before any `tree-sitter` shell-out
- [ ] `forest-shim/cobol/` — does not exist; VEND-01's entire deliverable
- [ ] `forest-shim/cobol/` smoke test — no smoke test file exists in the shim dir
- [ ] `forest-shim/refresh.sh` — does not exist; VEND-04's entire deliverable
- [ ] Guard script + its self-verifying fail-then-pass test (D-18) — FORK-02's entire deliverable
- [ ] `docs/vendoring.md`, `docs/baseline.md` (names are planner's discretion) — `docs/` currently
      holds only `docs/spec/`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| tree-sitter-cli 0.25.3 spike | VEND-03 | One-time throwaway measurement whose whole point is that the result is recorded and the change reverted — automating a decision already made against (D-10) has no payoff | Isolate in a `git worktree`, regenerate with `npx --package tree-sitter-cli@0.25.3`, run `tree-sitter test` (13 fixtures) + `sh run_nist_cobol85.sh` (11-entry `skip_tests.txt` gate) + confirm the 0.25.3-generated `parser.c` loads under gortex's `go-tree-sitter v0.25.0`. Record pass/fail in `docs/`. Delete the worktree; working tree must be left clean and the `^0.24.5` pin intact. |
| Commit separability | FORK-03 | Discipline over a human action (`git commit`), not a state that can be asserted after the fact without rewriting history | Per commit: `git show --stat HEAD` — confirm grammar paths and fork-local paths do not co-occur. Never `git commit -a` (D-12). |

---

## Residual Limitations (recorded, not mitigated in this phase)

- **`git push --no-verify` bypasses the pre-push guard.** No server-side backstop is in scope.
  Acceptable within the phase boundary; recorded here so it is not silently assumed away.
- **NIST fixtures (`test/cobol85/src/*.CBL`) legitimately carry populated sequence areas.** The
  guard's "flag **added** lines only" scoping handles this correctly. A future change to a
  full-file scan would false-positive on these — do not "simplify" it that way.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s (one sanctioned exception: `01-05` task 1, see above)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** plan-time sign-off 2026-08-28 (gsd-plan-checker Dimension 8 pass). `status: draft` until `/gsd-validate-phase` runs.
