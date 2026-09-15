#!/bin/bash
# .githooks/estate-guard.sh
#
# Estate-leak guard (FORK-02, D-16). This fork is PUBLIC on GitHub; `estate/`
# is a 697MB proprietary production-source working copy that must never reach
# the public remote. This script is the guard; `.githooks/pre-push` is where
# it fires (D-17).
#
# Three checks, every invocation:
#   1. reject any `estate/` path anywhere in the range -- every commit is
#      walked individually (git log + git diff-tree), not just the range's
#      two endpoint trees, so a file added then removed within the same push
#      is still seen (CR-01)
#   2. assert `.git/info/exclude` still declares `/estate/` and `.gitignore`
#      does NOT (the split is deliberate: the exclusion lives repo-locally so
#      the upstream PR diff stays at zero)
#   3. flag added COBOL lines whose columns 73-80 sequence area is populated,
#      sourced from the same per-commit walk as check 1
#
# Check 2 runs on EVERY invocation, including an empty range/staged set/stdin
# list, so an empty change can never produce a vacuous pass (T-01-05).
#
# Modes:
#   --check-exclude      run check 2 only
#   --range <A>..<B>     run all three checks over that commit range
#   --staged             run all three checks over `git diff --cached`
#   --remote <name>      scope the stdin new-branch bound to this remote's
#                        remote-tracking refs only. Required for a new-branch
#                        ref update on stdin (CR-04); has no effect on the
#                        other modes.
#   (no mode selector)   read git's pre-push stdin ref-update protocol:
#                        one line per ref update, "<local ref> <local sha>
#                        <remote ref> <remote sha>". Zero lines is valid.
#
# Interpreter: bash, not sh -- NUL-delimited path enumeration (CR-02) needs
# `read -r -d ''`, a bashism with no fully portable sh equivalent. `pre-push`
# and `test/check_tests.sh` already use bash, so this stays inside house
# style.
#
# House style (matches run_nist_cobol85.sh / test/check_tests.sh): no
# `set -e` / `set -u` anywhere in this repo's shell scripts -- every command
# that can fail is checked explicitly. Match that here. Quote every path
# expansion; never hand diff-derived content back to the shell for
# re-interpretation as a command -- the shell builtin that re-parses a
# string as code is never invoked anywhere in this script.

COBOL_PATH_RE='\.(cbl|CBL|cpy|CPY|cob|COB)$|^test/corpus/|^test/cobol85/'

# Columns 73-80 of a fixed-format COBOL line means BYTES 73-80 of the line
# CONTENT, counted after the leading diff `+` is stripped. We scan the raw
# `+`-prefixed diff line rather than stripping the `+` first, so byte 73 of
# the content sits at byte 74 of the raw line -- SEQ_AREA_FIRST_BYTE pins
# that offset so the two can never silently drift apart. A tab is one byte
# and is NOT expanded to a tab stop -- this is a fixed-format byte-column
# rule, not a display-column rule. A UTF-8 multibyte character counts as its
# byte length, not one code point or one display column. Every extraction
# below therefore runs under LC_ALL=C so awk's length/substr are byte-indexed
# rather than character-indexed.
SEQ_AREA_FIRST_BYTE=74

FAIL_COUNTER=0
CHECKS_RUN=0
ESTATE_GUARD_LOG="${ESTATE_GUARD_LOG:-}"

GUARD_TMP="$(mktemp -d)"
if [ $? -ne 0 ] || [ -z "$GUARD_TMP" ] || [ ! -d "$GUARD_TMP" ] || [ ! -w "$GUARD_TMP" ]; then
    printf '%s\n' "estate-guard: FAIL - cannot create a writable temp directory; every check writes into it and none can run without it"
    exit 1
fi
trap 'rm -rf "$GUARD_TMP"' EXIT INT TERM

report() {
    if [ -n "$ESTATE_GUARD_LOG" ]; then
        printf '%s\n' "$1" | tee -a "$ESTATE_GUARD_LOG"
    else
        printf '%s\n' "$1"
    fi
}

