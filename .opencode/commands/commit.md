---
description: Commits changes using conventional commit format with issue reference
agent: agent-context
---

# /commit Command

Commits changes using conventional commit format with proper issue reference.

## Usage

Run this slash command:
```
/commit
```

Or with message:

```
/commit feat: Add dark mode support
```

Or with full message:

```
/commit feat: Add dark mode support

- Implemented theme toggle
- Added user preference storage
- Updated UI components

Fixes #217
```

## What It Does

With no arguments, the command is **context-aware**:
1. Detects current branch and extracts issue number from `issue-<number>/*`
2. Stages all changes (`git add .`)
3. Auto-appends `Fixes #<number>` to the commit message footer
4. If branch does not match convention, prompts user for issue number

With arguments, the command uses the provided message and still auto-appends the issue reference if the branch matches.

## Context-Aware Execution (No Arguments)

When called without a message, the command inspects the branch:

```bash
# Detect branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Extract issue number from branch name
if [[ "$BRANCH" =~ ^issue-([0-9]+)/ ]]; then
    ISSUE="${BASH_REMATCH[1]}"
    echo "Detected issue #$ISSUE from branch '$BRANCH'"
fi
```

Then appends `Fixes #<n>` to any message the user provides.

## Full Behavior

1. Stages all changes (`git add .`)
2. Formats commit message per conventional commit standard
3. Includes issue reference (Fixes #<number>) — auto-detected from branch if not provided
4. Creates commit
5. Confirms successful commit

## Commit Format

```
<type>: <short description>

<optional body>

Fixes #<issue-number>
```

## Types

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks
- `ci` - CI/CD changes

## Requirements

- `git` installed
- Changes staged or ready to stage
- Issue number available

## Example

```
/commit fix: Resolve encoding issue in PR descriptions

This handles special characters in markdown.

Fixes #218
```

## Related

- `/branch` - Create branch first
- `/pr` - Create pull request after commits
- `/workflow` - Run full Issue-First workflow
