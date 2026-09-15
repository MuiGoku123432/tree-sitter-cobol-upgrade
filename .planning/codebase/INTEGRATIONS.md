# External Integrations

**Analysis Date:** 2026-08-28

## APIs & External Services

**No external APIs detected.**

This project is a self-contained grammar package with no cloud, SaaS, or third-party API integrations. All functionality is local to the parser generation and compilation pipeline.

## Data Storage

**Databases:**
- None - No persistent data storage

**File Storage:**
- Local filesystem only
  - Grammar source: `grammar.js`
  - Generated artifacts: `src/parser.c`, `src/grammar.json`, `src/node-types.json`
  - Query files: `queries/sample.scm`
  - Test data: Fixtures in `test/cobol85/` (NIST COBOL85 corpus)
  - Sample files: `sample/` directory

**Caching:**
- None - No distributed or persistent caching layer

## Authentication & Identity

**Auth Provider:**
- Not applicable - No user authentication required

**Authorization:**
- Not applicable - Package-level access controlled via npm registry and Cargo.io publication

## Monitoring & Observability

**Error Tracking:**
- None - No centralized error reporting service

**Logs:**
- Console output only via:
  - `tree-sitter test` - Grammar test results
  - `run_nist_cobol85.sh` - Test suite runner (output redirected to `nist.txt`)
  - `tree-sitter parse` - Parse tree output (redirected to `out.txt` in sample script)

**Metrics:**
- None - No performance or usage metrics collection

## CI/CD & Deployment

**Hosting:**
- GitHub - Repository hosting and release management
  - Repository URL: `https://github.com/yutaro-sakamoto/tree-sitter-cobol.git`
  - Issues: `https://github.com/yutaro-sakamoto/tree-sitter-cobol/issues`

**CI Pipeline:**
- GitHub Actions (`.github/workflows/`)
  - `test.yml` - Main CI workflow (triggered on push and pull_request)
    - Runs on: `ubuntu-latest`
    - Actions used:
      - `actions/checkout@v4` - Clone repository
      - `actions/setup-node@v4` - Install Node.js environment
    - Build steps:
      1. `npm install` - Install npm dependencies
      2. `tree-sitter init-config` - Initialize tree-sitter config
      3. `tree-sitter generate` - Generate parser from grammar.js
      4. `sh run_nist_cobol85.sh` - Run NIST COBOL85 test suite
    - Commented-out: Artifact upload, opensource COBOL compilation, dependency tests

  - `check-workflows.yml` - Workflow linting (triggered as workflow_call)
    - Runs on: `ubuntu-latest`
    - External tool: `actionlint` (golang-based GitHub Actions linter)
    - Installed via: `go install github.com/rhysd/actionlint/cmd/actionlint@latest`

**Package Distribution:**
- npm Registry - Node.js package published as `tree-sitter-cobol`
- Cargo.io - Rust crate published as `tree-sitter-COBOL`
- No automated publish workflow detected in current CI; manual or separate release process

## Environment Configuration

**Required env vars:**
- None explicitly required in package.json or build scripts

**Optional env vars (implied by tools):**
- `npm_config_*` - Standard npm configuration vars
- `CARGO_*` - Standard Cargo environment vars (if building Rust bindings)

**Build Artifacts Location:**
- Node.js: `build/Release/tree_sitter_COBOL_binding` or `build/Debug/tree_sitter_COBOL_binding` (platform-specific .node binary)
- Rust: Standard Cargo output in `target/` directory

**Secrets location:**
- None - No secrets management; this is an open-source grammar package

## Webhooks & Callbacks

**Incoming:**
- GitHub webhooks (managed by GitHub Actions) - trigger test.yml on push/PR

**Outgoing:**
- None detected

## Test Data & Reference Implementations

**NIST COBOL85 Test Suite:**
- External reference: `https://www.itl.nist.gov/div897/ctg/cobol_form.htm`
- Usage: Validation corpus in CI pipeline
- Location: Downloaded and run via `run_nist_cobol85.sh`
- Output: Test results in `nist.txt` (optional artifact in commented CI step)

**OpenSource COBOL Reference:**
- External reference: `https://github.com/yutaro-sakamoto/opensource-cobol` (noted in README.md)
- Usage: Syntax rules basis; not compiled/run in current CI
- Compilation steps: Commented out in test.yml (likely for future use)

---

*Integration audit: 2026-08-28*
