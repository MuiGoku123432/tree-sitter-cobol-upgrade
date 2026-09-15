#!/bin/bash
# run_sql_query_capture.sh
# Exact D-17/D-18 gate for queries/sql.scm. All fixtures are invented and
# neutral. Scratch output stays in .git/info/exclude and is never printed.
# House style: no shell fail-fast flags; checks accumulate explicit status.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TOP_DIR=${TOP_DIR:-$SCRIPT_DIR}
TREE_SITTER=${TREE_SITTER:-$TOP_DIR/node_modules/tree-sitter-cli/tree-sitter}
QUERY_FILE=${QUERY_FILE:-$TOP_DIR/queries/sql.scm}
SCRATCH_DIR=${SCRATCH_DIR:-$TOP_DIR/.sql-query-scratch}
FIXTURE=$SCRATCH_DIR/query-sample.cbl
CAPTURE_LOG=$SCRATCH_DIR/capture.log
CAPTURE_TSV=$SCRATCH_DIR/captures.tsv
ASSIGNED_TSV=$SCRATCH_DIR/assigned.tsv
PHYSICAL_TSV=$SCRATCH_DIR/physical.tsv
ANALYZER=$SCRATCH_DIR/analyze.awk
FAIL_COUNTER=0

report() { printf '%s\n' "$1"; }
fail() { report "$1"; FAIL_COUNTER=$((FAIL_COUNTER + 1)); }

EXCLUDE_FILE="$TOP_DIR/.git/info/exclude"
if [ -f "$EXCLUDE_FILE" ]; then
    grep -qF '/.sql-query-scratch/' "$EXCLUDE_FILE" >/dev/null 2>&1
    [ $? -eq 0 ] || printf '%s\n' '/.sql-query-scratch/' >> "$EXCLUDE_FILE"
fi

STEP1_OK=1
if [ -x "$TREE_SITTER" ]; then
    report "STEP 1 (tree-sitter binary): OK - pinned CLI is executable"
else
    report "STEP 1 (tree-sitter binary): FAIL - $TREE_SITTER is unavailable"
    STEP1_OK=0
fi
if [ -f "$QUERY_FILE" ]; then
    report "STEP 1 (query file): OK - queries/sql.scm is present"
else
    report "STEP 1 (query file): FAIL - $QUERY_FILE is unavailable"
    STEP1_OK=0
fi
if [ "$STEP1_OK" -ne 1 ]; then
    report "SUMMARY: preconditions failed"
    exit 1
fi

mkdir -p "$SCRATCH_DIR"
if [ $? -ne 0 ]; then
    report "STEP 2 (scratch): FAIL - cannot create owned scratch directory"
    exit 1
fi

