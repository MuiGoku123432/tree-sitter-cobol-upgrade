# Project Research Summary

**Project:** tree-sitter-cobol-upgrade
**Milestone:** v0.26.0 Estate Parse Recovery
**Domain:** Deterministic COBOL preprocessing, source-mapped parse assessment, secure review evidence, and evidence-driven grammar recovery
**Researched:** 2026-09-17
**Confidence:** HIGH for scope, boundaries, stack, and build order; MEDIUM for thresholds and greenfield packet/signature details

## Executive Summary

v0.26.0 is an end-to-end parse-recovery reliability layer, not merely a preprocessor and not another broad grammar expansion. It must take immutable consolidated COBOL through deterministic fixed-format transformation, preserve reversible byte-level provenance, parse through the existing COBOL grammar, assess whether the recovered tree is trustworthy, route degraded results into a private review system, and use recurring evidence to drive narrowly justified grammar or preprocessing fixes. The complete 1,369-program population is the measurement spine. Process success and ERROR count are insufficient because Tree-sitter can return a superficially successful tree after a recovery cascade has discarded most graph-relevant structure.

The recommended implementation is a standalone top-level `preprocessor/` Go module. Keep transformation, source mapping, grading policy, review records, and corpus aggregation as library-first packages with a thin CLI. Keep the transformation and source-map core standard-library-only; isolate `go-tree-sitter v0.25.0` and the unchanged `forest-shim/cobol` dependency behind a parser adapter. Build in dependency order: freeze contracts and the corpus manifest, prove byte-first maps, implement fixed-format transforms, collect parse facts and grades, add deterministic records/clustering/offline packets, establish a reproducible full-estate baseline, then repair the highest-impact residual families and rerun every gate.

The main failure mode is false improvement. Trimming fixed-format input, flattening continuations, neutralizing graph-bearing syntax, counting only ERROR nodes, dropping failed files, or leaking source through an "offline" packet can all make metrics look better while making results less trustworthy. Prevent this with immutable input, append-output-and-provenance-together transforms, hard-red quality conditions, complete-denominator accounting, versioned policies and schemas, exact occurrence retention, fail-closed packet export, fresh double-run determinism checks, a frozen development/holdout policy, and same-manifest before/after comparisons that measure semantic retention as well as parser recovery.

## Locked Milestone Decisions

These choices come from `.planning/PROJECT.md` and override suggestions or ambiguities in the four research documents:

- `preprocessor/` is a standalone top-level Go module. It must not change the module identity or drop-in API of `forest-shim/cobol`.
- Scope is end to end: transform -> source map -> parse -> assess -> review -> benchmark -> classify residuals -> implement justified recovery -> rebenchmark.
- Original estate source is read-only. Transformation always produces a distinct generated buffer and separate artifacts outside the corpus and public repository.
- Mapping is byte-first and reversible by explicit provenance. No line-only maps, guessed column deltas, or silent semantic rewrites are acceptable.
- Review packets are minimized, provider-neutral, local artifacts. v0.26.0 performs no external AI/model call and adds no provider adapter.
- The authoritative benchmark denominator is exactly 1,369 compilable programs selected from 3,781 declared COBOL members. Failures and timeouts remain in that denominator.
- The current grammar and forest-shim delivery path remain authoritative. No alternate parser is introduced.
- Nodes-for-edges remains the goal. Removing recovery nodes by erasing graph-bearing statement content is not success.

## Key Findings

### Recommended Stack

Use Go 1.23 for `preprocessor/go.mod`, matching the minimum declared by `github.com/tree-sitter/go-tree-sitter v0.25.0`. Use the existing forest-compatible COBOL shim at module identity `github.com/alexaandru/go-sitter-forest/cobol v1.9.1`, selected locally through a workspace rather than a committed filesystem `replace`. Keep `tree-sitter-cli` at the lockfile-pinned 0.24.5 for this milestone because the measured 0.25.3 experiment provided no benefit and the generated parser already loads under the Go binding.

**Core technologies:**

- **Go 1.23:** module baseline for the library, CLI, tests, fuzzing, and benchmark runner.
- **Go standard library:** byte scanners, SHA-256, typed JSON, filesystem traversal, flags, testing, fuzzing, and atomic artifact handling. It is sufficient and minimizes audit surface.
- **`go-tree-sitter v0.25.0`:** official parser API for ERROR, MISSING, byte ranges, points, traversal, and ABI-checked language setup.
- **Existing `forest-shim/cobol`:** sole owner of generated COBOL parser/query artifacts and the forest-compatible API. It remains unchanged.
- **Existing grammar harnesses:** `tree-sitter test`, query gates, cascade tests, shim refresh/smoke checks, collision differentials, and NIST COBOL-85 remain the grammar regression net.

