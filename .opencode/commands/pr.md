---
description: Creates a GitHub pull request following the AIXCL PR format
agent: agent-context
---

# /pr Command

Creates a GitHub pull request following the AIXCL PR format and workflow.

## Usage

```
/pr
```

Or with description:

```
/pr Fix CLI encoding issue
```

## What It Does

1. Ensures branch is pushed to remote
2. Creates PR with proper title format: `<Description> (#<number>)`
3. Includes PR body with:
   - Issue reference (Fixes #<number>)
   - Summary of changes
   - Checklist of changes
   - Testing notes
4. Assigns PR to author
5. Adds matching labels from issue
6. Notes PR number
7. Verifies CI status

## PR Title Format

```
<Description> (#<number>)
```

**NO colons in title**

Examples:
- `Fix CLI encoding issue (#217)`
- `Add dark mode support (#218)`
- `Refactor configuration loading (#220)`

## PR Body Template

```markdown
Fixes #<issue-number>

## Summary
Brief description of what changed and why.

## Changes
- [x] Change 1: Description
- [x] Change 2: Description

## Testing
- Tested locally with...
- Verified that...

## Verification
- [x] Behavior works as expected
- [x] No regressions observed
```

## Requirements

- `gh` CLI installed and authenticated
- Branch pushed to remote
- Commits made with issue references
- Issue number available

## Example

```
/pr Fix encoding in PR descriptions
```

This will:
- Push branch if not already
- Create PR with title "Fix encoding in PR descriptions (#218)"
- Include body with Fixes #218
- Assign to you
- Add matching labels

## Related

- `/branch` - Create branch
- `/commit` - Make commits
- `/verify` - Check CI status
- `/workflow` - Run full Issue-First workflow
