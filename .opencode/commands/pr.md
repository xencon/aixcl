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

1. Reads the PR template from `ai/templates/pr/pull_request.md` first
2. Drafts PR body using the template's exact section headings (Summary, Description of Changes, Change Checklist, Testing Notes, Verification, Related Issues)
3. Ensures branch is pushed to remote
4. Creates PR with proper title format: `<Description> (#<number>)`
5. Enforces assignee and labels after creation:
   ```bash
   gh pr edit <number> --add-label "component:cli,Maintenance" --add-assignee <username>
   ```
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