cat > "$FIXTURE" <<'FIXTURE_EOF'
       identification division.
       program-id. sql-query-gate.
       procedure division.
       EXEC SQL SELECT ID FROM APP.CUSTOMER AS C END-EXEC.
       EXEC SQL WITH RECENT AS
           (SELECT ID FROM ARCHIVE.EVENTS)
           SELECT ID FROM RECENT END-EXEC.
       EXEC SQL WITH RECENT AS
           (SELECT ID FROM ARCHIVE.EVENTS JOIN CORE.ACCOUNTS AS A)
           SELECT ID FROM RECENT END-EXEC.
       EXEC SQL WITH RECENT AS
           (SELECT ID FROM ARCHIVE.EVENTS)
           SELECT ID FROM RECENT JOIN CORE.ACCOUNTS END-EXEC.
       EXEC SQL WITH ITEMS AS
           (SELECT ID FROM REGION.ONE)
           SELECT ID FROM ITEMS END-EXEC.
       EXEC SQL WITH ITEMS AS
           (SELECT ID FROM REGION.TWO)
           SELECT ID FROM ITEMS END-EXEC.
       EXEC SQL SELECT ID FROM
           (SELECT ID FROM LOC.CAT.ORDERS) AS D END-EXEC.
       EXEC SQL PREPARE STMT FROM :SQL-TEXT END-EXEC.
       EXEC SQL COMMIT WORK END-EXEC.
       EXEC SQL INCLUDE SQLCA END-EXEC.
       EXEC SQL INCLUDE TEAM-MEMBER END-EXEC.
       EXEC SQL INSERT INTO APP.ORDERS VALUES (1) END-EXEC.
       EXEC SQL UPDATE APP.CUSTOMER AS C SET FLAG = 1 END-EXEC.
       EXEC SQL DELETE FROM APP.ARCHIVE WHERE FLAG = 0 END-EXEC.
       EXEC SQL MERGE INTO APP.TARGET AS T
           USING STAGE.SOURCE AS S ON T-ID = S-ID
       END-EXEC.
       EXEC SQL CREATE TABLE APP.NEW-TABLE END-EXEC.
       EXEC SQL ALTER TABLE APP.NEW-TABLE ADD FLAG END-EXEC.
       EXEC SQL DROP TABLE APP.OLD-TABLE END-EXEC.
       EXEC SQL SELECT ID FROM APP.ONE JOIN APP.TWO AS T
           JOIN APP.ONE END-EXEC.
       EXEC SQL SELECT ID FROM (SELECT ID FROM APP.NESTED) AS D
           JOIN APP.OUTER END-EXEC.
FIXTURE_EOF
if [ $? -ne 0 ]; then
    report "STEP 2 (fixture): FAIL - cannot write invented fixture"
    exit 1
fi
report "STEP 2 (fixture): OK - wrote invented SQL scope cases"

cat > "$ANALYZER" <<'AWK_EOF'
BEGIN { FS="\t"; OFS="\t"; bad=0 }
function before(ar,ac,br,bc) { return ar<br || (ar==br && ac<=bc) }
function contains(i,sr,sc,er,ec) {
    return before(ssr[i],ssc[i],sr,sc) && before(er,ec,ser[i],sec[i])
}
function fail(msg) { print "analyzer: " msg > "/dev/stderr"; bad=1 }
$1=="statement" {
    ns++; ssr[ns]=$2+0; ssc[ns]=$3+0; ser[ns]=$4+0; sec[ns]=$5+0; stxt[ns]=$6
    role[NR]=$1; sr[NR]=$2+0; sc[NR]=$3+0; er[NR]=$4+0; ec[NR]=$5+0; txt[NR]=$6; next
}
{
    role[NR]=$1; sr[NR]=$2+0; sc[NR]=$3+0; er[NR]=$4+0; ec[NR]=$5+0; txt[NR]=$6
}
END {
    for (i=1;i<=ns;i++) for (j=i+1;j<=ns;j++) {
        if (before(ssr[j],ssc[j],ser[i],sec[i]) && before(ssr[i],ssc[i],ser[j],sec[j]))
            fail("overlapping sibling statements " i " and " j)
    }
    for (n=1;n<=NR;n++) {
        if (role[n]=="" || role[n]=="statement") continue
        if (role[n]=="include") {
            print 0, role[n], sr[n], sc[n], er[n], ec[n], txt[n] > assigned_file
            continue
        }
        best=0; ties=0
        for (i=1;i<=ns;i++) if (contains(i,sr[n],sc[n],er[n],ec[n])) {
            rows=ser[i]-ssr[i]; cols=(rows==0 ? sec[i]-ssc[i] : 0)
            if (best==0 || rows<brows || (rows==brows && cols<bcols)) {
                best=i; brows=rows; bcols=cols; ties=1
            } else if (rows==brows && cols==bcols) ties++
        }
        if (best==0) { fail(role[n] " has no containing statement"); continue }
        if (ties!=1) { fail(role[n] " has multiple equal smallest containers"); continue }
        if (!contains(best,sr[n],sc[n],er[n],ec[n])) {
            fail(role[n] " lies outside assigned statement"); continue
        }
        assigned[n]=best
        print best, role[n], sr[n], sc[n], er[n], ec[n], txt[n] > assigned_file
        if (role[n]=="cte_definition") {
            name=txt[n]; sub(/[[:space:]].*/, "", name); cte[best SUBSEP name]=1
        }
    }
    for (n=1;n<=NR;n++) if (role[n]=="table" && assigned[n]>0) {
        if (!cte[assigned[n] SUBSEP txt[n]])
            print assigned[n], txt[n] > physical_file
    }
    exit bad
}
AWK_EOF

