---
description: Generates a visual workflow completion report with status tables and summaries
agent: agent-context
---

# /report Command

Generates a visual workflow completion report showing Issue-First workflow progress, CI status, and summary.

## Usage

Run this slash command:
```
/report
```

Or with specific issue/PR:

```
/report issue 661 pr 662
```

## What It Does

Runs explicit state detection commands against the current repository, then generates a visual report showing exactly where the user is in the Issue-First workflow.

### State Detection Commands

These commands are run in sequence to detect the repository state:

```bash
# Current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Uncommitted changes (empty = clean)
UNSTAGED=$(git status --short)

# Commits not on main (empty = no commits)
COMMITS=$(git log --oneline main..HEAD)

# Open PR for this branch
PR_JSON=$(gh pr list --head "$BRANCH" --json state,number --jq '.[0]')
PR_STATE=$(echo "$PR_JSON" | jq -r '.state // "none"')
PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number // "none"')

# Issue number extracted from branch name
if [[ "$BRANCH" =~ ^issue-([0-9]+)/ ]]; then
    ISSUE="${BASH_REMATCH[1]}"
    # Fetch issue existence
    ISSUE_STATE=$(gh issue view "$ISSUE" --json state --jq '.state // "none"')
fi

# CI status (if PR exists)
if [[ "$PR_STATE" == "OPEN" ]]; then
    CI_STATUS=$(gh pr checks "$PR_NUMBER" --json state)
fi
```

### Decision Tree

| Branch Pattern | Unstaged Changes | Commits on Branch | PR State | Current Phase | Next Action |
|---------------|-------------------|-------------------|----------|---------------|-------------|
| `main` | any | — | none | No active workflow | Start with `/workflow` or `/issue` |
| `main` | yes | — | none | Working on main (blocked) | Create issue first, then switch to `/branch` |
| `issue-<n>` branch | yes | none or old | none | **Phase 3: Work in progress** | `Add .` then `/commit` to stage and commit |
| `issue-<n>` branch | no | none | none | **Phase 3: Work pending** | Begin implementation or `/commit` |
| `issue-<n>` branch | no | 1+ commits | none | **Phase 5: PR needed** | `/pr` to create pull request |
| `issue-<n>` branch | no | 1+ commits | OPEN | **Phase 6: CI pending** | `/verify` to check or continue monitoring |
| `issue-<n>` branch | no | 1+ commits | OPEN + CI green | Ready to merge | `/merge` or `gh pr merge` |
| `issue-<n>` branch | no | 1+ commits | MERGED | Completed | `git checkout main` |

### Report Format

```
================================================================
  Issue-First Workflow Report
================================================================

Workflow Steps
| Step | Action | Result |
|------|--------|--------|
| 1. Create Issue  | gh issue create | pass issue #661 (state: open)   |
| 2. Create Branch | git checkout -b | pass issue-661/fix-encoding     |
| 3. Make Changes  | Implementation  | pass 2 commits ahead of main    |
| 4. Commit        | git commit      | pass abc1234                    |
| 5. Create PR     | gh pr create    | pass PR #662 (state: open)      |
| 6. Verify CI     | gh pr checks    | pass all checks green           |

CI Status
| Check | Status |
|-------|--------|
| Dependency Review     | pass |
| Validate Shell Scripts| pass |
| ...                   | ...  |

Workflow Summary
- Branch:         issue-661/fix-encoding
- Issue:          #661 (open)
- Pull Request:   #662 (open)
- Commits on branch: 2
- CI status:      pass (all green)
- Current phase:  Phase 6 (CI verified)
- Next action:    Ready to merge (use gh pr merge 662)
```

## When to Use

- After completing any workflow step to verify progress
- Before asking the user what to do next (run `/report` first)
- Before merging to confirm CI is green
- After interruption to resume at the correct phase
- To share status with team members

## Related

- `/workflow` - Run full Issue-First workflow
- `/verify` - Check CI only
- `/status` - Quick stack triage
