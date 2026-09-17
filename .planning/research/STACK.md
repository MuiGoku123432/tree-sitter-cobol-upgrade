# Technology Stack: v0.26.0 Estate Parse Recovery

**Project:** tree-sitter-cobol-upgrade
**Milestone:** v0.26.0 Estate Parse Recovery
**Researched:** 2026-09-17
**Scope:** Stack only
**Overall confidence:** HIGH

## Recommendation

Build `preprocessor/` as an independent Go module using **Go 1.23**, the existing COBOL forest shim through a local workspace, and **`github.com/tree-sitter/go-tree-sitter v0.25.0` as the only new third-party runtime dependency**. Use the Go standard library for transforms, source maps, SHA-256 identities, JSON artifacts, CLI flags, filesystem walking, tests, fuzzing, and benchmarks.

Do not turn the preprocessor into another framework-bearing application. The domain problem is byte-accurate transformation and measurement, not dependency orchestration. A small standard-library core will be easier to audit for source fidelity, reproducibility, and proprietary-source leakage.

## Recommended Stack

### Core Go module

| Technology | Version | Purpose | Why |
|---|---:|---|---|
| Go | `1.23` directive | Preprocessor library, CLI, tests, benchmark runner | `go-tree-sitter v0.25.0` declares Go 1.23. Matching that floor avoids claiming support the parser binding does not provide. It is also compatible with the installed Go 1.27.1 toolchain. Keep `forest-shim/cobol` unchanged at Go 1.22.2 because its module identity and surface are a tested drop-in contract. |
| `github.com/tree-sitter/go-tree-sitter` | `v0.25.0` | Parse transformed COBOL and inspect quality evidence | This is the exact version used and checksum-pinned by gortex. It exposes `Node.IsError`, `Node.IsMissing`, `Node.HasError`, byte offsets, zero-based points, and complete `Range` values. Staying aligned prevents a second parser-API behavior to reconcile. |
| `github.com/alexaandru/go-sitter-forest/cobol` | local workspace module, forest-compatible identity `v1.9.1` | COBOL language pointer and embedded queries | Depend on the existing `forest-shim/cobol` module locally rather than copying parser C into `preprocessor/`. The shim already owns generated artifacts and the cgo ABI proof. Use a developer/CI `go.work` containing `./preprocessor` and `./forest-shim/cobol`; do not add a filesystem-specific `replace` to a committed `go.mod`. |

Recommended initial `preprocessor/go.mod` shape:

```go
module github.com/MuiGoku123432/tree-sitter-cobol-upgrade/preprocessor

go 1.23

require (
    github.com/alexaandru/go-sitter-forest/cobol v1.9.1
    github.com/tree-sitter/go-tree-sitter v0.25.0
)
```

The forest requirement supplies a portable module-graph identity. Local development selects this repository's shim with `go.work`, following the already-proven gortex integration pattern. The exact repository module path should be confirmed when the module is created; do not publish an accidental API commitment merely to make a local command work.

### Standard-library facilities

| Package | Purpose | Decision |
|---|---|---|
| `bytes`, `strings`, `bufio` | Byte-preserving fixed-format and continuation processing | Operate on `[]byte`; COBOL columns and Tree-sitter offsets are byte coordinates. Avoid rune-indexed transformations. Use `bufio.Reader`, not default `Scanner`, if arbitrary line length must be accepted. |
| `crypto/sha256`, `encoding/hex` | Input, transformed-output, configuration, packet, and corpus-manifest identities | Use full lowercase 64-hex SHA-256 values in persisted records. No non-standard hash is needed. Hash exact bytes and domain-separate composite identities. |
| `encoding/json` | Versioned source maps, quality reports, review packets, manifests | Use typed structs and slices. `json.Marshal` is stable for struct field order and sorts map keys, but persisted schemas should avoid maps where order carries meaning. Add exactly one trailing newline when writing files. |
| `flag` | Thin command-line interface | Enough for a small local tool. Parse flags in `cmd/cobol-preprocess`; keep behavior in importable packages. |
| `filepath`, `io/fs`, `os` | Corpus discovery and artifact I/O | Normalize recorded paths to slash-separated repository-relative names. Sort discovered paths before processing or emission. Never persist absolute estate paths. |
| `testing` | Unit, golden, fuzz, and benchmark tests | Use `go test`, table tests, `testdata/`, `Fuzz*`, and `Benchmark*`. No test framework dependency. |
| `runtime/pprof` only when diagnosing | Local profiling | Keep profiling out of the artifact schema and normal execution path. |

