---
name: "Create Release"
description: "Automates the complete release process from version detection to GitHub publication"
role: system
---

# Action: Create Release

Automates the AIXCL release workflow end-to-end.

## Prerequisites

- `gh` CLI installed and authenticated
- `git` configured with push access
- Valid semantic versioning understanding
- Clean working tree

## Workflow Steps

### Step 1: Detect Current State

```bash
# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Get latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

# Check working tree status
if [ -n "$(git status --short)" ]; then
    echo "❌ Working tree has uncommitted changes"
    exit 1
fi

# Check CI status (if PR exists)
gh pr checks 2>/dev/null || echo "⚠️ No open PR, skipping CI check"

# Verify CHANGELOG has Unreleased section
if ! grep -q "^## \\[Unreleased\\]" CHANGELOG.md; then
    echo "❌ CHANGELOG.md missing [Unreleased] section"
    exit 1
fi
```

**Success Criteria:**
- On main branch
- Clean working tree
- CHANGELOG has [Unreleased] section

### Step 2: Determine Version

```bash
# Parse latest tag
MAJOR=$(echo $LATEST_TAG | cut -d. -f1 | sed 's/v//')
MINOR=$(echo $LATEST_TAG | cut -d. -f2)
PATCH=$(echo $LATEST_TAG | cut -d. -f3 | cut -d- -f1)
RC=$(echo $LATEST_TAG | grep -o 'rc[0-9]*' | sed 's/rc//' || echo "")

# Suggest next version
if [ -n "$RC" ]; then
    NEXT_RC=$((RC + 1))
    SUGGESTED="v${MAJOR}.${MINOR}.${PATCH}-rc${NEXT_RC}"
    ALTERNATIVE="v${MAJOR}.${MINOR}.${PATCH}"
else
    SUGGESTED="v${MAJOR}.${MINOR}.$((PATCH + 1))"
    ALTERNATIVE="v${MAJOR}.$((MINOR + 1)).0"
fi

echo "Latest: $LATEST_TAG"
echo "Suggested: $SUGGESTED"
echo "Alternative: $ALTERNATIVE"
```

**User Prompt:**
- Present suggested version
- Allow custom version input
- Validate semantic versioning

### Step 3: Validate Version

```bash
RELEASE_VERSION="$1"  # User input

# Validate semver format
if [[ ! $RELEASE_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$ ]]; then
    echo "❌ Invalid version format. Use: vX.Y.Z or vX.Y.Z-rcN"
    exit 1
fi

# Check tag doesn't exist
if git rev-parse "$RELEASE_VERSION" >/dev/null 2>&1; then
    echo "❌ Tag $RELEASE_VERSION already exists"
    exit 1
fi

echo "✅ Version $RELEASE_VERSION validated"
```

### Step 4: Generate Release Notes

```bash
# Read current and previous tag names
LATEST_TAG=$(git describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo "v0.0.0")

# Extract Unreleased section from CHANGELOG — first line is the summary
CHANGELOG_SUMMARY=$(sed -n '/^## \[Unreleased\]/,/^## \[v/p' CHANGELOG.md | grep -v "^## " | grep -v "^###" | grep "^$" | head -1)

# Generate release notes in unified format
RELEASE_NOTES="## AIXCL $RELEASE_VERSION

**$CHANGELOG_SUMMARY**

### What's New in $RELEASE_VERSION

$(sed -n '/^## \[Unreleased\]/,/^## \[v/p' CHANGELOG.md | sed 's/^### /#### /' | grep -v "^## \[" | grep -v "^---$" | grep -v "^$(date +%Y-%m-%d)$" | sed 's/^- /- ✅ /')

### Installation

\`\`\`bash
git clone https://github.com/xencon/aixcl.git
cd aixcl
./aixcl utils check-env
./aixcl stack start --profile usr
\`\`\`

### Documentation
- [Getting Started](README.md)
- [Development Workflow](DEVELOPMENT.md)
- [Changelog](CHANGELOG.md)

---

**Full Changelog**: https://github.com/xencon/aixcl/compare/${LATEST_TAG}...${RELEASE_VERSION}
"

echo "$RELEASE_NOTES"
```

**Present to user for approval.**

### Step 5: Update CHANGELOG

```bash
TODAY=$(date +%Y-%m-%d)

# Create backup
cp CHANGELOG.md CHANGELOG.md.bak

# Update CHANGELOG
sed -i "s/^## \\[Unreleased\\]/## [Unreleased]\n\n---\n\n## [$RELEASE_VERSION] - $TODAY/" CHANGELOG.md

echo "✅ CHANGELOG.md updated"
```

### Step 6: Commit CHANGELOG Update

```bash
git add CHANGELOG.md
git commit -m "docs: Update CHANGELOG for $RELEASE_VERSION

- Move [Unreleased] to [$RELEASE_VERSION] - $(date +%Y-%m-%d)
- Add new [Unreleased] section

Fixes release preparation"

git push origin main

echo "✅ CHANGELOG committed and pushed"
```

### Step 7: Create Git Tag

```bash
git tag -a "$RELEASE_VERSION" -m "Release $RELEASE_VERSION

$(echo "$UNRELEASED" | grep -v "^###" | grep -v "^$" | head -5)

git push origin "$RELEASE_VERSION"

echo "✅ Tag $RELEASE_VERSION created and pushed"
```

### Step 8: Create GitHub Release

```bash
# Create release using gh CLI
gh release create "$RELEASE_VERSION" \
    --title "Release $RELEASE_VERSION" \
    --notes "$RELEASE_NOTES" \
    --latest

echo "✅ GitHub Release $RELEASE_VERSION published"
```

### Step 9: Verification

```bash
# Verify tag exists on remote
if git ls-remote --tags origin | grep -q "$RELEASE_VERSION"; then
    echo "✅ Tag $RELEASE_VERSION exists on remote"
else
    echo "❌ Tag $RELEASE_VERSION not found on remote"
    exit 1
fi

# Verify release exists
if gh release view "$RELEASE_VERSION" >/dev/null 2>&1; then
    echo "✅ GitHub Release $RELEASE_VERSION exists"
else
    echo "❌ GitHub Release $RELEASE_VERSION not found"
    exit 1
fi

# Verify CHANGELOG
grep -q "^## \\[$RELEASE_VERSION\\]" CHANGELOG.md
echo "✅ CHANGELOG.md updated"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Release $RELEASE_VERSION Complete! 🎉"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Release URL: https://github.com/xencon/aixcl/releases/tag/$RELEASE_VERSION"
echo ""
```

## Error Handling

| Error | Recovery |
|-------|----------|
| Working tree dirty | Commit or stash changes first |
| Tag exists | Delete tag or use different version |
| CI failing | Fix failures before releasing |
| No Unreleased section | Add section to CHANGELOG |
| GitHub auth fail | Run `gh auth login` |

## Dry Run Mode

When `--dry-run` flag provided:
- Execute all validation steps
- Show commands that would run
- Skip actual changes (tag creation, push, release)
- Generate preview report

## Template Variables

The following variables are available in templates:

| Variable | Description |
|----------|-------------|
| `{{RELEASE_VERSION}}` | Version being released |
| `{{PREVIOUS_VERSION}}` | Last released version |
| `{{RELEASE_DATE}}` | Today's date (YYYY-MM-DD) |
| `{{CHANGELOG_SECTION}}` | Parsed [Unreleased] content |

## Related

- Command: `.opencode/commands/release.md`
- Template: `ai/templates/release/release_notes.md`
- Template: `.github/RELEASE_TEMPLATE.md`
