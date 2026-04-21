---
description: Creates a feature branch from main following the branch naming convention
agent: agent-context
---

# /branch Command

Creates a feature branch from main following the AIXCL branch naming convention.

## Usage

```
/branch
```

Or with issue number:

```
/branch 217
```

Or with description:

```
/branch 217 fix-encoding-problem
```

## Context-Aware Execution (No Arguments)

When called without an issue number, the command inspects the current state:

### State Detection

```bash
# Detect current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
```

### Decision Tree

| State | Action |
|-------|--------|
| **On `main`** | Proceed as normal: prompt user for issue number and description |
| **On `issue-<n>/*` branch** | Warn user: `Already on feature branch issue-<n>. Run /commit or /pr instead.` Confirm before proceeding |
| **On any other branch** | Warn user: `Not on main. Create an issue first with /issue`, then return to main before running /branch again |

### Deriving Description from Issue

If the user provides an issue number but no description, the command can fetch the issue title and construct the branch description:

```bash
ISSUE_TITLE=$(gh issue view <number> --json title --jq '.title')
# Convert issue title to branch-friendly description
DESCRIPTION=$(echo "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -c1-50)
# Result: issue-<number>/<description>
```

## What It Does

1. Verifies issue exists (if number provided)
2. Checks out main branch
3. Pulls latest changes from origin/main
4. Creates branch with format: `issue-<number>/<description>`
5. Confirms branch creation
6. Ready to make changes

## Branch Naming

```
issue-<number>/<short-description>
```

Examples:
- `issue-217/fix-encoding-problem`
- `issue-42/add-user-authentication`
- `issue-156/update-documentation`

## Requirements

- `git` installed
- Repository cloned
- Issue number available (optional but recommended)

## Example

```
/branch 217
```

This will:
- Checkout main
- Pull origin/main
- Create `issue-217/<inferred-description>` branch
- Switch to new branch

## Related

- `/issue` - Create an issue first
- `/commit` - Commit changes to this branch
- `/workflow` - Run full Issue-First workflow
