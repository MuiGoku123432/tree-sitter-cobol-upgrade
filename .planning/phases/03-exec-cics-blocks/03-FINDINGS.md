# Phase 3 Findings — 03-01 Task 2

Resolutions for the three open questions in `03-RESEARCH.md § Open Questions`.
Each answer records the command that produced it, so plan 03-04 can cite these
as constants rather than re-deriving them.

**Estate hygiene (D-32/T-03-01):** no line of estate source text appears in this
file. The probe in finding (2) reads the estate but writes only counts.

---

## Finding 1 — Pre-Phase-2 grammar SHA (OQ-1, for the D-26 reconstruction)

**Citable constant:**

```
5a3a8679a12a0bf3fd970fce90f606a5a09dc042
```

**Derivation.** The plan's rule is "the parent of the earliest Phase-2 commit
that touched `grammar.js`". Applied literally:

```bash
git log --oneline -- grammar.js          # earliest Phase-2 entry: 44ce5df
git rev-parse 44ce5df                    # 44ce5dfcc622ff784777930a21c1f042b3ab54ba
git rev-parse 44ce5df^                   # 5a3a8679a12a0bf3fd970fce90f606a5a09dc042
```

| Role | SHA | Subject |
|------|-----|---------|
| Earliest Phase-2 `grammar.js` commit | `44ce5dfcc622ff784777930a21c1f042b3ab54ba` | `feat(02-01): wire OBTAIN NEXT ... WITHIN ... to a green query capture` |
| **Its parent — the baseline** | `5a3a8679a12a0bf3fd970fce90f606a5a09dc042` | `test(02-01): add failing corpus fixture for IDMS OBTAIN navigation` |
| Last commit to actually touch `grammar.js` before Phase 2 | `c7a36d7` | `Expose comment nodes (#19)` |

**Ambiguity RESEARCH A6 warned about, and how it is discharged.** There are two
defensible readings of "the parent", and they disagree: `git log -- grammar.js`
applies history simplification, so it lists `c7a36d7` next, whereas the literal
parent commit is `5a3a867`. The disagreement is immaterial here, and that is
verified rather than assumed:

```bash
git diff --quiet c7a36d7 5a3a867 -- grammar.js   # exit 0 — IDENTICAL
```

`5a3a867` is Phase 2's RED-test commit: it adds `test/corpus/idms_navigation.txt`
and touches nothing else (`git show --stat 5a3a867` → 1 file changed). Its
`grammar.js` is byte-identical to `c7a36d7`'s. Either SHA reconstructs the same
grammar; **`5a3a867` is the recorded constant** because it follows the plan's
stated rule deterministically and needs no history-simplification caveat.

**Checkout cleanliness confirmed.** The baseline grammar contains zero Phase-2
and zero Phase-3 rules:

```bash
git show 5a3a867:grammar.js | grep -c "idms_\|exec_cics"   # 0
```

---

## Finding 2 — Fixed-format continuation lines inside `EXEC CICS` blocks (OQ-2, assumption A4)

**Answer: NO. Count = 0.**

`src/scanner.c` stays untouched. The grammar-only approach is safe, and no scope
escalation is required before plan 03-02.

**Probe.** Walk every file under `estate/`, track the region between an
`EXEC CICS` opening and its `END-EXEC` terminator, and count lines carrying a
continuation indicator (`-`) in column 7 (index 6) inside that region:

```bash
python3 - <<'PY'
import os,re
root="estate"
exec_open=re.compile(r'EXEC\s+CICS',re.I)
end_exec=re.compile(r'END-EXEC',re.I)
files=0; blocks=0; multiline=0; cont=0; contfiles=set()
for dp,_,fns in os.walk(root):
    for fn in fns:
        p=os.path.join(dp,fn)
        try:
            with open(p,'r',encoding='latin-1') as f: lines=f.read().split('\n')
        except Exception: continue
        if not any(exec_open.search(l) for l in lines): continue
        files+=1
        inblk=False; blklines=0
        for l in lines:
            if not inblk and exec_open.search(l):
                inblk=True; blklines=0; blocks+=1
                if end_exec.search(l): inblk=False
                continue
            if inblk:
                blklines+=1
                if len(l)>6 and l[6]=='-':
                    cont+=1; contfiles.add(p)
                if end_exec.search(l):
                    inblk=False
                    if blklines>0: multiline+=1
print(f"files_with_exec_cics={files}")
print(f"exec_cics_blocks={blocks}")
print(f"multiline_blocks={multiline}")
print(f"continuation_lines_col7_inside_blocks={cont}")
print(f"files_with_continuation={len(contfiles)}")
PY
```

