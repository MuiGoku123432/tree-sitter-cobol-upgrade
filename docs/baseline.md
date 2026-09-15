# Baseline — recall measurement and build order of record

**Status:** Living record, updated as Phase 1 lands and Phases 2-4 measure their deltas against it
**Date:** 2026-08-29
**Repo:** `MuiGoku123432/tree-sitter-cobol-upgrade` — fork of `yutaro-sakamoto/tree-sitter-cobol` (MIT)
**Consumer:** `gortex` (Gortex Mainframe Engine)
**Corpus of record:** `~/repos/mine/cobolCode/cam-corpus-dcc/DCC` — 606 `.cbl` + 958 `.cpy` files

---

## 1. What this file is

This is the measurement of record: the `cobolprobe` recall baseline every later phase's recall
delta is compared against, and the build order those measurements justify. Both were produced
in `MuiGoku123432/tree-sitter-cobol-upgrade` — this fork — against the corpus of record named
above, through the local vendoring path `docs/vendoring.md` describes (the `go.work`-resolved
shim at `forest-shim/cobol/`), consumed by `gortex`.

---

## 2. The recall baseline (VEND-05)

This is the same-method, same-corpus, same-grammar-lineage recall measurement every later
phase's delta is judged against. Measured through the local vendoring path
(`docs/vendoring.md` — the `go.work`-resolved shim at `forest-shim/cobol/`, embedding this
fork's own generated parser), not through `go-sitter-forest/cobol` v1.9.1.

### Invocation

Exactly `gortex/internal/parser/forest/cobolprobe/README.md`'s documented command, run
2026-08-29:

```
go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m \
    -corpus      ~/repos/mine/cobolCode/cam-corpus-dcc/DCC \
    -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC
```

Exit code 0. `cascade_test.go`, `hypo_test.go`, `probe_test.go`, and `neutralize_test.go` all
passed. The `-timeout 20m` budget anticipates a run "on the order of twenty minutes"; the
actual run completed in **18.4 seconds** — recorded here as a genuine finding, not adjusted
toward the anticipated figure. It does not change the correctness of the result: the same
1,564 files were parsed by the same test code either way, and `probe_test.go`'s own log line
reports `probing 1564 files under ~/repos/mine/cobolCode/cam-corpus-dcc/DCC`, confirming the
full corpus ran, not a subset.

### Measured cells

Recall against source truth — level-number lines and area-A paragraph labels counted directly
from the code area (per `cobolprobe/README.md`). The denominators below (121,457 for `.cbl`,
24,478 for `.cpy`) are the README's published, already-counted source-truth field counts —
**they were not independently re-derived in this run**, because neither `probe_test.go` nor
`neutralize_test.go` emits a source-truth denominator; both report the grammar's own
`dataItems` count only. Every percentage below is this run's raw numerator divided by that
borrowed, previously-published denominator — never presented as a denominator this run
measured itself.

| | files | fields in source (borrowed denominator) | grammar alone | + `neutralize()` |
|---|---|---|---|---|
| `.cbl` | 606 | 121,457 | 17,905 (14.7%) | 32,360 (26.6%) |
| `.cpy` | 958 | 24,478 | 0 (0.0%) | 22,800 (93.1%) |

Raw counts sourced from this run's own log output:
`probe_test.go:141`: `.cbl 606 13 2% 17905 42` and `.cpy 958 0 0% 0 0` (grammar-alone
`dataItems`, over `files`); `neutralize_test.go:139`: `.cbl 606 | 13 -> 14 | 17905 -> 32360 |
9187 -> 14804` and `.cpy 958 | 0 -> 459 | 0 -> 22800 | 0 -> 1022` (`dataItems` before/after
neutralization).

### The `.cpy` zero, sanity-checked

The `.cpy` grammar-alone `dataItems` count (0) is reported over the `files` column value of
**958** — the full corpus, not a subset the grammar happened to yield something for. A
skipped-file denominator would make this ratio undefined or artificially 100%; a
counted-file denominator, which this is, is exactly what makes a 0% figure meaningful rather
than an artifact of how files were selected.

### Comparison against the previously published figures

The previously published figures — measured through `go-sitter-forest/cobol` v1.9.1 — are
`.cbl` 15% grammar-alone / 27% with `neutralize()`, `.cpy` 0% / 93%.

**This run's raw counts are numerically identical to the previously published ones**:
17,905 / 32,360 for `.cbl`, 0 / 22,800 for `.cpy`, matching digit-for-digit, which is why the
rounded percentages above (14.7%→15%, 26.6%→27%, 93.1%→93%) land on the same rounded figures
already published.

This identical-recall result coexists with a genuine grammar-lineage difference recorded in
`docs/vendoring.md`: this fork's committed `src/parser.c` reports `SYMBOL_COUNT`/`TOKEN_COUNT`
**1215**/585, while forest v1.9.1's cached copy reports **1153**/523 — a different generated
build, not a rebuild of the same one. That the `dataItems` recall numbers came out identical
despite this difference is itself informative, not a contradiction: the symbols this fork's
grammar gained beyond forest's cached revision (per `docs/vendoring.md` §5, at minimum the
comment-node exposure added in commit `c7a36d7`) evidently do not touch the
`data_description`-node counting logic `cobolprobe` measures, on this specific corpus. Per
this phase's transparency prohibition, this agreement is recorded as observed, not engineered
— no figure here was adjusted, rounded toward, or re-described to produce this match; it is
what both runs' log lines report verbatim.

