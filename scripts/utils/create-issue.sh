#!/usr/bin/env bash
# create-issue.sh — Safe issue creation wrapper
# Usage: ./scripts/utils/create-issue.sh "[TASK] Title" "task" "component:cli" "sbadakhc"
#
# Benefits over manual gh issue create:
# - Uses /tmp for body files (never touches repo)
# - Always uses --body-file (no backtick injection risk)
# - Always sets --assignee (no PR validation race condition)
# - Validates issue type prefix before creation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"

# Arguments
TITLE="${1:-}"
TYPE="${2:-task}"        # bug, feature, task
LABELS="${3:-}"
ASSIGNEE="${4:-${GITHUB_USER:-}}"

# Validate
if [[ -z "$TITLE" ]]; then
    echo "Usage: $0 \"[TYPE] Title\" [type] [labels] [assignee]"
    echo "  type: bug | feature | task"
    exit 1
fi

if [[ ! "$TITLE" =~ ^\[(BUG|FEATURE|TASK)\]\  ]]; then
    echo "ERROR: Title must start with [BUG], [FEATURE], or [TASK]"
    exit 1
fi

if [[ -z "$ASSIGNEE" ]]; then
    echo "ERROR: Assignee required. Set GITHUB_USER or pass as 4th argument."
    exit 1
fi

# Select template
TEMPLATE_FILE=""
case "$TYPE" in
    bug)      TEMPLATE_FILE="${SCRIPT_DIR}/.github/ISSUE_TEMPLATE/bug_report.md" ;;
    feature)  TEMPLATE_FILE="${SCRIPT_DIR}/.github/ISSUE_TEMPLATE/feature_request.md" ;;
    task)     TEMPLATE_FILE="${SCRIPT_DIR}/.github/ISSUE_TEMPLATE/task.md" ;;
    *)        echo "ERROR: Unknown type '$TYPE'. Use: bug, feature, task"; exit 1 ;;
esac

# Create body file in /tmp
BODY_FILE="$(mktemp /tmp/aixcl-issue-XXXXXX.md)"
trap 'rm -f "$BODY_FILE"' EXIT

# Read template and strip frontmatter
if [[ -f "$TEMPLATE_FILE" ]]; then
    sed '1,/^---$/d' "$TEMPLATE_FILE" > "$BODY_FILE"
else
    cat > "$BODY_FILE" << 'EOF'
## Summary

## Deliverables
- [ ] Step 1

## Verification
- [ ] Complete
EOF
fi

echo "Creating issue: $TITLE"
echo "  Labels: $LABELS"
echo "  Assignee: $ASSIGNEE"

# Create the issue
gh issue create \
    --title "$TITLE" \
    --body-file "$BODY_FILE" \
    ${LABELS:+--label "$LABELS"} \
    --assignee "$ASSIGNEE"

# Cleanup handled by trap
echo "✅ Issue created successfully"
