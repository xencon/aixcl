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

The report displays using consistent markdown tables:

```markdown
## 📊 Issue-First Workflow Report

### Workflow Steps

| Step | Status |
|:---|:---|
| 1. Create Issue | ✅ #<number> - [TYPE] Description |
| 2. Create Branch | ✅ issue-<number>/short-description |
| 3. Make Changes | ✅ <N> files changed, <M> insertions(+), <P> deletions(-) |
| 4. Commit | ✅ <short-hash> |
| 5. Create PR | ✅ #<pr-number> - PR Title |
| 6. Verify CI | ✅ All checks passing |

### CI Status (PR #<number>)

| Check | Status |
|:---|:---|
| Dependency Review | ✅ SUCCESS |
| Shell Script Linting | ✅ SUCCESS |
| Security Tests | ✅ SUCCESS |
| check-env | ✅ SUCCESS |
| Analyze (actions) | ✅ SUCCESS |
| check-line-endings | ✅ SUCCESS |
| Validate Shell Scripts | ✅ SUCCESS |
| CodeQL | ⏭️ NEUTRAL |
| **Total** | **<N>/<N> checks completed** |

### Summary

| Field | Value |
|:---|:---|
| Issue | #<number> - [TYPE] Issue title |
| Issue URL | https://github.com/<owner>/<repo>/issues/<number> |
| Branch | issue-<number>/short-description |
| Pull Request | #<pr-number> - PR title |
| PR Status | MERGED ✅ / OPEN 🟡 / CLOSED ❌ |
| Commit | <hash> |
| Labels | label1 \| label2 \| label3 |

### Repository State

| Field | Value |
|:---|:---|
| Current Branch | <branch-name> |
| Working Tree | Clean ✅ / Dirty ❌ |
| Last Commit | <hash> - Commit message |

### Key Highlights

| Metric | Value |
|:---|:---|
| Workflow Status | ✅ Complete / ❌ Incomplete |
| CI Checks | <passing>/<total> Passing |
| PR Status | Merged / Open / Closed |
| Issue Status | Closed / Open |
| Repository | Clean on <branch> |

### Next Steps

| Field | Value |
|:---|:---|
| Status | This workflow cycle is COMPLETE ✅ |
| Action | Run `/workflow "description"` to start next task |
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
# Generate workflow report in consistent table format

ISSUE_NUMBER="$1"
PR_NUMBER="$2"

# Fetch data
ISSUE_DATA=$(gh issue view "$ISSUE_NUMBER" --json number,title,state,url,labels 2>/dev/null)
PR_DATA=$(gh pr view "$PR_NUMBER" --json number,title,state,url,headRefName,merged 2>/dev/null)
CI_DATA=$(gh pr checks "$PR_NUMBER" --json name,state 2>/dev/null)

echo "## 📊 Issue-First Workflow Report"
echo ""
echo "### Workflow Steps"
echo ""
echo "| Step | Status |"
echo "|:---|:---|"
echo "| 1. Create Issue | ✅ #$ISSUE_NUMBER - $(echo "$ISSUE_DATA" | jq -r '.title') |"
echo "| 2. Create Branch | ✅ $(git branch --show-current) |"
echo "| 3. Make Changes | ✅ $(git diff --stat main...HEAD 2>/dev/null | tail -1 || echo 'Complete') |"
echo "| 4. Commit | ✅ $(git log -1 --format=%h) |"
echo "| 5. Create PR | ✅ #$PR_NUMBER - $(echo "$PR_DATA" | jq -r '.title') |"
echo "| 6. Verify CI | ✅ $(echo "$CI_DATA" | jq -r '[.[] | select(.state == "SUCCESS")] | length')/$(echo "$CI_DATA" | jq '. | length') checks passing |"
echo ""

echo "### CI Status (PR #$PR_NUMBER)"
echo ""
echo "| Check | Status |"
echo "|:---|:---|"
echo "$CI_DATA" | jq -r '.[] | "| \(.name) | \(.state) |"' | sed 's/SUCCESS/✅ SUCCESS/g; s/FAILED/❌ FAILED/g; s/PENDING/⏳ PENDING/g; s/NEUTRAL/⏭️ NEUTRAL/g'
echo "| **Total** | **$(echo "$CI_DATA" | jq -r '[.[] | select(.state == "SUCCESS")] | length')/$(echo "$CI_DATA" | jq '. | length') checks completed** |"
echo ""

echo "### Summary"
echo ""
echo "| Field | Value |"
echo "|:---|:---|"
echo "| Issue | #$ISSUE_NUMBER - $(echo "$ISSUE_DATA" | jq -r '.title') |"
echo "| Issue URL | $(echo "$ISSUE_DATA" | jq -r '.url') |"
echo "| Branch | $(echo "$PR_DATA" | jq -r '.headRefName') |"
echo "| Pull Request | #$PR_NUMBER - $(echo "$PR_DATA" | jq -r '.title') |"
PR_STATE=$(echo "$PR_DATA" | jq -r '.state')
if [ "$PR_STATE" = "MERGED" ]; then
  echo "| PR Status | MERGED ✅ |"
elif [ "$PR_STATE" = "OPEN" ]; then
  echo "| PR Status | OPEN 🟡 |"
else
  echo "| PR Status | CLOSED ❌ |"
fi
echo "| Commit | $(git log -1 --format=%h) |"
LABELS=$(echo "$ISSUE_DATA" | jq -r '.labels | map(.name) | join(" | ")')
echo "| Labels | $LABELS |"
echo ""

echo "### Repository State"
echo ""
echo "| Field | Value |"
echo "|:---|:---|"
echo "| Current Branch | $(git branch --show-current) |"
if [ -z "$(git status --porcelain)" ]; then
  echo "| Working Tree | Clean ✅ |"
else
  echo "| Working Tree | Dirty ❌ |"
fi
echo "| Last Commit | $(git log -1 --oneline) |"
echo ""

echo "### Key Highlights"
echo ""
echo "| Metric | Value |"
echo "|:---|:---|"
echo "| Workflow Status | ✅ Complete |"
SUCCESS_COUNT=$(echo "$CI_DATA" | jq -r '[.[] | select(.state == "SUCCESS")] | length')
TOTAL_COUNT=$(echo "$CI_DATA" | jq '. | length')
echo "| CI Checks | $SUCCESS_COUNT/$TOTAL_COUNT Passing |"
PR_MERGED=$(echo "$PR_DATA" | jq -r '.merged')
if [ "$PR_MERGED" = "true" ]; then
  echo "| PR Status | Merged |"
else
  echo "| PR Status | $PR_STATE |"
fi
ISSUE_STATE=$(echo "$ISSUE_DATA" | jq -r '.state')
echo "| Issue Status | $ISSUE_STATE |"
if [ -z "$(git status --porcelain)" ]; then
  echo "| Repository | Clean on $(git branch --show-current) |"
else
  echo "| Repository | Dirty on $(git branch --show-current) |"
fi
echo ""

echo "### Next Steps"
echo ""
echo "| Field | Value |"
echo "|:---|:---|"
if [ "$PR_MERGED" = "true" ] && [ "$SUCCESS_COUNT" -eq "$TOTAL_COUNT" ]; then
  echo "| Status | This workflow cycle is COMPLETE ✅ |"
  echo "| Action | Run \`/workflow \"description\"\` to start next task |"
else
  echo "| Status | Workflow in progress |"
  echo "| Action | Complete remaining steps |"
fi
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