**Result:**

| Measure | Count |
|---------|-------|
| Files containing at least one `EXEC CICS` | 267 |
| `EXEC CICS` blocks | 3,726 |
| Multi-line blocks | 2,837 |
| **Continuation lines (col 7 = `-`) inside blocks** | **0** |
| Files with any such continuation line | 0 |

**Interpretation.** 2,837 of 3,726 blocks (76%) span multiple source lines, so the
probe had ample opportunity to find a continuation indicator and found none. The
estate wraps `EXEC CICS` blocks by starting a new line at a token boundary, not by
splitting a token across lines with a column-7 continuation. Token-level
continuation is what would force a `src/scanner.c` change; line-level wrapping is
already handled by the grammar treating the block body as a `repeat()` of options
with whitespace in `extras`.

**Scope of the claim.** This measures the column-7 continuation indicator only —
the mechanism that splits a *token*. It does not claim the estate has no
multi-line blocks; it plainly has 2,837 of them, and those are exactly the shape
plan 03-02 must cover.

---

## Finding 3 — `NODE_TYPE_REGEX` for the D-31 differential

**Recorded regex:**

```
read_statement|write_statement|delete_statement|return_statement|exec_cics_statement
```

Invocation:

```bash
sh run_accept_differential.sh snapshot <CORPUS_DIR> <OUT_FILE> \
  'read_statement|write_statement|delete_statement|return_statement|exec_cics_statement'
```

**The four colliding verb statement node types it must cover:**

| CICS command word | Colliding existing COBOL node type |
|-------------------|-----------------------------------|
| `READ` | `read_statement` |
| `WRITE` | `write_statement` |
| `DELETE` | `delete_statement` |
| `RETURN` | `return_statement` |

Plus the new type the reclassification lands in: `exec_cics_statement`.

Node type names verified against the regenerated grammar:

```bash
node -e 'const nt=require("./src/node-types.json").map(n=>n.type);
  console.log(nt.filter(t=>/^(read|write|delete|return|exec_cics)_statement$/.test(t)))'
```

**Why Phase 2's `accept_statement` default is insufficient.** The default
`accept_statement|idms_accept_statement` cannot detect the reclassification D-31
exists to catch, because that is not where the Phase 3 collision surface is.
Phase 2's risk was `ACCEPT`, a single verb adjacent to `idms_accept_statement`.
Phase 3's risk is `field('command', $.WORD)` sitting immediately after
`EXEC CICS`, where four *existing* COBOL verb tokens — `READ`, `WRITE`, `DELETE`,
`RETURN` — are simultaneously among the most common CICS commands. A regression
would show up as an ordinary COBOL `READ` losing its `read_statement`
classification, and a snapshot filtered to `accept_statement` would inventory
zero such records and report a green gate over an unmeasured surface.

Task 1's fixture already proves the four words parse correctly in isolation
(`test/corpus/exec_cics.txt`, case `exec cics d-18 keyword extraction proof`).
The differential is the estate-scale version of that same assertion, and it is
what plan 03-04 runs.

**RESEARCH Pitfall 3 — the qualifier is not evidence about multi-line blocks.**
`run_accept_differential.sh` derives its `clean` / `trailing_error` qualifier from
a same-source-row heuristic: a record is `trailing_error` when an `(ERROR ...)`
node *begins* on the row on which the matched node *ends*. That heuristic rests on
one statement per source line — an assumption 2,837 multi-line `EXEC CICS` blocks
(76%, per Finding 2) directly violate. For those blocks the qualifier is
undefined-in-practice, not merely noisy.