Do not add Cobra, Viper, a dependency-injection framework, a database, a logging framework, a browser source-map library, a test assertion framework, a generic rewrite engine, another parser, or any AI/network SDK. The only new third-party runtime dependency should be `go-tree-sitter`; the existing shim is the grammar delivery dependency.

### Required Product Capabilities

**Must have:**

- Deterministic fixed-format preprocessing that respects byte zones, line endings, comments, suffix areas, and true column-7 continuation semantics.
- Exact Endevor `-INC` recognition in the code area, deterministic rewrite to parser-legible `COPY`, preserved member/directive provenance, and explicit diagnostics for unsupported shapes.
- Narrow IDMS structural-line handling that leaves grammar-native IDMS DML, CICS, SQL, standard COBOL, and graph-bearing operands untouched.
- A versioned transformation ledger and reversible byte-first source map with explicit copy, rewrite, insertion, deletion, synthetic-anchor, and multi-piece continuation semantics.
- Tree inspection that records ERROR and MISSING separately, maps every finding to original provenance, and measures retained divisions, data items, paragraphs, and graph-bearing captures.
- A pure, versioned green/amber/red grading policy with ordered reason codes and non-compensable red gates.
- Immutable per-file occurrence records, deterministic exact-signature clusters, and lifecycle/disposition data that never deduplicate away observations.
- Provider-neutral, allowlisted, minimized review packets that work offline and cannot contain raw estate source, names, paths, literals, comments, or reconstructable source maps.
- A frozen, reconciled 1,369-program benchmark with paired before/after comparison, complete failure accounting, reproducibility checks, and separate parse-trust and semantic-retention axes.
- An evidence-driven recovery loop that classifies each important cluster before changing code, fixes preprocessing/map defects before grammar, and admits only generic grammar changes backed by invented fixtures and existing regression gates.

**Should have within v0.26.0:**

- Regrading from stored parse facts without reparsing when only the policy changes.
- Stable cluster lineage across versions as resolved, persistent, split, merged, or new, once signature v1 is stable.
- Single-worker reference execution plus bounded parallel execution that emits byte-identical canonical records.
- Content-addressed private records and deterministic manifests, with noncanonical performance timing kept outside identity hashes.

**Defer:**

- Approximate, embedding-based, or model-based clustering.
- Provider invocation, prompt orchestration, RAG, agents, vector stores, or automatic patching.
- UI, dashboard, ticketing, notifications, or a multi-user review service.
- Generalized site-macro processing, universal conditional compilation, remote include retrieval, and arbitrary recursive COPY expansion.
- A full SQL grammar, `EXEC DLI`, alternate parser adoption, or broad low-volume grammar-tail work.
- Production Gortex extractor adoption. v0.26.0 proves the source-mapped shim-backed pipeline and leaves a stable parser-neutral seam for a later Gortex integration.

### Recommended Architecture

Use a functional core and imperative shell. Transformation, map validation/projection, fact collection, grading, signature generation, and packet shaping should be deterministic functions over typed values. File discovery, parser construction, timeouts, permissions, and atomic writes belong in adapters and the CLI.

```text
read-only source bytes
  -> transform pipeline + transformation ledger
  -> generated bytes + composed source map
  -> injected Tree-sitter COBOL parser adapter
  -> parse snapshot: ERROR/MISSING + retained structure
  -> mapped assessment facts + versioned grade/reasons
  -> immutable occurrence record
  -> deterministic structural cluster
  -> private benchmark aggregate and minimized offline packet
  -> owner classification and synthetic fixture
  -> preprocessor or generic grammar fix
  -> full same-manifest differential and regression gates
```

**Recommended module layout:**

```text
preprocessor/
  go.mod
  cmd/cobol-preprocess/   # transform, grade, corpus, compare, verify wiring
  sourcemap/              # spans, origin pieces, composition, lookup, validation
  transform/              # fixed format, continuation, -INC, IDMS, pipeline
  quality/                # parser-neutral snapshots, facts, policy, grades
  review/                 # occurrences, signatures, clusters, packets
  corpus/                 # manifest, deterministic runner, aggregation, compare
  internal/cobolfmt/      # byte-zone and newline primitives
  internal/tsadapter/     # go-tree-sitter + forest shim integration only
```

**Dependency direction:**

```text
cmd -> corpus
corpus -> transform + quality + review + internal/tsadapter
transform -> sourcemap
quality -> sourcemap + parser-neutral observation types
review -> quality + approved provenance summaries
internal/tsadapter -> quality + go-tree-sitter + forest-shim/cobol
forest-shim/cobol -> neither preprocessor nor benchmark code
```