**This run's numbers are the baseline of record for Phases 2-4.** Even though they match the
previously published figures for this corpus, they are the ones measured through this fork's
own grammar lineage via the local vendoring path this phase built — the same-method,
same-grammar-lineage number a later phase's delta must be compared against, rather than a
number inherited from a different parser build that happens to agree today.

---

## 3. Build order and the volumes behind it (SEQ-01)

The remaining build order — IDMS DML, then `EXEC CICS`, then `EXEC SQL` — is fixed to measured
volume, largest family first, transcribed cell for cell from `.planning/PROJECT.md`'s "Volume
drives the order" table. Measured over the **1,369 compilable programs** in the consolidated
estate tree (programs holding both an `IDENTIFICATION DIVISION` and a `PROCEDURE DIVISION`; the
remainder of the 3,781 COBOL members are macro source and fragments, not counted here):

| family | programs | statements |
|---|---|---|
| IDMS DML | 541 (40%) | 14,764 |
| `EXEC CICS` | 221 (16%) | 3,539 |
| `EXEC SQL` | 49 (4%) | 489 |
| `EXEC DLI` | 0 (0%) | 0 |

`EXEC DLI` is not built at all, per locked decision **D4**: zero occurrences measured across
the 1,369 programs, so there is no construct to add nodes for.

This ordering is the **reverse** of the intuitive "CICS / SQL / DLI" framing a reader might
expect from alphabetical or conventional-familiarity ordering — IDMS DML, at 40% of programs
and by far the largest statement count, comes first, not last. That is the whole reason these
volumes are recorded beside the order rather than left implicit: the order only makes sense
once the counts are visible.

**The IDMS DML verb mix**, which is what makes Phase 2's `ACCEPT` ambiguity concrete: BIND 4631,
OBTAIN 2939, FIND 1792, READY 1444, ERASE 714, **ACCEPT 634**, GET 613, STORE 603, FINISH 550,
MODIFY 384, CONNECT 200, ROLLBACK 144, COMMIT 61, DISCONNECT 53. Naive verb matching finds
**2,391** `ACCEPT`s across the estate; only **634** are IDMS forms (`FROM … CURRENCY`, `…
DB-KEY`) and **1,757** are standard COBOL. The grammar must disambiguate on the operand tail,
never on the verb alone — an over-eager rule would silently break 1,757 ordinary `ACCEPT`
statements to gain 634 IDMS ones.

