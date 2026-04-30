---
name: Create Branch
description: Creates a feature branch from dev following the branch naming convention
category: workflow
tool: git
requires:
  - git installed
  - Local clone of repository
  - Issue number available
---

# Action: Create Branch

Creates a feature branch from `dev` following AIXCL branch naming conventions.

## Commands

```bash
# Checkout dev and pull latest
git checkout dev
git pull origin dev

# Create branch
git checkout -b issue-<number>/<short-description>
```

## Branch Naming Format

```
issue-<number>/<short-description>
```

**Examples:**
- `issue-217/fix-encoding-problem`
- `issue-42/add-user-authentication`
- `issue-156/update-documentation`

## Parameters

- **number**: Issue number (e.g., 217)
- **short-description**: 2-4 word hyphenated description

## Process

1. Verify issue exists and is assigned
2. Ensure you're on dev and it's up to date
3. Create branch with correct naming format
4. Confirm branch creation
5. Ready to make changes

## Verification

After creation:
- [ ] Branch name includes issue number
- [ ] Branch name is lowercase with hyphens
- [ ] Branch is based on latest dev
- [ ] Issue number matches exactly

## Alternative Patterns

While `issue-<number>/<description>` is preferred, these are also valid:
- `feature/<name>` - For new features
- `fix/<name>` - For bug fixes
- `refactor/<name>` - For refactoring

**Note:** Issue-First workflow strongly prefers the `issue-<number>/` prefix for traceability.
