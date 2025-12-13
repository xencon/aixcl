#!/usr/bin/env bash
# Rename git tags

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
echo "Renaming Git Tags"
echo "=========================================="
echo ""

# Tag mappings: old_tag -> new_tag (using hyphens instead of spaces for valid git tag names)
declare -A TAG_MAPPINGS=(
    ["v1.0.0"]="v1.0.0-delta"
    ["v1.1.0"]="v1.1.0-theta"
    ["v2.0.0"]="v1.2.0-alpha"
)

# Process each tag
for old_tag in "${!TAG_MAPPINGS[@]}"; do
    new_tag="${TAG_MAPPINGS[$old_tag]}"
    
    echo "Processing: $old_tag -> $new_tag"
    
    # Check if old tag exists
    if ! git rev-parse "$old_tag" > /dev/null 2>&1; then
        echo "  ⚠ Warning: Tag '$old_tag' does not exist, skipping..."
        continue
    fi
    
    # Check if new tag already exists
    if git rev-parse "$new_tag" > /dev/null 2>&1; then
        echo "  ⚠ Warning: Tag '$new_tag' already exists, skipping..."
        continue
    fi
    
    # Get the commit hash the old tag points to
    commit_hash=$(git rev-parse "$old_tag")
    echo "  Found commit: $commit_hash"
    
    # Create new tag pointing to the same commit
    git tag "$new_tag" "$commit_hash"
    echo "  ✓ Created new tag: $new_tag"
    
    # Delete old tag
    git tag -d "$old_tag"
    echo "  ✓ Deleted old tag: $old_tag"
    
    echo ""
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Local tags have been renamed."
echo ""
echo "To push the changes to remote:"
echo "  # Push new tags"
echo "  git push origin --tags"
echo ""
echo "  # Delete old tags from remote"
for old_tag in "${!TAG_MAPPINGS[@]}"; do
    if git rev-parse "$old_tag" > /dev/null 2>&1; then
        echo "  git push origin --delete $old_tag"
    fi
done
echo ""
