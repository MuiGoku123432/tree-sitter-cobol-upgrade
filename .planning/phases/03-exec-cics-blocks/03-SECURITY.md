---
phase: 03-exec-cics-blocks
status: secured
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
threats_total: 7
threats_closed: 7
threats_open: 0
verified: 2026-09-11
---

# Phase 3 Security Verification

## Verdict

**SECURED.** All plan-authored threat mitigations are present or accepted as planned. No blocking threat remains.

## Threat Register

| Threat ID | Category | Severity | Disposition | Status | Evidence |
|-----------|----------|----------|-------------|--------|----------|
| T-03-01 | Information Disclosure | high | mitigate | CLOSED | `estate/` is excluded in `.git/info/exclude`; `run_accept_differential.sh` refuses inventory output under the repo; all fixtures and gortex injected shapes state invented/neutral naming; every differential inventory remained under `$TMPDIR/opencode`; tracked artifacts contain counts and node types only, no estate source or path inventory. |
| T-03-02 | Denial of Service / V5 | medium | mitigate | CLOSED | `cics_unparsed_tail` is `repeat1()` over a fixed atomic vocabulary, bounded by required `END_EXEC`; no scanner loop was added; boundary and malformed-tail fixtures are green; DCC and estate tail censuses both return zero. |
| T-03-03 | Shim tampering | medium | mitigate | CLOSED | `forest-shim/cobol/binding.go`, `plugin.go`, and `go.mod` were not edited; `refresh.sh` Step 5 drift check and Step 6 Go smoke build passed without `REFRESH_ALLOW_DRIFT`. |
| T-03-04 | Measurement integrity | high | mitigate | CLOSED | Historical and current parsers were isolated in temporary worktrees; `.git/PHASE3_PRE_CHECKOUT_HEAD` recorded the live head; restoration was mechanically asserted before measurement; current shim retained `exec_cics_statement`; parser-specific compiled helpers prevented CLI cache contamination. |
| T-03-05 | Repudiation | medium | mitigate | CLOSED | `docs/baseline.md` and `03-FINDINGS.md` record exact commands, integer arithmetic, raw log lines, population sizes, failures/timeouts, and comparator semantics. |
| T-03-SC | Supply chain / V14 | low | accept | CLOSED | No dependency was introduced. Refresh uses the committed lockfile via `npm ci`; the already-installed pinned CLI was used for isolated historical measurement. Accepted risk matches the PLAN registers. |
| Cross-repo gortex module integrity | low | accept | CLOSED | No Go dependency or `go.mod` change was made. `cascade_test.go` uses existing stdlib/imports, and changes were confined to that file in two atomic commits. |

## Trust Boundary Verification

### COBOL source to grammar

Malformed or unmodelled content is constrained to bounded grammar leaves. Required `END_EXEC` prevents statement swallowing. Four representative recovery shapes preserve 20/20 following paragraphs and data items in gortex.

### Proprietary estate to public fork

- `git check-ignore -v estate` confirms `.git/info/exclude` coverage.
- The differential output guard rejects repository-local inventory paths.
- DCC/estate inventories and logs were stored only under `$TMPDIR/opencode`.
- Tracked findings report aggregate counts; no source excerpt or path inventory is present.
- The pre-push estate guard remains executable.

### Historical parser to current measurement

The literal checkout sequence was replaced with safer isolated worktrees because the live checkout contained an unrelated config edit. Historical reconstruction and before/after helpers used distinct generated parser sources. The first CLI-cache-contaminated comparison was explicitly declared void and replaced; no invalid number was recorded.

## Accepted Risks

| Risk | Reason accepted |
|------|-----------------|
| Existing npm dependency chain | No new package was added; `npm ci` and committed lockfile controls are unchanged. |
| Four comma-bearing CICS arguments remain an ERROR | 4/7,971 (0.05%); verified contained with all following paragraphs surviving. Fixing it requires changing the shared upstream `integer` token, an out-of-scope blast radius. |
| D-22 program capture usually names a variable | Explicitly disclosed in query, requirements, summaries and verification; resolving variables to program edges is downstream DATA DIVISION work, not hidden parser behavior. |

## Security Audit 2026-09-11

| Metric | Count |
|--------|-------|
| Threats found | 7 |
| Closed | 7 |
| Open | 0 |

ASVS L1 grep-depth and artifact verification are sufficient because the complete threat register was authored at plan time and no threat remains open.