# ---------------------------------------------------------------------------
# Check 2 -- exclusion posture. Runs on EVERY invocation.
# ---------------------------------------------------------------------------
check_exclude() {
    CHECKS_RUN=$((CHECKS_RUN + 1))
    EXCLUDE_FILE="$(git rev-parse --git-path info/exclude 2>/dev/null)"
    if [ -z "$EXCLUDE_FILE" ]; then
        report "CHECK 2 (exclusion posture): FAIL - not inside a git repository, cannot resolve .git/info/exclude"
        FAIL_COUNTER=$((FAIL_COUNTER + 1))
        return
    fi

    EXCLUDE_OK=1
    if [ -f "$EXCLUDE_FILE" ] && grep -qx '/estate/' "$EXCLUDE_FILE"; then
        EXCLUDE_OK=0
    fi

    TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
    GITIGNORE_FILE="$TOPLEVEL/.gitignore"
    GITIGNORE_LEAKED=1
    if [ -f "$GITIGNORE_FILE" ] && grep -qx '/estate/' "$GITIGNORE_FILE"; then
        GITIGNORE_LEAKED=0
    fi

    if [ "$EXCLUDE_OK" = "0" ] && [ "$GITIGNORE_LEAKED" != "0" ]; then
        report "CHECK 2 (exclusion posture): PASS - /estate/ declared in .git/info/exclude, absent from .gitignore"
    else
        report "CHECK 2 (exclusion posture): FAIL - /estate/ must be declared in .git/info/exclude (present: $( [ "$EXCLUDE_OK" = 0 ] && echo yes || echo no )) and absent from .gitignore (leaked: $( [ "$GITIGNORE_LEAKED" = 0 ] && echo yes || echo no ))"
        FAIL_COUNTER=$((FAIL_COUNTER + 1))
    fi
}

