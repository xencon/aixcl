#!/usr/bin/env bash
# Check diffs for AI-elision damage: placeholder text standing in for real
# code ("rest of the file unchanged") and suspicious mass deletions.
#
# Motivation: an AI-assisted refactor once replaced a 639-line module with
# a 126-line stub whose last line read "(rest of your file remains EXACTLY
# unchanged)" -- and it was committed. Prose rules did not catch it; this
# script does, deterministically.
#
# Usage:
#   check-ai-elisions.sh --staged           # staged changes (pre-commit)
#   check-ai-elisions.sh --range <A> <B>    # commit range (CI)
#   check-ai-elisions.sh                    # staged if any, else HEAD~1..HEAD
#
# Bypass for intentional large removals (deletion check only; the marker
# check has no bypass -- reword the text instead):
#   AIXCL_ALLOW_MASS_DELETE=1 check-ai-elisions.sh --staged
#
# In --range mode (CI), the deletion check is also skipped when a commit
# message in the range contains the token AIXCL_ALLOW_MASS_DELETE. State
# the intent in the commit message and CI will honor it.
#
# Markdown files are exempt: documentation legitimately discusses these
# phrases, and elision damage matters most in source files.
#
# Exit code: 0 if all checks pass, 1 if any check fails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0

# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/core/color.sh"

error() {
    echo -e "${RED}${ICON_ERROR:-❌}${NC} $1" >&2
    ((ERRORS++)) || true
}

warn() {
    echo -e "${YELLOW}${ICON_WARNING:-⚠️}${NC} $1" >&2
}

info() {
    print_info "$1"
}

# Placeholder phrases AI tools emit instead of preserved content.
# Matched case-insensitively against ADDED lines only.
ELISION_PATTERNS='rest of (the|your) (file|code|function|class|implementation)
remains? (exactly )?unchanged
existing (code|implementation|logic) (here|remains|unchanged)
\.\.\. ?(rest|existing|unchanged|snip|omitted)
(code|implementation|content) (omitted|elided) (for brevity|here)?
unchanged (below|above) this (line|point)
same as (before|the original|previous version)'

# Deletion thresholds: flag a MODIFIED file losing this many lines AND
# this fraction of its previous size.
MASS_DELETE_MIN_LINES=50
MASS_DELETE_MIN_RATIO=60   # percent

# -- Diff selection ---------------------------------------------------------

MODE="auto"
RANGE_A=""
RANGE_B=""

case "${1:-}" in
    --staged)
        MODE="staged"
        ;;
    --range)
        MODE="range"
        RANGE_A="${2:?--range requires <base> <head>}"
        RANGE_B="${3:?--range requires <base> <head>}"
        ;;
    "")
        if git diff --cached --quiet 2>/dev/null; then
            MODE="range"
            RANGE_A="HEAD~1"
            RANGE_B="HEAD"
            if ! git rev-parse --verify -q "HEAD~1" >/dev/null; then
                info "Single-commit repository; nothing to compare."
                exit 0
            fi
        else
            MODE="staged"
        fi
        ;;
    *)
        echo "Usage: $0 [--staged | --range <base> <head>]" >&2
        exit 2
        ;;
esac

diff_cmd() {
    if [ "$MODE" = "staged" ]; then
        git diff --cached --no-renames "$@"
    else
        git diff --no-renames "$RANGE_A" "$RANGE_B" "$@"
    fi
}

# Line count of a file before the change (empty output for new files)
old_line_count() {
    local file="$1"
    local ref
    if [ "$MODE" = "staged" ]; then
        ref="HEAD"
    else
        ref="$RANGE_A"
    fi
    git cat-file -e "${ref}:${file}" 2>/dev/null || return 0
    git show "${ref}:${file}" | wc -l
}

# -- Check 1: elision markers in added lines --------------------------------