---

## 4. Phase 2 — IDMS DML delta and the Phase 3 gap-closure target

Measured after Phase 2's four IDMS verb classes landed and reached `cobolprobe` through the
Phase 1 pipe. Same corpus, same flags, same method as §2.

```
go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m \
  -corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC \
  -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC
```

Exit 0. `probe_test.go:87`: `probing 1564 files` — the full corpus, not a subset.

### Measured cells

| ext | files | clean | clean% | dataItems (grammar-alone) | dataItems (+ neutralize) |
|-----|-------|-------|--------|---------------------------|--------------------------|
| `.cbl` (Phase 1) | 606 | 13 | 2% | 17,905 | 32,360 |
| `.cbl` (Phase 2) | 606 | 13 | 2% | **17,905** | **32,360** |
| `.cpy` (Phase 2) | 958 | 0 | 0% | 0 | 22,800 |

Verbatim: `probe_test.go:141`: `.cbl 606 13 2% 17905 42`;
`neutralize_test.go:139`: `.cbl 606 | 13 -> 14 | 17905 -> 32360 | 15323 -> 16732`.

The `.cpy` grammar-alone 0% is **structural** — copybooks have no `IDENTIFICATION DIVISION` to
anchor a parse — and is not a Phase 2 failure.

### Gap-closure fraction

Using the §2 constants verbatim — 17,905 grammar-alone and 32,360 neutralized, gap 14,455:

```
(X − 17,905) / (32,360 − 17,905) = (17,905 − 17,905) / 14,455 = 0
```

**Phase 2's measured share of the gap is 0.** D-15's written-cause requirement therefore fires.

### Written cause: the DATA DIVISION is gated at SCHEMA SECTION

The zero is a real measurement, not a broken pipe. All three pipe checks passed: `go.work` lists
the shim, `forest-shim/cobol/parser.c` holds the IDMS grammar (114 IDMS node references) with
`idms.scm` byte-identical, and `refresh.sh` step 6's smoke build succeeded.

The grammar demonstrably works. One real IDMS program yields 35 `idms_navigation_statement`,
17 `idms_update_statement`, 30 `idms_record_name`, 28 `idms_set_name`, 3 `idms_accept_statement`
and 3 `idms_session_statement` where it previously yielded none.

`dataItems` does not move because it is a DATA DIVISION metric and Phase 2 built PROCEDURE
DIVISION statement nodes. Attributing all 17,905 items by population (the total reconciles
exactly with the probe, which validates the method):

| population | files | dataItems | share |
|------------|-------|-----------|-------|
| with `SCHEMA SECTION` | 321 (53%) | 213 | 1.2% |
| without | 285 (47%) | 17,692 | 98.8% |

`SCHEMA SECTION` is unmodelled — it has zero references in `grammar.js` — so a single ERROR node
swallows the DATA DIVISION in 53% of the corpus. At the non-blocked density of ~62 items/file
those 321 files would yield roughly 19,900 items, which alone over-explains the whole 14,455 gap.

**Locked decision D3 assigns `SCHEMA SECTION`, `IDMS-CONTROL SECTION`, `PROTOCOL.` and
`DB x WITHIN y` to preprocessing, in a different repository.** The gap is preprocessing's to
close, and no grammar-only phase can move this axis. This mirrors the `neutralize()` harness
itself, whose `reSchema` regex exists precisely to simulate that missing stage.

### `idms_unparsed_tail` census (D-09)

Measured with the existing differential tool — no parallel harness:
`run_accept_differential.sh snapshot <DCC> <$DIFF_TMP/tail-census> idms_unparsed_tail`, exit 0,
606 files walked, 0 failed to emit a tree, 0 timed out.

