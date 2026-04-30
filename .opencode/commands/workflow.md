---
description: Runs the complete Issue-First development workflow end-to-end
agent: agent-context
---

# /workflow Command

Runs the complete AIXCL Issue-First development workflow end-to-end.

## Usage

Run this slash command:
```
/workflow
```

Or with description:

```
/workflow Implement user authentication feature
```

## Context-Aware Execution (No Arguments)

When `/workflow` is called **without a description**, it inspects the repository state and acts based on what it finds:

### State Detection

Run these commands automatically to determine the current state:

```bash
# Current branch
git rev-parse --abbrev-ref HEAD

# Uncommitted changes
git status --short

# Commits not on main
git log --oneline main..HEAD

# Open PR for this branch
gh pr list --head $(git rev-parse --abbrev-ref HEAD) --json number,state
```

### Decision Tree

| State | Action |
|-------|--------|
| **On `main` with no changes** | Prompt user: `What would you like to work on?` Then proceed with Phase 1 |
| **On `main` with changes** | Block: `Create an issue first. Use: /issue \u003cdescription\u003e` |
| **On `issue-\u003cn\u003e/*` branch, no commits, no changes** | Fetch issue #n, prompt user to begin implementation |
| **On `issue-\u003cn\u003e/*` branch, uncommitted changes** | Stage, commit, push, create PR if none exists, verify CI |
| **On `issue-\u003cn\u003e/*` branch, commits exist, no PR** | Push, create PR with `gh pr create`, assign/label, verify CI |
| **On any branch with existing PR** | Verify CI status and report |

### Example: Running `/workflow` from Mid-Workflow

```
# You are on issue-42/fix-login, have uncommitted changes
/workflow
```

This will:
1. Detect branch `issue-42/fix-login` → extract issue #42
2. See uncommitted changes → stage all (`git add .`)
3. Draft commit message referencing issue #42
4. Commit, push, create PR, assign/label, verify CI

## What It Does (With Arguments)

This command orchestrates the entire Issue-First workflow:

### Phase 1: Issue Creation
1. Creates a new GitHub issue
2. Determines appropriate type (TASK/BUG/FEATURE)
3. Adds component and priority labels
4. Assigns to user
5. Notes issue number

### Phase 2: Branch Creation
6. Checks out dev branch
7. Pulls latest changes
8. Creates feature branch: `issue-<number>/<description>`
9. Switches to new branch

### Phase 3: Work
10. Prompts for code changes
11. Assists with implementation

### Phase 4: Commit
12. Stages changes
13. Commits with conventional format
14. References issue in commit

### Phase 5: Pull Request
15. Pushes branch to remote
16. Creates PR with proper format
17. Assigns and labels PR
18. Notes PR number

### Phase 6: Verification
19. Monitors CI status
20. Waits for all checks to pass
21. Confirms workflow completion
22. Generates visual workflow report

## Workflow Steps Summary

```
[Create Issue] → [Create Branch] → [Make Changes] → [Commit] → [Create PR] → [Verify CI]
```

## Requirements

- `gh` CLI installed and authenticated
- `git` configured with remote access
- Valid GitHub repository
- User has push access

## Examples

### Feature Development
```
/workflow Add support for PostgreSQL database
```
Creates a [FEATURE] issue, branches, implements, commits, and creates PR.

### Bug Fix
```
/workflow Fix memory leak in connection pooling
```
Creates a [BUG] issue with Fix label, branches from dev, implements fix.

### Refactoring Task
```
/workflow Refactor database abstraction layer
```
Creates a [TASK] issue with Refactor label, restructures code without changing behavior.

### Documentation Update
```
/workflow Update API documentation for v2 endpoints
```
Creates issue for docs changes, updates documentation files.

## Interactive Mode

The workflow will:
- Prompt for user approval at each major step
- Ask for confirmation before creating resources
- Provide options to skip steps if already done
- Handle errors gracefully

## Workflow Report

At the end of the workflow, a visual report is generated showing:

```
════════════════════════════════════════════════════════════════
  Issue-First Workflow Complete! pass
════════════════════════════════════════════════════════════════

Workflow Steps Completed

| Step | Action | Result |
|------|--------|--------|
| 1. Create Issue | gh issue create | pass #661 |
| 2. Create Branch | git checkout -b | pass issue-661/... |
| 3. Make Changes | Implementation | pass Complete |
| 4. Commit | git commit | pass abc1234 |
| 5. Create PR | gh pr create | pass #662 |
| 6. Verify CI | gh pr checks | pass Passing |

CI Status

| Check | Status |
|-------|--------|
| Dependency Review | pass pass |
| Validate Shell Scripts | pass pass |
| ... | ... |

Summary
- Issue: #661
- Branch: issue-661/...
- Pull Request: #662
- Status: pass Ready to merge

The feature is complete and ready for review! 
```

## Resuming or Interrupting Workflows

### Resuming After Interruption

If the workflow is interrupted (e.g., network issue, system restart), you can resume:

1. **Check current status**: Run `/report` to see which phase you're in
2. **Skip completed phases**: Use individual commands to skip completed steps:
   - Issue already created? Use `/branch` instead of `/workflow`
   - Branch exists? Use `/commit` directly
   - Commits ready? Use `/pr` to create PR
   - PR exists? Use `/verify` to check CI status

### Starting from Mid-Workflow

If you've manually completed some steps:

```
# If issue #123 exists and branch created
/commit feat: Add authentication

# If branch pushed with commits
/pr Add user authentication feature

# If PR #124 exists
/verify 124
```

### Error Recovery

If a step fails:
1. **Issue creation failed**: Check `gh auth status`, fix error, re-run `/issue`
2. **Branch creation failed**: Ensure clean git status, resolve conflicts, re-run `/branch`
3. **Push failed**: Check remote access, resolve merge conflicts manually
4. **PR creation failed**: Verify issue exists, ensure branch is pushed
5. **CI failing**: Fix code locally, commit, push, re-run `/verify`

## Next Steps After Workflow

Once complete:
- Monitor PR for code review
- Address reviewer feedback
- Merge when approved and CI is green

## Related

- `/issue` - Create issue only
- `/branch` - Create branch only
- `/commit` - Commit changes only
- `/pr` - Create PR only
- `/verify` - Check CI only