check_elision_markers() {
    info "Checking added lines for AI-elision placeholder text..."

    local self="scripts/checks/check-ai-elisions.sh"
    local found=0

    local file=""
    local added
    # Walk the unified diff; track current file, test added lines.
    while IFS= read -r line; do
        case "$line" in
            +++\ b/*)
                file="${line#+++ b/}"
                continue
                ;;
            +++*)
                file=""
                continue
                ;;
            +*)
                ;;
            *)
                continue
                ;;
        esac

        [ -z "$file" ] && continue
        [ "$file" = "$self" ] && continue
        case "$file" in
            *.md) continue ;;
        esac

        added="${line#+}"
        while IFS= read -r pattern; do
            [ -z "$pattern" ] && continue
            if echo "$added" | grep -qiE "$pattern"; then
                error "$file: added line looks like an AI elision placeholder:"
                echo "    ${added}" >&2
                found=1
                break
            fi
        done <<< "$ELISION_PATTERNS"
    done < <(diff_cmd)

    if [ "$found" -eq 0 ]; then
        info "No elision placeholder text found"
    fi
}

# -- Check 2: suspicious mass deletions --------------------------------------

check_mass_deletions() {
    info "Checking modified files for suspicious mass deletions..."

    if [ "${AIXCL_ALLOW_MASS_DELETE:-}" = "1" ]; then
        print_skip "Mass-deletion check skipped (AIXCL_ALLOW_MASS_DELETE=1)"
        return 0
    fi

    # Range mode (CI): honor the bypass token when it is spelled out in a
    # commit message within the range. Same trust model as the env var --
    # the author must state the intent, and it stays auditable in review.
    # Capture-then-match, never `git log | grep -q`: under pipefail, grep's
    # early exit can SIGPIPE git mid-write on large ranges and silently
    # discard the token (#1970). A failed git log is warned, not hidden.
    if [ "$MODE" = "range" ]; then
        local range_messages
        if ! range_messages="$(git log --format=%B "${RANGE_A}..${RANGE_B}" 2>&1)"; then
            warn "token check unavailable: git log ${RANGE_A}..${RANGE_B} failed: ${range_messages}"
            range_messages=""
        fi
        case "$range_messages" in
            *AIXCL_ALLOW_MASS_DELETE*)
                print_skip "Mass-deletion check skipped (AIXCL_ALLOW_MASS_DELETE token in commit message)"
                return 0
                ;;
        esac
    fi

    local found=0
    local added deleted file
    while read -r added deleted file; do
        [ -z "$file" ] && continue
        # Binary files report "-" counts
        [ "$deleted" = "-" ] && continue
        # Only files that still exist after the change (deletions are intentional)
        if [ "$MODE" = "staged" ]; then
            git ls-files --cached --error-unmatch "$file" >/dev/null 2>&1 || continue
        else
            git cat-file -e "${RANGE_B}:${file}" 2>/dev/null || continue
        fi

        [ "$deleted" -lt "$MASS_DELETE_MIN_LINES" ] && continue

        local old_lines
        old_lines="$(old_line_count "$file")"
        [ -z "$old_lines" ] || [ "$old_lines" -eq 0 ] && continue

        local ratio=$(( deleted * 100 / old_lines ))
        if [ "$ratio" -ge "$MASS_DELETE_MIN_RATIO" ]; then
            error "$file: ${deleted} of ${old_lines} lines deleted (${ratio}%) but file still exists."
            echo "    If this rewrite is intentional, re-run with AIXCL_ALLOW_MASS_DELETE=1" >&2
            echo "    and say so in the commit message. Otherwise inspect for truncation." >&2
            found=1
        fi
    done < <(diff_cmd --numstat)

    if [ "$found" -eq 0 ]; then
        info "No suspicious mass deletions found"
    fi
}

# -- Main ---------------------------------------------------------------------

echo "========================================"
echo "AI Elision Check (${MODE}${RANGE_A:+: ${RANGE_A}..${RANGE_B}})"
echo "========================================"
echo ""

check_elision_markers
check_mass_deletions

echo ""
echo "========================================"
if [ "$ERRORS" -gt 0 ]; then
    error "Found ${ERRORS} issue(s). A diff that deletes what it claims to keep is the failure this check exists for."
    exit 1
fi
info "All elision checks passed!"
exit 0
