#!/bin/bash
# Script to create a branch, commit changes, push, and create a PR

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

BRANCH_NAME="fix/council-config-and-paths"
COMMIT_MSG="Fix council configuration and path issues

- Remove all COUNCILLOR references from codebase
- Fix path issues in start() and related functions to use SCRIPT_DIR
- Update council_cmd to require explicit action (no default status)
- Fix status_council and list_council to use SCRIPT_DIR for .env paths
- Enhance cleanup logic to remove entire council configuration sections
- Update test script to handle empty configuration and provide clear warnings
- Fix test summary to not show false 'all operational' messages when config is empty
- Add automatic config reload attempt in test before warning about restart needed"

echo "🔀 Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"

echo "📝 Staging all changes..."
git add -A

echo "💾 Committing changes..."
git commit -m "$COMMIT_MSG" || {
    echo "⚠️  No changes to commit or commit failed"
    exit 1
}

echo "📤 Pushing branch to remote..."
git push -u origin "$BRANCH_NAME" || {
    echo "❌ Failed to push branch. Please check your git remote configuration."
    exit 1
}

echo ""
echo "✅ Branch pushed successfully!"
echo ""
echo "To create a PR, you can:"
echo "  1. Use GitHub CLI: gh pr create --title 'Fix council configuration and path issues' --body '$COMMIT_MSG'"
echo "  2. Visit: https://github.com/xencon/aixcl/compare/$BRANCH_NAME"
echo ""

# Try to create PR with GitHub CLI if available
if command -v gh &> /dev/null; then
    echo "🔗 Attempting to create PR with GitHub CLI..."
    gh pr create \
        --title "Fix council configuration and path issues" \
        --body "$COMMIT_MSG" \
        --base main \
        --head "$BRANCH_NAME" || {
        echo "⚠️  Failed to create PR automatically. Please create it manually using the link above."
    }
else
    echo "ℹ️  GitHub CLI (gh) not found. Please create the PR manually using the link above."
fi

echo ""
echo "✅ Done!"
