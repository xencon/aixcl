---
description: Creates a GitHub pull request following the AIXCL PR format
agent: agent-context
---

# /pr Command

Creates a GitHub pull request following the AIXCL PR format and workflow.

## Usage

Run this slash command:
```
/pr
```

Or with description:

```
/pr Fix CLI encoding issue
```

## What It Does

With no arguments, the command is **context-aware**:
1. Detects current branch and extracts issue number from `issue-<number>/*`
2. Fetches issue title and body via `gh issue view <n> --json title,body`
3. Drafts PR title: `<Issue Title> (#<n>)`
4. Reads PR template from `.github/PULL_REQUEST_TEMPLATE.md`
5. Maps issue body sections to template sections (Summary, Description, etc.)
6. Ensures branch is pushed to remote
7. Creates PR with proper title format and pre-filled body
8. Enforces assignee and labels after creation
9. Verifies CI status

With arguments, the command uses the provided description as the PR title and falls back to template defaults for the body.

## Context-Aware Execution (No Arguments)

### State Detection

```bash
# Detect branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Extract issue number
if [[ "$BRANCH" =~ ^issue-([0-9]+)/ ]]; then
    ISSUE="${BASH_REMATCH[1]}"
    gh issue view "$ISSUE" --json title,body,labels,assignees
fi
```

### Mapping Issue to PR Template

| Issue Section | PR Template Section |
|---------------|---------------------|
| Task Summary / Feature Overview / Bug Summary | Summary |
| Description / Deliverables | Description of Changes |
| Verification | Verification |

If the issue body does not contain template sections, the agent drafts the PR body manually using the issue title as the summary.

## Full Behavior

1. Reads the PR template from `.github/PULL_REQUEST_TEMPLATE.md` first
2. Drafts PR body using the template's exact section headings (Summary, Description of Changes, Change Checklist, Testing Notes, Verification, Related Issues)
3. Ensures branch is pushed to remote
4. Creates PR with proper title format: `<Description> (#<number>)`
5. **Uses correct base branch:**
   - Feature branches (issue-\*/\*) → `gh pr create --base dev`
   - Dev to main releases → `gh pr create --base main --head dev`
6. Enforces assignee and labels after creation:
   ```bash
   gh pr edit <number> --add-label "component:cli,Maintenance" --add-assignee <username>
   ```
7. Notes PR number
8. Verifies CI status

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
- Target `dev` branch (correct for feature branches)
- Assign to you
- Add matching labels

## PR Creation Commands

### Feature Branch to Dev (Standard Workflow)
```bash
# From feature branch issue-<n>/<description>
gh pr create --base dev --title "Description (#<number>)" --body "Fixes #<number>"
```

### Dev to Main (Release Workflow)
```bash
# From dev branch when releasing
gh pr create --base main --head dev --title "Release vX.Y.Z"
```

### Emergency Hotfix to Main
```bash
# From hotfix branch issue-<n>/hotfix-*
gh pr create --base main --title "Hotfix: Description (#<number>)"
```

## Related

- `/branch` - Create branch
- `/commit` - Make commits
- `/verify` - Check CI status
- `/workflow` - Run full Issue-First workflow