### Existing non-Go toolchain to retain

| Technology | Version | Purpose | Decision |
|---|---:|---|---|
| `tree-sitter-cli` | lockfile-pinned `0.24.5` under the existing `^0.24.5` manifest range | Grammar generation and corpus parsing | Do not bump it for this milestone. The project measured 0.25.3 and found no benefit; 0.24.5-generated output loads under Go Tree-sitter v0.25.0. Use `npm ci`, never a global binary or a newly resolved install. |
| Existing grammar regression tools | repository versions | `tree-sitter test`, NIST COBOL-85, query gates, shim refresh | Extend these only when residual evidence causes a grammar change. Preprocessor unit tests do not replace grammar tests. |
| Shell scripts | existing house style | Orchestrate established cross-module and corpus gates | Keep orchestration thin and portable across macOS and GNU/Linux. Put transformation and grading logic in Go, not shell. |

## Tree-sitter Go API Capability Matrix

All capabilities below are verified against the locally cached source for `go-tree-sitter v0.25.0`, tag commit `adc13ffd8b2c0b01b878fda9f7c422ce0df5fad3`.

| Need | API | Semantics and use |
|---|---|---|
| Fast clean-tree check | `root.HasError()` | Reports whether the node or any descendant contains syntax errors. Use only as a fast path; it does not replace evidence collection. |
| Explicit recovery node | `node.IsError()` | Identifies an `ERROR` node representing source that could not be incorporated into a valid tree. Record its kind and generated range. |
| Inserted recovery token/node | `node.IsMissing()` | Identifies a zero-width node inserted by Tree-sitter. Count and record it separately from `ERROR`; the current `cobolprobe` count only calls `IsError`, so it under-reports recovery. |
| Byte coordinates | `StartByte`, `EndByte`, `ByteRange` | Half-open generated byte ranges. These are the canonical coordinates for source-map lookup and hashing. |
| Human-readable coordinates | `StartPosition`, `EndPosition` | Zero-based row and column. Treat the column as a byte column for UTF-8 input; do not reinterpret it as a rune count or display-cell width. Persist byte offsets as authority and points as derived audit fields. |
| Combined evidence | `node.Range()` | Returns start/end bytes plus start/end points in one value. Convert `uint` to an explicitly sized persisted type only after checking bounds. |
| Complete traversal | `ChildCount` + `Child`, or `TreeCursor` | Walk all children, not only named children. Missing and anonymous recovery evidence can be lost if grading traverses only named grammar nodes. For 1,369 files either approach is adequate; a cursor minimizes wrapper allocation. |
| Query alternative | `(ERROR)`, `(MISSING)`, `(MISSING kind)` | v0.25.0 query tests prove ERROR and MISSING captures work. Prefer one full walk for grading because retained-structure counts and recovery evidence are needed together. |
| Parser setup | `Parser.SetLanguage` | Returns an ABI mismatch error. Unlike gortex's compatibility shim, which deliberately swallows it, the new module should call the official API directly and fail closed on this error. |
| Parse | `Parser.Parse` or `ParseWithOptions` | A returned tree may contain recovery nodes. Nil means no tree, not merely a degraded parse. Use `ParseWithOptions` only when a cancellation/progress callback is needed. Avoid deprecated `ParseCtx`, which v0.25.0 says will be removed in 0.26. |

### Quality grading implications

- A successful parse call is not a quality grade. Tree-sitter intentionally produces trees through syntax errors.
- Grade from a typed `ParseEvidence` record containing at least: parse outcome, ERROR count/ranges, MISSING count/ranges, root span, retained `program_definition`, `data_description`/`data_description_entry`, and `paragraph_header` counts, plus relevant graph-bearing statement/node counts.
- Define green/amber/red policy in project code and version it (`grading_policy_version`). Do not encode thresholds in CLI flags or infer them from the color name.
- Keep ERROR and MISSING evidence separate. MISSING nodes are often zero-width, so coalescing only overlapping ranges can silently erase them.
- Map every generated diagnostic range back through the source map before writing a review packet. If an inserted generated span has no original bytes, report an anchored insertion with left/right original boundaries instead of inventing an original span.
- Never use `HasError == false` as the sole green condition. Retained-structure floors are required because a permissive or collapsed parse can contain no ERROR while still being useless for graph extraction.

