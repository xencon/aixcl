#!/bin/bash
# Script to create branch, commit, push, and create PR

set -e

cd "$(dirname "$0")/.."

BRANCH_NAME="fix/council-config-and-paths"
COMMIT_MSG="Fix council configuration and path issues

- Remove all COUNCILLOR references from codebase
- Fix path issues in start() and related functions to use SCRIPT_DIR
- Update council_cmd to require explicit action (no default status)
- Fix status_council and list_council to use SCRIPT_DIR for .env paths
- Enhance cleanup logic to remove entire council configuration sections
- Update test script to handle empty configuration and provide clear warnings
- Fix test summary to not show false 'all operational' messages when config is empty
- Add automatic config reload attempt in test before warning about restart needed
- Clean up temporary helper scripts"

echo "🔀 Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"

echo "📝 Staging all changes..."
git add -A

echo "💾 Committing changes..."
if git diff --cached --quiet; then
    echo "⚠️  No changes to commit"
    exit 0
fi

git commit -m "$COMMIT_MSG"

echo "📤 Pushing branch to remote..."
git push -u origin "$BRANCH_NAME"

echo ""
echo "✅ Branch pushed successfully!"
echo ""

# Try to create PR with GitHub CLI if available
if command -v gh &> /dev/null; then
    echo "🔗 Creating PR with GitHub CLI..."
    PR_BODY="This PR fixes several issues with council configuration and path handling:

- Remove all COUNCILLOR references from codebase
- Fix path issues in start() and related functions to use SCRIPT_DIR
- Update council_cmd to require explicit action (no default status)
- Fix status_council and list_council to use SCRIPT_DIR for .env paths
- Enhance cleanup logic to remove entire council configuration sections
- Update test script to handle empty configuration and provide clear warnings
- Fix test summary to not show false 'all operational' messages when config is empty
- Add automatic config reload attempt in test before warning about restart needed
- Clean up temporary helper scripts"

    gh pr create \
        --title "Fix council configuration and path issues" \
        --body "$PR_BODY" \
        --base main \
        --head "$BRANCH_NAME" && {
        echo ""
        echo "✅ PR created successfully!"
    } || {
        echo ""
        echo "⚠️  Failed to create PR automatically."
        echo "   Please create it manually at:"
        echo "   https://github.com/xencon/aixcl/compare/$BRANCH_NAME"
    }
else
    echo "ℹ️  GitHub CLI (gh) not found."
    echo "   Please create the PR manually at:"
    echo "   https://github.com/xencon/aixcl/compare/$BRANCH_NAME"
fi

echo ""
echo "✅ Done!"
