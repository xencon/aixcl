---
description: Commits changes using conventional commit format with issue reference
agent: agent-context
---

# /commit Command

Commits changes using conventional commit format with proper issue reference.

## Usage

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

1. Stages all changes (`git add .`)
2. Formats commit message per conventional commit standard
3. Includes issue reference (Fixes #<number>)
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
