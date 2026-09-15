---
phase: 02-idms-dml-statement-nodes
plan: 05
status: complete
requirements: [IDMS-04, IDMS-07]
commits:
  fork:
    - 6ac7691 build(02-05) carry queries/*.scm into the shim during refresh
    - c100b6c build(02-05) refresh shim with idms grammar and queries
    - e927786 fix(02-05) replace read-only shim queries before copying
  gortex:
    - 13b2c035 test(02-05) add IDMS DML injection cases to TestErrorCascade
    - 3ffc0ad7 test(02-05) assert idms dml cascade parity and data division rejection
---

# 02-05: Deliver the IDMS grammar to gortex and close IDMS-04

## Outcome

IDMS-04 is closed. `TestErrorCascade` now carries the first real assertions in its
history, and an IDMS DML statement injected after a paragraph no longer destroys the
rest of the procedure division.

`queries/idms.scm` reaches gortex through the shim's `//go:embed grammar.json *.scm`.

## RED / GREEN evidence

Both runs use the same `TestErrorCascade` program shape: a clean control of 20 data
items and 20 paragraphs. RED was measured against the pre-IDMS shim (Phase 1 commit
`0373e64`); GREEN against the refreshed shim (`c100b6c`).

| Case | RED errs | RED data | RED paras | GREEN errs | GREEN data | GREEN paras |
|------|----------|----------|-----------|------------|------------|-------------|
| clean control | 0 | 20 | 20 | 0 | 20 | 20 |
| IDMS DML after para 1 | 1 | 20 | **1/20** | **0** | 20 | **20/20** |
| IDMS DML before data item | 1 | **1/20** | 20 | 1 | **1/20** | 20 |

Unchanged control cases, recorded to show the baseline did not move:

| Case | RED | GREEN |
|------|-----|-------|
| EXEC CICS after para 1 | errs=1, data=20, paras=1 | errs=1, data=20, paras=1 |
| SCHEMA SECTION before data | errs=1, data=0, paras=20 | errs=1, data=0, paras=20 |

The `EXEC CICS` case is Phase 3's gate and `SCHEMA SECTION` belongs to preprocessing per
locked decision D3. Neither carries an assertion, so neither can fail the build on a
known-open problem this phase does not fix.

### Falsifiability

Removing `go.work` and re-running makes the new assertions fail:

```
cascade_test.go:118: IDMS DML after para 1 cascaded: got 1 paragraphs, want 20 (clean control)
FAIL
```

This proves the gate measures this fork's grammar through the shim pipe and not forest
v1.9.1's cached parser. `go.work` was restored immediately afterward, as Phase 1 plan
01-01 did.

### Determinism

`go test -run TestErrorCascade -count=2 -v` exits 0 and both iterations report identical
paragraph, data-item and error counts.

## Deviation: Case B is a negative control, not a parity gate

The plan's must-have stated that "a DML statement immediately followed by a data item"
should leave the following construct intact. **This is not achievable and should not be.**

`OBTAIN` is a procedural DML verb. The four IDMS statement nodes attach to the general
`statement` alternation in `grammar.js:1382-1385`, alongside `display_statement` and
`compute_statement` — that is, to the procedure division only. Injecting `OBTAIN` into
`WORKING-STORAGE SECTION` is invalid COBOL, and the grammar reaching parity there would
mean it had started accepting programs it must reject.

Case B was therefore reasserted as a **negative control**: the gate asserts the error is
still reported (`e5 != 0`) rather than asserting recovery. Its RED and GREEN numbers are
identical by design, and that identity is now the asserted behavior.

The valid adjacency direction from IDMS-04 — a DML statement followed by a paragraph
header — is covered by Case A, which moved from 1/20 to 20/20 paragraphs.

Recommend amending the plan's must-have wording if this phase's artifacts are revisited.

## Root cause found during Task 2: read-only shim queries

The first refresh attempt failed at Step 3 with:

```
cp: forest-shim/cobol/sample.scm: Permission denied
```

`forest-shim/cobol/sample.scm` arrived via forest's own module-cache drop-in and carries
mode `0444`, as everything under `$GOPATH/pkg/mod` does. The new `queries/*.scm` copy
loop could not overwrite it. The four original copy targets (`parser.c`, `scanner.c`,
`grammar.json`, `parser.h`) were already `0644` from Phase 1 refreshes, which is why this
never surfaced until 02-05 added a loop that touches a module-cache file.

Fixed in `e927786` by removing the destination before copying. This also makes the step
idempotent, which acceptance criterion 7 requires.

**Secondary finding, not fixed here:** a Step 3 FAIL does not halt Steps 4-6. They ran and
reported OK against content Step 3 had failed to deliver, producing a log that looked
almost-clean while the shim was stale. Worth addressing separately; it is a reporting
weakness in `refresh.sh`, not a defect this plan introduced.

## SYMBOL_COUNT / TOKEN_COUNT against docs/vendoring.md §5

The refreshed shim reports:

| Constant | Refreshed shim | Fork committed (§5) | forest v1.9.1 (§5) |
|----------|----------------|---------------------|---------------------|
| `SYMBOL_COUNT` | **1224** | 1215 | 1153 |
| `TOKEN_COUNT` | **550** | 585 | 523 |

`SYMBOL_COUNT` rose by 9 and `TOKEN_COUNT` **fell** by 35 (585 → 550), which the added
`_KEYWORD` terminals do not explain on their own. That drop was investigated rather than
left open.

### Diagnosis: the parser is valid; the lost tokens were dead rules

Diffing the symbol enum of `src/parser.c` at `0373e64` (pre-IDMS) against HEAD:

| | Removed | Added | Net |
|---|---------|-------|-----|
| symbols | 59 | 68 | +9 |

All 59 removed symbols are **hidden terminals** (`sym__X`), and none has a surviving
visible counterpart. They are dead rules: their visible wrappers are commented out in
`grammar.js`, and have been since before Phase 1 —

```js
//CONTROL_HEADING: $ => $._CONTROL_HEADING,
//GENERATE: $ => $._GENERATE,
//INITIATE: $ => $._INITIATE,
```

Most are COBOL Report Writer vocabulary (`_GENERATE`, `_INITIATE`, `_CONTROL_HEADING`,
`_PAGE_FOOTING`, `_DETAIL`, `_LAST_DETAIL`, `_HEADING`, `_LIMITS`), and the Report Writer
is not implemented at all. `grammar.js:1233` is a placeholder stub:

```js
report_section: $ => /report_section/,
```

A worktree at `0373e64` confirms the baseline carried the **same** stub and the **same**
commented-out wrappers. Report Writer never parsed, before or after — nothing was lost.
The remainder are relational-operator terminals (`_GE`, `_LE`, `_EQUALS`, `_MINUS`) whose
constructs still parse: a program using `IS GREATER THAN OR EQUAL TO` and `NEXT SENTENCE`
parses with zero ERROR nodes against the refreshed grammar.

The added `prec.right` on `with_clause` and this phase's new conflicts changed lexical
state merging enough for tree-sitter to prune those unreachable keyword tokens. The
`grammar.js` diff corroborates it — 222 insertions, 10 deletions, and every deletion is
benign: one duplicate `_COMPUTE`, the `with_clause` precedence change, and seven lines
*uncommented* into live rules (`COMMIT`, `CONTINUE`, `CURRENCY`, `FROM`, `IS`, `LAST`,
`ROLLBACK`).

**Caveat:** this was proven by source comparison, not by executing the baseline parser.
Building it would have corrupted the main tree's native binding — the hazard 02-01 hit and
documented. Since the Report Writer grammar text is provably identical at both commits the
behaviour must be identical, but this is inference from source, not a direct A/B parse.

### Regression evidence

| Check | Baseline `0373e64` | HEAD | Verdict |
|---|---|---|---|
| Corpus suite | — | 113 pass / 1 fail | the fail is the long-standing `comment` fixture (02-02) |
| `tree-sitter test -e '^comment$'` | — | exit 0 | pass |
| NIST COBOL-85 | Fail: 0, Skip: 11 | 382 tests, Fail: 0, Skip: 11 | identical |
| Estate files with parse errors | 1742 / 1804 | 1742 / 1804 | identical — zero regression |
| ACCEPT records recognised | 1073 | 1401 | +328, the intended 02-04 gain |
| Regenerate drift | — | none | `src/` byte-identical |

Estate figures come from `run_accept_differential.sh run 0373e64 estate/endevor`. That run
reports FAIL, but only via 02-04's incomplete-denominator guard tripping on 17 timeouts —
not a reclassification regression. `run_accept_differential_selftest.sh` passes 6/6.

**§5 disposition:** the fork-vs-forest divergence (1215/585 vs 1153/523) remains open — this
plan did not investigate it. What is now closed is the *fork-internal* 585 → 550 movement
introduced by this phase, which is dead-rule pruning and not a loss of capability.

### Unrelated finding, not this phase's to fix

1742 of 1804 estate programs (96.6%) carry parse errors, flat across this change. These are
CBAP macro sources requiring preprocessing per locked decision D3 — Phase 3/4 territory.

## IDMS-07 / estate discipline

The injected COBOL uses only invented neutral names — `CUSTOMER-REC`,
`CUST-ORDER-SET` — matching this phase's existing fixtures.

**This fork's `.githooks/estate-guard.sh` does not run in the `gortex` repository.** The
neutral-names discipline there was manual and is unenforced by machinery. The only
estate-derived identifiers in `cascade_test.go` (`DCCSS000`, `CAMSC000`, line 74) are
pre-existing in the `SCHEMA SECTION` case and were not touched by this plan.

## Commit separability (FORK-03)

Every fork-local commit touches only `forest-shim/` paths:

- `6ac7691` — `forest-shim/refresh.sh`
- `c100b6c` — `forest-shim/cobol/{parser.c,parser.h,grammar.json,idms.scm}`
- `e927786` — `forest-shim/refresh.sh`

The `cascade_test.go` changes are committed in `gortex` only (`13b2c035`, `3ffc0ad7`).
`git status --porcelain` in this fork shows no `gortex` path staged at any point.

## Verification

| # | Check | Result |
|---|-------|--------|
| 1 | RED run shows the IDMS injection cascading | pass — 1/20 paragraphs |
| 2 | `bash forest-shim/refresh.sh` exits 0, second run is a no-op | pass |
| 3 | `cmp queries/idms.scm forest-shim/cobol/idms.scm` | pass |
| 4 | `cmp queries/sample.scm forest-shim/cobol/sample.scm` | pass |
| 5 | `go build ./...` in `forest-shim/cobol/` | pass |
| 6 | `go test -run TestErrorCascade -count=2` identical counts | pass |
| 7 | Removing `go.work` makes assertions fail | pass |
| 8 | All 6 refresh steps OK, no FAIL line | pass |
| 9 | Fork commits touch only `forest-shim/` | pass |

`REFRESH_ALLOW_DRIFT` was never set. Step 5's drift check passed on its own.