## Source-Map Representation

### Recommendation: ordered byte segments, not a VLQ/source-map library

Use a purpose-built, versioned list of non-overlapping half-open segments. Browser Source Map v3 libraries solve generated JavaScript line/column lookup, names, and VLQ compression. This project needs reversible byte spans, deletions, inserted synthetic text, fixed-column lineage, and deterministic audit JSON. A small typed representation is clearer and more correct.

```go
type Offset uint64

type Span struct {
    Start Offset `json:"start"`
    End   Offset `json:"end"`
}

type SegmentKind string

const (
    SegmentCopy    SegmentKind = "copy"      // generated bytes correspond 1:1 to original bytes
    SegmentReplace SegmentKind = "replace"   // generated and original spans correspond as a unit
    SegmentInsert  SegmentKind = "insert"    // generated bytes have an original anchor, no source span
    SegmentDelete  SegmentKind = "delete"    // original bytes omitted from generated text
)

type Segment struct {
    Kind      SegmentKind `json:"kind"`
    Generated Span        `json:"generated"`
    Original  Span        `json:"original"`
    Anchor    Offset      `json:"anchor,omitempty"`
    Rule      string      `json:"rule"`
}

type SourceMap struct {
    SchemaVersion string    `json:"schema_version"`
    InputSHA256   string    `json:"input_sha256"`
    OutputSHA256  string    `json:"output_sha256"`
    OriginalSize  Offset    `json:"original_size"`
    GeneratedSize Offset    `json:"generated_size"`
    Segments      []Segment `json:"segments"`
}
```

### Required invariants

1. Generated spans are sorted by `(start, end, kind, original.start, rule)` and never overlap.
2. Original spans are bounded by the exact input length; generated spans are bounded by exact output length.
3. `copy` spans have equal lengths and support exact offset translation.
4. `replace` spans preserve provenance but do not promise interior character identity. Interior mapping uses an explicit boundary policy, never proportional guessing hidden from callers.
5. `insert` spans map to an original boundary anchor; `delete` spans preserve original provenance even though they occupy no generated bytes.
6. Adjacent segments may be coalesced only when kind, rule, and affine mapping are identical.
7. The map validates before serialization and supports generated-to-original range mapping as the required direction. Original-to-generated lookup should also be implemented for copied/replaced material to make reversibility testable.
8. Public APIs use half-open byte intervals. Row/column lookup comes from precomputed line-start byte arrays for original and generated content.

Use `uint64` in persisted artifacts rather than architecture-sized `uint`. Tree-sitter v0.25.0 exposes `uint` but its underlying C API is `uint32_t`; validate source size before conversion instead of silently wrapping. The 697 MB estate is far below that per-file ceiling, but the invariant belongs at the boundary.

### Transform implementation

Use a monotonic emitter that appends generated bytes and emits provenance segments in the same operation. Do not perform a chain of regex replacements and attempt to reconstruct mappings afterward. A good internal primitive is conceptually:

```go
EmitCopy(originalStart, originalEnd)
EmitReplacement(originalStart, originalEnd, generated, rule)
EmitInsertion(anchor, generated, rule)
EmitDeletion(originalStart, originalEnd, rule)
```

Each preprocessing pass should consume the previous pass's mapped document and compose mappings back to the raw input. Better yet, where practical, scan once and emit final parser-ready bytes plus raw-source lineage directly. Either design must prove composition with property tests.

For fixed-format COBOL:

- Treat columns as byte positions after newline recognition.
- Preserve the original newline convention in the source record, or normalize deliberately and map each emitted newline.
- Keep sequence area provenance even if it is omitted from parser input.
- Model continuation joins explicitly. Do not label a whole joined logical line as 1:1 copied text.
- Do not rely on line-count preservation as a substitute for a source map. The existing `neutralize()` preserves newlines but loses columns and content provenance.

## Deterministic Hashing and Serialization

### Artifact format

Use schema-versioned JSON for these machine-readable records:

- one per-file transform/source-map record;
- one per-file parse-quality record;
- one minimized review packet per unique issue signature;
- one sorted corpus manifest and one aggregate benchmark summary.

Persist typed structs. Prefer arrays of typed key/value entries to semantic maps. Before marshaling:

