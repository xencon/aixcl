#!/usr/bin/env bash
# Merge-readiness gate for a pull request and its linked issue
# Validates title format, assignee, label taxonomy, checkbox completion,
# body reference style, and CI state before a merge is performed.
# Usage: check-pr-ready.sh <pr-number> [owner/repo]
# Exit code: 0 if the PR is ready to merge, 1 otherwise

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0
WARNINGS=0

# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/core/color.sh"

error() {
    echo -e "${RED}${ICON_ERROR:-[FAIL]}${NC} $1" >&2
    ((ERRORS++)) || true
}

warn() {
    echo -e "${YELLOW}${ICON_WARNING:-[WARN]}${NC} $1" >&2
    ((WARNINGS++)) || true
}

info() {
    print_info "$1"
}

PR_NUMBER="${1:-}"
REPO="${2:-${AIXCL_UPSTREAM_REPO:-xencon/aixcl}}"

if [[ -z "$PR_NUMBER" ]] || [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <pr-number> [owner/repo]"
    exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
    echo "gh CLI not installed"
    exit 1
fi

# Label taxonomy from AGENTS.md Section 3 (exact case)
TYPE_LABELS="Bug Feature Task"
CATEGORY_LABELS="Fix Enhancement Refactor Maintenance"
PRIORITY_LABELS="P1 P2 P3"

_in_list() {
    local needle="$1" haystack="$2" item
    for item in $haystack; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

_taxonomy_label() {
    local label="$1"
    _in_list "$label" "$TYPE_LABELS" && return 0
    _in_list "$label" "$CATEGORY_LABELS" && return 0
    _in_list "$label" "$PRIORITY_LABELS" && return 0
    [[ "$label" == component:* ]] && return 0
    [[ "$label" == profile:* ]] && return 0
    [[ "$label" == agent:* ]] && return 0
    return 1
}

_report_unchecked() {
    local body="$1" context="$2" line
    while IFS= read -r line; do
        # Boxes marked "(post-merge)" track release-lifecycle steps (tag,
        # publish, sync) that can only become true after the PR merges --
        # release prep stamps them; they inform but never block (issue #1778).
        if [[ "$line" == *"(post-merge)"* ]]; then
            info "$context post-merge item (not blocking): $line"
        else
            error "$context has an unticked checkbox: $line"
        fi
    done < <(echo "$body" | grep -E '^\s*- \[ \]' || true)
}

echo "========================================"
echo "PR Merge-Readiness Check: #${PR_NUMBER} (${REPO})"
echo "========================================"

# --- Fetch PR ---
info "Fetching PR #${PR_NUMBER}..."
PR_JSON=$(gh pr view "$PR_NUMBER" --repo "$REPO" \
    --json title,body,state,isDraft,assignees,labels 2>/dev/null) || {
    echo "Could not fetch PR #${PR_NUMBER} from ${REPO}"
    exit 1
}

PR_TITLE=$(jq -r '.title' <<<"$PR_JSON")
PR_BODY=$(jq -r '.body' <<<"$PR_JSON")
PR_STATE=$(jq -r '.state' <<<"$PR_JSON")
PR_DRAFT=$(jq -r '.isDraft' <<<"$PR_JSON")

# --- PR state ---
info "Checking PR state..."
[[ "$PR_STATE" == "OPEN" ]] || error "PR state is ${PR_STATE}, expected OPEN"
[[ "$PR_DRAFT" == "false" ]] || error "PR is a draft"

# --- PR title format ---
info "Checking PR title format..."
if [[ "$PR_TITLE" == *:* ]]; then
    error "PR title contains a colon: ${PR_TITLE}"
fi
if [[ ! "$PR_TITLE" =~ \(#([0-9]+)\)$ ]]; then
    error "PR title must end with '(#<number>)': ${PR_TITLE}"
    ISSUE_NUMBER=""
else
    ISSUE_NUMBER="${BASH_REMATCH[1]}"
fi

# --- PR assignee and labels ---
info "Checking PR assignee and labels..."
PR_ASSIGNEES=$(jq -r '[.assignees[].login] | length' <<<"$PR_JSON")
[[ "$PR_ASSIGNEES" -gt 0 ]] || error "PR has no assignee"

PR_HAS_COMPONENT=false
while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    [[ "$label" == component:* ]] && PR_HAS_COMPONENT=true
    if ! _taxonomy_label "$label"; then
        warn "PR label outside AGENTS.md taxonomy: ${label}"
    fi
done < <(jq -r '.labels[].name' <<<"$PR_JSON")
[[ "$PR_HAS_COMPONENT" == true ]] || error "PR has no component:* label"

# --- PR checkboxes and references ---
info "Checking PR body checkboxes..."
_report_unchecked "$PR_BODY" "PR #${PR_NUMBER}"

info "Checking PR body reference style..."
if ! echo "$PR_BODY" | bash "${REPO_ROOT}/scripts/checks/check-pr-references.sh" > /dev/null 2>&1; then
    error "PR body fails reference style check (run: ./aixcl checks pr-refs <body-file>)"
fi

# --- Linked issue ---
if [[ -n "$ISSUE_NUMBER" ]]; then
    info "Fetching linked issue #${ISSUE_NUMBER}..."
    if ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" \
        --json title,body,assignees,labels 2>/dev/null); then

        ISSUE_TITLE=$(jq -r '.title' <<<"$ISSUE_JSON")
        ISSUE_BODY=$(jq -r '.body' <<<"$ISSUE_JSON")

        info "Checking issue title format..."
        # An optional [OVERRIDE] prefix is allowed before the type tag for
        # emergency-workflow-override issues (AGENTS.md Section 8)
        if [[ ! "$ISSUE_TITLE" =~ ^(\[OVERRIDE\]\ )?\[(BUG|FEATURE|TASK)\]\  ]]; then
            error "Issue title must start with [BUG], [FEATURE], or [TASK] (optionally prefixed with [OVERRIDE]): ${ISSUE_TITLE}"
        fi
        if [[ "$ISSUE_TITLE" == *:* ]]; then
            error "Issue title contains a colon: ${ISSUE_TITLE}"
        fi

        info "Checking issue assignee and labels..."
        ISSUE_ASSIGNEES=$(jq -r '[.assignees[].login] | length' <<<"$ISSUE_JSON")
        [[ "$ISSUE_ASSIGNEES" -gt 0 ]] || error "Issue #${ISSUE_NUMBER} has no assignee"

        ISSUE_HAS_COMPONENT=false
        ISSUE_TYPE_COUNT=0
        while IFS= read -r label; do
            [[ -z "$label" ]] && continue
            [[ "$label" == component:* ]] && ISSUE_HAS_COMPONENT=true
            _in_list "$label" "$TYPE_LABELS" && ((ISSUE_TYPE_COUNT++)) || true
            if ! _taxonomy_label "$label"; then
                warn "Issue label outside AGENTS.md taxonomy: ${label}"
            fi
        done < <(jq -r '.labels[].name' <<<"$ISSUE_JSON")
        [[ "$ISSUE_HAS_COMPONENT" == true ]] || error "Issue #${ISSUE_NUMBER} has no component:* label"
        [[ "$ISSUE_TYPE_COUNT" -eq 1 ]] || error "Issue #${ISSUE_NUMBER} must have exactly one type label (Bug/Feature/Task), found ${ISSUE_TYPE_COUNT}"

        info "Checking issue body checkboxes..."
        _report_unchecked "$ISSUE_BODY" "Issue #${ISSUE_NUMBER}"

        info "Checking issue body reference style..."
        if ! echo "$ISSUE_BODY" | bash "${REPO_ROOT}/scripts/checks/check-pr-references.sh" > /dev/null 2>&1; then
            error "Issue body fails reference style check"
        fi
    else
        error "Linked issue #${ISSUE_NUMBER} not found in ${REPO}"
    fi
fi

# --- CI state ---
info "Checking CI state..."
CHECKS_JSON=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --json name,bucket 2>/dev/null || echo "[]")
if [[ $(jq 'length' <<<"$CHECKS_JSON") -eq 0 ]]; then
    warn "No CI checks reported yet"
else
    while IFS= read -r line; do
        error "CI check not green: $line"
    done < <(jq -r '.[] | select(.bucket != "pass" and .bucket != "skipping") | "\(.name): \(.bucket)"' <<<"$CHECKS_JSON")
fi

# --- Summary ---
echo ""
echo "========================================"
if [[ "$ERRORS" -gt 0 ]]; then
    echo "NOT READY: ${ERRORS} blocking issue(s), ${WARNINGS} warning(s)"
    exit 1
fi
if [[ "$WARNINGS" -gt 0 ]]; then
    info "Ready to merge (${WARNINGS} warning(s) to review)"
else
    info "Ready to merge"
fi
exit 0
