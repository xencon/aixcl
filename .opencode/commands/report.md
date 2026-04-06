---
description: Generates a visual workflow completion report with status tables and summaries
agent: agent-context
---

# /report Command

Generates a visual workflow completion report showing Issue-First workflow progress, CI status, and summary.

## Usage

```
/report
```

Or with specific issue/PR:

```
/report issue 661 pr 662
```

## What It Does

1. Detects current workflow state (issue, branch, PR, CI status)
2. Generates visual report with tables
3. Displays workflow steps completed
4. Shows CI check status
5. Provides summary with links and status

## Report Format

```
════════════════════════════════════════════════════════════════
  Issue-First Workflow Report
════════════════════════════════════════════════════════════════

Workflow Steps
| Step | Action | Result |
|------|--------|--------|
| 1. Create Issue | gh issue create | ✅ #661 |
| 2. Create Branch | git checkout -b | ✅ issue-661/... |
| 3. Make Changes | Implementation | ✅ Complete |
| 4. Commit | git commit | ✅ abc1234 |
| 5. Create PR | gh pr create | ✅ #662 |
| 6. Verify CI | gh pr checks | ✅ Passing |

CI Status
| Check | Status |
|-------|--------|
| Dependency Review | ✅ pass |
| Validate Shell Scripts | ✅ pass |
| ... | ... |

Summary
- Issue: #661
- Branch: issue-661/...
- PR: #662
- Status: ✅ Ready to merge
```

## When to Use

- After completing workflow steps
- To check current state
- Before merging
- To share status with team

## Related

- `/workflow` - Run full workflow
- `/verify` - Check CI only
