#!/usr/bin/env bash
# create-issue.sh — Safe issue creation wrapper
# Usage: ./scripts/utils/create-issue.sh "[TASK] Title" "task" "component:cli" "<github-username>" [body-file]
#
# Benefits over manual gh issue create:
# - Targets the canonical repo regardless of which clone you run from
# - Uses /tmp for body files (never touches repo)
# - Always uses --body-file (no backtick injection risk)
# - Always sets --assignee (no PR validation race condition)
# - Validates issue type prefix before creation
# - With a body-file argument, validates reference style (one issue/PR
#   reference per list item) before creation -- the same rule the
#   pr-ready merge gate enforces on issue bodies later (#1883)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"

# Canonical repository issues are filed against (override for forks of the fork)
UPSTREAM_REPO="${AIXCL_UPSTREAM_REPO:-xencon/aixcl}"

# Arguments
TITLE="${1:-}"
TYPE="${2:-task}"        # bug, feature, task
LABELS="${3:-}"
ASSIGNEE="${4:-${GITHUB_USER:-}}"
CUSTOM_BODY="${5:-}"     # optional: path to a ready-made body file

# Validate
if [[ -z "$TITLE" ]]; then
    echo "Usage: $0 \"[TYPE] Title\" [type] [labels] [assignee] [body-file]"
    echo "  type: bug | feature | task"
    echo "  body-file: optional ready-made body (validated, replaces the template)"
    exit 1
fi

if [[ -n "$CUSTOM_BODY" ]] && [[ ! -f "$CUSTOM_BODY" ]]; then
    echo "ERROR: Body file not found: $CUSTOM_BODY"
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

if [[ -n "$CUSTOM_BODY" ]]; then
    # Custom body: validate reference style before anything reaches GitHub.
    # The pr-ready gate applies this same check to issue bodies at merge
    # time; catching it here saves a round-trip (#1883).
    if [[ -f "${SCRIPT_DIR}/scripts/checks/check-pr-references.sh" ]]; then
        if ! bash "${SCRIPT_DIR}/scripts/checks/check-pr-references.sh" < "$CUSTOM_BODY"; then
            echo "ERROR: Body failed reference style check (one reference per list item)"
            echo "  Reminder: checkboxes only satisfiable after a merge need a '(post-merge)' suffix."
            exit 1
        fi
    fi
    cp "$CUSTOM_BODY" "$BODY_FILE"
elif [[ -f "$TEMPLATE_FILE" ]]; then
    # Read template and strip frontmatter
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
    --repo "$UPSTREAM_REPO" \
    --title "$TITLE" \
    --body-file "$BODY_FILE" \
    ${LABELS:+--label "$LABELS"} \
    --assignee "$ASSIGNEE"

# Cleanup handled by trap
echo "✅ Issue created successfully"