# ---------------------------------------------------------------------------
# Checks 1 and 3 -- operate over a single git-diff spec token, either
# "--cached" or a "<A>..<B>" commit range.
# ---------------------------------------------------------------------------
check_paths_and_seq_area() {
    DIFF_SPEC="$1"

    # --- Enumerate every path touched by every commit in the range ---------
    # CR-01: a two-dot endpoint diff (`git diff A..B`) only compares the two
    # trees and is blind to a file added then removed within the range, even
    # though git transmits the full object closure of every pushed commit.
    # Walk each commit individually instead.
    CHANGED_PATHS_FILE="$GUARD_TMP/paths"
    COMMIT_PATH_PAIRS_FILE="$GUARD_TMP/commit_paths"
    : > "$CHANGED_PATHS_FILE"
    : > "$COMMIT_PATH_PAIRS_FILE"
    ENUM_FAILED=0
    ENUM_ERR=""

    if [ "$DIFF_SPEC" = "--cached" ]; then
        # Staged mode: a single cached diff. Still NUL-delimited (-z) and
        # --no-renames, same as the range walk below, so a rename out of
        # estate/ still surfaces the source path and a C-quoted path (CR-02)
        # is never mangled.
        git diff --cached --name-only --no-renames -z > "$GUARD_TMP/raw" 2>"$GUARD_TMP/err"
        if [ $? -ne 0 ]; then
            ENUM_FAILED=1
            ENUM_ERR="staged change: $(cat "$GUARD_TMP/err")"
        else
            cat "$GUARD_TMP/raw" > "$CHANGED_PATHS_FILE"
            while IFS= read -r -d '' p; do
                [ -z "$p" ] && continue
                printf '%s\0%s\0' "--cached" "$p" >> "$COMMIT_PATH_PAIRS_FILE"
            done < "$GUARD_TMP/raw"
        fi
    else
        git log --format=%H "$DIFF_SPEC" > "$GUARD_TMP/commits" 2>"$GUARD_TMP/err"
        if [ $? -ne 0 ]; then
            ENUM_FAILED=1
            ENUM_ERR="range '$DIFF_SPEC': $(cat "$GUARD_TMP/err")"
        else
            while IFS= read -r c; do
                [ -z "$c" ] && continue
                # -m: decompose merge commits against each parent so a merge
                #     yields its touched paths instead of nothing (same root
                #     cause as WR-01).
                # --no-renames: a rename out of estate/ still surfaces the
                #     source path.
                # -z: NUL-delimited so a non-ASCII or embedded-quote path
                #     (CR-02) is never C-quoted into an unmatchable line.
                git diff-tree -r -m --no-commit-id --name-only --no-renames -z "$c" \
                    > "$GUARD_TMP/raw_commit" 2>"$GUARD_TMP/err"
                if [ $? -ne 0 ]; then
                    ENUM_FAILED=1
                    ENUM_ERR="commit ${c}: $(cat "$GUARD_TMP/err")"
                    break
                fi
                cat "$GUARD_TMP/raw_commit" >> "$CHANGED_PATHS_FILE"
                while IFS= read -r -d '' p; do
                    [ -z "$p" ] && continue
                    printf '%s\0%s\0' "$c" "$p" >> "$COMMIT_PATH_PAIRS_FILE"
                done < "$GUARD_TMP/raw_commit"
            done < "$GUARD_TMP/commits"
        fi
    fi

    # --- Check 1: reject any estate/ path -----------------------------------
    CHECKS_RUN=$((CHECKS_RUN + 1))
    if [ "$ENUM_FAILED" -eq 1 ]; then
        # CR-03: a range/commit this guard cannot resolve must block the
        # push, never affirm that nothing bad was found.
        report "CHECK 1 (estate/ path reject): FAIL - cannot resolve $ENUM_ERR"
        FAIL_COUNTER=$((FAIL_COUNTER + 1))
        return
    fi
    # Translate NUL to newline only here, at the point of the anchored match
    # -- the accumulated list stays NUL-delimited everywhere else so a
    # C-quoted path is never reconstructed from human-readable text.
    ESTATE_HITS="$(LC_ALL=C tr '\0' '\n' < "$CHANGED_PATHS_FILE" | grep -E '^estate/')"
    if [ -n "$ESTATE_HITS" ]; then
        report "CHECK 1 (estate/ path reject): FAIL - proprietary path(s) in change: $(printf '%s' "$ESTATE_HITS" | tr '\n' ' ')"
        FAIL_COUNTER=$((FAIL_COUNTER + 1))
    else
        report "CHECK 1 (estate/ path reject): PASS - no estate/ path in change"
    fi

    # --- Check 3: sequence-area heuristic on diff-ADDED lines only ---------
    # Scoped to diff-added lines, never a whole-file scan: the NIST fixtures
    # under test/cobol85/src/*.CBL are public, upstream-owned, 80-column
    # fixed-format files that legitimately carry a populated columns 73-80
    # sequence area. Re-scanning whole files would false-positive on every
    # one of those files -- do not "simplify" this into a full-file scan.
    # Sourced from the same per-commit walk as check 1, never re-derived from
    # human-readable diff output.
    CHECKS_RUN=$((CHECKS_RUN + 1))
    : > "$GUARD_TMP/seq-hits"
    while IFS= read -r -d '' c && IFS= read -r -d '' f; do
        [ -z "$f" ] && continue
        printf '%s\n' "$f" | grep -qE "$COBOL_PATH_RE" || continue
        # --literal-pathspecs: no byte in $f can be interpreted as pathspec
        # magic, since $f is diff-derived (attacker-influenceable) content.
        if [ "$c" = "--cached" ]; then
            LC_ALL=C git --literal-pathspecs diff --cached --no-renames -- "$f" \
                > "$GUARD_TMP/patch3" 2>"$GUARD_TMP/err3"
        else
            LC_ALL=C git --literal-pathspecs diff-tree -p -m --no-renames "$c" -- "$f" \
                > "$GUARD_TMP/patch3" 2>"$GUARD_TMP/err3"
        fi
        if [ $? -ne 0 ]; then
            report "CHECK 3 (columns 73-80 sequence area, added lines only): FAIL - cannot resolve diff for '$f' at $c: $(cat "$GUARD_TMP/err3")"
            FAIL_COUNTER=$((FAIL_COUNTER + 1))
            continue
        fi
        LC_ALL=C awk -v off="$SEQ_AREA_FIRST_BYTE" -v fname="$f" '
            /^\+\+\+/ { next }
            /^\+/ {
                # Bytes 73-80 of the content == bytes off..off+7 of this
                # raw +-prefixed diff line (off=74). A line whose content
                # is shorter than 73 bytes has no sequence area at all
                # and is never flagged.
                if (length($0) < off) next
                seq = substr($0, off, 8)
                if (seq !~ /^[ ]*$/) {
                    print fname ": " seq
                }
            }
        ' "$GUARD_TMP/patch3" >> "$GUARD_TMP/seq-hits"
    done < "$COMMIT_PATH_PAIRS_FILE"
    if [ -s "$GUARD_TMP/seq-hits" ]; then
        report "CHECK 3 (columns 73-80 sequence area, added lines only): FAIL - populated sequence area on added line(s):"
        while IFS= read -r hit; do
            report "  $hit"
        done < "$GUARD_TMP/seq-hits"
        FAIL_COUNTER=$((FAIL_COUNTER + 1))
    else
        report "CHECK 3 (columns 73-80 sequence area, added lines only): PASS - no populated sequence area on added COBOL lines"
    fi
}

