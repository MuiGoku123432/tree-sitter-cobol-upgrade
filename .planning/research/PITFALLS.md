# Domain Pitfalls: v0.26.0 Estate Parse Recovery

**Domain:** Deterministic fixed-format COBOL preprocessing, source mapping, parse-quality triage, secure review packets, and estate benchmarking
**Researched:** 2026-09-17
**Scope:** Milestone v0.26.0 only
**Evidence basis:** Repository-local project contract, parser/scanner behavior, estate-leak controls, baseline records, and existing test/differential harnesses. No paid API, web research, or external model call was used.
**Overall confidence:** HIGH for observed repository behavior; MEDIUM for proposed v0.26.0 designs that do not exist yet

## Executive Warning

This milestone can report dramatic improvement while making the output less trustworthy. Tree-sitter always returns a tree; preprocessing can erase the syntax that caused recovery cascades; a lower ERROR count can coexist with lost identifiers, wrong coordinates, or invented graph edges. The hard acceptance rule must therefore be multi-dimensional: deterministic transform, exact source-map invariants, retained graph-bearing structure, complete denominators, and before/after evidence from a frozen corpus and parser lineage.

The project already contains concrete examples of deceptive green results: four ERROR nodes coexisting with only five of 77 paragraphs; an invalid node regex producing a successful empty census before the harness was fixed; duplicate differential keys hiding reclassification; a shared Tree-sitter parser cache causing a false identical baseline/current result; and a green refresh log built from stale artifacts after generation failure before atomic staging was added. v0.26.0 should treat those as design inputs, not historical trivia.

## Critical Pitfalls

### Pitfall 1: Treating fixed-format COBOL as trimmed text

**What goes wrong:** A preprocessor trims, tab-expands, wraps, or scans whole physical lines without first applying fixed-format zones. Sequence numbers become syntax, indicator-column comments become code, content past column 72 leaks into tokens, and continuation semantics change.

**Why it happens:** Humans see visual columns; the parser and existing guard use byte positions. The current scanner treats columns 1-6 as prefix material, column 7 as the indicator, columns 8-72 as code, and column 73 onward as suffix. The estate guard deliberately runs under `LC_ALL=C` because tabs are one byte and UTF-8 characters occupy multiple bytes. A Phase 4 fixture already proved this boundary has teeth: SQL beyond column 72 became `_LINE_SUFFIX_COMMENT`, and changing the grammar would have hidden a bad fixture.

**Consequences:** Silent token loss, false comments, changed literals, broken source maps, inconsistent behavior between preprocessing and `src/scanner.c`, and misleading quality gains.

**Prevention:**
- Define offsets once as zero-based byte slices: sequence `[0:6]`, indicator `[6]`, code `[7:72]`, suffix `[72:]`.
- Normalize line endings before indexing, but never normalize tabs, Unicode, or trailing spaces before recording their byte spans.
- Preserve one output newline per original physical line unless the mapping model explicitly supports generated-only or deleted segments.
- Test short lines, exactly 72-byte lines, populated 73-80 sequence fields, tabs, UTF-8, CRLF, blank lines, `*` and `/` indicators, `-` continuations, and content crossing byte 72.
- Differential-test preprocessor output against the current scanner's zone behavior. Never “fix” the grammar or scanner merely to accommodate malformed transformed input.

**Detection / warning signs:**
- Output columns are computed with rune counts, display width, `strings.TrimSpace`, or tab stops.
- Tests use only ASCII short lines.
- A parser improvement appears only after deleting columns 73-80 or moving text left.
- Source lines or query captures end exactly at column 72 far more often after preprocessing.
- Golden output passes while a byte-for-byte zone round-trip fails.

**Confidence:** HIGH -- verified in `src/scanner.c`, `.githooks/estate-guard.sh`, its encoding self-tests, and the Phase 4 fixed-format fixture correction.

### Pitfall 2: Flattening continuations before lexical classification

**What goes wrong:** Every column-7 `-` line is concatenated mechanically, spaces are inserted or removed indiscriminately, or all multi-line statements are called continuations. COBOL continuation can continue a literal/token; ordinary wrapping at a token boundary is different.

