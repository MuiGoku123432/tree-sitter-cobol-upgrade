---
phase: 2
slug: idms-dml-statement-nodes
status: secured
threats_open: 0
asvs_level: 1
created: 2026-09-16
verified: 2026-09-17
---

# Phase 2 - Security

> Retrospective STRIDE verification of the shipped Phase 2 implementation. Phase 2 predates
> plan-time threat registers, so this register was reconstructed from the implementation,
> plans, summaries, and adversarial tests. No proprietary estate source was read or quoted.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Estate to parser tooling | Proprietary source paths enter local census and differential tools | Confidential paths and aggregate parse records |
| Grammar to graph consumer | Named AST captures become graph-edge inputs | Record, set, area, command, and table identifiers |
| Source tree to forest shim | Generated parser and query artifacts are copied into the Go delivery module | Executable parser artifacts and query contracts |
| Repository to public remote | Pre-push controls prevent estate-derived data from leaving the machine | Public commits and push ranges |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-02-R01 | Information Disclosure | `run_accept_differential.sh` output boundary | high | mitigate | Physical canonicalization and path-aware containment; parent/final/dangling/DIFF_TMP symlink tests | closed |
| T-02-R02 | Information Disclosure | Estate commit and fixed-format guards | high | mitigate | Tracked-path and sequence-area checks run from pre-push | closed |
| T-02-R03 | Tampering / Repudiation | Differential comparison keys | high | mitigate | Strict four-column validation and duplicate-key rejection before verdicts | closed |
| T-02-R04 | Repudiation | Snapshot node regex | medium | mitigate | Validate regex before output and propagate extraction failures | closed |
| T-02-R05 | Tampering | IDMS update grammar | high | mitigate | Verb-specific syntax plus 19 negative corpus cases and zero-capture gate | closed |
| T-02-R06 | Tampering | IDMS query contract | high | mitigate | Exact token capture for all 14 verbs, including token-scoped ACCEPT | closed |
| T-02-R07 | Tampering | READY and navigation operand roles | medium | mitigate | Syntax-grounded area/set/scope nodes and exact selector coverage | closed |
| T-02-R08 | Tampering | Standard versus IDMS ACCEPT | high | mitigate | Required CURRENCY tail and standard ACCEPT regression fixtures | closed |
| T-02-R09 | Tampering | Forest shim refresh | medium | mitigate | Stage and validate a coherent artifact set before atomic installation | closed |
| T-02-R10 | Elevation of Privilege | Fork CI workflow | low | mitigate | Read-only contents permission; no privileged pull-request trigger | closed |
| T-02-R11 | Denial of Service | Generated parser conflicts | medium | mitigate | Zero generated conflicts and no dynamic precedence path | closed |
| T-02-R12 | Repudiation | Recall and census evidence | medium | mitigate | Commands, raw measurements, arithmetic, and causes recorded | closed |
| T-02-R13 | Tampering | Planning-roadmap rewrite | medium | mitigate | All phase sections and progress rows preserved | closed |
| T-02-R14 | Supply-chain Tampering | Pinned parser dependencies | low | accept | Record an explicit accepted-risk entry if retained | open - below high threshold |
| T-02-R15 | Repudiation | Differential/query CI coverage | low | mitigate | Differential, exact query, refresh, parity, and shim Go gates run in CI | closed |

Only open threats at or above the configured `high` threshold count toward `threats_open`.

## Closed Blocking Evidence

- **T-02-R01:** Physical path resolution and path-aware containment now reject parent, existing
  final, dangling-final, and DIFF_TMP symlink bypasses before output creation. All synthetic cases
  pass.
- **T-02-R03:** Both inventories are validated before comparison; malformed rows and duplicate
  keys on either side are rejected before a verdict. All orderings pass their rejection tests.
- **T-02-R05:** Update syntax is verb-specific. Nineteen negative update cases pass and the exact
  invalid-subject gate emits zero graph-bearing captures.
- **T-02-R06:** All 14 statement classes emit exact token-valued verb captures. Source and
  delivered-shim gates both pass, including six-character `ACCEPT`.

## Accepted Risks Log

No accepted risks. T-02-R14 remains open below the blocking threshold because no project-owner
acceptance has been recorded. The residual risk is limited to the pre-existing lockfile-pinned
toolchain; this phase added no dependency.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-16 | 15 | 6 | 9 (4 blocking) | GSD security auditor |
| 2026-09-17 | 15 | 14 | 1 (0 blocking) | Independent GSD security auditor |

## Verification Executed

- Differential adversarial self-test: all 34 synthetic cases passed
- Exact source and delivered-shim IDMS query gates passed
- Invalid-update gate and 61 focused IDMS corpus assertions passed
- Full non-comment corpus suite passed
- NIST COBOL-85: 371 success, 0 failure, 11 skipped
- Shim source/query identity, refresh self-test, and Go tests passed
- Gortex enhanced-parser cascade test passed through isolated target-shim GOWORK
- DCC and approved copied-estate differentials reported zero reclassifications, failures, and timeouts

## Sign-Off

- [x] All threats have a disposition
- [x] No accepted risk falsely recorded; T-02-R14 remains visibly open below threshold
- [x] `threats_open: 0` confirmed
- [x] `status: secured` set in frontmatter

**Approval:** secured at ASVS L1 with high blocking threshold; one low non-blocking risk remains open