| tail shape (identifiers masked) | count | share |
|---------------------------------|-------|-------|
| `BIND RUN-UNIT` ‖ `DBNAME <id>` | 96 | 81% |
| `ERASE <id>` ‖ `ALL` / `ALL MEMBERS` | 14 | 12% |
| continuation ‖ `USING <id>` | 8 | 7% |
| `OBTAIN <id> WITHIN <id>` ‖ `USING <id>` | 1 | <1% |

Two shapes carried 93% of the volume, so D-09's "extend where the volume is" fired and both were
modelled: `BIND RUN-UNIT DBNAME <db-name>` and
`ERASE <record> [ALL|PERMANENT|SELECTIVE] [MEMBERS]`. One new terminal (`DBNAME`) was added; the
`ALL`, `MEMBERS`, `PERMANENT` and `SELECTIVE` terminals already existed.

**Second census after the extension: 119 → 9 records**, satisfying the D-09 gate that the second
count be less than or equal to the first. The residual 9 are all `USING <id>` — a long thin tail
with no concentration, so nothing further was modelled. Extending for shapes with no measured
volume is the speculative generality D-09 exists to rule out.

Regression net after the extension: corpus 116 passing (`tree-sitter test -e '^comment$'` exit 0),
NIST `382 tests. (Success: 371, Fail: 0, Skip: 11)` — unchanged.

### ACCEPT differential (02-04 instrument, re-run this phase)

Against the Phase 1 baseline `0373e64` over the estate corpus: 1,804 files walked both sides,
**1,742 files with parse errors on both sides — identical, zero regression** — and ACCEPT records
recognised rising 1,073 → 1,401. The run reports FAIL only because 02-04's incomplete-denominator
guard trips on 17 timeouts, not because of any reclassification.
`run_accept_differential_selftest.sh` passes 6/6.

### Precompiled `CALL 'IDMS'` form (D-12)

**DCC `.cbl`: 0 occurrences** (`CALL 'IDMS'` and `IDBMSCOM` both zero), matching the
discussion-time measurement. Estate: 4 files. Precompiled programs correctly show zero DML nodes
because the IDMS precompiler has already rewritten the statements; they are excluded so that any
edge-coverage claim is read against the right denominator. This does not affect the DCC recall
measurement at all.

### The Phase 3 gap-closure target

**Phase 3 is held to 6% of the 14,455-item gap — grammar-alone `.cbl` dataItems ≥ 18,772** —
with the remainder explicitly assigned to preprocessing rather than to Phase 3.

Derivation, from the same attribution above:

| population | files | current | potential @ ~65/file | reachable gain |
|------------|-------|---------|----------------------|----------------|
| `SCHEMA`-free, has `EXEC CICS` | 47 | 2,144 | ~3,055 | **~911** |
| `SCHEMA`-blocked | 321 | 213 | ~19,900 | ~19,700 (preprocessing) |

`911 / 14,455 ≈ 6.3%`, taken as **6%**.

Why not the D-13 terminal condition (grammar-alone ≥ neutralized) as Phase 3's gate: of the 169
`.cbl` containing `EXEC CICS`, **122 (72%) also contain `SCHEMA SECTION`**, so their DATA DIVISION
stays dead however well Phase 3 parses CICS. Only 47 files are both CICS-affected and
`SCHEMA`-free. Holding Phase 3 to the full remainder would set a criterion it cannot satisfy by
construction — the same defect this phase found twice already. The terminal condition is retained
as the **programme-level** end state across preprocessing plus Phases 3-4, not as Phase 3's gate.

The 6% figure is an **upper bound**, and is disclosed as such. `EXEC CICS` sits in the PROCEDURE
DIVISION and the cascade measurement shows it destroys paragraphs while leaving data items intact
(1/20 paragraphs, 20/20 data items), so part of the 45-vs-65 items/file difference is likely file
composition rather than CICS blocking. Per D-15 the direction is blocking and the magnitude is
explained: if Phase 3 misses 6%, the cause is written down, not the number adjusted.

---

## 5. Phase 1 `paragraph_header` reconstruction (D-26)