**Why it happens:** Multi-line formatting and continuation indicators look equivalent after whitespace normalization. They are not. The estate study found 2,837 multi-line CICS blocks but zero column-7 continuation lines inside them; broad continuation logic there would solve a nonexistent case and create new behavior.

**Consequences:** Split identifiers become two tokens, separate tokens merge, quote delimiters change, periods migrate, and subsequent mappings point to synthesized text rather than either contributing physical segment.

**Prevention:**
- Parse the indicator byte before interpreting code-area content.
- Keep ordinary line wrapping as separate mapped segments; invoke token/literal continuation logic only when column 7 actually carries the continuation indicator.
- Preserve all contributing original spans for a joined token. If the map format cannot represent one generated span mapping to multiple source spans, do not flatten it in v0.26.0.
- Add metamorphic tests: preprocessing twice is byte-identical, and non-continuation multi-line CICS/SQL is unchanged apart from declared transforms.

**Detection / warning signs:**
- Continuation code is keyed on indentation or an unterminated quote alone.
- The transform inserts a space at every join.
- 2,837 ordinary multi-line CICS blocks are counted as continuation cases.
- A mapped token has only one source origin even though it crosses physical lines.

**Confidence:** HIGH for estate/scanner facts; MEDIUM for the proposed multi-origin map policy.

### Pitfall 3: Building a line map and calling it reversible

**What goes wrong:** The implementation stores only `generated line -> original line`, assumes columns are unchanged, or maps replacement text to the start of a line. `-INC` expansion and structural neutralization alter columns and byte lengths, so graph locations and review evidence drift even when line counts match.

**Why it happens:** The older `neutralize()` prototype preserved line count, which is enough for a coarse recall experiment but not for exact AST provenance. Tree-sitter exposes both byte ranges and row/column points; either can drift independently if edits are represented incompletely.

**Consequences:** Wrong editor navigation, evidence attached to adjacent identifiers, impossible inverse mapping, collisions during deduplication, and privacy redaction performed on the wrong source slice.

**Prevention:**
- Use ordered segment maps with half-open generated byte intervals and original byte intervals, plus explicit transform kind and generated-only/deleted semantics.
- Derive row/column from the exact byte buffers rather than maintaining a second independently mutated coordinate system.
- Specify that Tree-sitter rows and columns are zero-based; external COBOL columns are one-based; code-area column 8 corresponds to Tree-sitter column 7 on an unchanged line.
- Specify end coordinates as exclusive. Test boundary points immediately before, at, and after every edit.
- Require monotonic, non-overlapping, total coverage of generated bytes; map inversion must either return an exact source span or an explicit non-exact result, never a guessed coordinate.
- Property-test identity, replacements shorter/longer/equal length, CRLF, final line without newline, UTF-8, tabs, and multiple edits on one line.

**Detection / warning signs:**
- Map entries contain only line numbers.
- Code adds or subtracts a global column delta.
- Inclusive and exclusive ends are mixed.
- Tests assert transformed text but not every mapped boundary.
- Two generated bytes map backward in original order.

**Confidence:** HIGH that byte and point ranges both matter in the pinned Tree-sitter runtime and existing exact query gates; MEDIUM on the recommended segment schema.

### Pitfall 4: Losing COPY/-INC identity while making input parseable

**What goes wrong:** `-INC MEMBER` is globally regex-replaced, identifiers are uppercased or stripped, directives in comments/literals are rewritten, unmatched forms are silently dropped, or the preprocessor recursively resolves copybooks when the milestone only requires parser-ready syntax.

**Why it happens:** `-INC` is abundant and syntactically simple. The project records 12,819 statements across 1,639 files, with two unmatched cases, which tempts a broad substitution and a success metric based only on parseability.

**Consequences:** False include edges, loss of the original directive location, source-map ambiguity, accidental expansion cycles, environment-dependent output, and hidden unsupported forms.

**Prevention:**
- Recognize `-INC` only in the code area and only in the exact directive grammar; exclude comment indicators and literal content.
- Rewrite to `       COPY <member>.` while preserving the original columns 73-80 suffix as the project contract states.
- Preserve the original directive/member span in mapping metadata; distinguish rewrite from include resolution.
- Record unmatched or ambiguous directives as diagnostics and route them to review. Never silently pass them as ordinary COBOL or silently delete them.
- Do not resolve nested COPY content unless a later requirement explicitly defines search paths, cycle behavior, `REPLACING`, provenance, and duplicate member rules.

