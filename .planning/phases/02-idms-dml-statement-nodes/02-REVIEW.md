---
phase: 02-idms-dml-statement-nodes
reviewed: 2026-09-16T13:41:32Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - grammar.js
  - src/parser.c
  - src/grammar.json
  - src/node-types.json
  - test/corpus/idms_navigation.txt
  - test/corpus/idms_update.txt
  - test/corpus/idms_session.txt
  - test/corpus/idms_accept.txt
  - test/idms/query-sample.cbl
  - queries/idms.scm
  - run_accept_differential.sh
  - run_accept_differential_selftest.sh
  - .github/workflows/fork-checks.yml
  - .githooks/commit-separability.sh
  - forest-shim/refresh.sh
  - forest-shim/cobol/parser.c
  - forest-shim/cobol/grammar.json
  - forest-shim/cobol/idms.scm
  - docs/baseline.md
findings:
  critical: 4
  warning: 6
  info: 0
  total: 10
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-09-16T13:41:32Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

The reviewed parser artifacts regenerate cleanly, the 36 focused IDMS corpus cases pass, and the
vendored grammar/query files match their sources apart from the intentional flattened include.
Those green checks do not make the implementation safe. The differential's proprietary-output
boundary is bypassable, its comparator can return a false clean verdict, the published query omits
most verb captures and mislabels an area as a record, and the update grammar accepts invalid or
wrong-verb operand shapes. Six additional robustness and test-gate defects leave these failures
undetected.

No proprietary estate content was read or quoted during this review.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Symlinks bypass the proprietary-inventory write boundary

**Classification:** BLOCKER
**File:** `run_accept_differential.sh:158-176,882-884`
**Issue:** `path_is_under_repo` constructs an absolute-looking path from `pwd`, but does not resolve
the candidate or its parent physically. A caller can therefore point `OUT_FILE` or `DIFF_TMP` at an
outside-directory symlink whose target is this public repository. Both `snapshot` and `run` accept
that path and write inventory files containing proprietary relative paths into the working tree.
This directly defeats the T-02-02/FORK-02 data-leak control. Reproduced with an external `repo-link`
symlink: `snapshot` exited 0 and created the inventory at the repository target; `run` likewise
created `before-inventory.txt` and `after-inventory.txt` there.

**Fix:** Resolve the final destination through symlinks before the prefix check and fail closed if it
cannot be canonicalized. For a not-yet-created file, canonicalize its existing parent physically
(`realpath`, or Python `Path(parent).resolve(strict=True)`) and append only the basename; for
`DIFF_TMP`, canonicalize the directory itself. Compare with a path-aware containment operation such
as `os.path.commonpath`, not a textual prefix. Add snapshot and run self-tests using an external
symlink back into the repository and require refusal with no created file.

### CR-02: Duplicate inventory keys can make a real reclassification pass

**Classification:** BLOCKER
**File:** `run_accept_differential.sh:496-559`
**Issue:** `compare` stores rows in maps keyed only by `path + start position`, while separately
retaining every row in `aorder`/`border`. A duplicate key silently overwrites the earlier type and
qualifier. Order therefore controls the verdict. Reproduced with a clean baseline
`accept_statement` and two after rows at the same key, first `idms_accept_statement` and then
`accept_statement`: the command reported `RECLASSIFIED_COUNT: 0` and exited 0. The summary was also
corrupted (`after_accept_statement=2`, `after_idms_accept_statement=0`) because both order entries
read the final overwritten map value. A malformed or unexpectedly nested inventory can therefore
hide the exact regression this hard gate claims to detect.

**Fix:** Validate each input as strict four-column TSV and reject duplicate `(path, position)` keys
before comparison. Alternatively include a stable disambiguator such as end position and traversal
ordinal, but still reject exact duplicate keys. Count directly while reading rows rather than
re-reading overwritten maps through order arrays. Add duplicate-before and both duplicate-after
orderings to the self-test and require nonzero exit.

### CR-03: The extraction contract does not capture most IDMS verbs

**Classification:** BLOCKER
**File:** `queries/idms.scm:9-20`
**Issue:** D-04 requires the query to capture the verb, and D-01 says every verb-class node carries a
verb. The query captures `@verb` only for navigation statements. Update and session patterns capture
operands but never their `verb:` fields. ACCEPT is worse: line 20 captures the entire statement as
`@verb`, so consumers receive text such as the full `ACCEPT ... CURRENCY` statement instead of the
verb token. A query run over STORE, BIND, READY, FINISH, COMMIT, and ROLLBACK emitted no verb
captures; the existing query sample never asserts capture names or values, so this shipped silently.

**Fix:** Add `verb: (_) @verb` to update and session patterns. Expose ACCEPT as a visible field,
for example `field('verb', alias($._ACCEPT, $.ACCEPT))`, and capture that field rather than the whole
statement. Regenerate all generated artifacts and refresh the shim. Add a deterministic query-output
test that requires one `@verb` value equal to each of all 14 verbs, not merely a successful query
command.

### CR-04: Update verbs share operands they do not legally support

**Classification:** BLOCKER
**File:** `grammar.js:2696-2723`
**Issue:** The six update verbs share one optional body. That makes five operand-required verbs
(`STORE`, `MODIFY`, `ERASE`, `CONNECT`, `DISCONNECT`) parse as valid bare statements, although only
GET has an operand-free form. It also permits every verb to use every clause: STORE/GET accept
`TO set`, MODIFY accepts `FROM set`, CONNECT accepts ERASE's `ALL MEMBERS`, CONNECT accepts FROM,
and DISCONNECT accepts TO. These invalid shapes produce clean, named ASTs and can create false
record/set graph edges rather than an ERROR or countable unparsed tail.

