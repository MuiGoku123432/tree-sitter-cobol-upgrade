---
gsd_state_version: 1.0
milestone: v0.26.0
milestone_name: Estate Parse Recovery
status: ready_to_plan
last_updated: "2026-09-17T18:00:00Z"
last_activity: 2026-09-17
progress:
  total_phases: 7
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-17)

**Core value:** Raw estate COBOL becomes a source-mapped, measurable AST whose graph-relevant identifiers remain accurate and whose degraded parses are routed for review rather than silently trusted.
**Current focus:** Phase 5 -- Pipeline Contract & Corpus Controls

## Current Position

Phase: 5 of 11 (v0.26.0 phase 1 of 7) -- Pipeline Contract & Corpus Controls
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-09-17 -- Created the v0.26.0 roadmap with 23/23 active requirements mapped

Progress: [----------] 0%

## Performance Metrics

**Current milestone:**
- Phases complete: 0/7
- Plans complete: 0/TBD
- Completion: 0%

**Prior work retained:**
- Phases 1-4 artifacts remain under `.planning/phases/`; formal v0.25.0 archive/tag closeout was intentionally skipped.
- Prior phase verification records Phase 1, Phase 2, Phase 3, and Phase 4 capabilities as complete; no prior artifact was archived or deleted.

## Accumulated Context

### Decisions

Full decisions are logged in PROJECT.md. Current milestone constraints:

- Build a standalone top-level `preprocessor/` Go module; keep `forest-shim/cobol` module identity, generated-artifact ownership, and API unchanged.
- Treat original and generated estate source as confidential; original input is read-only and artifacts stay outside the corpus and public repository.
- Use reversible byte-first source maps and complete-denominator accounting for exactly 1,369 programs from 3,781 declared members.
- Keep review packets minimized, provider-neutral, and offline; add no provider SDK, model invocation, or network path.
- Perform grammar work only after residual ownership classification and an invented synthetic reproduction.

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 5 planning must lock the development/holdout partition policy, exported-ID key policy, and published `preprocessor` module path before detailed failure mining.
- Numeric quality thresholds remain evidence-driven. Hard-red conditions are fixed, but no performance SLO or unsupported threshold may be invented.
- Continuation semantics and packet usefulness/privacy need focused adversarial validation in their owning phases.

## Deferred Items

| Category | Item | Status | Deferred To |
|----------|------|--------|-------------|
| Integration | Production Gortex source-mapped extractor adoption | Out of v0.26.0 | Future milestone |
| Review | External/internal model invocation and review UI | Out of v0.26.0 | Future milestone |
| Language | Arbitrary recursive COPY expansion and generalized site macros | Out of v0.26.0 | Future measured scope |
| Grammar | `EXEC DLI`, full SQL grammar, and unmeasured long-tail families | Out of v0.26.0 | Evidence-driven future scope |

## Session Continuity

Last session: 2026-09-17
Stopped at: v0.26.0 roadmap created; Phase 5 is ready for planning
Resume file: None
Next: `/gsd-plan-phase 5`