**Detection / warning signs:**
- Match counts differ from the frozen census with no explained corpus change.
- A regex searches the entire raw line or file.
- `-INC` inside a comment changes output.
- COPY expansion depends on filesystem traversal order or ambient search paths.
- The two known unmatched shapes disappear from accounting.

**Confidence:** HIGH for recorded volumes and required rewrite shape; MEDIUM for exact unmatched-form handling until current raw-estate fixtures are characterized in-phase.

### Pitfall 5: Over-neutralizing IDMS structure

**What goes wrong:** Every line containing `SCHEMA`, `PROTOCOL`, `DB`, or `SECTION` is blanked; IDMS DML statements are neutralized with structural declarations; or lines are deleted instead of converted to fixed-format comments.

**Why it happens:** `SCHEMA SECTION` is a dominant cascade source -- 321 of 606 pilot `.cbl` files have it, and those files yielded only 213 data items. A broad rule gives an immediate metric jump. But D3 separates structural precompiler artifacts from grammar-native DML precisely to avoid destroying graph-bearing operands.

**Consequences:** Standard COBOL or data names are suppressed, IDMS record/set edges vanish, source maps lose totality, and low ERROR counts falsely certify semantic destruction.

**Prevention:**
- Match complete structural forms in the correct fixed-format zone: `IDMS-CONTROL SECTION`, `PROTOCOL.`, `SCHEMA SECTION`, and `DB <subschema> WITHIN <schema>.`.
- Neutralize by replacing the indicator column with `*` or another explicitly tested compiler-equivalent comment form while preserving byte length, line count, suffix, and original map.
- Never neutralize the 14 grammar-supported IDMS DML verbs or `EXEC CICS`/`EXEC SQL` blocks.
- Maintain positive and near-miss negative fixtures, including ordinary `DB-*` names, standard `ACCEPT`, and unrelated `SECTION` headers.
- Score retained graph-bearing nodes after preprocessing; structural recovery with lost DML operands is a red result, not green.

**Detection / warning signs:**
- Neutralization is `strings.Contains` or an unanchored regex.
- Data-item recall rises while IDMS record/set captures fall.
- Transformed lines are shorter than originals or disappear.
- A file becomes “green” only because DML was changed to `CONTINUE`.

**Confidence:** HIGH -- D3, baseline attribution, and the prior `neutralize()` limitation are repository-verified.

### Pitfall 6: Grading parse quality by ERROR/MISSING count alone

**What goes wrong:** Green means zero ERROR nodes, or a weighted sum treats every error equally. A tiny early error can swallow a division, while several local errors may preserve all graph-relevant structure.

**Why it happens:** ERROR and MISSING nodes are easy to count. Tree-sitter recovery quality is positional and structural. This estate already has a 5,352-line example with four ERROR nodes but only five of 77 paragraphs, proving count is not severity.

**Consequences:** Catastrophic parses are trusted; harmless local recovery is quarantined; benchmarks optimize the wrong objective; AI review receives low-value cases.

**Prevention:**
- Calculate features separately: ERROR count and covered bytes/lines, MISSING count, earliest error by division, longest error span, root/error coverage, retained division/section/paragraph/data-item counts, expected graph-bearing captures, timeout/failure state, and source-map validity.
- Make hard-red conditions non-compensable: parser timeout/no tree, invalid or incomplete source map, loss of required divisions/anchors, or graph-bearing capture loss. A good aggregate score must not cancel these.
- Calibrate green/amber/red on hand-labelled representative files and pin thresholds as versioned benchmark configuration, not magic constants hidden in code.
- Keep raw features in audit records so a grade can be recomputed after threshold changes.
- Compare preprocessed parse to both raw parse and a declared structural expectation; do not use `neutralize()` as unquestioned truth.

**Detection / warning signs:**
- Quality is one formula with no hard gates.
- A four-error catastrophic file grades better than a ten-local-error file by construction.
- Threshold changes rewrite history without a scoring-version field.
- A green record has missing `IDENTIFICATION`, `DATA`, or `PROCEDURE DIVISION` structure.