# ---------------------------------------------------------------------------
# Mode dispatch -- a parsing loop, not a single-shot case on "$1", so
# --remote can be combined with any mode selector in any position (CR-04).
# ---------------------------------------------------------------------------
MODE=""
RANGE_ARG=""
PUSH_REMOTE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --check-exclude)
            MODE=check-exclude
            shift
            ;;
        --range)
            MODE=range
            RANGE_ARG="$2"
            if [ -z "$RANGE_ARG" ]; then
                report "estate-guard: --range requires a <A>..<B> argument"
                exit 1
            fi
            shift 2
            ;;
        --staged)
            MODE=staged
            shift
            ;;
        --remote)
            PUSH_REMOTE="$2"
            if [ -z "$PUSH_REMOTE" ]; then
                report "estate-guard: --remote requires a remote-name argument"
                exit 1
            fi
            shift 2
            ;;
        *)
            report "estate-guard: unrecognized argument: $1"
            exit 1
            ;;
    esac
done

# No mode selector at all still means the stdin ref-update mode.
if [ -z "$MODE" ]; then
    MODE=stdin
fi

case "$MODE" in
    check-exclude)
        check_exclude
        ;;
    range)
        check_exclude
        check_paths_and_seq_area "$RANGE_ARG"
        ;;
    staged)
        check_exclude
        check_paths_and_seq_area "--cached"
        ;;
    stdin)
        check_exclude
        # git's pre-push protocol on stdin: one line per ref update,
        # "<local ref> <local sha> <remote ref> <remote sha>". Zero lines is
        # a valid, non-error case (e.g. a push that only deletes a ref).
        while IFS=' ' read -r LOCAL_REF LOCAL_SHA REMOTE_REF REMOTE_SHA; do
            [ -z "$LOCAL_REF" ] && continue
            case "$LOCAL_SHA" in
                0000000000000000000000000000000000000000)
                    # branch deletion: nothing is being pushed for this line.
                    continue
                    ;;
            esac
            case "$REMOTE_SHA" in
                0000000000000000000000000000000000000000)
                    # New branch: bound the scan to commits not already on
                    # the remote actually being pushed to. CR-04: excluding
                    # `--remotes` with no argument at all means every
                    # configured remote, so a commit already on a second
                    # remote (e.g. `upstream`) would be excluded from a scan
                    # of a push to the public `origin`. Without a remote name
                    # the only fallback is that argument-less, wrong form, so
                    # fail closed instead of guessing.
                    if [ -z "$PUSH_REMOTE" ]; then
                        CHECKS_RUN=$((CHECKS_RUN + 1))
                        report "CHECK 1 (estate/ path reject): FAIL - cannot determine which remote this new-branch push targets for $LOCAL_REF; guard was not invoked with --remote"
                        FAIL_COUNTER=$((FAIL_COUNTER + 1))
                        continue
                    fi
                    OLDEST_NEW="$(git rev-list "$LOCAL_SHA" --not --remotes="$PUSH_REMOTE" 2>"$GUARD_TMP/remote.err")"
                    if [ $? -ne 0 ]; then
                        CHECKS_RUN=$((CHECKS_RUN + 1))
                        report "CHECK 1 (estate/ path reject): FAIL - cannot enumerate commits new to remote '$PUSH_REMOTE' for $LOCAL_REF: $(cat "$GUARD_TMP/remote.err")"
                        FAIL_COUNTER=$((FAIL_COUNTER + 1))
                        continue
                    fi
                    OLDEST_NEW="$(printf '%s\n' "$OLDEST_NEW" | tail -1)"
                    if [ -z "$OLDEST_NEW" ]; then
                        # A definitive answer, not a silent skip: nothing in
                        # this ref update is new to that remote.
                        CHECKS_RUN=$((CHECKS_RUN + 1))
                        report "CHECK 1 (estate/ path reject): PASS - no commit in $LOCAL_REF is new to remote '$PUSH_REMOTE'"
                        continue
                    fi
                    if git rev-parse -q --verify "${OLDEST_NEW}^" >/dev/null 2>&1; then
                        BASE_SHA="$(git rev-parse "${OLDEST_NEW}^")"
                    else
                        BASE_SHA="$(git hash-object -t tree /dev/null)"
                    fi
                    check_paths_and_seq_area "${BASE_SHA}..${LOCAL_SHA}"
                    ;;
                *)
                    check_paths_and_seq_area "${REMOTE_SHA}..${LOCAL_SHA}"
                    ;;
            esac
        done
        ;;
esac

if [ "$FAIL_COUNTER" -eq 0 ]; then
    report "estate-guard: PASS (${CHECKS_RUN} check(s) run, 0 failed)"
    exit 0
else
    report "estate-guard: FAIL (${CHECKS_RUN} check(s) run, ${FAIL_COUNTER} failed)"
    exit 1
fi