1. normalize paths to relative slash form;
2. sort files by normalized relative path;
3. sort diagnostics by generated start byte, generated end byte, evidence kind, and node kind;
4. sort segments by their invariant order;
5. sort normalized signatures lexically;
6. exclude timestamps, temp paths, machine names, map iteration order, and elapsed wall time from content-addressed payloads.

`encoding/json.Marshal` is sufficient. It sorts map keys, but relying on that should be a fallback rather than the schema design. Use one canonical compact byte representation for hashing and optionally `MarshalIndent` only for human-readable copies. Pretty and compact forms must not acquire separate logical IDs.

### Hash rules

Use standard-library SHA-256:

```text
input_id  = sha256(raw input bytes)
output_id = sha256(transformed bytes)
config_id = sha256(canonical JSON of transform rules + schema versions)
issue_id  = sha256("cobol-review-v1\x00" + canonical normalized issue JSON)
run_id    = sha256("cobol-benchmark-v1\x00" + canonical manifest + tool/config identities)
```

- Domain-separate every composite hash with a schema/version prefix and NUL separators.
- Persist full digests. A shortened prefix is display-only.
- Hash raw bytes before JSON conversion. `encoding/json` replaces invalid UTF-8 in strings, so raw COBOL must not be embedded as a JSON string and then treated as byte-identical evidence.
- Do not hash absolute paths, modification times, process IDs, or unordered aggregate maps.
- Packet deduplication should key on normalized issue evidence, not just source file hash and not raw source text.

## Secure Review Packet Stack

Keep review packet generation offline and provider-neutral. A packet is an artifact, not a model invocation.

Recommended fields:

- schema and grading-policy versions;
- issue ID and normalized signature;
- input/output/config hashes;
- relative pseudonymous file ID (prefer a hash in exported packets);
- quality grade and aggregate metrics;
- ERROR/MISSING kinds and mapped original ranges;
- retained-structure counts;
- transformation rule IDs touching the evidence range;
- tightly bounded, redacted or synthetic context only when policy permits it.

Use an allowlist serializer: construct an export DTO containing only approved fields rather than marshaling an internal object and deleting dangerous fields later. Do not include raw source, transformed full source, absolute paths, usernames, repository roots, environment variables, or surrounding comments by default. Write locally with restrictive permissions (`0700` directories, `0600` files) and fail if an export would escape its configured output root.

No HTTP client, SDK, API key loader, prompt framework, embedding library, vector database, or provider adapter belongs in v0.26.0. A future consumer can read the versioned packet format after separate privacy and threat review.

## CLI Approach

Use one small executable, for example `preprocessor/cmd/cobol-preprocess`, with standard `flag.FlagSet` subcommands implemented without Cobra:

| Subcommand | Responsibility | Output |
|---|---|---|
| `transform` | Raw file/stdin to parser-ready bytes plus source map | Explicit output files; never overwrite input |
| `grade` | Transform, parse with local shim, and emit quality evidence | Deterministic JSON report; optional secure packet directory |
| `corpus` | Process a root or manifest in deterministic order | Per-file records plus aggregate summary and manifest |
| `verify` | Validate an existing map/artifact and hash linkage | Exit status plus concise diagnostics |

Operational rules:

- Require explicit input and output roots for estate runs; no hidden default that writes beside proprietary source.
- Refuse input/output path aliasing after `filepath.EvalSymlinks` where available.
- Send machine-readable output to stdout only when explicitly requested; diagnostics go to stderr.
- Stable exit codes should distinguish invalid invocation, transform failure, parse failure/no-tree, degraded-grade policy failure, and I/O failure.
- Accept a worker count, but emit records in sorted input order. Start with `workers=1` as the reproducibility reference and compare parallel output byte-for-byte before changing the default.
- Do not put business logic in `main`; packages should expose `Transform`, `MapRange`, `Grade`, `BuildPacket`, and `RunCorpus`-level operations.

## Test and Benchmark Approach

### Go tests

Use only the standard `testing` package.