**Confidence:** HIGH for the failure mode; MEDIUM for threshold design pending calibration data.

### Pitfall 7: Deduplicating away distinct failures

**What goes wrong:** Review records are keyed only by file hash, ERROR text, `(row,column)`, or normalized signature. Repeated cascade symptoms collapse across different root causes; conversely volatile paths or generated coordinates prevent identical failures from grouping.

**Why it happens:** Deduplication is framed as queue-size reduction instead of an evidence model. The existing differential once keyed only by path and start position; duplicate keys overwrote one another and could produce a false clean verdict.

**Consequences:** Lost occurrences and severity, unstable queue IDs, incorrect “fixed” status, inability to trace one signature across corpus/parser/preprocessor versions, or hidden source-map collisions.

**Prevention:**
- Separate immutable occurrence records from dedup groups. Never discard occurrences.
- Derive a deterministic signature from sanitized structural facts: diagnostic kind, normalized node-path/context shape, original mapped span class, transform kind(s), parser/preprocessor/scoring versions, and bounded token classes -- not raw identifiers or absolute paths.
- Store occurrence count and severity distribution per group; select a deterministic representative by stable sanitized source ID and original coordinate.
- Reject duplicate occurrence IDs and signature collisions with incompatible metadata.
- Version the normalization/signature algorithm and support regrouping without rewriting original observations.

**Detection / warning signs:**
- `map[key] = record` silently overwrites.
- Queue size falls but total affected-file/occurrence count is unavailable.
- Reruns choose a different representative.
- A source-map change merges unrelated errors at generated `(0,0)`.

**Confidence:** HIGH for overwrite/collision risk from the repaired differential; MEDIUM for the proposed review-signature fields.

### Pitfall 8: Letting proprietary evidence escape through “offline” AI packets

**What goes wrong:** No model is called, but packets contain raw lines, identifiers, relative paths, program/member names, literals, comments, sequence areas, or reversible hashes over a small namespace. They are then written under the public worktree or printed to logs.

**Why it happens:** “Provider-neutral” and “offline” are mistaken for “safe.” Existing review found a symlink bypass that wrote proprietary inventories into the repository. Existing aggregate harnesses deliberately avoid persisted paths and text because those are themselves sensitive.

**Consequences:** Permanent Git objects, CI/log disclosure, easy dictionary attacks on member names, and future accidental upload of packets designed for a provider.

**Prevention:**
- Define a packet schema with an allowlist, not a redact-afterward denylist. Default fields should be opaque source ID, versioned signature, aggregate metrics, node kinds, transform kinds, coarse/relative positions, and synthetic minimized reproducer only.
- Generate synthetic context from token/node classes; do not “redact” raw source by replacing a few identifiers.
- Use keyed HMAC with a local secret for stable private pseudonyms if cross-run linkage is required; plain SHA-256 of member names is not anonymization.
- Canonicalize output directories and final paths through symlinks, reject anything under the repository, create with restrictive permissions, write atomically, and clean scratch on success, failure, INT, and TERM while preserving the original status.
- Keep packet creation separate from provider invocation. v0.26.0 must contain no network/model client and no auto-send path.
- Add canary tests containing synthetic secrets in names, strings, comments, paths, and sequence fields; assert none occur in packets, stdout, stderr, tracked reports, or temp leftovers.

**Detection / warning signs:**
- Packet JSON has fields named `source`, `snippet`, `path`, `member`, or `literal` without a documented safety proof.
- Hashes are unsalted/unkeyed.
- `--output` accepts a symlink into the repo.
- Debug mode prints raw context.
- A packet can reconstruct an original line exactly.

**Confidence:** HIGH for local leak paths and required policy; MEDIUM for packet schema until implemented.

### Pitfall 9: Non-deterministic preprocessing or benchmark output

**What goes wrong:** Map iteration, parallel workers, filesystem walk order, timestamps, temp paths, locale-sensitive sorting/casing, environment-dependent COPY lookup, or stale parser caches alter output and queue ordering between runs.

**Why it happens:** Aggregate counts may remain stable, masking byte-level differences. The existing harnesses explicitly sort inventories, pin `LC_ALL=C` where byte semantics matter, use isolated helpers, and create fresh scratch because prior shared parser caching produced a false identical comparison.

