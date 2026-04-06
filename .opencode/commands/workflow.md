---
description: Runs the complete Issue-First development workflow end-to-end
agent: agent-context
---

# /workflow Command

Runs the complete AIXCL Issue-First development workflow end-to-end.

## Usage

```
/workflow
```

Or with description:

```
/workflow Implement user authentication feature
```

## What It Does

This command orchestrates the entire Issue-First workflow:

### Phase 1: Issue Creation
1. Creates a new GitHub issue
2. Determines appropriate type (TASK/BUG/FEATURE)
3. Adds component and priority labels
4. Assigns to user
5. Notes issue number

### Phase 2: Branch Creation
6. Checks out main branch
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

## Workflow Steps Summary

```
[Create Issue] → [Create Branch] → [Make Changes] → [Commit] → [Create PR] → [Verify CI]
```

## Requirements

- `gh` CLI installed and authenticated
- `git` configured with remote access
- Valid GitHub repository
- User has push access

## Example

```
/workflow Add support for PostgreSQL database
```

This will:
- Create [FEATURE] issue with appropriate labels
- Create branch issue-<number>/add-postgresql-support
- Guide through implementation
- Commit with proper format
- Create PR with proper format
- Verify CI passes

## Interactive Mode

The workflow will:
- Prompt for user approval at each major step
- Ask for confirmation before creating resources
- Provide options to skip steps if already done
- Handle errors gracefully

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
