---
phase: 02-idms-dml-statement-nodes
plan: 06
status: complete
requirements: [IDMS-05, IDMS-07, IDMS-08]
commits:
  fork:
    - d29af7a feat(02-06) model bind dbname and erase members options from tail census
    - 1e4085a build(02-06) refresh shim with tail census grammar extension
    - 4faa129 docs(02-06) record phase 2 delta and phase 3 gap-closure target
    - 129e7c7 docs(02-06) resolve oq-3 with the phase 3 gap-closure target
---

# 02-06: Measure the Phase 2 delta and commit the Phase 3 target

## Outcome

OQ-3 is resolved. Phase 3 is held to **6% of the 14,455-item gap — grammar-alone `.cbl`
dataItems >= 18,772** — recorded in `docs/baseline.md` §4 and carried identically into
`ROADMAP.md`, `PROJECT.md` and `STATE.md`.

**IDMS-05 did not pass and is left unchecked.** Its cause is diagnosed, not excused.

## Measured (Task 1)

| Metric | Value | Source |
|--------|-------|--------|
| `.cbl` grammar-alone dataItems | **17,905** | `probe_test.go:141` |
| `.cbl` neutralized | 32,360 | `neutralize_test.go:139` |
| Gap-closure fraction | `(17,905 − 17,905) / 14,455` = **0** | computed |
| `idms_unparsed_tail` census | **119 → 9** (−92%) | differential snapshot |
| Precompiled `CALL 'IDMS'` | DCC **0**, estate 4 | D-12 confirmed |

Verbatim: `probe_test.go:141`: `.cbl 606 13 2% 17905 42`;
`neutralize_test.go:139`: `.cbl 606 | 13 -> 14 | 17905 -> 32360 | 15323 -> 16732`.
`probe_test.go:87` reports `probing 1564 files` — the full corpus.

### The zero delta is real, not a broken pipe

All three mandated pipe checks passed before the zero was accepted:

1. `go work edit -json` lists this fork's `forest-shim/cobol`
2. `forest-shim/cobol/parser.c` holds the IDMS grammar (114 IDMS node references);
   `cmp queries/idms.scm forest-shim/cobol/idms.scm` exits 0
3. `refresh.log` STEP 6 smoke build OK

The grammar demonstrably works — one real IDMS program yields 35 `idms_navigation_statement`,
17 `idms_update_statement`, 30 `idms_record_name`, 28 `idms_set_name`, 3 `idms_accept_statement`,
3 `idms_session_statement`.

### Written cause (D-15)

`dataItems` is a DATA DIVISION metric; Phase 2 built PROCEDURE DIVISION statement nodes.
Attributing all 17,905 items by population — the total reconciles exactly with the probe, which
validates the method:

| population | files | dataItems | share |
|------------|-------|-----------|-------|
| with `SCHEMA SECTION` | 321 (53%) | 213 | 1.2% |
| without | 285 (47%) | 17,692 | 98.8% |

`SCHEMA SECTION` has **zero references in `grammar.js`**, so one ERROR node swallows the DATA
DIVISION in 53% of the corpus. At the non-blocked density (~62 items/file) those 321 files would
yield ~19,900 items — alone over-explaining the entire 14,455 gap.

Locked decision **D3 assigns `SCHEMA SECTION` to preprocessing, in a different repository.** No
grammar-only phase can move this axis.

## D-09 grammar extension (Task 1, authorised by the plan)

The census showed concentration, so D-09's "extend where the volume is" fired:

| tail shape (identifiers masked) | count | share |
|---------------------------------|-------|-------|
| `BIND RUN-UNIT` ‖ `DBNAME <id>` | 96 | 81% |
| `ERASE <id>` ‖ `ALL` / `ALL MEMBERS` | 14 | 12% |
| continuation ‖ `USING <id>` | 8 | 7% |
| `OBTAIN <id> WITHIN <id>` ‖ `USING <id>` | 1 | <1% |

Both concentrated shapes are now modelled. One new terminal (`DBNAME`); `ALL`, `MEMBERS`,
`PERMANENT`, `SELECTIVE` already existed. Second census **9 records** — the D-09 gate (second <=
first) holds. The residual 9 are all `USING <id>`: a long thin tail with no concentration, so
nothing further was modelled.

Three corpus fixtures were updated because the extension made their expected trees obsolete —
they asserted `idms_unparsed_tail` for constructs now properly parsed. Two were rewritten to the
new trees, one was renamed, and two replacement fixtures using genuinely unmodelled input were
added so tail coverage is preserved rather than lost.

