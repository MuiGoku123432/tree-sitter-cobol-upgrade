# Constraints

Extracted from classified source documents. One entry per constraint.

---

## Upstreamability is a hard constraint
- source: docs/spec/SPEC-001-nodes-for-edges.md (§7, §1)
- type: nfr
- content: Changes must stay rebasable onto upstream and offerable as clean PRs. Rebase, don't merge. The additions must be generic COBOL dialect support, not site-specific hacks. This is not a rewrite and not a vendor drop.
  Caveat recorded in the SPEC: `git rev-list --left-right --count upstream/main...origin/main` is only as truthful as the last `git fetch upstream` — it once read "0 behind" while 1,304 commits behind, in a sibling fork.

## Fork hygiene — planning artifacts must never reach an upstream PR
- source: docs/spec/SPEC-001-nodes-for-edges.md (§7)
- type: nfr
- content: `.planning/` and `docs/spec/` are fork-local and must never appear in an upstream PR. Grammar changes go on topic branches cut from `upstream/main`; planning lives on `main` only.

## Toolchain / ABI compatibility
- source: docs/spec/SPEC-001-nodes-for-edges.md (§7)
- type: nfr
- content: The grammar builds with `tree-sitter-cli ^0.24.5` (a devDependency — `npm install`, no global install needed). gortex runs `go-tree-sitter v0.25.0`. A CLI bump may be required to regenerate a compatible `parser.c`, and that edits upstream's own build config — verify before assuming.
- related open question: OQ-2 in context.md — whether the 0.24.5 → 0.25.x bump breaks upstream's existing corpus tests is unmeasured.

## License — MIT, keep it
- source: docs/spec/SPEC-001-nodes-for-edges.md (§7)
- type: nfr
- content: Upstream (`yutaro-sakamoto/tree-sitter-cobol`) is MIT licensed. Keep it.

## Use the existing regression net — do not invent a parallel harness
- source: docs/spec/SPEC-001-nodes-for-edges.md (§7)
- type: nfr
- content: A regression net already exists: `test/corpus/*.txt`, `run_nist_cobol85.sh`, `skip_tests.txt`, `test/check_tests.sh`. Build on it; don't invent a parallel harness.

## NIST COBOL-85 regression threshold — 11 known-failing tests
- source: docs/spec/SPEC-001-nodes-for-edges.md (§6 criterion 4, §7) — CORRECTED against repo
- type: nfr
- content: The NIST COBOL-85 suite run via `run_nist_cobol85.sh` must gain no failures beyond those already listed in `skip_tests.txt`. The authoritative count is **11** non-empty entries: NC205A, SM101A, SM103A, SM105A, SM107A, SM201A, SM203A, SM205A, SM206A, SM208A, SM401M.
- drift: The SPEC states "12" in both §6 criterion 4 and §7. This is an acceptance-gate threshold — inheriting 12 would silently permit one new NIST regression. See INGEST-CONFLICTS.md WARNING. The SPEC should be corrected to 11.

## Corpus fixture tests must pass
- source: docs/spec/SPEC-001-nodes-for-edges.md (§6 criterion 4)
- type: nfr
- content: `tree-sitter test` against the corpus fixtures must pass with no regressions. 13 corpus test files exist under `test/corpus/`.

## Standard COBOL must remain unharmed — ACCEPT regression gate
- source: docs/spec/SPEC-001-nodes-for-edges.md (§5 grammar design note, §6 criterion 5)
- type: nfr
- content: A required regression test — not an edge case — must prove that standard COBOL `ACCEPT` is unaffected by IDMS DML `ACCEPT` support. Naive verb matching finds 2,391 `ACCEPT`s in the estate; only 634 are IDMS (`ACCEPT … FROM … CURRENCY`, `… DB-KEY`), and 1,757 are standard COBOL. The grammar must disambiguate on the operand tail, never on the verb alone. An over-eager rule will silently break ordinary COBOL.

## Out of scope — handled by preprocessing in the preprocessing repo
- source: docs/spec/SPEC-001-nodes-for-edges.md (§5)
- type: nfr
- content: The following must NOT be implemented in this grammar:
  - Endevor `-INC <MEMBER>` — 837 of 1,361 programs (61%); not COBOL at all, a site include directive. Rewrite `-INC NAME` → `       COPY NAME.`, padded to col 72 with the sequence area (cols 73-80) preserved. 12,819 statements across 1,639 files; 2 unmatched.
  - `IDMS-CONTROL SECTION`, `PROTOCOL.`, `SCHEMA SECTION`, `DB x WITHIN y` — structural; the real IDMS precompiler comments these out (see locked decision D3), and a preprocessor should do the same.
  - The `site-macro` / `%`-macro site preprocessor language.
  - Anything site-specific that would make a PR unupstreamable.