| Test layer | What to prove |
|---|---|
| Table unit tests | Endevor `-INC`, IDMS structural suppression, fixed columns, tabs/non-ASCII policy, CRLF/LF, comments, blank lines, and continuation forms. Fixtures are invented and minimal. |
| Golden tests | Exact transformed bytes, exact source-map JSON, exact grade JSON, and exact review packet JSON under `testdata/`. |
| Round-trip/property tests | Segment ordering/non-overlap; every generated byte is mapped or explicitly synthetic; copied bytes map exactly; original/generated boundaries remain in range; map composition is associative for tested passes. |
| Fuzz tests | Arbitrary bytes, newline combinations, truncation at columns 6/7/72/73/80, continuation markers, and malformed directives. Assert no panic, deterministic output, valid maps, and source immutability. |
| Parser integration tests | Use the actual local forest shim and official v0.25.0 API. Pin examples for ERROR, MISSING, no-tree handling, mapped ranges, retained structures, and green/amber/red policy. |
| Privacy tests | Scan serialized packets for raw fixture sentinels, absolute temp paths, and disallowed fields. Prove duplicate signatures produce one packet. |
| CLI tests | Run command entry functions with in-memory or temp-dir I/O; verify exit codes and no input mutation. Use subprocess tests only where process behavior matters. |

Run routine module gates as:

```bash
cd preprocessor
go test ./...
go test -race ./...
go vet ./...
go test -run=^$ -fuzz=FuzzTransform -fuzztime=30s ./...
```

`-race` is a CI/release gate, not necessarily every edit loop. Fuzzing should have short bounded CI smoke time and longer explicit local runs.

### Corpus benchmark

Treat the 1,369-program run as a reproducible **measurement command**, not a normal unit test and not solely a Go microbenchmark:

- input is a sorted manifest of normalized relative paths plus each raw SHA-256;
- selection must reconcile to 3,781 declared members / 1,369 compilable programs using the existing estate selector semantics;
- outputs retain aggregate counts and hashed identities, not estate source excerpts;
- per-file metrics include transform rule counts, input/output bytes, ERROR/MISSING counts and covered bytes, retained structures, grade, and normalized issue IDs;
- aggregate results include grade distribution, parse/transform failures, residual signatures, and before/after comparison against a pinned baseline artifact;
- wall-clock durations may be emitted in a separate non-canonical performance section, never included in deterministic run identity;
- rerunning with the same manifest, binaries, parser, rules, and worker count must produce byte-identical canonical records.

Use `testing.B` only for focused microbenchmarks such as source-map lookup, transform throughput, and grade traversal. Run with `go test -bench . -benchmem`; do not add `benchstat` unless comparative performance becomes a release gate requiring statistical analysis.

When corpus evidence points to a grammar gap, reuse the established grammar gates: generated parser, non-comment `tree-sitter test`, exact query contracts, shim refresh, gortex cascade checks, differential checks, and NIST's exact 371 success / 0 fail / 11 skip result. Do not migrate these into a new Go harness.

## Dependency Boundaries

Recommended package boundaries inside `preprocessor/`:

```text
preprocessor/
  go.mod
  cmd/cobol-preprocess/   # flags, exit codes, wiring only
  transform/              # lexical/fixed-format transformations
  sourcemap/              # spans, composition, lookup, validation
  quality/                # Tree-sitter traversal and policy versioning
  review/                 # minimized DTO, dedup, secure local writes
  corpus/                 # sorted discovery, manifest, aggregation
```

Dependency direction:

```text
cmd -> corpus -> transform + quality + review
transform -> sourcemap
quality -> sourcemap + go-tree-sitter + forest-shim/cobol
review -> quality + sourcemap
```

Keep `sourcemap` independent from Tree-sitter so it can be fuzzed and verified without cgo. Keep `transform` independent from parser internals. Only `quality` should need the Tree-sitter and grammar modules.

## What Not to Add