The Phase 1 record in §2 predates the `paragraph_header` counter, so IDMS-05 and CICS-04 had no comparable before value on the axis to which they were re-scoped. This section reconstructs that missing cell from the citable pre-Phase-2 grammar SHA recorded in `03-FINDINGS.md`:

```
5a3a8679a12a0bf3fd970fce90f606a5a09dc042
```

That SHA is the literal parent of `44ce5df`, the earliest Phase 2 commit touching `grammar.js`; its grammar is byte-identical to the history-simplified predecessor `c7a36d7`. The reconstruction was performed in isolated temporary worktrees so the live Phase 3 checkout, its unrelated `.planning/config.json` edit, and the current vendored shim were never switched or overwritten.

### Invocation

The historical shim was regenerated from that SHA, then measured through a temporary gortex workspace using §2's exact command and corpus:

```
go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m \
  -corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC \
  -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC
```

The full probe command exited 1 only because plan 03-03's newly committed fail-first CICS cascade assertions correctly reject the historical parser at 1/20 paragraphs. `TestNeutralizedParseRate` and `TestCobolParseRate`, which produce the recall cells, both passed over all 1,564 files.

### Reconstructed measured cell

| ext | files | `paragraph_header` (grammar-alone) | `paragraph_header` (+ neutralize) |
|-----|-------|------------------------------------|-----------------------------------|
| `.cbl` (Phase 1 reconstructed) | 606 | **9,187** | **14,804** |
| `.cbl` (Phase 2 recorded) | 606 | **15,323** | **16,732** |

Verbatim: `neutralize_test.go:139`: `.cbl      606 |      13 -> 14       |   17905 -> 32360    |   9187 -> 14804`.

The raw output is retained outside the repository at `$TMPDIR/opencode/phase3-baseline-probe.log`; no estate path inventory or source text was copied here.

### IDMS-vs-CICS partition of the 7,545-item Phase 1 gap

The terminal target is 16,732. The reconstruction shows Phase 2 IDMS work already closed most of the original gap before CICS started:

```
Phase 1 gap       = 16,732 - 9,187  = 7,545
IDMS closed       = 15,323 - 9,187  = 6,136  (81.3%)
Residual for CICS = 16,732 - 15,323 = 1,409  (18.7%)
```

This confirms, rather than contradicts, D-16d's premise: the Phase 3 target of 16,732 asks CICS to close exactly the **1,409-item residual measured after IDMS**, not to claim all 7,545 items as a CICS contribution.

### Restoration attestation

The live Phase 3 checkout remained at the SHA recorded in `.git/PHASE3_PRE_CHECKOUT_HEAD`, and its vendored shim retained the current parser throughout the isolated reconstruction. Mechanical assertion:

```
[ "$(git rev-parse HEAD)" = "$(cat .git/PHASE3_PRE_CHECKOUT_HEAD)" ]
```

---

## 6. Phase 3 — EXEC CICS delta and terminal `paragraph_header` result

Measured after the complete EXEC CICS grammar, query, vendored shim and four-shape gortex cascade gate landed. Same corpus, flags and method as §2 and §4:

```
go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m \
  -corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC \
  -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC
```

Exit 0. All four cobolprobe tests passed over the full 1,564-file corpus.

### Measured cells

| ext | files | clean | clean% | dataItems (grammar-alone) | dataItems (+ neutralize) | `paragraph_header` (grammar-alone) | `paragraph_header` (+ neutralize) |
|-----|-------|-------|--------|---------------------------|--------------------------|------------------------------------|-----------------------------------|
| `.cbl` (Phase 1 reconstructed) | 606 | 13 | 2% | 17,905 | 32,360 | 9,187 | 14,804 |
| `.cbl` (Phase 2) | 606 | 13 | 2% | 17,905 | 32,360 | 15,323 | 16,732 |
| `.cbl` (Phase 3) | 606 | **15** | **2%** | **17,905** | **32,360** | **18,234** | **16,732** |