Consequence for how 03-04 reads the output: **the `RECLASSIFIED_COUNT` tally is
the hard gate; the clean/trailing_error split is not evidence about multi-line
blocks and must not be cited as such.** `RECLASSIFIED_COUNT` compares before-type
to after-type at the same path and position and never consults the qualifier, so
it is unaffected by the heuristic. Do not report a
`trailing_error → exec_cics_statement` movement as a Phase 3 conversion result the
way Phase 2 legitimately did for `accept_statement`; that reading is only sound
for the one-statement-per-line shape.

---

## Finding 4 — Phase 3 measurement and regression gates (03-04)

**Checkpoint decision:** `confirm-with-note`. D-16d remains the inclusive terminal target `paragraph_header >= 16,732`, explicitly qualified by the reconstructed partition: IDMS closed 6,136 nodes; CICS was responsible for the remaining 1,409.

### Corpus recall

Command:

```bash
go test ./internal/parser/forest/cobolprobe/ -v -timeout 20m \
  -corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC \
  -neut-corpus ~/repos/mine/cobolCode/cam-corpus-dcc/DCC
```

Raw line: `neutralize_test.go:139: .cbl      606 |      15 -> 14       |   17905 -> 32360    |  18234 -> 16732`.

Result: grammar-alone `.cbl` `paragraph_header = 18,234`; `18,234 >= 16,732`, PASS by 1,502. Residual closure: `(18,234 - 15,323) / (16,732 - 15,323) = 2,911 / 1,409 = 206.6%`.

### D-31 zero-reclassification differential

Regex, exactly as Finding 3 records:

```
read_statement|write_statement|delete_statement|return_statement|exec_cics_statement
```

The existing differential's compiled C inventory helper was built once against the pre-Phase-3 parser and once against the current parser. Inventories were written under `$TMPDIR/opencode`, outside the repository. The shell `compare` subcommand is ACCEPT-specific, so a generic path+position+type comparison was applied to the helper outputs; any clean baseline node whose type changed or disappeared counted as a reclassification.

DCC raw result:

```
files=606 failures=0 timeouts=0
CLEAN_RECLASSIFIED_COUNT: 0
TRAILING_ERROR_CONVERTED_COUNT: 2
NEW_EXEC_CICS_COUNT: 905
```

Estate raw result:

```
files=1347 failures=0 timeouts=0
CLEAN_RECLASSIFIED_COUNT: 0
TRAILING_ERROR_CONVERTED_COUNT: 3
NEW_EXEC_CICS_COUNT: 1311
```

The trailing-error conversions are intended corrections: baseline `return_statement/trailing_error` nodes at the affected rows become clean `exec_cics_statement` nodes. They are disclosed separately and are not standard-COBOL regressions. The clean/trailing-error qualifier is a same-source-row heuristic and is not evidence about multi-line blocks; only the zero clean-reclassification tally is the hard gate.

### NIST COBOL85

Command: `sh run_nist_cobol85.sh`.

Raw line: `382 tests. (Success: 371, Fail: 0, Skip: 11)`.

Result: PASS, no failure beyond the unchanged 11-entry skip list.

### `cics_unparsed_tail` census

The same compiled current-parser helper was run with regex `^cics_unparsed_tail$` over both measured populations.

Raw results:

```
DCC:    files=606  failures=0 timeouts=0 records_written=0
Estate: files=1347 failures=0 timeouts=0 records_written=0
```

Result: zero tails. There is no missed high-volume form to name, and D-30 provides no basis for widening the tail rule.

## Cross-references

| Consumer | Constant it needs |
|----------|-------------------|
| Plan 03-02 | Finding 2 — no scanner change required; multi-line block count (2,837) is the coverage target |
| Plan 03-04 | Finding 1 — baseline SHA `5a3a867` for the D-26 reconstruction |
| Plan 03-04 | Finding 3 — `NODE_TYPE_REGEX` and the Pitfall 3 reading rule for the D-31 differential |

## Open-question status

| Question | Status | Resolved by |
|----------|--------|-------------|
| OQ-1 — pre-Phase-2 grammar SHA | RESOLVED | Finding 1 |
| OQ-2 — continuation lines (A4) | RESOLVED | Finding 2 |
| OQ-3 — `NODE_TYPE_REGEX` for D-31 | RESOLVED | Finding 3 |
| Query-test route | Out of scope here | Plan 03-03 |
