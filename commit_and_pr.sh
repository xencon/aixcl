#!/usr/bin/env bash
# Script to commit changes and prepare for PR creation

set -euo pipefail

echo "=========================================="
echo "Committing AIXCL Refactoring Changes"
echo "=========================================="
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Get current branch (fallback for older Git)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "Current branch: $CURRENT_BRANCH"

# Define branch name
BRANCH_NAME="refactor/aixcl-modular-structure"

# Switch or create branch if needed
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
        echo "Switching to existing branch: $BRANCH_NAME"
        git checkout "$BRANCH_NAME"
    else
        echo "Creating branch: $BRANCH_NAME"
        git checkout -b "$BRANCH_NAME"
    fi
fi

echo ""
echo "Staging all changes..."
git add -A

echo ""
echo "Changes to be committed:"
git status --short

echo ""
echo "Creating commit..."
if [ -f COMMIT_MESSAGE.txt ]; then
    git commit -F COMMIT_MESSAGE.txt
else
    git commit -m "Refactor: Modular AIXCL structure" -m "- Extract monolithic script into modular CLI structure
- Create cli/, lib/, services/, completion/, docs/, tests/ directories
- Implement nested command structure (aixcl stack start)
- Extract all CLI modules and shared libraries
- Remove unused LLM council frontend code
- Add comprehensive test suite
- Create complete documentation
- Verify Continue plugin integration

Breaking changes:
- Command structure: aixcl start -> aixcl.sh stack start
- Utils: aixcl check-env -> aixcl.sh utils check-env"
fi

echo ""
echo "✅ Commit created successfully!"
echo ""

# Check if remote exists
if git remote get-url origin >/dev/null 2>&1; then
    echo "Pushing to remote..."
    git push -u origin "$BRANCH_NAME"
    echo ""
    echo "✅ Branch pushed to remote!"
    echo ""

    echo "To create a Pull Request:"
    echo "  1. Visit: https://github.com/xencon/aixcl/compare/$BRANCH_NAME"
    
    if command -v gh >/dev/null 2>&1; then
        echo "  2. Or use GitHub CLI:"
        echo "     gh pr create --title 'Refactor: Modular AIXCL structure' --body-file PR_DESCRIPTION.md"
    fi
else
    echo "⚠️  No remote configured. Commit is local only."
    echo "   To push later: git push -u origin $BRANCH_NAME"
fi

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="

