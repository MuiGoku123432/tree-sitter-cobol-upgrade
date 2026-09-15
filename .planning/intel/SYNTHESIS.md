# Synthesis Summary

Entry point for downstream consumers (`gsd-roadmapper`). Produced by `gsd-doc-synthesizer`.

Mode: new
Date: 2026-08-28

---

## Documents ingested (1)

- SPEC — 1: `docs/spec/SPEC-001-nodes-for-edges.md` (confidence: high, manifest override: true)
- ADR — 0
- PRD — 0
- DOC — 0
- UNKNOWN — 0

Cycle detection: run on the cross-ref graph. No cycles. All 13 cross-refs point to
repos and files outside the ingest set.

---

## Decisions (4, all locked)

All four originate in SPEC §9 "Decisions already made — do not re-litigate".
Source: `docs/spec/SPEC-001-nodes-for-edges.md`

- D1 — Target is nodes-for-edges, not cascade-removal
- D2 — Build on this grammar rather than adopting another parser
- D3 — IDMS DML is a preprocessing problem AND a grammar problem; do both
- D4 — EXEC DLI is out (zero occurrences in the estate)

Detail: `.planning/intel/decisions.md`

---

## Requirements (9)

- REQ-idms-dml-nodes — 541 programs / 14,764 statements (FIRST)
- REQ-exec-cics-nodes — 221 programs / 3,539 statements (SECOND)
- REQ-exec-sql-nodes — 49 programs / 489 statements (THIRD; blocked on OQ-1)
- REQ-scope-ordering-by-volume — IDMS DML → EXEC CICS → EXEC SQL; DLI excluded
- REQ-accept-disambiguation — 634 IDMS vs 1,757 standard COBOL `ACCEPT`s
- REQ-cascade-elimination — parity with a file lacking the construct
- REQ-recall-improvement — above the 27% neutralized `.cbl` baseline
- REQ-local-vendoring-path — needs its own phase (SPEC §8)
- REQ-upstreamable-delivery — topic branch, rebased, corpus tests, no site-specific naming

Detail: `.planning/intel/requirements.md`

---

## Constraints (9, all type `nfr`)

- Upstreamability (hard constraint) — rebase, don't merge
- Fork hygiene — `.planning/` and `docs/spec/` never reach an upstream PR
- Toolchain / ABI — `tree-sitter-cli ^0.24.5` vs gortex's `go-tree-sitter v0.25.0`
- License — MIT, keep it
- Use the existing regression net; no parallel harness
- NIST COBOL-85 regression threshold — **11** known-failing (SPEC says 12; corrected)
- Corpus fixture tests must pass (13 files under `test/corpus/`)
- Standard COBOL unharmed — `ACCEPT` regression gate
- Out-of-scope list handled by preprocessing in the preprocessing repo

Detail: `.planning/intel/constraints.md`

---

## Context topics (8) + open questions (4)

Topics: what this repo is; the goal (parse vs. legible); the four-stage pipeline;
the corpus; measured recall baseline; error cascade as root cause; integration gap
with go-sitter-forest; repo state verified at ingest time. Plus a provenance note on
the SPEC's own measurements.

Open questions — explicitly NOT decisions:
- OQ-1 — EXEC SQL node granularity (blocks REQ-exec-sql-nodes; leaning opaque-plus-extraction)
- OQ-2 — does CLI 0.24.5 → 0.25.x break upstream's corpus tests (unmeasured)
- OQ-3 — concrete recall target (only "rises measurably" today)
- OQ-4 — upstream appetite for dialect support

Detail: `.planning/intel/context.md`

---

## Conflicts

- 0 blockers
- 0 competing variants
- 1 warning — `skip_tests.txt` holds 11 entries, not the 12 the SPEC's acceptance gate cites
- 10 info entries — 5 verified-true SPEC claims plus 5 handling / context notes

Detail: `.planning/INGEST-CONFLICTS.md`

---

## Files

- `.planning/intel/decisions.md`
- `.planning/intel/requirements.md`
- `.planning/intel/constraints.md`
- `.planning/intel/context.md`
- `.planning/INGEST-CONFLICTS.md`

Status: READY to route, after the single WARNING is acknowledged. The warning is a
numeric correction already applied in `constraints.md`; the SPEC itself should be
updated to match.
