## Conflict Detection Report

Mode: new
Docs ingested: 1 (SPEC-001-nodes-for-edges.md)
Cross-doc contradictions: none possible — single source document
Cycle detection: run on the cross-ref graph; no cycles (single node, no self-reference; all 13 cross-refs point outside the ingest set)

### BLOCKERS (0)

No blockers. No LOCKED-vs-LOCKED contradictions, no UNKNOWN/low-confidence
classifications, no reference cycles, no existing `.planning/` context to
contradict (MODE=new).

### WARNINGS (1)

[WARNING] skip_tests.txt count is wrong in the SPEC
  Found: docs/spec/SPEC-001-nodes-for-edges.md §6 criterion 4 says the NIST COBOL-85 suite must gain "no failures beyond the 12 already listed in skip_tests.txt", and §7 says "skip_tests.txt (12 known-failing)". The actual file holds 11 non-empty entries: NC205A, SM101A, SM103A, SM105A, SM107A, SM201A, SM203A, SM205A, SM206A, SM208A, SM401M.
  Impact: This number is an acceptance-gate threshold. Inheriting 12 would silently permit one new NIST regression to pass the gate.
  → Recorded as 11 in .planning/intel/constraints.md ("NIST COBOL-85 regression threshold"). Correct §6 criterion 4 and §7 of the SPEC to read 11.

### INFO (10)

[INFO] Verified: grammar.js line count matches SPEC §1
  Note: grammar.js is exactly 3,783 lines, as claimed. Source: docs/spec/SPEC-001-nodes-for-edges.md §1, verified against the repo.

[INFO] Verified: embedded-language support is greenfield, per SPEC §1
  Note: grammar.js contains zero occurrences of EXEC, CICS, SQL, and DLI, as claimed. Source: docs/spec/SPEC-001-nodes-for-edges.md §1, verified against the repo.

[INFO] Verified: existing regression net is present, per SPEC §7
  Note: test/check_tests.sh exists, and 13 corpus test files exist under test/corpus/ — consistent with the SPEC's "regression net already exists". Source: docs/spec/SPEC-001-nodes-for-edges.md §7, verified against the repo.

[INFO] Verified: toolchain pin matches SPEC §7
  Note: tree-sitter-cli ^0.24.5 is a devDependency, as claimed. Source: docs/spec/SPEC-001-nodes-for-edges.md §7, verified against the repo.

[INFO] Verified: fork is at parity with upstream, per SPEC §1 and §3
  Note: the upstream remote is yutaro-sakamoto/tree-sitter-cobol; origin/main and upstream/main are both at e99dbdc with 0 ahead / 0 behind (upstream fetched 2026-08-28 13:14). This confirms the SPEC's "no version-bump win available — this is net-new grammar development." Source: docs/spec/SPEC-001-nodes-for-edges.md §1, §3, verified against the repo.

[INFO] Upstream carries a CLI 0.25.3 branch bearing on SPEC §10 open question 2
  Note: upstream has remotes/upstream/dependabot/npm_and_yarn/tree-sitter-cli-0.25.3. SPEC §10 OQ-2 asks whether the 0.24.5 → 0.25.x bump breaks upstream's existing corpus tests and records it as unmeasured. That branch may already carry evidence — check it before measuring from scratch. Source: repo verification against docs/spec/SPEC-001-nodes-for-edges.md §10.

[INFO] Local main is 1 commit ahead of upstream/main with a planning artifact
  Note: the divergence is commit 8a17d90, the .planning/codebase map. This is exactly the fork-hygiene constraint in SPEC §7 — planning artifacts live on main and must never reach an upstream PR. Grammar work must be cut onto topic branches from upstream/main. Source: docs/spec/SPEC-001-nodes-for-edges.md §7, verified against the repo.

[INFO] SPEC §9 D1-D4 recorded as LOCKED decisions
  Note: the source is typed SPEC, not ADR, so the classification's `locked` field is false by schema rule. However §9 is titled "Decisions already made — do not re-litigate" and carries four ADR-shaped decision statements with rationale. D1-D4 are recorded in .planning/intel/decisions.md with status `locked`, per the ingest handling rules. Source: docs/spec/SPEC-001-nodes-for-edges.md §9.

[INFO] SPEC §10 open questions recorded as open, not as decisions
  Note: four items are explicitly undecided — EXEC SQL node granularity (blocks REQ-exec-sql-nodes), CLI 0.24.5→0.25.x corpus impact, concrete recall target, upstream appetite. They are recorded in .planning/intel/context.md under OPEN QUESTIONS as OQ-1 through OQ-4 and must not be converted into decisions downstream without an explicit resolution step. Source: docs/spec/SPEC-001-nodes-for-edges.md §10.

[INFO] Scope ordering is deliberately counter-intuitive
  Note: in-scope ordering is IDMS DML (541 programs / 14,764 statements) → EXEC CICS (221 / 3,539) → EXEC SQL (49 / 489), with EXEC DLI excluded entirely (0 / 0, locked decision D4). The SPEC explicitly flags this as the reverse of the intuitive "EXEC CICS/SQL/DLI" framing; the ordering is derived from measured volume. Preserved verbatim in .planning/intel/requirements.md as REQ-scope-ordering-by-volume. Source: docs/spec/SPEC-001-nodes-for-edges.md §5.