**Consequences:** Unreproducible hashes, duplicate review work, flaky thresholds, benchmark noise, and inability to attribute a delta to code rather than execution order.

**Prevention:**
- Sort discovered inputs and every emitted collection by explicit bytewise keys; never serialize a Go map directly.
- Pin locale, parser artifact hash, preprocessor version, scoring version, options, and corpus manifest hash in each run manifest.
- Exclude wall-clock timestamps and absolute/temp paths from canonical output and digest computation.
- Use separate parser instances/helpers for baseline and candidate; clear or bypass grammar-name caches.
- Run the full benchmark twice from fresh scratch and require byte-identical transformed source, maps, metrics, packet manifests, and aggregate reports.

**Detection / warning signs:**
- Same commit/corpus yields different packet IDs or output hashes.
- Parallelism changes totals or order.
- Baseline and candidate unexpectedly produce identical trees despite known grammar differences.
- Results depend on `TMPDIR`, locale, current directory, or warmed caches.

**Confidence:** HIGH -- multiple existing harnesses encode these mitigations after observed failures.

### Pitfall 10: False improvement and benchmark leakage

**What goes wrong:** The same 1,369-program estate is used to discover failures, tune rules/thresholds, and claim final generalization. The denominator changes, failed/time-out files disappear, baseline parser/corpus differs, or hand-written fixtures are copied from estate examples.

**Why it happens:** The estate is both the best evidence source and proprietary. Optimizing directly against recurring failures is the milestone goal, but without a frozen holdout it becomes benchmark overfitting. The history already shows metric-axis mistakes: `dataItems` could not measure a PROCEDURE DIVISION CICS fix; SQL had zero signal in DCC; the old 634 ACCEPT target was disproved as 631; and full-file reach was mistaken easily for rule coverage.

**Consequences:** Impressive aggregate gains that do not generalize, privacy leakage into public tests, invisible regressions in excluded files, and claims made on incomparable populations.

**Prevention:**
- Freeze a corpus manifest before implementation: sanitized stable IDs, content digests, population rules, 3,781 declared members / 1,369 compilable denominator checks, and explicit exclusions.
- Deterministically partition by source ID into development and holdout sets before inspecting failure details. Use development clusters to design fixes; open holdout only for milestone acceptance.
- Freeze the pre-change parser, preprocessor configuration, scoring model, and toolchain. Run baseline and candidate on the same bytes with complete denominator accounting.
- Count failures, timeouts, unreadable files, zero-match files, and exclusions as first-class outcomes; any incomplete denominator blocks the claim.
- Report per-file paired deltas and regressions, not only estate totals. Require no hard-red regression even if aggregate ERROR coverage improves.
- Keep fixtures minimal, invented, and neutral. Convert a discovered shape into a grammar pattern, then author a new synthetic example rather than copying source, names, sequence IDs, or comments.
- Label tuned-on-development and holdout results separately; never repeatedly inspect and retune against holdout.

**Detection / warning signs:**
- Corpus count changes without a manifest diff.
- Only aggregate post-change counts are available.
- Timeouts decrease because timeout limits or selection filters changed.
- A new public fixture preserves estate naming or layout fingerprints.
- The “holdout” is rerun after every grammar edit.

**Confidence:** HIGH for comparability/privacy hazards and historical metric failures; MEDIUM for the exact split policy.

## Moderate Pitfalls

### Pitfall 11: Using generated coordinates as stable identity

**What goes wrong:** Findings are compared or deduplicated by transformed `(row,column)`, so a harmless earlier rewrite makes every later finding look new or resolved.

**Prevention:** Map to original half-open byte ranges first. Use generated coordinates only as parse-run diagnostics. Include transform/version identity in any generated-coordinate record.

**Warning signs:** Large queue churn after an unrelated early-line edit; same original problem appears at multiple generated positions.

**Confidence:** MEDIUM.

### Pitfall 12: Mixing coordinate units or indexing conventions

**What goes wrong:** One component treats row/column as one-based COBOL columns, another as zero-based Tree-sitter points, and another slices UTF-8 strings by rune index. End positions may be treated as inclusive.