# Convert 0.24.5 output to a stable role/range/text stream. Multiline captures
# omit text, so source text is reconstructed from the exact reported range.
awk -v source="$FIXTURE" '
BEGIN { while ((getline line < source)>0) src[n++]=line }
/capture:/ && /start: \(/ {
    raw=$0
    sub(/^.*capture: ([0-9]+ - )?/, "", raw); role=raw; sub(/,.*/, "", role)
    pos=$0; sub(/^.*start: \(/, "", pos); split(pos,a,"\\), end: \\\(")
    split(a[1],s,", "); end=a[2]; sub(/\).*/,"",end); split(end,e,", ")
    sr=s[1]+0; sc=s[2]+0; er=e[1]+0; ec=e[2]+0
    text=""
    if (sr==er) text=substr(src[sr],sc+1,ec-sc)
    else {
        text=substr(src[sr],sc+1)
        for (i=sr+1;i<er;i++) text=text "\n" src[i]
        text=text "\n" substr(src[er],1,ec)
    }
    gsub(/\t/," ",text); gsub(/\n/," ",text); gsub(/[[:space:]]+/," ",text)
    print role "\t" sr "\t" sc "\t" er "\t" ec "\t" text
}' /dev/null > "$CAPTURE_TSV"
# The parser above reads capture.log after the query has populated it.
( cd "$TOP_DIR" && "$TREE_SITTER" query "$QUERY_FILE" "$FIXTURE" ) > "$CAPTURE_LOG" 2>&1
QUERY_STATUS=$?
if [ "$QUERY_STATUS" -ne 0 ]; then
    fail "STEP 3 (query): FAIL - tree-sitter query exited $QUERY_STATUS"
else
    awk -v source="$FIXTURE" '
    BEGIN { while ((getline line < source)>0) src[n++]=line }
    /capture:/ && /start: \(/ {
        raw=$0; sub(/^.*capture: ([0-9]+ - )?/, "", raw); role=raw; sub(/,.*/, "", role)
        pos=$0; sub(/^.*start: \(/, "", pos); split(pos,a,"\\), end: \\\(")
        split(a[1],s,", "); end=a[2]; sub(/\).*/,"",end); split(end,e,", ")
        sr=s[1]+0; sc=s[2]+0; er=e[1]+0; ec=e[2]+0
        if (sr==er) text=substr(src[sr],sc+1,ec-sc)
        else { text=substr(src[sr],sc+1); for(i=sr+1;i<er;i++) text=text " " src[i]; text=text " " substr(src[er],1,ec) }
        gsub(/\t/," ",text); gsub(/[[:space:]]+/," ",text)
        print role "\t" sr "\t" sc "\t" er "\t" ec "\t" text
    }' "$CAPTURE_LOG" > "$CAPTURE_TSV"
    if [ $? -ne 0 ]; then
        fail "STEP 3 (capture parser): FAIL - could not normalize query output"
    else
        report "STEP 3 (capture parser): OK - normalized row/column ranges"
    fi
fi

: > "$ASSIGNED_TSV"; : > "$PHYSICAL_TSV"
awk -v assigned_file="$ASSIGNED_TSV" -v physical_file="$PHYSICAL_TSV" -f "$ANALYZER" "$CAPTURE_TSV" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    fail "STEP 4 (containment): FAIL - actual captures violate fail-closed scope rules"
else
    report "STEP 4 (containment): OK - every role has one smallest statement"
fi

EXPECTED_PHYSICAL='1	APP.CUSTOMER
2	ARCHIVE.EVENTS
3	ARCHIVE.EVENTS
3	CORE.ACCOUNTS
4	ARCHIVE.EVENTS
4	CORE.ACCOUNTS
5	REGION.ONE
6	REGION.TWO
7	LOC.CAT.ORDERS
10	APP.ORDERS
11	APP.CUSTOMER
12	APP.ARCHIVE
13	APP.TARGET
13	STAGE.SOURCE
14	APP.NEW-TABLE
15	APP.NEW-TABLE
16	APP.OLD-TABLE
17	APP.ONE
17	APP.TWO
17	APP.ONE
18	APP.NESTED
18	APP.OUTER'
printf '%b\n' "$EXPECTED_PHYSICAL" > "$SCRATCH_DIR/expected-physical.tsv"
cmp -s "$SCRATCH_DIR/expected-physical.tsv" "$PHYSICAL_TSV"
if [ $? -ne 0 ]; then
    fail "STEP 5 (physical tables): FAIL - exact statement-scoped sets differ"
else
    report "STEP 5 (physical tables): OK - exact sets include empty utility and exclude same-statement CTE names"
fi

# D-17 locks the complete raw stream, not mere role presence. Comparing the
# ordered TSV proves exact text, start/end row-column pairs, count,
# multiplicity, and source order in one deterministic assertion.
cat > "$SCRATCH_DIR/expected-captures.tsv" <<'CAPTURE_EOF'
statement	3	7	3	57	EXEC SQL SELECT ID FROM APP.CUSTOMER AS C END-EXEC
source_candidate	3	31	3	48	APP.CUSTOMER AS C
table	3	31	3	43	APP.CUSTOMER
alias	3	44	3	48	AS C
statement	4	7	6	41	EXEC SQL WITH RECENT AS (SELECT ID FROM ARCHIVE.EVENTS) SELECT ID FROM RECENT END-EXEC
cte_definition	4	21	5	42	RECENT AS (SELECT ID FROM ARCHIVE.EVENTS)
source_candidate	5	27	5	41	ARCHIVE.EVENTS
table	5	27	5	41	ARCHIVE.EVENTS
source_candidate	6	26	6	32	RECENT
table	6	26	6	32	RECENT
statement	7	7	9	41	EXEC SQL WITH RECENT AS (SELECT ID FROM ARCHIVE.EVENTS JOIN CORE.ACCOUNTS AS A) SELECT ID FROM RECENT END-EXEC
cte_definition	7	21	8	66	RECENT AS (SELECT ID FROM ARCHIVE.EVENTS JOIN CORE.ACCOUNTS AS A)
source_candidate	8	27	8	41	ARCHIVE.EVENTS
table	8	27	8	41	ARCHIVE.EVENTS
source_candidate	8	47	8	65	CORE.ACCOUNTS AS A
table	8	47	8	60	CORE.ACCOUNTS
alias	8	61	8	65	AS A
source_candidate	9	26	9	32	RECENT
table	9	26	9	32	RECENT
statement	10	7	12	60	EXEC SQL WITH RECENT AS (SELECT ID FROM ARCHIVE.EVENTS) SELECT ID FROM RECENT JOIN CORE.ACCOUNTS END-EXEC
cte_definition	10	21	11	42	RECENT AS (SELECT ID FROM ARCHIVE.EVENTS)
source_candidate	11	27	11	41	ARCHIVE.EVENTS
table	11	27	11	41	ARCHIVE.EVENTS
source_candidate	12	26	12	32	RECENT
table	12	26	12	32	RECENT
source_candidate	12	38	12	51	CORE.ACCOUNTS
table	12	38	12	51	CORE.ACCOUNTS
statement	13	7	15	40	EXEC SQL WITH ITEMS AS (SELECT ID FROM REGION.ONE) SELECT ID FROM ITEMS END-EXEC
cte_definition	13	21	14	38	ITEMS AS (SELECT ID FROM REGION.ONE)
source_candidate	14	27	14	37	REGION.ONE
table	14	27	14	37	REGION.ONE
source_candidate	15	26	15	31	ITEMS
table	15	26	15	31	ITEMS
statement	16	7	18	40	EXEC SQL WITH ITEMS AS (SELECT ID FROM REGION.TWO) SELECT ID FROM ITEMS END-EXEC
cte_definition	16	21	17	38	ITEMS AS (SELECT ID FROM REGION.TWO)
source_candidate	17	27	17	37	REGION.TWO
table	17	27	17	37	REGION.TWO
source_candidate	18	26	18	31	ITEMS
table	18	26	18	31	ITEMS
statement	19	7	20	56	EXEC SQL SELECT ID FROM (SELECT ID FROM LOC.CAT.ORDERS) AS D END-EXEC
source_candidate	20	27	20	41	LOC.CAT.ORDERS
table	20	27	20	41	LOC.CAT.ORDERS
alias	20	43	20	47	AS D
statement	21	7	21	52	EXEC SQL PREPARE STMT FROM :SQL-TEXT END-EXEC
statement	22	7	22	36	EXEC SQL COMMIT WORK END-EXEC
include	23	24	23	29	SQLCA
include	24	24	24	35	TEAM-MEMBER
CAPTURE_EOF
awk -F '\t' '$2 <= 24 && $1 != "dynamic_source"' "$CAPTURE_TSV" > "$SCRATCH_DIR/legacy-captures.tsv"
cmp -s "$SCRATCH_DIR/expected-captures.tsv" "$SCRATCH_DIR/legacy-captures.tsv"
if [ $? -ne 0 ]; then
    fail "STEP 6 (raw capture contract): FAIL - text, range, count, multiplicity, or order differs"
else
    report "STEP 6 (raw capture contract): OK - all 47 captures match exactly in source order"
fi

cat > "$SCRATCH_DIR/expected-static-tables.tsv" <<'STATIC_EOF'
10	table	25	28	25	38	APP.ORDERS
11	table	26	23	26	35	APP.CUSTOMER
12	table	27	28	27	39	APP.ARCHIVE
13	table	28	27	28	37	APP.TARGET
13	table	29	17	29	29	STAGE.SOURCE
14	table	31	29	31	42	APP.NEW-TABLE
15	table	32	28	32	41	APP.NEW-TABLE
16	table	33	27	33	40	APP.OLD-TABLE
17	table	34	31	34	38	APP.ONE
17	table	34	44	34	51	APP.TWO
17	table	35	16	35	23	APP.ONE
18	table	36	47	36	57	APP.NESTED
18	table	37	16	37	25	APP.OUTER
STATIC_EOF
awk -F '\t' '$2 == "table" && $3 >= 25' "$ASSIGNED_TSV" > "$SCRATCH_DIR/static-tables.tsv"
cmp -s "$SCRATCH_DIR/expected-static-tables.tsv" "$SCRATCH_DIR/static-tables.tsv"
if [ $? -ne 0 ]; then
    fail "STEP 6 (static table ranges): FAIL - text, range, count, or source order differs"
else
    report "STEP 6 (static table ranges): OK - all 13 D-04 records match exactly"
fi

cat > "$SCRATCH_DIR/expected-dynamic-sources.tsv" <<'DYNAMIC_EOF'
dynamic_source	21	34	21	43	:SQL-TEXT
DYNAMIC_EOF
awk -F '\t' '$1 == "dynamic_source"' "$CAPTURE_TSV" > "$SCRATCH_DIR/dynamic-sources.tsv"
cmp -s "$SCRATCH_DIR/expected-dynamic-sources.tsv" "$SCRATCH_DIR/dynamic-sources.tsv"
if [ $? -ne 0 ]; then
    fail "STEP 6 (dynamic source): FAIL - text, range, or count differs"
else
    report "STEP 6 (dynamic source): OK - exact PREPARE source captured once"
fi
if awk -F '\t' '$1 == "table" && $6 == ":SQL-TEXT" { found=1 } END { exit !found }' "$CAPTURE_TSV"; then
    fail "STEP 6 (dynamic raw table): FAIL - PREPARE source emitted as @table"
else
    report "STEP 6 (dynamic raw table): OK - PREPARE source absent from @table"
fi

# Negative identities are checked independently of the exact physical list so
# future role extensions cannot accidentally turn a CTE, derived alias, or
# dynamic host variable into a physical table.
for FORBIDDEN in RECENT ITEMS 'AS D' 'AS C' 'AS T' 'AS S' ':SQL-TEXT' SQLCA TEAM-MEMBER; do
    grep -qF "$FORBIDDEN" "$PHYSICAL_TSV"
    if [ $? -eq 0 ]; then
        fail "STEP 6 (negative physical '$FORBIDDEN'): FAIL - non-physical identity leaked"
    else
        report "STEP 6 (negative physical '$FORBIDDEN'): OK - absent"
    fi
done

# Extension points: 04-04 Task 3 adds @include expectations; 04-05 Task 3 adds
# every D-04 static source; 04-05 Task 4 adds @dynamic_source expectations.
run_negative() {
    NAME="$1"; DATA="$2"
    printf '%b\n' "$DATA" > "$SCRATCH_DIR/negative.tsv"
    : > "$SCRATCH_DIR/negative-assigned.tsv"; : > "$SCRATCH_DIR/negative-physical.tsv"
    awk -v assigned_file="$SCRATCH_DIR/negative-assigned.tsv" -v physical_file="$SCRATCH_DIR/negative-physical.tsv" -f "$ANALYZER" "$SCRATCH_DIR/negative.tsv" >/dev/null 2>&1
    if [ $? -eq 0 ]; then fail "STEP 6 ($NAME): FAIL - malformed ranges were accepted"; else report "STEP 6 ($NAME): OK - failed closed"; fi
}
run_negative "no container" 'statement\t1\t0\t1\t10\tS\ntable\t2\t0\t2\t1\tT'
run_negative "equal smallest containers" 'statement\t1\t0\t1\t10\tS1\nstatement\t1\t0\t1\t10\tS2\ntable\t1\t1\t1\t2\tT'
run_negative "out of range" 'statement\t1\t2\t1\t8\tS\ntable\t1\t1\t1\t3\tT'
run_negative "overlapping siblings" 'statement\t1\t0\t2\t5\tS1\nstatement\t2\t0\t3\t5\tS2\ntable\t2\t1\t2\t2\tT'

printf '%b\n' 'statement\t4\t7\t4\t20\tS\ntable\t4\t7\t4\t20\tBOUNDARY' > "$SCRATCH_DIR/boundary.tsv"
: > "$SCRATCH_DIR/boundary-assigned.tsv"; : > "$SCRATCH_DIR/boundary-physical.tsv"
awk -v assigned_file="$SCRATCH_DIR/boundary-assigned.tsv" -v physical_file="$SCRATCH_DIR/boundary-physical.tsv" -f "$ANALYZER" "$SCRATCH_DIR/boundary.tsv" >/dev/null 2>&1
if [ $? -ne 0 ]; then fail "STEP 6 (boundary containment): FAIL"; else report "STEP 6 (boundary containment): OK"; fi

if [ "$FAIL_COUNTER" -ne 0 ]; then
    report "SUMMARY: $FAIL_COUNTER SQL query gate check(s) failed"
    exit 1
fi
report "SUMMARY: all D-18 statement-scoped physical-table checks passed"
exit 0
