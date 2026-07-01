#!/usr/bin/env bash
# create-pr.sh — Safe pull request creation wrapper
# Usage: ./scripts/utils/create-pr.sh "Title (#42)" "Fixes #42" "component:cli" "<github-username>" [base]
#
# Benefits over manual gh pr create:
# - Targets the canonical repo and passes fork-aware --head automatically
# - Always passes --assignee at creation time (no PR validation race condition)
# - Always uses --body-file with /tmp (no backtick injection)
# - Validates title format, branch name, and body reference style before creation
# - Non-interactive safe: fails hard instead of prompting (agent-friendly)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"

# Canonical repository PRs target (override for forks of the fork)
UPSTREAM_REPO="${AIXCL_UPSTREAM_REPO:-xencon/aixcl}"

# Arguments
TITLE="${1:-}"
BODY="${2:-}"
LABELS="${3:-}"
ASSIGNEE="${4:-${GITHUB_USER:-}}"
BASE="${5:-dev}"

# Validate
if [[ -z "$TITLE" ]] || [[ -z "$BODY" ]]; then
    echo "Usage: $0 \"Title (#42)\" \"Fixes #42\" [labels] [assignee] [base]"
    exit 1
fi

# Validate title format (no colons before issue reference)
if echo "$TITLE" | grep -qE '^[^:]+:'; then
    echo "ERROR: PR title must not contain colons before the issue reference"
    exit 1
fi

# Validate title ends with (#number)
if ! echo "$TITLE" | grep -qE '\(#[0-9]+\)$'; then
    echo "ERROR: PR title must end with issue reference '(#number)'"
    exit 1
fi

# Extract issue number from title (e.g. "Description (#42)" => 42)
ISSUE_NUM=$(echo "$TITLE" | grep -oE '#[0-9]+' | tr -d '#' | tail -1)

# Validate branch name (hard error -- no interactive prompt, agents have no TTY)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ ! "$BRANCH" =~ ^issue-[0-9]+/ ]] && [[ ! "$BRANCH" =~ ^(dev|main)$ ]]; then
    echo "ERROR: Branch '$BRANCH' does not follow 'issue-N/description' format"
    echo "  Rename it (git branch -m issue-N/description) or create the PR manually."
    exit 1
fi

if [[ -z "$ASSIGNEE" ]]; then
    echo "ERROR: Assignee required. Set GITHUB_USER or pass as 4th argument."
    exit 1
fi

# Fork-aware head: if origin is a fork of the canonical repo, gh needs
# --head <fork-owner>:<branch> or PR creation fails from a fork clone.
ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
ORIGIN_OWNER=$(echo "$ORIGIN_URL" | sed -E 's#(git@github\.com:|https://github\.com/)([^/]+)/.*#\2#')
UPSTREAM_OWNER="${UPSTREAM_REPO%%/*}"

HEAD_REF="$BRANCH"
if [[ -n "$ORIGIN_OWNER" ]] && [[ "$ORIGIN_OWNER" != "$UPSTREAM_OWNER" ]]; then
    HEAD_REF="${ORIGIN_OWNER}:${BRANCH}"
fi

# Read PR template and substitute issue number
TEMPLATE_FILE="${SCRIPT_DIR}/.github/PULL_REQUEST_TEMPLATE.md"
BODY_FILE="$(mktemp /tmp/aixcl-pr-XXXXXX.md)"
trap 'rm -f "$BODY_FILE"' EXIT

if [[ -f "$TEMPLATE_FILE" ]]; then
    # Replace placeholder with actual issue reference
    sed "s/#<ISSUE_NUMBER>/${ISSUE_NUM}/g" "$TEMPLATE_FILE" > "$BODY_FILE"
    # Append any additional body content if provided
    if [[ -n "$BODY" ]]; then
        echo "" >> "$BODY_FILE"
        echo "## Additional Notes" >> "$BODY_FILE"
        echo "" >> "$BODY_FILE"
        echo "$BODY" >> "$BODY_FILE"
    fi
else
    cat > "$BODY_FILE" <<EOF
${BODY}
EOF
fi

# Validate body reference style before creation (same check CI enforces)
if [[ -f "${SCRIPT_DIR}/scripts/checks/check-pr-references.sh" ]]; then
    if ! bash "${SCRIPT_DIR}/scripts/checks/check-pr-references.sh" < "$BODY_FILE"; then
        echo "ERROR: PR body failed reference style check (one reference per line)"
        exit 1
    fi
fi

echo "Creating PR: $TITLE"
echo "  Repo:   $UPSTREAM_REPO"
echo "  Head:   $HEAD_REF → $BASE"
echo "  Labels: $LABELS"
echo "  Assignee: $ASSIGNEE"

# CRITICAL: --assignee passed at creation time (not edit afterward)
# This prevents the PR validation race condition
gh pr create \
    --repo "$UPSTREAM_REPO" \
    --head "$HEAD_REF" \
    --title "$TITLE" \
    --body-file "$BODY_FILE" \
    --base "$BASE" \
    --assignee "$ASSIGNEE" \
    ${LABELS:+--label "$LABELS"}

echo "✅ PR created successfully"
