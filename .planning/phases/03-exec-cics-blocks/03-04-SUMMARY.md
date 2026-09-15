---
phase: 03-exec-cics-blocks
plan: 04
subsystem: measurement
tags: [cobolprobe, paragraph-header, differential, nist, baseline]

requires:
  - phase: 03-exec-cics-blocks
    provides: "03-01 through 03-03 grammar, query, vendored parser and cascade gate"
provides:
  - "Reconstructed Phase 1 paragraph_header baseline of 9,187"
  - "Phase 3 grammar-alone paragraph_header measurement of 18,234 against target 16,732"
  - "Zero clean reclassifications on DCC and estate"
  - "Green NIST regression at 371 success, 0 fail, 11 skip"
  - "Zero cics_unparsed_tail census on DCC and estate"
  - "Closed IDMS-05 and CICS-01 through CICS-06"
affects: [phase-4-exec-sql]

actuals:
  tokens: 65000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Compile parser-specific inventory helpers to avoid tree-sitter CLI grammar-name cache contamination"
    - "Use isolated worktrees for historical measurement when the live checkout contains unrelated changes"

key-files:
  created: []
  modified:
    - docs/baseline.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/phases/03-exec-cics-blocks/03-FINDINGS.md

key-decisions:
  - "Confirmed D-16d with an explicit partition qualifier: IDMS closed 6,136; CICS was responsible for the remaining 1,409."
  - "Count only clean baseline-node type loss/change as D-31 reclassification; disclose trailing-error corrections separately."
  - "Use compiled C helpers rather than CLI snapshots after proving the CLI's grammar-name cache contaminated the first comparison."

requirements-completed: [CICS-04, CICS-05, CICS-06, IDMS-05]

coverage:
  - id: D1
    description: "Phase 1 paragraph_header baseline reconstructed and partitioned"
    requirement: IDMS-05
    verification:
      - kind: integration
        ref: "docs/baseline.md §5; raw neutralize line 9187 -> 14804"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase 3 exceeds the inclusive terminal paragraph_header target"
    requirement: CICS-04
    verification:
      - kind: integration
        ref: "docs/baseline.md §6; 18,234 >= 16,732"
        status: pass
    human_judgment: false
  - id: D3
    description: "DCC and estate retain every clean READ/WRITE/DELETE/RETURN node"
    requirement: CICS-05
    verification:
      - kind: integration
        ref: "03-FINDINGS.md Finding 4; CLEAN_RECLASSIFIED_COUNT: 0 on both populations"
        status: pass
    human_judgment: false
  - id: D4
    description: "NIST and corpus regression suites remain green"
    requirement: CICS-05
    verification:
      - kind: integration
        ref: "382 tests (371 success, 0 fail, 11 skip); tree-sitter corpus exit 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "No cics_unparsed_tail nodes remain on either measured population"
    requirement: CICS-06
    verification:
      - kind: integration
        ref: "DCC 606 files = 0 tails; estate 1,347 programs = 0 tails"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-11
status: complete
---

# Phase 3 Plan 04: Measurement and Closeout Summary

**Phase 3 reaches 18,234 grammar-alone paragraph headers, exceeding the inclusive 16,732 terminal target by 1,502 while preserving every clean colliding COBOL statement across both measured populations.**

## Accomplishments

- Reconstructed the missing Phase 1 `paragraph_header` baseline at **9,187** from pre-Phase-2 SHA `5a3a8679a12a0bf3fd970fce90f606a5a09dc042`.
- Partitioned the original 7,545-item gap: IDMS closed 6,136 (81.3%); 1,409 (18.7%) remained for CICS.
- Recorded checkpoint decision `confirm-with-note`: retain 16,732 and explicitly qualify it with that partition.
- Measured Phase 3 at **18,234**, passing by 1,502 and closing 2,911 / 1,409 = **206.6%** of the residual.
- Proved zero clean reclassifications on DCC (606 files) and estate executable programs (1,347 files).
- Kept NIST at **382 tests: 371 success, 0 fail, 11 skip**.
- Measured zero `cics_unparsed_tail` nodes on both populations.
- Closed IDMS-05 and CICS-01 through CICS-06 with artifact/command evidence.

## Task Commits

1. **Task 1: reconstruct Phase 1 baseline** — `067c2f9` (docs)
2. **Task 2: record Phase 3 recall and regressions** — `35d7651` (docs)
3. **Task 3: close requirements and phase state** — this summary's planning commit

## Measurement Record

| Stage | Grammar-alone `paragraph_header` | Delta |
|-------|----------------------------------|-------|
| Phase 1 reconstructed | 9,187 | baseline |
| Phase 2 IDMS | 15,323 | +6,136 |
| Phase 3 CICS | 18,234 | +2,911 |
| Terminal target | 16,732 | passed by 1,502 |

## Differential Results

| Population | Files | Clean reclassifications | Trailing-error corrections | New CICS nodes |
|------------|-------|-------------------------|----------------------------|----------------|
| DCC | 606 | 0 | 2 | 905 |
| Estate executable programs | 1,347 | 0 | 3 | 1,311 |

The trailing-error corrections are intended: baseline `return_statement/trailing_error` nodes inside `EXEC CICS RETURN` become clean `exec_cics_statement` nodes. They are disclosed separately and are not standard-COBOL regressions. The qualifier is not evidence about multi-line blocks; only clean reclassification is the hard gate.

## Deviations

### 1. Historical reconstruction used isolated worktrees

The plan assumed a clean live worktree, but `.planning/config.json` contained an unrelated user/runtime edit. Rather than discard or stash it, the historical parser and gortex workspace were created under `$TMPDIR/opencode`. The live Phase 3 HEAD and shim never changed. This preserves the measurement contract more safely than the literal checkout sequence.

### 2. The planned CLI differential route was invalid

The tree-sitter CLI caches parsers by grammar name, not checkout path. The first DCC snapshot comparison produced an impossible baseline containing 905 `exec_cics_statement` nodes and was declared void. The existing `run_accept_differential_helper.c` was then compiled separately against historical and current parser sources and run over identical NUL-delimited path lists. This removed shared parser selection while reusing the project's inventory implementation.

### 3. The shell comparator is ACCEPT-specific

`run_accept_differential.sh compare` hard-codes `accept_statement`; it cannot enforce the wider D-31 regex despite `snapshot` accepting it. A one-off path+position+type comparison over the helper outputs counted any clean baseline node that changed type or disappeared. No parallel parser/corpus harness was created.

## Prohibition Compliance

- No grammar was re-tuned after measurement.
- No shortfall was rounded away; the phase exceeded the target.
- Every inventory and raw log remained under `$TMPDIR/opencode`, outside the repository.
- No estate source text or inventory path appears in tracked artifacts.
- Docs and planning changes remain in separate commits; no closeout commit touches grammar, generated, query, corpus, shim, gate or gortex paths.

## Verification

- Corpus: exit 0, no failures.
- Recall: 18,234 >= 16,732.
- DCC clean reclassifications: 0.
- Estate clean reclassifications: 0.
- NIST: 371 success, 0 fail, 11 skip.
- Tail census: 0 on both populations.
- Restoration marker `1b8d254` is an ancestor of current HEAD; current shim retains `exec_cics_statement`.