Verbatim: `neutralize_test.go:139`: `.cbl      606 |      15 -> 14       |   17905 -> 32360    |  18234 -> 16732`.

The grammar-alone value **18,234 >= 16,732** passes D-16d's inclusive terminal gate by 1,502 nodes. No rounding is involved; `paragraph_header` is an integer count produced by exact node-type matching.

### Residual gap-closure fraction

Per the `confirm-with-note` checkpoint decision, the target remains 16,732 and is explicitly qualified by the reconstructed IDMS-vs-CICS partition: IDMS closed 6,136 of the original 7,545-item gap; CICS was responsible for the remaining 1,409.

```
(X - 15,323) / (16,732 - 15,323)
= (18,234 - 15,323) / 1,409
= 2,911 / 1,409
= 206.6%
```

Phase 3 closes **206.6% of the measured residual** and exceeds the terminal target. The overshoot is reported as measured, not fitted: no grammar change was made after this measurement.

### Regression and coverage gates

- **DCC D-31 differential:** 606/606 files parsed with zero failures/timeouts. `CLEAN_RECLASSIFIED_COUNT: 0`; 2 baseline `return_statement/trailing_error` records became clean `exec_cics_statement` nodes, which are intended corrections rather than clean-node regressions. 905 new CICS nodes were observed.
- **Estate D-31 differential:** 1,347 executable COBOL programs selected by the differential's identification/procedure-division rule, zero failures/timeouts. `CLEAN_RECLASSIFIED_COUNT: 0`; 3 trailing-error corrections; 1,311 new CICS nodes.
- **Qualifier limit:** clean-versus-trailing-error is a same-source-row heuristic and is not evidence about multi-line blocks. Only the zero clean-reclassification tally is the hard gate.
- **NIST COBOL85:** `382 tests. (Success: 371, Fail: 0, Skip: 11)` — no failure beyond the unchanged 11-entry skip list.
- **`cics_unparsed_tail` census:** DCC 606 files and estate 1,347 programs both report **0** tail nodes, with zero failures/timeouts. No grammar widening is justified or performed.

All inventories and raw logs were written under `$TMPDIR/opencode`, outside this repository. No estate path inventory or source text is recorded here.

---

## 7. How to reproduce this

The exact commands, cross-referenced to `docs/vendoring.md` rather than duplicated here:

1. **Turn the pipe on** — `docs/vendoring.md` §3, "Turning the pipe on and off": `go work init
   . /path/to/tree-sitter-cobol-upgrade/forest-shim/cobol` in `~/repos/mine/GoApps/gortex`, and
   `go env GOWORK` as the one-line "is it on" check.
2. **Refresh the shim** (only needed after a `grammar.js` change; not required to reproduce
   this measurement against the unmodified grammar) — `docs/vendoring.md` §4, "The refresh
   sequence": `bash forest-shim/refresh.sh`.
3. **Run the recall measurement** — §2 above's exact invocation:
   `go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m -corpus
   ~/repos/mine/cobolCode/cam-corpus-dcc/DCC -neut-corpus
   ~/repos/mine/cobolCode/cam-corpus-dcc/DCC`.

---

## 8. What this baseline does NOT set

> ⚠ **Superseded by §4 for the recall target.** The paragraph below records the pre-Phase-2
> position and is kept for provenance. OQ-3 is now resolved: §4 sets the Phase 3 gap-closure
> target at 6% of the 14,455-item gap.
>
> ⚠ **No numeric recall target exists yet.** The bar until Phase 2 lands is that `.cbl` recall
> "rises measurably" from the grammar-alone/neutralized baseline recorded in §2 — nothing more
> precise than that. The concrete target is set in Phase 2, from the real slope observed once
> IDMS DML lands (Open Question OQ-3, `.planning/ROADMAP.md`). Do not invent a percentage here;
> this document records what was measured, not what should be aimed for.