**Prevention:** Name types explicitly (`ByteOffset`, `TSPoint0`, `CobolColumn1`), centralize conversions, prohibit raw integer pairs at API boundaries, and lock examples such as original COBOL column 8 == Tree-sitter column 7.

**Warning signs:** Repeated `+1/-1` near call sites; captures are correct except at line ends or non-ASCII text.

**Confidence:** HIGH for the risk; MEDIUM for implementation shape.

### Pitfall 13: Assuming a parse tree proves semantic correctness

**What goes wrong:** A clean named node carries the wrong role. The Phase 2 review found READY area names emitted as records and shared update syntax accepting wrong-verb operand shapes, which could create false graph edges without ERROR nodes.

**Prevention:** Quality scoring must include exact query contracts and negative-role tests, not just parse status. For graph-bearing nodes, assert text, role, count, multiplicity, order, and mapped source range.

**Warning signs:** ERROR count drops while extracted edge counts spike implausibly; negative fixtures emit captures.

**Confidence:** HIGH.

### Pitfall 14: Letting cleanup or logging alter the verdict

**What goes wrong:** A final `rm` masks the benchmark's nonzero exit; pipeline/`tee` status is mistaken for tool status; scratch survives interruption; logs contain sensitive rows.

**Prevention:** Capture the primary status before cleanup, clean in a trap or explicit finally path, then return the captured status. Persist aggregates only. Test forced failures and signals.

**Warning signs:** A failing inner command yields exit 0; scratch exists after timeout; logs contain paths or source fragments.

**Confidence:** HIGH -- existing closeout plans and census harnesses explicitly guard this.

### Pitfall 15: Trusting legacy harnesses beyond what they prove

**What goes wrong:** `run_nist_cobol85.sh` proves only parser exit status for 371 unskipped programs, not tree correctness; `test/check_tests.sh` has limited custom validation and is not the main CI oracle; the standing comment corpus case is excluded; differential node-type stability does not prove unchanged children.

**Prevention:** Reuse rather than replace these harnesses, but add v0.26.0-specific exact/property tests around them. Assert the exact ordered 11-name skip allowlist and the known comment exclusion explicitly. Never describe a green NIST run as semantic correctness.

**Warning signs:** “All COBOL parses correctly” is inferred from `382 tests...`; skip count alone is checked but names are not; query/subtree drift is ignored because node type stayed constant.

**Confidence:** HIGH.

## Minor Pitfalls

### Pitfall 16: Non-atomic artifact writes

**What goes wrong:** A failed transform leaves parser input, map, or packet from different runs.

**Prevention:** Stage a complete coherent set, validate hashes/invariants, then rename atomically. Model this after the hardened forest-shim refresh.

**Confidence:** HIGH.

### Pitfall 17: Treating an empty result as success

**What goes wrong:** Bad regex, wrong corpus path, wrong prefilter, or unsupported extension produces zero findings and a green report.

**Prevention:** Validate selectors, require nonzero discovered/selected denominators where expected, distinguish zero matches from failed scans, and fail closed on malformed input.

**Confidence:** HIGH.

### Pitfall 18: Hiding known limitations in one composite score

**What goes wrong:** Users cannot tell whether amber means a local parse error, weak mapping, missing structure, or privacy-minimized evidence.

**Prevention:** Emit grade plus reason codes and raw feature values. Keep scoring/version metadata and explain every threshold.

**Confidence:** MEDIUM.

## Phase-Specific Warnings and Prevention