The pure core is Go and standard-library-only; the Tree-sitter adapter is the isolated CGO boundary. The public contracts must not depend on Gortex internals. A future consumer can inject a parser and must keep generated bytes, parse tree, source map, original identity, and assessment together for the tree's lifetime.

### Reconciled Design Decisions

| Research tension | Decision for v0.26.0 |
|---|---|
| "Pure Go module" versus Tree-sitter/CGO integration | Keep `sourcemap`, `transform`, policy, and record logic pure Go. Isolate CGO and the two parser dependencies in `internal/tsadapter`; do not pretend the whole executable is CGO-free. |
| `cmd/estate-bench` versus `cmd/cobol-preprocess` | Ship one thin `cobol-preprocess` command with `transform`, `grade`, `corpus`, `compare`, and `verify` subcommands. This avoids two competing CLIs while covering the end-to-end workflow. |
| Gap-free generated map versus explicit deletions | Generated segments cover every generated byte using copy/rewrite/insert semantics. Deleted original spans live in the same versioned provenance model as zero-generated-width ledger entries. Both directions return explicit zero/one/many results rather than invented coordinates. |
| Single original interval versus continuation/include multi-origin mappings | A generated range may return ordered original `pieces`; exactness is true only for one-to-one copied bytes. The required `-INC` behavior is exact code-area rewrite to `COPY` with provenance, not ambient recursive expansion. If a later explicit catalog expansion is enabled, source identity and cycle/missing diagnostics become mandatory. |
| Green may contain a bounded diagnostic versus zero-recovery green | Policy v1 starts conservatively: green requires zero ERROR and MISSING plus retained required structure and exact graph-bearing mappings. A future version may admit a specifically proven contained diagnostic, but only through a new policy version and pinned negative/positive tests. |
| Benchmark timings required versus canonical determinism | Record timing distributions as clearly noncanonical run metadata. Never include elapsed time, host, temp paths, or timestamps in content-addressed identities or byte-equality checks. |
| Path/content hashes in local records versus packet privacy | Private local records may keep content hashes and a separately protected path sidecar. Export packets use opaque IDs, preferably keyed HMAC when stable cross-run linkage is required, and omit raw path hashes/source hashes unless an explicit declassification policy approves them. |
| Full-estate discovery versus honest acceptance | Freeze the 1,369-entry manifest and a deterministic development/holdout partition before detailed failure mining. Use development clusters for iteration; keep holdout details sealed until the milestone acceptance run. Final reporting still reconciles all 1,369 programs. |

### Source-Map Contract

The map is the load-bearing contract and must be settled before transformation breadth:

- Coordinates are unsigned byte offsets and half-open ranges. Tree-sitter rows/columns are zero-based byte coordinates; one-based COBOL display columns are derived only at presentation boundaries.
- Ordered generated segments cover `[0, generated_size)` exactly, never overlap, and are bounded by the output hash/size.
- Copy segments have equal source/generated lengths and support exact offset translation.
- Rewrite segments retain all contributing original pieces but do not claim character-level identity. Boundary bias is explicit and tested.
- Inserted text maps to an original boundary anchor and is marked synthetic. Deleted source remains in the transformation ledger and has no generated image.
- Continuation joins return every contributing original piece. A bounding box alone is not a reversible answer.
- Generated-to-original lookup is mandatory. Original-to-generated lookup is set-valued and must distinguish exact image, rewritten image, multiple images, and no image.
- Row/column is derived from precomputed line-start indexes over exact original/generated bytes. It is not maintained as an independently mutable map.
- Every transformation emits bytes and provenance in the same builder operation. Post-hoc reconstruction from regex replacements is prohibited.
- Every map carries schema/policy versions and exact input/output SHA-256 values and validates before serialization.

### Quality and Review Contract

Tree-sitter parse success is only an observation. Assessment must persist raw facts independently of the grade so policy revisions are auditable and can be replayed.

- **Green v1:** parse completed; map valid; zero ERROR/MISSING; expected program/division anchors survive; graph-bearing captures have exact original provenance.
- **Amber:** a returned tree has localized recovery or an explicit unresolved transform condition, but substantial unaffected structure remains and every trusted capture is outside affected provenance.
- **Red:** timeout/no tree/parser failure; invalid or incomplete map; nondeterminism; missing required anchors; division-scale recovery; retained data-item/paragraph collapse; graph-bearing overlap/loss; or unbounded transformation provenance.

Review storage has two levels. An occurrence is immutable and includes source/tool/config identities, facts, grade/reasons, mapped evidence, and transform summaries. A cluster is a deterministic view over occurrences using a versioned sanitized structural signature. Clustering must preserve counts and severity distributions; it must never overwrite an occurrence. Packet export consumes only an allowlisted cluster/assessment DTO, never raw source, a Tree-sitter node, or an internal object that is redacted after serialization.

