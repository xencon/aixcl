---
name: Create Pull Request
description: Creates a GitHub pull request following the AIXCL PR format with proper issue reference
category: workflow
tool: gh
requires:
  - gh CLI installed
  - Branch pushed to remote
  - Issue number available
  - Changes committed
---

# Action: Create Pull Request

Creates a GitHub pull request following AIXCL PR format and workflow.

## Commands

```bash
# Push branch to remote (if not already)
git push -u origin issue-<number>/<description>

# Create PR
gh pr create --title "<Description> (#<number>)" --body "<body>"

# Assign and label PR (after creation)
gh pr edit <pr-number> --add-assignee <username> --add-label "<labels>"
```

## PR Title Format

```
<Description> (#<number>)
```

**Examples:**
- `Fix CLI encoding issue (#217)`
- `Add dark mode support (#218)`
- `Refactor configuration loading (#220)`

**Rules:**
- NO colons in title
- Include issue number in parentheses at end
- Use imperative mood
- Be concise but descriptive

## PR Body Template

```markdown
Fixes #<issue-number>

## Summary
Brief description of what changed and why.

## Changes
- [x] Change 1: Description
- [x] Change 2: Description
- [x] Change 3: Description

## Testing
- Tested locally with...
- Verified that...
- Checked edge cases...

## Verification
- [ ] Behavior works as expected
- [ ] No regressions observed
- [ ] Tests cover the change
```

## Process

1. Ensure branch is pushed: `git push -u origin <branch>`
2. Create PR with proper title and body
3. Note the PR number
4. Assign the PR to author
5. Add matching labels (same as issue)
6. Verify CI status

## Label Matching

PR labels MUST match the linked issue labels:
- Component labels (required)
- Priority labels (if applicable)
- Profile labels (if applicable)
- Category labels (if applicable)

## Verification

After creation:
- [ ] PR title has no colons
- [ ] Issue number is referenced in body
- [ ] Assignee is set
- [ ] Labels match the issue
- [ ] All CI checks are passing (monitor status)

## CI Status Check

Monitor CI status:
```bash
gh run list --branch=<branch-name>
```

Or view in GitHub web interface. All status checks must be green before considering the task complete.

## Next Steps After PR Creation

1. Wait for code review
2. Address feedback
3. Ensure CI is green
4. Merge via GitHub UI or CLI (do not force push)