**Fix:** Make the body verb-specific inside a single class node, for example a `choice` of
`STORE|MODIFY` plus required record, ERASE plus required record/options, CONNECT plus required
`record TO set`, DISCONNECT plus required `record FROM set`, and GET plus optional record. Keep the
shared public statement node and `verb` field, but do not share incompatible operands. Add negative
corpus cases for bare non-GET verbs, reversed CONNECT/DISCONNECT prepositions, set clauses on
STORE/MODIFY/GET, and ERASE options on non-ERASE verbs.

## Warnings

### WR-01: READY area names are emitted as record captures

**Classification:** WARNING
**File:** `grammar.js:2739-2752`; `queries/idms.scm:15-16`
**Issue:** The READY syntax takes an optional area name, but the grammar wraps it in
`idms_record_name`, and the generic session query emits it as `@record`. `READY CUST-AREA.` therefore
produces a record-edge capture for an area, corrupting semantic extraction and violating IDMS-02's
record-name meaning.

**Fix:** Add an `idms_area_name` node or leave READY's area as a plain `WORD`; restrict the session
`@record` query to the BIND-record arm. Add a query test proving READY emits no `@record` capture.

### WR-02: Standalone snapshot accepts malformed node regexes as a successful empty census

**Classification:** WARNING
**File:** `run_accept_differential.sh:182-199,277-278,416-467`
**Issue:** `cmd_run` validates only the text prefilter, while `cmd_snapshot` never validates
`NODE_TYPE_REGEX`. With `[` as the regex, `grep` reports `parentheses not balanced`, but command
substitution discards that status, every file becomes `files_zero_match`, and snapshot exits 0 with
an empty inventory. This can turn an invalid tail-census request into false evidence of zero gaps.

**Fix:** Validate the node regex before creating output, using the same regex engine as the selected
path where possible. Check the `grep`/`sed` pipeline status explicitly and fail on status greater
than 1. Remove partial output on failure. Add malformed-regex tests for both `snapshot` and `run`.

### WR-03: The self-test cannot be invoked directly as documented

**Classification:** WARNING
**File:** `run_accept_differential_selftest.sh:1-2`
**Issue:** The file has a Bash shebang but is committed as mode `100644`. The phase calls it a
re-runnable script beside the executable differential, yet `./run_accept_differential_selftest.sh`
fails with permission denied. CI also never runs it, so the hard regression gate's own proof can
rot unnoticed.

**Fix:** Commit mode `100755` and add the self-test to fork CI. Keep `bash script` compatibility, but
test direct invocation too.

### WR-04: CI never validates the extraction query or differential safety gate

**Classification:** WARNING
**File:** `.github/workflows/fork-checks.yml:12-39`
**Issue:** The only fork-local job regenerates and runs corpus tests. It never runs
`run_accept_differential_selftest.sh`, never executes `queries/idms.scm`, and never checks the shim
copy. Consequently CR-01 through CR-03 and malformed-regex behavior can merge while CI remains
green. `test/idms/query-sample.cbl` appears under `tree-sitter test` as “0 assertions,” confirming it
is not a query contract test.

**Fix:** Add steps for the differential self-test; exact query-output assertions for all verb,
record, and set captures; `cmp queries/idms.scm forest-shim/cobol/idms.scm`; and a shim Go test that
loads/compiles the embedded IDMS query. Continue using only invented fixture data.

### WR-05: Refresh proceeds after generation or copy failure and tests stale/mixed output

**Classification:** WARNING
**File:** `forest-shim/refresh.sh:91-109,111-148,150-207`
**Issue:** A failed generation only increments `FAIL_COUNTER`; Step 3 then copies the previously
committed `src/`. A partial Step 3 likewise continues through rewrites, drift checking, and a smoke
build. Reproduced with a failing generator: Step 2 reported FAIL, but Steps 3-6 all reported OK and
the stale shim built. The final exit is nonzero, but logs and downstream artifacts can misleadingly
look validated, and a failed copy can leave a mixed parser/grammar/query set in the shim.

**Fix:** Abort immediately after failed generation. Copy all artifacts into a temporary sibling
directory, rewrite and validate there, compile the embedded queries, then atomically replace the
shim artifact set only after every gate passes. At minimum, skip Steps 3-6 after Step 2 failure and
Steps 4-6 after Step 3 failure, reporting them as skipped.

### WR-06: Navigation coverage omits documented alternatives and never tests them

**Classification:** WARNING
**File:** `grammar.js:2786-2803`; `test/corpus/idms_navigation.txt:49-160`
**Issue:** The phase plan's must-have names `CALC|ANY|DUPLICATE` and WITHIN set/area selector
variants, but the grammar models only CALC and ANY. `FIND DUPLICATE CUSTOMER-REC.` parses
`DUPLICATE` as the record and the actual record as `idms_unparsed_tail`, yielding the wrong record
edge. The corpus also has no ANY, DUPLICATE, FIRST, LAST, PRIOR, numeric selector, PAGE-INFO, or area
case, so the claim that all documented navigation formats and operand roles are covered is much
broader than the tests.

**Fix:** Model the documented DUPLICATE selector as a keyword, or explicitly remove that acceptance
claim if it is intentionally deferred. Add corpus/query cases for every selector and PAGE-INFO.
Represent area operands distinctly from `idms_set_name` so area forms cannot create false set
edges.

---

_Reviewed: 2026-09-16T13:41:32Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