| Do not add | Why |
|---|---|
| Cobra, Viper, urfave/cli, or a DI framework | Four local subcommands do not justify a framework. They increase transitive dependencies and configuration ambiguity. |
| Testify, Gomega, GoConvey, or snapshot packages | The standard `testing` package already covers tables, fuzzing, benchmarks, and golden files. Exact artifact comparisons are simple byte comparisons. |
| A generic/browser source-map library | VLQ line mappings do not naturally model deletions, replacement provenance, fixed columns, or reversible byte spans. |
| UUID dependency | Content-addressed SHA-256 IDs are deterministic and auditable; random UUIDs harm reproducibility. |
| BLAKE3/xxhash dependency | SHA-256 performance is ample for a 697 MB local corpus and already available in the standard library. Avoid two identity schemes. |
| YAML/TOML configuration | A versioned typed JSON config or explicit flags are enough. More formats create canonicalization and precedence problems. |
| SQLite, BoltDB, Badger, or a queue service | 1,369 programs and deduplicated packets fit sorted files/JSON. A database creates migration, locking, and cleanup obligations before scale requires it. |
| Logging framework | Stable stderr messages and deterministic JSON records suffice. Timestamps and structured logger metadata can contaminate reproducible artifacts. |
| Goroutine pool library | A bounded channel/worker pattern is trivial if parallelism is needed. First establish deterministic single-worker behavior. |
| Character-encoding library in this module | The input is already consolidated COBOL. EBCDIC/RDW decode belongs upstream in the retrieve/consolidate/decode stage. Do not blur pipeline ownership. |
| Regex-only rewrite engine | Regex can identify narrow forms, but chained replacements cannot safely preserve fixed columns, continuations, or composable source maps. Use an explicit byte scanner/state machine. |
| Another COBOL parser or grammar fork | Locked decision D2 and the proven forest-shim delivery path already settle parser choice. |
| A second copy of generated `parser.c` | The existing shim owns generated parser artifacts. Duplicating them in `preprocessor/` invites ABI and refresh drift. |
| `go.mod replace` with an absolute or sibling filesystem path | It breaks other checkouts and CI. Use a local `go.work`; keep committed module metadata portable. |
| External AI/model SDKs or calls | Explicitly out of scope and unsafe for proprietary estate data. Export minimized packets only. |
| Raw source in fixtures, logs, packets, benchmark artifacts, or failure output | The repository is public and the estate is proprietary. Use hand-written fixtures and hashes/aggregates. |
| Automatic grammar mutation from benchmark findings | Evidence should open a reviewed, regression-tested grammar task. Self-modifying grammar work would bypass corpus, NIST, and privacy gates. |

## Alternatives Considered

| Category | Recommended | Alternative | Why not |
|---|---|---|---|
| Go baseline | Go 1.23 | Reuse shim's 1.22.2 | Direct dependency `go-tree-sitter v0.25.0` itself requires Go 1.23. |
| Parser API | Official `go-tree-sitter v0.25.0` in `quality` | Import gortex's internal compatibility wrapper | An `internal/` package cannot be imported, and its `SetLanguage` intentionally swallows ABI errors. Recreate only the small correct usage, not the wrapper. |
| Grammar delivery | Existing forest shim via `go.work` | Copy C files or wait for forest release | Copying creates drift; waiting defeats the established same-day local delivery path. |
| Serialization | Typed canonical JSON | Protobuf/CBOR/MessagePack | JSON is inspectable, standard-library, and sufficient at this corpus size. A schema version supplies evolution without code generation. |
| Source mapping | Ordered byte segments | Browser Source Map v3 | Byte-accurate reversible transforms and deletions are the actual requirement, not JavaScript debugger interoperability. |
| CLI | `flag` plus thin dispatch | Cobra | Framework cost exceeds CLI complexity. |
| Benchmark persistence | Sorted JSON artifacts | Database | Deterministic file artifacts are easier to diff, review, secure, and reproduce. |

## Version and Installation Plan

From `preprocessor/` after creating the module:

```bash
go mod edit -go=1.23
go get github.com/tree-sitter/go-tree-sitter@v0.25.0
go get github.com/alexaandru/go-sitter-forest/cobol@v1.9.1
go mod tidy
```

For local integration, create or generate a workspace without committing machine-specific paths:

```bash
go work init ./preprocessor ./forest-shim/cobol

go test ./preprocessor/...
```

If running from inside `preprocessor/`, the equivalent is `go test ./...`. Ensure cgo and a C compiler are available because the forest shim compiles the generated COBOL parser.

Do not modify `forest-shim/cobol/go.mod`, its module path, or its mirrored Go surface as part of adding the preprocessor. Do not change `package.json` or the Tree-sitter CLI pin unless a separately measured grammar-generation need appears.

## Roadmap Implications

