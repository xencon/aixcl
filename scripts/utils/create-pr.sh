#!/usr/bin/env bash
# create-pr.sh — Safe pull request creation wrapper
# Usage: ./scripts/utils/create-pr.sh "Title (#42)" "Fixes #42" "component:cli" "sbadakhc"
#
# Benefits over manual gh pr create:
# - Always passes --assignee at creation time (no PR validation race condition)
# - Always uses --body-file with /tmp (no backtick injection)
# - Validates title format before creation
# - Validates branch name format before creation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"

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

# Validate branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ ! "$BRANCH" =~ ^issue-[0-9]+/ ]]; then
    echo "WARNING: Branch '$BRANCH' does not follow 'issue-N/description' format"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if [[ -z "$ASSIGNEE" ]]; then
    echo "ERROR: Assignee required. Set GITHUB_USER or pass as 4th argument."
    exit 1
fi

# Create body file in /tmp
BODY_FILE="$(mktemp /tmp/aixcl-pr-XXXXXX.md)"
trap 'rm -f "$BODY_FILE"' EXIT

cat > "$BODY_FILE" <<EOF
${BODY}
EOF

echo "Creating PR: $TITLE"
echo "  Branch: $BRANCH → $BASE"
echo "  Labels: $LABELS"
echo "  Assignee: $ASSIGNEE"

# CRITICAL: --assignee passed at creation time (not edit afterward)
# This prevents the PR validation race condition
gh pr create \
    --title "$TITLE" \
    --body-file "$BODY_FILE" \
    --base "$BASE" \
    --assignee "$ASSIGNEE" \
    ${LABELS:+--label "$LABELS"}

# Add labels if not passed at creation (fallback)
if [[ -n "$LABELS" ]] && ! echo "$LABELS" | grep -q ','; then
    PR_NUM=$(gh pr view --json number -q '.number')
    gh pr edit "$PR_NUM" --add-label "$LABELS" 2>/dev/null || true
fi

echo "✅ PR created successfully"