### Critical Pitfalls

1. **Treating fixed-format COBOL as trimmed text** -- scan byte zones first; test columns 1-6, 7, 8-72, and 73-80, plus tabs, UTF-8, CRLF/LF, short lines, and no-final-newline cases.
2. **Flattening continuations before lexical classification** -- only column-7 continuation markers invoke continuation logic, and joined tokens retain all source pieces. Ordinary multiline CICS/SQL must remain unchanged.
3. **Calling a line map reversible** -- require total generated-byte coverage, explicit exactness, half-open boundaries, inversion behavior, and property/fuzz tests at every edit boundary.
4. **Over-broad `-INC` or IDMS rewriting** -- recognize complete code-area forms, preserve suffix/provenance, emit diagnostics for near misses, and prove IDMS DML/CICS/SQL/standard COBOL captures do not fall.
5. **Grading by ERROR count or process status** -- use recovery span/coverage, required anchors, retained structures, graph overlap, map validity, and hard-red conditions. Good totals never compensate for a catastrophic failure.
6. **Deduplicating away evidence** -- retain immutable occurrences and make clustering a versioned projection. Reject duplicate IDs and incompatible signature collisions.
7. **Leaking proprietary data through local packets or paths** -- use allowlisted packet construction, synthetic token-class evidence, keyed pseudonyms, symlink-safe external roots, restrictive permissions, and canary leak tests.
8. **Nondeterministic or incomparable benchmark runs** -- freeze manifest/toolchain/policies, isolate parser instances and scratch, sort every collection, count all outcomes, and run twice from fresh state.
9. **Overfitting the 1,369-program estate** -- lock a development/holdout policy before examining detailed residuals and use invented fixtures rather than estate-derived examples.
10. **Trusting existing harnesses beyond their scope** -- retain them, but do not claim NIST exit success or stable node types prove semantic roles, child structure, or source-map correctness.

## Requirements Implications

The roadmap should turn the following into checkable requirements, not implementation notes:

| Contract | Requirement implication |
|---|---|
| Immutable source | Library accepts borrowed bytes and returns a non-aliasing generated buffer. Commands open input read-only and reject any output root inside the corpus or public repository after canonical/symlink resolution. |
| Deterministic transformation | Identical input/config/tool versions produce identical generated bytes, maps, ledgers, diagnostics, IDs, and canonical JSON regardless of discovery order. Parallel execution cannot change canonical output. |
| Fixed-format semantics | Byte-zone policy is explicit and versioned. No trimming, tab expansion, locale-dependent casing, or suffix deletion occurs implicitly. |
| Named transforms | Every non-identity change has a stable rule ID/version, reason, original pieces, generated range or deletion marker, and before/after hash linkage. |
| Reversible provenance | Every generated byte and boundary is covered. Every diagnostic resolves to exact pieces, approximate pieces, or an explicit synthetic anchor. No caller receives a guessed original coordinate. |
| Parser facts | ERROR and MISSING are separate; all children are traversed; root coverage, span/line coverage, anchors, retained structures, graph-bearing captures, and transform interactions are persisted. |
| Versioned grading | Grade is pure over persisted facts and a policy ID. Hard-red reasons cannot be averaged away. Reason codes and raw metrics accompany every grade. |
| Review evidence | Every amber/red file yields one immutable occurrence. Exact signature grouping is deterministic and occurrence totals always reconcile. State transitions close history rather than erase it. |
| Packet safety | Export is opt-in, offline, schema-allowlisted, size-bounded, path-safe, and free of prohibited fields/content. Failure to prove safety blocks export. |
| Benchmark integrity | Manifest membership, tool/config/parser/policy/signature versions, and every per-file outcome are recorded. Missing, unreadable, timeout, transform, map, parser, and write failures are first-class outcomes. |
| Differential integrity | Baseline and candidate use the same bytes, parser lineage, manifest, and frozen policy or are declared incomparable. Report every grade transition, retention change, mapped diagnostic change, timeout, and cluster transition. |
| Recovery ownership | Each residual is classified as preprocessor, map, include/catalog, grammar, malformed input, accepted degradation, or infrastructure before a fix is proposed. |
| Grammar promotion | A grammar candidate needs affected-program count, structural/graph impact, correct preprocessing/map evidence, an invented minimal fixture, expected benchmark movement, and all existing gates. |
| Privacy | Canonical/repository-safe artifacts contain aggregate counts, hashes, normalized signatures, and synthetic evidence only. Raw and transformed source remain equally confidential. |

## Measurable Acceptance Gates

These gates should appear in requirements and phase verification. A phase is not complete on narrative assurance alone.

### Module and input safety

