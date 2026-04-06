---
name: Workflow Report
description: Generates a visual workflow completion report with status tables and summaries
category: workflow
tool: gh, git
requires:
  - gh CLI
  - git repository
---

# Action: Workflow Report

Generates a visual workflow completion report with status tables and summaries, similar to the format shown after completing Issue-First workflow steps.

## Usage

This action is automatically invoked at the end of the `/workflow` command, or can be called manually.

## Report Format

The report displays:

```
════════════════════════════════════════════════════════════════
  Issue-First Workflow Complete! ✅
════════════════════════════════════════════════════════════════

Workflow Steps Completed

| Step | Action | Result |
|------|--------|--------|
| 1. Create Issue | gh issue create | ✅ #661 created |
| 2. Create Branch | git checkout -b ... | ✅ issue-661/... |
| 3. Make Changes | Implementation | ✅ 38 files changed |
| 4. Commit | git commit | ✅ abc1234 |
| 5. Create PR | gh pr create | ✅ #662 opened |
| 6. Verify CI | gh pr checks | ✅ All passing |

CI Status

| Check | Status | Duration |
|-------|--------|----------|
| Dependency Review | ✅ pass | 7s |
| Validate Shell Scripts | ✅ pass | 5s |
| Analyze (actions) | ✅ pass | 40s |
| Security Tests | ✅ pass | 4s |
| check-agents | ✅ pass | 5s |
| check-env | ✅ pass | 10s |

Summary

- Issue: #661 - Feature Request (https://...)
- Branch: issue-661/implement-opencode-agent-template
- Pull Request: #662 - Implement OpenCode agent template (https://...)
- Status: ✅ Ready to merge (all CI checks green)

The feature is complete and ready for review! 🚀
```

## Generating the Report

### Method 1: Automatic (End of /workflow)

The `/workflow` command automatically calls this action at completion.

### Method 2: Manual

```
Generate a workflow report for the current state.
```

Or use the report command:

```
/report
```

### Method 3: Post-Workflow

After completing individual steps, generate a report:

```bash
# Get workflow status
gh issue view 661 --json number,title,state
gh pr view 662 --json number,title,state,checks

# Get CI status
gh pr checks 662

# Generate report
```

## Report Components

### 1. Workflow Steps Table

Tracks the 6 Issue-First steps:

| Step | Command | Status | Details |
|------|---------|--------|---------|
| 1. Create Issue | `gh issue create` | ✅/❌ | Issue # and URL |
| 2. Create Branch | `git checkout -b` | ✅/❌ | Branch name |
| 3. Make Changes | File edits | ✅/❌ | Files changed |
| 4. Commit | `git commit` | ✅/❌ | Commit hash |
| 5. Create PR | `gh pr create` | ✅/❌ | PR # and URL |
| 6. Verify CI | `gh pr checks` | ✅/❌ | Check statuses |

### 2. CI Status Table

Displays GitHub Actions results:

| Check | Status | Duration | Link |
|-------|--------|----------|------|
| Dependency Review | ✅/❌/⏭️ | Ns | [Details](url) |
| Shell Script Linting | ✅/❌/⏭️ | Ns | [Details](url) |
| check-agents | ✅/❌/⏭️ | Ns | [Details](url) |
| ... | ... | ... | ... |

Status symbols:
- ✅ pass
- ❌ fail  
- ⏭️ skip/pending

### 3. Summary Section

Key information:
- Issue number and title
- Branch name
- Pull request number and title
- Overall status (ready to merge / needs work)
- Direct links to GitHub

### 4. Next Steps

Recommendations:
- If all green: "Ready to merge! 🚀"
- If failures: "Fix failing checks before merging"
- If pending: "Waiting for CI to complete"

## Commands Used

```bash
# Get issue info
gh issue view <number> --json number,title,state,url

# Get PR info
gh pr view <number> --json number,title,state,url,headRefName

# Get CI status
gh pr checks <number>

# Get branch info
git branch --show-current

# Get commit info
git log -1 --oneline

# Get file stats
git diff --stat <base-branch>..<current-branch>
```

## Example Report Generation

```bash
#!/bin/bash
# Generate workflow report

ISSUE_NUMBER="$1"
PR_NUMBER="$2"

echo "════════════════════════════════════════════════════════════════"
echo "  Issue-First Workflow Complete! ✅"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Workflow Steps Completed"
echo ""
echo "| Step | Action | Result |"
echo "|------|--------|--------|"
echo "| 1. Create Issue | gh issue create | ✅ #$ISSUE_NUMBER |"
echo "| 2. Create Branch | git checkout -b | ✅ $(git branch --show-current) |"
echo "| 3. Make Changes | Implementation | ✅ Complete |"
echo "| 4. Commit | git commit | ✅ $(git log -1 --format=%h) |"
echo "| 5. Create PR | gh pr create | ✅ #$PR_NUMBER |"
echo "| 6. Verify CI | gh pr checks | ✅ Passing |"
echo ""
echo "CI Status"
echo ""
echo "| Check | Status |"
echo "|-------|--------|"
gh pr checks "$PR_NUMBER" --json name,state -q '.[] | "| \(.name) | \(.state) |"'
echo ""
echo "Summary"
echo ""
echo "- Issue: #$ISSUE_NUMBER"
echo "- Branch: $(git branch --show-current)"
echo "- Pull Request: #$PR_NUMBER"
echo "- Status: ✅ Ready to merge"
echo ""
echo "The feature is complete and ready for review! 🚀"
```

## Verification

Report should include:
- [ ] All 6 workflow steps listed
- [ ] Each step shows command used
- [ ] CI checks displayed with status
- [ ] Summary with links
- [ ] Clear overall status indication
- [ ] Next steps guidance

## Related

- `/workflow` - Full Issue-First workflow
- `/verify` - Check CI status
- `action-detect-workflow-state.md` - State detection