Regression after the extension: corpus **116 passing** (`-e '^comment$'` exit 0, up from 113),
NIST **382 tests, Fail: 0, Skip: 11** — unchanged.

## Decision (Task 2, one-way)

**Option B — proportional share sized to what Phase 3 controls.**

Option A (the plan's recommendation) was rejected on measured evidence: of the 169 `.cbl`
containing `EXEC CICS`, **122 (72%) also contain `SCHEMA SECTION`**, so their DATA DIVISION stays
dead however well Phase 3 parses CICS. Only 47 files are both CICS-affected and `SCHEMA`-free.
Holding Phase 3 to the full remainder would set a criterion it cannot satisfy by construction.

Sizing:

| population | files | current | potential @ ~65/file | reachable gain |
|------------|-------|---------|----------------------|----------------|
| `SCHEMA`-free, has `EXEC CICS` | 47 | 2,144 | ~3,055 | ~911 |
| `SCHEMA`-blocked | 321 | 213 | ~19,900 | ~19,700 (preprocessing) |

`911 / 14,455 ≈ 6.3%` → **6%**.

Disclosed as an **upper bound**: `EXEC CICS` sits in the PROCEDURE DIVISION and the cascade
measurement shows it destroys paragraphs while leaving data items intact (1/20 paragraphs, 20/20
data items), so part of the 45-vs-65 items/file difference is likely file composition rather than
CICS blocking. The terminal condition grammar-alone >= neutralized is retained as the
programme-level end state across preprocessing plus Phases 3-4, not as Phase 3's gate.

## Requirement dispositions

| Requirement | State | Reason |
|-------------|-------|--------|
| IDMS-05 | **Outstanding, unchecked** | Second clause passed (tail 119 → 9); first clause failed (recall flat at 17,905). Mis-specified for a grammar phase — the axis is gated by `SCHEMA SECTION`, which D3 assigns to preprocessing. |
| IDMS-07 | Met | No corpus path, program name or source line in `docs/` or `.planning/`; aggregate counts only. `estate-guard-selftest.sh` exits 0. |
| IDMS-08 | **Met, checked** | Concrete target set from the measurement, recorded with derivation, carried identically to all four files. |

IDMS-05 was deliberately not checked. Per the plan's own prohibition, a box is not ticked to make
a phase look finished.

## Deviation: commit scope

The plan's Task 3/4 acceptance criteria state that *every* commit in this plan touches only
`docs/` and `.planning/`. Two commits (`d29af7a`, `1e4085a`) touch `grammar.js`, `src/`,
`test/corpus/` and `forest-shim/cobol/`. These are **Task 1's D-09 extension**, which the plan's
Task 1 action explicitly authorises ("extend the grammar for those within this phase — that is
what D-09 exists for"). The `docs/`-and-`.planning/`-only constraint holds for the Task 3 and
Task 4 commits (`4faa129`, `129e7c7`), which it does. The criterion's wording was scoped to the
no-extension path.

## Verification

| # | Check | Result |
|---|-------|--------|
| 1 | Probe exits 0 over the full 1,564-file corpus | pass |
| 2 | Three pipe checks before accepting the zero | pass |
| 3 | Tail census second count <= first (9 <= 119) | pass |
| 4 | Corpus gate `-e '^comment$'` | exit 0, 116 passing |
| 5 | NIST `Fail: 0, Skip: 11` | unchanged |
| 6 | `docs/baseline.md` §4 present with 17,905 / 32,360 / 14,455 | pass |
| 7 | `grep -c 'value open' ROADMAP.md` = 0 | pass |
| 8 | `grep -c 'The value is still unset' STATE.md` = 0 | pass |
| 9 | ROADMAP still has all 4 phase entries | pass |
| 10 | OQ-1, OQ-2, OQ-4 untouched | pass |
| 11 | `estate-guard-selftest.sh` | exit 0 |
| 12 | Target value `18,772` byte-identical in all 4 files | pass |

Census artifacts were written to `mktemp -d` outside the repository; `git status --porcelain`
carries no census output.

## Open for Phase 3 planning

1. **IDMS-05's axis needs re-scoping.** This is the third instance this phase of a criterion that
   cannot be satisfied by construction (02-05 Case B, IDMS-05, and Option A had it been taken).
   Worth a planning-time check that each success criterion is reachable by the work it gates.
2. **`SCHEMA SECTION` is the single largest recall blocker** — 321 files, ~19,700 items — and it
   is unowned in this repo's roadmap. It belongs to preprocessing under D3, but no phase tracks it.
3. **96.6% of estate programs still carry parse errors** (1,742 / 1,804), flat across this change.
   CBAP macro sources requiring preprocessing.