- `preprocessor/go.mod` declares Go 1.23; the shim module path/API and generated-artifact ownership remain unchanged.
- Identity transformation returns bytes equal to input but with distinct backing storage; the input SHA-256 and caller buffer remain unchanged after every test and fuzz case.
- Input/output aliasing and artifact roots under the corpus or public repository, including symlink traversal, are rejected.
- Canonical files are written with restrictive permissions and atomically; interrupted or failed writes cannot leave mixed-run artifacts.

### Transformation and mapping

- The synthetic matrix covers every fixed-format boundary, `*`/`/`/`-` indicators, comments, literals, blank/short lines, columns 72/73/80, tabs, UTF-8, CRLF/LF, and missing final newline.
- Positive and near-miss fixtures prove `-INC` rewrites only the exact code-area form, preserves the 73-80 suffix, records provenance, and never changes comments/literals.
- Positive and near-miss fixtures prove only the four assigned IDMS structural forms are neutralized; all grammar-native IDMS DML, CICS, SQL, and standard COBOL query captures remain unchanged.
- Source-map validation reports 100% generated-byte coverage, zero overlap, in-range source/output spans, exact copy lengths, and explicit anchors/no-image results for insertions/deletions.
- Every map property/fuzz run proves deterministic output, no panic, valid composition, boundary-bias behavior, and exact copy round trips across arbitrary bytes and truncation at key columns.
- Every non-identity output segment and every deleted source span references a stable transform rule. There are zero silent edits.

### Parse facts and grading

- The adapter fails closed on language ABI mismatch, distinguishes no-tree/timeout from an error-bearing tree, and traverses anonymous as well as named children.
- Every ERROR and MISSING is retained separately and receives a valid original mapping classification; unclassified or silently unmapped diagnostics equal zero.
- Golden assessments pin required anchors, recovery coverage, maximum span, retained data-item/paragraph counts, graph-bearing captures, map exactness, grades, and ordered reason codes.
- Synthetic cascade controls modeled on the known low-error/high-loss cases grade red when required structure collapses, regardless of low ERROR count.
- Timeout, no tree, invalid map, missing required anchors, or lost/unmapped graph-bearing captures always grade red.
- Regrading identical facts with an identical policy emits byte-identical results; changing thresholds requires a new policy version.

### Records, clustering, and packets

- One occurrence is persisted for every amber/red program outcome. The sum of cluster occurrence counts equals the number of degraded occurrences, with no overwrite or unexplained duplicate.
- Input-order and worker-order permutations produce identical occurrence IDs, signatures, cluster IDs, representative selection, counts, manifests, and packet bytes.
- Signature changes require a new signature version and explicit split/merge/new/resolved lineage.
- Packet schema validation passes offline with no credentials or network. Source code contains no provider/model SDK or send path.
- Canary values placed in synthetic paths, member names, identifiers, literals, comments, sequence areas, environment values, stdout/stderr, and temp files have zero occurrences in exported packets and repository-safe reports.
- Packets contain no raw/transformed source, absolute/relative estate paths, member names, business identifiers, comments, literals, arbitrary AST text, credentials, or reconstructable detailed source map.
- Packet output under the repository/corpus or through a symlink is rejected; failed validation emits no packet.

### Full benchmark and recovery

- Preflight reconciles exactly 3,781 declared COBOL members and exactly 1,369 compilable programs with a stable membership digest. A changed count or digest requires an explicit manifest-version decision.
- Every one of the 1,369 entries ends in exactly one recorded outcome. There are no silent skips; incomplete denominator makes the run fail.
- Two fresh same-version runs produce byte-identical canonical transformed/map/assessment/record/cluster/manifest/summary artifacts. Performance timing is reported separately and excluded from identity.
- Single-worker and approved multi-worker runs produce identical canonical bytes before parallelism becomes the default.
- Baseline and candidate comparison is paired by opaque source identity and exposes every green/amber/red transition, timeout/failure change, ERROR/MISSING change, recovery-span change, retained-structure change, graph-capture change, map-exactness regression, and cluster transition.
- A candidate cannot pass with a new hard-red outcome, a green-to-degraded transition, denominator drift, mapping regression, or graph-bearing retention loss under the frozen comparison policy.
- Selected recovery work demonstrates reduction/resolution of its target recurring signature and stable or improved retained structure on development and sealed holdout results. If no generic grammar candidate remains, the evidence must show classification and stop conditions rather than forcing a speculative grammar widening.
- Every grammar change passes generated-parser checks, all 149 non-comment corpus assertions, exact query/cascade contracts, shim refresh/smoke and collision differentials, and NIST's exact 371 success / 0 failure / 11 named skips. The known legacy comment fixture remains disclosed rather than silently reclassified.

