# Create Pull Request

## Quick Method

Run the commit script:

```bash
bash commit_and_pr.sh
```

This will:
1. Create/switch to `refactor/aixcl-modular-structure` branch
2. Stage all changes
3. Create commit with detailed message
4. Push to remote
5. Provide PR creation instructions

## Manual Method

### 1. Create Branch and Commit

```bash
# Create branch
git checkout -b refactor/aixcl-modular-structure

# Stage all changes
git add -A

# Commit
git commit -F .gitmessage

# Push
git push -u origin refactor/aixcl-modular-structure
```

### 2. Create Pull Request

#### Option A: GitHub Web Interface

1. Visit: https://github.com/xencon/aixcl/compare/refactor/aixcl-modular-structure
2. Click "Create Pull Request"
3. Use the content from `PR_DESCRIPTION.md` for the description
4. Set title: "Refactor: Modular AIXCL structure"
5. Submit

#### Option B: GitHub CLI

```bash
gh pr create \
  --title "Refactor: Modular AIXCL structure" \
  --body-file PR_DESCRIPTION.md \
  --base main \
  --head refactor/aixcl-modular-structure
```

## PR Details

**Title:** Refactor: Modular AIXCL structure

**Description:** See `PR_DESCRIPTION.md` for full description

**Key Points:**
- Modular structure with comprehensive testing
- All functionality preserved
- Breaking changes documented
- Complete documentation included
- Continue plugin integration verified