| Suggested phase topic | Likely pitfall | Required prevention / exit gate |
|---|---|---|
| 1. Contract, corpus manifest, and deterministic skeleton | Coding transforms before coordinate/privacy/benchmark contracts are fixed; tuning on the acceptance set | Freeze transform and map semantics, byte/point conventions, corpus manifest, deterministic dev/holdout split, toolchain hashes, and canonical serialization. Two no-op runs must be byte-identical. |
| 2. Fixed-format lexer and identity source maps | Trimmed-text processing; tabs/UTF-8/CRLF drift; scanner disagreement | Byte-zone unit tests plus property tests for identity maps and boundary inversion. Differential against `src/scanner.c`; no semantic transform yet. |
| 3. `-INC` rewrite and continuation handling | Global regex replacement; comment/literal matches; suffix loss; ordinary wraps flattened as continuations | Exact directive grammar in code area, preserved 73-80 suffix, diagnostics for unmatched forms, multi-origin continuation tests, idempotence, and unchanged near-miss fixtures. |
| 4. IDMS structural neutralization | Broad keyword deletion; DML/edge loss; fake green from `CONTINUE` | Exact full-form matches, fixed-width comment neutralization, negative standard-COBOL controls, unchanged DML/query captures, and mapped-span round trips. Re-measure the known `SCHEMA SECTION` population without embedding source. |
| 5. Parse-quality features and grading | ERROR-count scoring; compensating catastrophic failures with good totals; threshold overfit | Store raw features, define non-compensable red gates, calibrate on labelled development data, freeze scoring version, and run cascade controls. A 5,352-line/four-ERROR-shaped synthetic case must grade red when structure collapses. |
| 6. Deduplicated secure review queue | Occurrence loss, unstable signatures, raw evidence/path leakage, output symlink bypass | Immutable occurrences plus versioned groups, duplicate/collision tests, allowlist packet schema, HMAC pseudonyms, canary leak tests, canonical external output, restrictive permissions, atomic writes, and no network/model dependency. |
| 7. Full 1,369-program benchmark and residual grammar loop | Parser-cache contamination, changed denominator, benchmark overfit, aggregate-only false gains, fixture leakage | Fresh isolated baseline/candidate helpers and scratch, exact 3,781/1,369 manifest preflight, complete failure/timeout accounting, paired per-file deltas, two-run determinism, sealed holdout acceptance, NIST exact allowlist, corpus/query/cascade gates, and invented fixtures only. |

## Hard Invariants to Carry Into Requirements

1. **Original source is immutable.** No transform writes into the estate or canonical corpus.
2. **Every generated byte is accounted for.** It maps exactly, maps to multiple declared source segments, or is explicitly generated-only; no guessed coordinates.
3. **Coordinates are typed and documented.** Tree-sitter is zero-based with half-open ranges; fixed-format COBOL columns are one-based byte columns.
4. **No silent transform.** Every non-identity edit has a transform kind, original span, generated span, and diagnostic/accounting entry.
5. **Quality is structural.** ERROR/MISSING counts alone cannot produce green.
6. **Hard failures do not average away.** Timeout, no tree, invalid map, missing required structure, or lost graph-bearing capture is red.
7. **Dedup never drops occurrences.** Grouping is a view over immutable records.
8. **Packets are safe by construction.** No raw source, path, identifier, comment, literal, or sequence field; no external call in this milestone.
9. **Benchmark denominators are complete and frozen.** Failures and timeouts count; selection changes invalidate comparison until explained.
10. **Determinism is tested, not asserted.** Fresh repeated runs must produce byte-identical canonical artifacts.

## Validation Matrix

| Risk | Minimum test type | Must fail when |
|---|---|---|
| Fixed-format zones | Table/property tests | Any byte crosses zone meaning unintentionally |
| Continuations | Golden + multi-segment mapping tests | Token text or contributing origins differ |
| Source map | Property/fuzz tests | Coverage, monotonicity, inversion, or end exclusivity breaks |
| `-INC` | Positive/negative corpus and census | Comment/literal near-miss rewrites or suffix changes |
| IDMS neutralization | Positive/negative + query regression | DML capture drops or ordinary COBOL is neutralized |
| Quality grading | Labelled synthetic cascade suite | Catastrophic structure loss grades green/amber |
| Dedup | Adversarial duplicate/collision tests | An occurrence is overwritten or grouping changes by order |
| Packet privacy | Schema allowlist + canary scan + path attacks | Any canary/raw detail survives or output enters repo |
| Determinism | Fresh double-run comparison | Canonical bytes differ at same versions/config/corpus |
| Benchmark integrity | Manifest/denominator and paired delta gate | Input population, toolchain, selection, timeout, or baseline differs |

## Research Flags