No performance SLO is invented for v0.26.0. Record stage timing and resource failures in the first baseline, then set a later threshold only from measured evidence.

## Implications for Roadmap

### Phase 1: Contract Freeze, Module Skeleton, and Corpus Controls

**Rationale:** Deterministic identities, immutable I/O, source/privacy boundaries, and the benchmark population must be fixed before transform code or failure mining can create incomparable evidence.

**Delivers:**

- Top-level Go 1.23 module and one thin CLI shell.
- Immutable `Document` contract, policy/schema fingerprints, canonical JSON/hash rules, parser-neutral interface, and package boundaries.
- Frozen 1,369-entry manifest with 3,781/1,369 reconciliation, opaque IDs, and a deterministic development/holdout partition.
- External artifact-root validation, permissions, atomic-write primitives, and a no-op corpus runner.

**Exit gate:** Two fresh no-op runs over the manifest emit byte-identical canonical identities, all entries reconcile, source hashes are unchanged, and path/symlink attacks fail closed.

**Avoids:** coding against stale planning state, benchmark leakage, mutable source, path leakage, and later identity/schema churn.

### Phase 2: Byte-First Source-Map Kernel and Fixed-Format Model

**Rationale:** Every later transform, diagnostic, capture, packet, and graph coordinate depends on map correctness. Transformation breadth before map invariants is unsafe.

**Delivers:**

- Typed byte offsets/ranges, generated segments, origin pieces, deletion ledger entries, boundary bias, line indexes, composition, inversion, exactness, and validation.
- Fixed-format byte-zone classifier shared by transforms, with explicit newline and source-format policy.
- Table, property, fuzz, and golden tests for identity and boundary behavior.

**Exit gate:** 100% generated coverage and zero guessed coordinates across the full synthetic matrix; every fuzz result is deterministic and validates; scanner-zone comparison agrees on fixed-format boundaries.

**Avoids:** line-only maps, rune/display-column drift, inclusive-end errors, post-hoc provenance, and false exactness.

### Phase 3: Deterministic COBOL Transformation Pipeline

**Rationale:** Once output/provenance cannot diverge, add the narrowly authorized transform families in a fixed versioned order.

**Delivers:**

- Fixed-format interpretation, true continuation handling, exact `-INC` to `COPY` rewrite, and narrow IDMS structural neutralization.
- Ordered transformation ledger, composed map to raw input, diagnostics for unsupported/ambiguous forms, and idempotence behavior.
- No ambient recursive COPY expansion and no synthetic shell for the 1,369 compilable-program benchmark.

**Exit gate:** Exact positive/near-miss goldens, multi-piece continuation mappings, preserved suffixes, unchanged IDMS DML/CICS/SQL/standard COBOL captures, no input mutation, and byte-identical reruns.

**Avoids:** regex-global rewrites, ordinary-line flattening, content loss disguised as recovery, and site/environment-dependent include behavior.

### Phase 4: Parser Adapter, Quality Facts, and Policy v1

**Rationale:** Grading can be trusted only after generated diagnostics map back to source and retained semantic structure is measured in the same observation pass.

**Delivers:**

- Isolated shim-backed `go-tree-sitter v0.25.0` adapter with timeout/no-tree/ABI handling.
- One complete tree walk for ERROR, MISSING, anchors, retained structures, and graph-bearing node counts.
- Mapped assessment facts, deterministic signatures, conservative policy v1 semantics, ordered reason codes, and regrading support.

**Exit gate:** All diagnostic/capture mappings are classified; hard-red controls cannot be averaged away; synthetic cascade fixtures grade correctly; assessment goldens are deterministic.

**Avoids:** `HasError`/exit-status grading, anonymous/MISSING omission, transformed-coordinate leakage, and magic unversioned thresholds.

### Phase 5: Durable Review Records, Exact Clustering, and Safe Packet Export

**Rationale:** Packets and cluster prioritization need a stable assessment record. Privacy must be designed at the serialization boundary, not added after raw objects exist.

**Delivers:**

- Immutable content-addressed occurrences, lifecycle states, exact normalized signatures, deterministic clusters, impact ranking, and lineage metadata.
- Private filesystem storage outside repo/corpus with ordered single-writer commits.
- Explicit, allowlisted, size-bounded, provider-neutral packet export with synthetic token-class evidence and no network path.

**Exit gate:** Occurrence/cluster totals reconcile under adversarial duplicates and ordering permutations; canary/path/symlink/privacy tests prove zero prohibited disclosure; packet bytes and IDs are deterministic offline.

**Avoids:** overwritten findings, unstable grouping, unsalted path pseudonyms, redact-after-serialize leaks, and accidental model/provider coupling.