1. **Module and source-map kernel first** -- establish byte semantics, typed spans, validation, composition, canonical JSON, and hashing before writing transformations.
2. **Transform families second** -- implement fixed-format normalization, continuation handling, `-INC`, and IDMS structural handling against invented golden/fuzz fixtures.
3. **Parser quality third** -- wire the existing shim and official v0.25.0 API; add ERROR plus MISSING ranges, retained-structure evidence, and versioned grading policy.
4. **Secure packets fourth** -- build allowlisted minimized packets only after mapped diagnostics and stable hashes exist.
5. **Corpus runner fifth** -- run the 1,369-program deterministic manifest, then group residual signatures. Parallelism comes only after byte-identical single- versus multi-worker results.
6. **Grammar work last and evidence-driven** -- each residual family enters the already-established corpus/query/shim/cascade/differential/NIST gates.

This order is load-bearing: grading before source maps produces unreviewable generated coordinates; packet export before a privacy DTO risks source leakage; corpus concurrency before canonical ordering produces unstable evidence.

## Confidence Assessment

| Area | Confidence | Basis |
|---|---|---|
| Minimal Go dependency set | HIGH | Existing module boundaries, local module metadata, and installed Go module versions were directly inspected. |
| Tree-sitter ERROR/MISSING/range APIs | HIGH | Verified against `go-tree-sitter v0.25.0` source and tests in the local module cache. |
| Source-map structure | HIGH | Derived directly from project reversibility, byte-coordinate, and transformation requirements; no external format is required. |
| Deterministic serialization/hashing | HIGH | Uses documented standard-library behavior and avoids known nondeterministic fields. |
| CLI and test approach | HIGH | Fits existing command-style cobolprobe and repository regression patterns while keeping new logic importable. |
| Exact grade thresholds | LOW / intentionally undecided | Thresholds require corpus evidence. Stack research should define the evidence model and policy versioning, not invent green/amber/red cutoffs. |

## Sources

### Project-local evidence

- `.planning/PROJECT.md` -- v0.26.0 scope, D7-D9, privacy, placement, source-fidelity, ABI, and regression constraints. [HIGH]
- `.planning/intel/constraints.md` -- existing toolchain, test net, NIST threshold, and preprocessor ownership. Some upstreamability wording is stale; current `PROJECT.md` amendments take precedence. [HIGH]
- `forest-shim/cobol/go.mod` and `binding.go` -- isolated Go 1.22.2 drop-in module and cgo language/query surface. [HIGH]
- `forest-shim/refresh.sh` and `docs/vendoring.md` -- generated artifact ownership, local `go.work` delivery, pinned CLI findings, staging, and ABI evidence. [HIGH]
- gortex `internal/parser/forest/cobolprobe/{probe,neutralize,cascade,hypo}_test.go` and README -- current traversal, command-style corpus flags, retained-structure metrics, and line-preserving neutralization baseline. [HIGH]
- gortex `go.mod`/`go.sum` -- exact `go-tree-sitter v0.25.0`, forest COBOL v1.9.1, and checksums. [HIGH]
- gortex `internal/parser/tsitter/tsitter.go` -- current wrapper exposes ERROR/MISSING/points and uses `ParseWithOptions`; also shows why the new module should not copy its swallowed `SetLanguage` error. [HIGH]
- `.github/workflows/fork-checks.yml`, `.planning/codebase/TESTING.md`, and `docs/sql-tail-census.md` -- current CI, grammar regression approach, and secure aggregate-only estate evidence pattern. [HIGH]

### Dependency source inspected locally

- `github.com/tree-sitter/go-tree-sitter@v0.25.0/node.go` -- `HasError`, `IsError`, `IsMissing`, byte/point ranges, traversal APIs. Tag origin commit `adc13ffd8b2c0b01b878fda9f7c422ce0df5fad3`. [HIGH]
- `github.com/tree-sitter/go-tree-sitter@v0.25.0/parser.go` -- ABI-checked `SetLanguage`, parse APIs, `ParseWithOptions`, and v0.26 deprecation notices for `ParseCtx`. [HIGH]
- `github.com/tree-sitter/go-tree-sitter@v0.25.0/query_test.go` -- direct ERROR and MISSING query-capture tests. [HIGH]
- `github.com/tree-sitter/go-tree-sitter@v0.25.0/go.mod` -- Go 1.23 minimum. [HIGH]
- Go standard-library documentation from the installed Go 1.27.1 toolchain -- JSON map-key sorting, SHA-256, `flag.FlagSet`, fuzz testing. [HIGH]

No external AI calls were made. No web research was needed: the authoritative dependency source, module metadata, repository evidence, and installed standard-library documentation were available locally.
