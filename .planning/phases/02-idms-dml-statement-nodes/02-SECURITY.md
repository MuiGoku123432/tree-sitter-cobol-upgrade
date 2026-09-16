---
phase: 2
slug: idms-dml-statement-nodes
status: blocked
threats_open: 4
asvs_level: 1
created: 2026-09-16
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
| T-02-R01 | Information Disclosure | `run_accept_differential.sh` output boundary | high | mitigate | Canonicalize symlink-resolved output and scratch paths; add refusal tests | open |
| T-02-R02 | Information Disclosure | Estate commit and fixed-format guards | high | mitigate | Tracked-path and sequence-area checks run from pre-push | closed |
| T-02-R03 | Tampering / Repudiation | Differential comparison keys | high | mitigate | Reject malformed TSV and duplicate inventory keys before comparison | open |
| T-02-R04 | Repudiation | Snapshot node regex | medium | mitigate | Validate regex and propagate pipeline failures | open - below high threshold |
| T-02-R05 | Tampering | IDMS update grammar | high | mitigate | Make operand and clause shapes verb-specific; add negative corpus cases | open |
| T-02-R06 | Tampering | IDMS query contract | high | mitigate | Capture every verb field correctly, including ACCEPT; assert exact output | open |
| T-02-R07 | Tampering | READY and navigation operand roles | medium | mitigate | Distinguish area, record, and set nodes; cover documented selectors | open - below high threshold |
| T-02-R08 | Tampering | Standard versus IDMS ACCEPT | high | mitigate | Required CURRENCY tail and standard ACCEPT regression fixtures | closed |
| T-02-R09 | Tampering | Forest shim refresh | medium | mitigate | Stage artifact copies and replace atomically only after all gates pass | open - below high threshold |
| T-02-R10 | Elevation of Privilege | Fork CI workflow | low | mitigate | Read-only contents permission; no privileged pull-request trigger | closed |
| T-02-R11 | Denial of Service | Generated parser conflicts | medium | mitigate | Zero generated conflicts and no dynamic precedence path | closed |
| T-02-R12 | Repudiation | Recall and census evidence | medium | mitigate | Commands, raw measurements, arithmetic, and causes recorded | closed |
| T-02-R13 | Tampering | Planning-roadmap rewrite | medium | mitigate | All phase sections and progress rows preserved | closed |
| T-02-R14 | Supply-chain Tampering | Pinned parser dependencies | low | accept | Record an explicit accepted-risk entry if retained | open - below high threshold |
| T-02-R15 | Repudiation | Differential/query CI coverage | low | mitigate | Run differential self-test and exact query/shim checks in CI | open - below high threshold |

Only open threats at or above the configured `high` threshold count toward `threats_open`.

## Blocking Evidence

- **T-02-R01:** An external symlink targeting this repository bypassed the inventory-output
  boundary for both `snapshot` and `run`, allowing proprietary path inventories to be written
  into the public working tree.
- **T-02-R03:** Conflicting duplicate inventory keys overwrote prior map values and produced a
  false `RECLASSIFIED_COUNT: 0` verdict.
- **T-02-R05:** Invalid update-verb operand combinations parsed as clean named nodes and could
  create semantically false record/set graph edges.
- **T-02-R06:** Update and session query patterns omitted verb captures, while ACCEPT labeled the
  whole statement as `@verb` rather than the verb token.

## Accepted Risks Log

No accepted risks. T-02-R14 remains open below the blocking threshold until explicitly accepted
or mitigated.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-16 | 15 | 6 | 9 (4 blocking) | GSD security auditor |

## Verification Executed

- Existing differential and estate-guard self-tests
- Parser generation and focused IDMS corpus tests
- Full non-comment corpus suite
- NIST COBOL-85 suite: 371 success, 0 failure, 11 skipped
- Shim source/query comparison and Go smoke tests
- Gortex enhanced-parser cascade test
- Synthetic symlink, duplicate-key, malformed-regex, invalid-grammar, semantic-role, and failed-refresh probes

## Sign-Off

- [x] All threats have a disposition
- [ ] Accepted risks documented
- [ ] `threats_open: 0` confirmed
- [ ] `status: verified` set in frontmatter

**Approval:** blocked pending four high-severity mitigations
