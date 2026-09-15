# API Coverage — Phase 1: Delivery Pipe & Measurement Baseline

No external API integration: this phase wires a local Go module, a shell refresh script and a git
pre-push hook entirely on-disk — the only network calls are `npm ci` / `npm install` against the npm
registry to fetch an already-pinned build tool, and `go` module resolution, neither of which is a
service capability surface with verbs to enumerate.

The deterministic detector (`api-coverage.cjs --json`) returned `{"detected": false, "signals": []}`
over this phase's ROADMAP section. This declaration is recorded at plan time so the seal-time gate
resolves against a written decision rather than re-running the detector over the finished PLAN
bodies.
