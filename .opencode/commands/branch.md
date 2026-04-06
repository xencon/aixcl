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
