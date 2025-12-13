#!/usr/bin/env bash
# Delete unnecessary tags from remote to match local tags

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

REMOTE="${1:-origin}"

echo "=========================================="
echo "Cleaning Up Remote Tags"
echo "=========================================="
echo ""
echo "This will delete the following tags from remote:"
echo "  - v1.0.0 (replaced by v1.0.0-delta)"
echo "  - v2.0.0 (replaced by v1.2.0-alpha)"
echo ""

# Tags to delete from remote
TAGS_TO_DELETE=("v1.0.0" "v2.0.0")

echo "Checking which tags exist on remote..."
echo ""

# Check and delete each tag
for tag in "${TAGS_TO_DELETE[@]}"; do
    if git ls-remote --tags "$REMOTE" | grep -q "refs/tags/$tag$"; then
        echo "Deleting remote tag: $tag"
        git push "$REMOTE" --delete "$tag"
        echo "  ✓ Deleted remote tag: $tag"
    else
        echo "  ⚠ Tag '$tag' does not exist on remote, skipping..."
    fi
    echo ""
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Remote tags cleaned up."
echo ""
echo "Current remote tags:"
git ls-remote --tags "$REMOTE" | grep -oP 'refs/tags/\K.*' | grep -v '\^{}' | sort -V
