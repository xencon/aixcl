#!/usr/bin/env bash
# Delete old git tags that have been renamed

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

echo "=========================================="
echo "Deleting Old Git Tags"
echo "=========================================="
echo ""

# Old tags to delete
OLD_TAGS=("v1.0.0" "v1.1.0" "v2.0.0")

# Delete tags locally
for tag in "${OLD_TAGS[@]}"; do
    if git rev-parse "$tag" > /dev/null 2>&1; then
        echo "Deleting local tag: $tag"
        git tag -d "$tag"
        echo "  ✓ Deleted local tag: $tag"
    else
        echo "  ⚠ Tag '$tag' does not exist locally, skipping..."
    fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Local tags have been deleted."
echo ""
echo "To delete tags from remote, run:"
for tag in "${OLD_TAGS[@]}"; do
    echo "  git push origin --delete $tag"
done
echo ""