### Phase 6: Full Baseline, Calibration, and Differential

**Rationale:** Numeric policy thresholds and backlog priority cannot be responsibly chosen from anecdotes. They require complete same-manifest evidence after the pipeline contracts are stable.

**Delivers:**

- Two-run canonical baseline over all 1,369 programs, with development/holdout reporting boundaries preserved.
- Full distributions for grades, ERROR/MISSING spans, retained structures, mapping quality, transform prevalence, clusters, failures, and noncanonical performance.
- Calibrated/frozen policy v1 numeric thresholds, cluster/signature v1, and same-manifest comparison command.

**Exit gate:** Complete denominator, byte-identical canonical rerun, documented threshold calibration, no hidden failures/timeouts, and a ranked owner-classification queue.

**Avoids:** changing denominators, parser-cache contamination, tuning metrics to look green, aggregate-only verdicts, and repeated holdout inspection.

### Phase 7: Evidence-Driven Recovery and Rebenchmark

**Rationale:** Grammar work before preprocessing/mapping evidence stabilizes risks solving the wrong layer. Residual concentration and structural impact should choose the work.

**Delivers:**

- Ownership classification for high-impact clusters.
- Preprocessor/map corrections first, followed by only generic grammar candidates with hand-written minimal fixtures.
- Separately delivered grammar changes, refreshed shim, updated cluster lineage, and final paired development/holdout/full-estate differential.

**Exit gate:** Target signatures and structural loss improve without new hard-red, mapping, retention, corpus/query/cascade, shim, differential, NIST, privacy, or denominator regressions.

**Avoids:** broad grammar widening, estate-derived fixtures, automatic patches, low-value singleton chasing, and claims based only on ERROR reduction.

### Phase Ordering Rationale

- Contract and manifest decisions precede evidence collection so every later artifact is comparable and privacy-safe.
- Source-map correctness precedes transform breadth because generated coordinates are otherwise unauditable.
- Transformation precedes grading because the assessment must describe the actual parser input and preserve its lineage.
- Facts precede policy, and immutable occurrences precede clusters, so grading and grouping can evolve without losing evidence.
- Stable records precede packets because export must consume minimized DTOs rather than parser/source internals.
- The complete baseline precedes grammar work because residual ownership, impact, and thresholds are empirical.
- Every recovery change closes the loop with the same manifest and the existing grammar regression net.

### Research Flags

Phases needing focused research during planning:

- **Phase 1:** choose and lock the development/holdout partition policy and exported-ID key-management policy before detailed estate inspection.
- **Phase 2:** run a focused API/design spike for multi-piece continuation ranges, rewrite boundary bias, deletion inversion, and any future multi-source catalog provenance.
- **Phase 3:** characterize observed continuation and unmatched `-INC` variants using aggregate/local analysis without creating estate-derived fixtures.
- **Phase 4:** calibrate numeric red/amber boundaries from labelled synthetic controls plus development-set distributions. Hard-red semantics are already settled.
- **Phase 5:** conduct an explicit packet threat-model review, especially pseudonym linkage, source-substring tests, path containment, and packet usefulness without raw context.
- **Phase 6:** validate that parser instances/caches, timeouts, worker counts, and holdout handling preserve comparability before accepting the baseline.
- **Phase 7:** research each promoted residual family separately. The first benchmark, not this synthesis, determines which grammar gaps deserve work.

Phases with established implementation patterns that do not need broad technology research:

- **Phase 1 module/JSON/hash/atomic-I/O mechanics:** standard-library patterns and repository precedents are sufficient after the two policy decisions are locked.
- **Phase 5 filesystem CAS and exact grouping mechanics:** deterministic typed JSON and one ordered writer are well understood; only privacy policy needs deeper review.
- **Existing grammar regeneration/regression execution in Phase 7:** reuse the current documented harnesses rather than researching a replacement.

## Explicit Out-of-Scope Boundaries

v0.26.0 does not include:

