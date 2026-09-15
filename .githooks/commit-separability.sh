#!/bin/sh
# .githooks/commit-separability.sh
#
# Commit-separability check (FORK-03, D-12/D-15). A clean topic branch for an
# eventual upstream PR is reconstructible on demand from separable commits --
# but only if no commit ever mixes grammar-family paths with fork-local-family
# paths. That is the one PR-preservation property that cannot be recovered
# retroactively, so it is checked on every push (D-12: never mix grammar
# paths -- grammar.js, src/, test/corpus/, test/idms/, queries/ -- with
# fork-local paths in one commit).
#
# For each commit in the range, if its changed-path set intersects BOTH
# families below, that commit fails. Every commit is reported independently;
# empty commits and zero-commit ranges are also reported explicitly so a
# zero-check run can never masquerade as an ordinary PASS.
GRAMMAR_PATH_RE='^grammar\.js$|^test/corpus/|^test/idms/|^queries/|^src/'
FORKLOCAL_PATH_RE='^forest-shim/|^docs/|^\.planning/|^\.githooks/|^run_accept_differential|^run_[a-z0-9_]*\.(sh|c)$|^\.github/workflows/fork-checks\.yml$'

FAIL_COUNTER=0
CHECKS_RUN=0

report() {
    printf '%s\n' "$1"
}

# ---------------------------------------------------------------------------
# Accept `--range <A>..<B>` and a bare invocation. Default range is commits
# on HEAD not on upstream/main. If upstream/main cannot be resolved (a clone
# without the upstream remote), report that explicitly and check
# HEAD~20..HEAD instead -- never silently check nothing.
# ---------------------------------------------------------------------------
if [ "$1" = "--range" ]; then
    RANGE="$2"
    if [ -z "$RANGE" ]; then
        report "commit-separability: --range requires a <A>..<B> argument"
        exit 1
    fi
else
    if git rev-parse -q --verify upstream/main >/dev/null 2>&1; then
        RANGE="upstream/main..HEAD"
    else
        report "commit-separability: upstream/main not resolvable (no upstream remote fetched?) -- falling back to HEAD~20..HEAD"
        RANGE="HEAD~20..HEAD"
    fi
fi

COMMIT_LIST="$(git rev-list "$RANGE" 2>/dev/null)"
REV_LIST_STATUS=$?
if [ "$REV_LIST_STATUS" -ne 0 ]; then
    report "commit-separability: FAIL (range ${RANGE} could not be resolved -- 0 commits checked)"
    exit 1
fi
if [ -z "$COMMIT_LIST" ]; then
    report "commit-separability: PASS (0 commits in range ${RANGE} -- nothing to check)"
    exit 0
fi

# Word-splitting on a newline-separated list of commit SHAs is safe (SHAs
# contain no whitespace or glob metacharacters), and avoids the classic
# `... | while read` subshell trap that would silently drop FAIL_COUNTER
# updates once the loop exits.
set -- $COMMIT_LIST

for sha in "$@"; do
    CHECKS_RUN=$((CHECKS_RUN + 1))
    PATHS="$(git diff-tree --no-commit-id --name-only -r --root "$sha" 2>/dev/null)"
    PATHS_STATUS=$?
    if [ "$PATHS_STATUS" -ne 0 ]; then
        report "COMMIT ${sha}: FAIL - changed paths could not be enumerated"
        FAIL_COUNTER=$((FAIL_COUNTER + 1))
        continue
    fi
    if [ -z "$PATHS" ]; then
        report "COMMIT ${sha}: PASS - 0 changed paths (empty commit checked explicitly)"
        continue
    fi
    GRAMMAR_HIT="$(printf '%s\n' "$PATHS" | grep -E "$GRAMMAR_PATH_RE" | head -1)"
    FORKLOCAL_HIT="$(printf '%s\n' "$PATHS" | grep -E "$FORKLOCAL_PATH_RE" | head -1)"
    if [ -n "$GRAMMAR_HIT" ] && [ -n "$FORKLOCAL_HIT" ]; then
        report "COMMIT ${sha}: FAIL - mixes grammar path (${GRAMMAR_HIT}) with fork-local path (${FORKLOCAL_HIT})"
        FAIL_COUNTER=$((FAIL_COUNTER + 1))
    else
        report "COMMIT ${sha}: PASS - single-family or no matching paths"
    fi
done

if [ "$FAIL_COUNTER" -eq 0 ]; then
    report "commit-separability: PASS (${CHECKS_RUN} commit(s) checked, 0 mixed)"
    exit 0
else
    report "commit-separability: FAIL (${CHECKS_RUN} commit(s) checked, ${FAIL_COUNTER} mixed)"
    exit 1
fi