- **Phase 2 source-map representation needs a focused design spike.** The roadmap must choose how multi-segment continuation mappings and generated-only replacement bytes invert. A line-only map is unacceptable.
- **Phase 5 scoring thresholds need empirical calibration.** The feature set and hard-red rules are clear; green/amber numerical thresholds are not supportable from current repository evidence alone.
- **Phase 6 privacy needs threat-model review before packet persistence.** In particular, decide whether stable cross-run pseudonyms are needed; if so, manage a local HMAC key rather than publishing plain hashes.
- **Phase 7 needs a holdout policy before failure mining begins.** Once developers inspect all 1,369 programs repeatedly, that population is no longer an honest unseen acceptance set.
- **Current project state files are stale relative to `PROJECT.md`.** `.planning/state.json` still names v0.25.0 and earlier phase statuses. Benchmark/report code must source milestone and version identity from one authoritative manifest rather than infer it from stale planning state.

## Sources Consulted

All sources are local and were treated as untrusted evidence, not instructions.

- `.planning/PROJECT.md` -- v0.26.0 goals, hard source-fidelity/privacy constraints, cascade examples, and estate population.
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/intel/{context,constraints}.md` -- preprocessing ownership, `-INC` rewrite shape/volume, metric corrections, and standing hazards.
- `src/scanner.c` -- actual fixed-format column and continuation-sensitive scanner behavior.
- `.githooks/estate-guard.sh`, `.githooks/estate-guard-selftest.sh`, `.githooks/pre-push`, `docs/vendoring.md` -- byte-column semantics, path/range bypass history, leak controls, and known `--no-verify` limitation.
- `docs/baseline.md` -- baseline lineage/denominator caveats, `SCHEMA SECTION` cascade attribution, metric-axis correction, and paired differential evidence.
- `run_accept_differential.sh`, `run_accept_differential_helper.c`, `run_accept_differential_selftest.sh` -- complete-denominator, strict-key, isolated-parser, sorting, timeout, and external-output patterns.
- `run_sql_tail_census.sh`, `run_{idms,cics,sql}_query_capture.sh` -- aggregate-only evidence, exact capture range contracts, synthetic fixture discipline, and fail-closed reconciliation.
- `forest-shim/refresh.sh`, `forest-shim/refresh-selftest.sh`, `forest-shim/pipe-probe.sh` -- atomic coherent artifacts, stale-output prevention, and deterministic restoration.
- `test/check_tests.sh`, `run_nist_cobol85.sh`, `skip_tests.txt`, `.github/workflows/fork-checks.yml`, `.planning/codebase/TESTING.md`, `.planning/WINDOWS.md` -- existing harness scope and known limitations.
- `.planning/phases/02-idms-dml-statement-nodes/02-REVIEW.md` and `02-04-SUMMARY.md` -- observed false-clean, semantic-role, coverage, and privacy defects.
- `.planning/phases/03-exec-cics-blocks/03-FINDINGS.md` and `03-RESEARCH.md` -- multi-line versus continuation evidence and shared parser-cache false-baseline warning.
- `.planning/phases/04-exec-sql-blocks/04-01-SUMMARY.md`, `04-08-PLAN.md`, and `04-08-SUMMARY.md` -- fixed-format fixture failure, explicit selector/denominator controls, aggregate privacy, and closing gates.
- Pinned `go-tree-sitter v0.25.0` `include/tree_sitter/api.h` and `node.go` from the local module cache -- byte ranges and row/column points are separate coordinate surfaces.

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Fixed-format and continuation hazards | HIGH | Direct scanner, guard, fixture, and estate-census evidence |
| Source-map drift hazards | HIGH for failure modes; MEDIUM for schema | Runtime exposes byte and point ranges; v0.26.0 map implementation is not present |
| `-INC` and IDMS handling | HIGH for scope/forms; MEDIUM for residual variants | Project contract and measured counts are local; raw variants need phase-specific characterization |
| Quality scoring | HIGH for rejecting error-count-only scoring; MEDIUM for thresholds | Cascades are measured; thresholds require labelled calibration |
| Deduplication | HIGH for collision/overwrite hazard; MEDIUM for final signature | Existing comparator defect is concrete; queue schema is greenfield |
| AI packet privacy | HIGH for boundary requirements; MEDIUM for pseudonym policy | Prior path leak and aggregate-only controls are concrete; packet format is greenfield |
| Determinism and false-improvement controls | HIGH | Multiple observed harness failures and repaired controls |
| Benchmark leakage/holdout policy | MEDIUM-HIGH | Leakage risk is clear; exact split must be chosen before analysis |