- Any call to OpenAI, Anthropic, Azure OpenAI, a local model server, or any other external/internal model provider.
- Provider-specific prompts/messages, SDKs, credentials, RAG, embeddings, vector databases, agent loops, or automatic packet upload.
- Raw or transformed estate source in packets, review exports, logs, tests, commits, benchmark reports, or public artifacts.
- In-place preprocessing, rewriting the canonical corpus, or using generated source as if it were safe to disclose.
- A raw-source review UI, dashboard, web service, multi-user workflow, ticketing system, or notification integration.
- Compilation/execution of COBOL or semantic/type/data-flow correctness beyond parse retention and graph-bearing capture evidence.
- A universal COBOL preprocessor, complete Endevor environment, arbitrary site macros, generalized conditional compilation, remote includes, fuzzy member lookup, or ambient recursive COPY expansion.
- Full DB2 SQL parsing, `EXEC DLI`, a new parser, another grammar fork, or a second copy of generated parser artifacts.
- Approximate/embedding clustering, automatic grammar mutation, automatic PR creation, or unsupervised acceptance of generated fixes.
- Replacing existing grammar/NIST/query/differential/shim harnesses, expanding the 11-name NIST skip list, or changing the 1,369 denominator without an explicit manifest-version decision.
- Production Gortex extractor migration. The milestone delivers an importable parser-neutral contract and an end-to-end benchmark adapter; Gortex graph-store integration requires a later source-mapped COBOL extractor design.
- Broad singleton/long-tail grammar expansion with no measured generic impact.

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Stack | HIGH | Versions and APIs were checked against local module metadata/source, the existing shim, lockfile behavior, and repository harnesses. |
| Features | HIGH for mandatory behavior; MEDIUM for thresholds/lineage | Product boundaries and measured failure modes are strong. Exact grade distribution and cluster inventory do not exist until the first benchmark. |
| Architecture | HIGH for boundaries/order; MEDIUM for final public types | Shim isolation, byte coordinates, immutable flow, and dependency direction are evidence-backed. Multi-piece API ergonomics need a focused spike. |
| Pitfalls | HIGH for failure modes; MEDIUM for greenfield mitigations | Most critical hazards have concrete prior examples in repository harnesses. Packet schema, HMAC policy, and holdout operations still need validation. |

**Overall confidence:** HIGH that this architecture and build order fit the milestone; MEDIUM on empirical policy values and the quantity/type of residual grammar work.

### Gaps to Address

- **Exact grade thresholds:** freeze hard-red semantics now; derive numeric span/retention limits from labelled development evidence and version the result.
- **Continuation variants:** validate literal/token continuation behavior against scanner semantics and observed aggregate forms before finalizing transforms.
- **`-INC` residual forms:** exact rewrite is the v0.26 default; unsupported shapes need explicit diagnostics. Any catalog expansion requires a separately locked contract.
- **Source-map public shape:** prove multi-piece ranges, zero-width MISSING bias, deletion inversion, and map composition with a prototype before API freeze.
- **Pseudonym key management:** decide whether private records may use local relative paths and how a local HMAC key is provisioned/rotated for exportable stable IDs.
- **Holdout policy:** select deterministic split ratio and access rules before detailed residual mining; final totals must still cover all 1,369 programs.
- **Packet usefulness:** validate that structural/synthetic evidence is actionable without allowing raw context to leak. Privacy wins if the two conflict.
- **Residual distribution:** phase count and grammar workload within Phase 7 must remain evidence-driven; do not pre-commit to unsupported families.
- **Production Gortex integration:** later design must pair tree/generated bytes/map and project every capture before graph persistence. It is deliberately not hidden inside this milestone.
- **Published module path:** confirm the project-owned `preprocessor` module path at creation without adding a machine-specific `replace` or changing the shim identity.

## Sources

### Primary -- HIGH confidence

- `.planning/PROJECT.md` -- v0.26.0 goal, D1-D9, fixed scope, constraints, benchmark denominator, privacy, source fidelity, and regression thresholds.
- `.planning/research/STACK.md` -- Go/dependency versions, Tree-sitter APIs, map/hash/serialization approach, CLI/test recommendations, and package boundaries.
- `.planning/research/FEATURES.md` -- table stakes, grade semantics, records/clustering/packet contracts, benchmark slices, anti-features, and recovery-loop dependencies.
- `.planning/research/ARCHITECTURE.md` -- shim isolation, parser-neutral seam, immutable data flow, byte-first projection, deterministic storage, packet boundary, Gortex future seam, and phase order.
- `.planning/research/PITFALLS.md` -- observed false-positive mechanisms, fixed-format/continuation hazards, source-map and privacy failures, benchmark leakage, validation matrix, and phase warnings.
- Repository-local grammar, scanner, shim, differential, query, cascade, NIST, estate-guard, baseline, and completed phase evidence cited by the four research documents.
- Locally inspected `go-tree-sitter v0.25.0` source/tests and module metadata -- ERROR/MISSING behavior, byte/point APIs, traversal, parser setup, and Go 1.23 floor.

### Secondary -- MEDIUM confidence

- Official Tree-sitter parsing and query documentation cited by `ARCHITECTURE.md` -- byte coordinates and ERROR/MISSING semantics.
- Proposed greenfield source-map, signature, packet, holdout, and pseudonym contracts -- consistent across research but still require implementation validation.

No external AI/model call was used in the research or synthesis. No proprietary source was read or copied into this document.

---
*Research completed: 2026-09-17*
*Ready for roadmap: yes*
