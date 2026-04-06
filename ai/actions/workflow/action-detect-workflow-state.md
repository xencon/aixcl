---
name: Workflow State Detection
description: Detects current workflow state and provides smart suggestions for Issue-First development
category: workflow
tool: gh, git
requires:
  - gh CLI
  - git repository
  - GitHub remote
---

# Action: Workflow State Detection

Detects current workflow state to provide smart suggestions and prevent duplicate work.

## State Detection Logic

### 1. Check for Existing Issues

**Command:**
```bash
gh issue list --limit=5 --state=open --author="$(gh api user -q .login 2>/dev/null || echo '')"
```

**Returns:** List of open issues created by current user

**Decision:**
- If recent open issues exist → Suggest using existing issue
- If no open issues → Suggest creating new issue

### 2. Check Current Branch

**Command:**
```bash
git branch --show-current
```

**Returns:** Current branch name

**Decision:**
- If on `main` → Need to create branch
- If on `issue-<number>/*` → On feature branch, ready to work
- If on other branch → May need to switch

### 3. Check for Uncommitted Changes

**Command:**
```bash
git status --porcelain
```

**Returns:** Modified, added, deleted files

**Decision:**
- If output not empty → Has uncommitted changes, prompt to commit
- If empty → Clean working directory

### 4. Check for Existing PR

**Command:**
```bash
gh pr list --state=open --head="$(git branch --show-current)" 2>/dev/null
```

**Returns:** Open PRs for current branch

**Decision:**
- If PR exists → Skip PR creation
- If no PR → Suggest creating PR

## Workflow State Matrix

| Current State | Detected | Suggested Next Step |
|--------------|----------|---------------------|
| No issue | `gh issue list` empty | `/issue` - Create issue |
| Issue exists, no branch | On `main` | `/branch <number>` - Create branch |
| On feature branch, no changes | Clean git status | Ready to work or `/commit` |
| On feature branch, has changes | Modified files | `/commit` - Commit changes |
| Branch pushed, no PR | `gh pr list` empty | `/pr` - Create PR |
| PR exists, not verified | CI unknown | `/verify` - Check CI |
| PR exists, CI passing | All checks green | Ready to merge |

## Labels and Assignment Detection

### Check Issue Labels

**Command:**
```bash
gh issue view <number> --json labels --jq '.labels[].name'
```

**Validation:**
- Must have at least one component label
- Should have type label (Bug, Feature, Task)
- May have priority (P1, P2, P3)
- May have profile (profile:usr, profile:dev, profile:ops, profile:sys)

### Check Issue Assignment

**Command:**
```bash
gh issue view <number> --json assignees --jq '.assignees[].login'
```

**Validation:**
- Should be assigned to someone
- If unassigned, suggest: `gh issue edit <number> --add-assignee <username>`

### Sync PR Labels with Issue

**Command:**
```bash
# Get issue labels
gh issue view <issue-number> --json labels --jq '.labels[].name' | paste -sd ',' -

# Apply to PR
gh pr edit <pr-number> --add-label "<labels>"
```

## Smart Workflow Command

### `/workflow` with State Detection

When running `/workflow`, the agent should:

1. **Detect current state**
   - Check for existing open issues
   - Check current branch
   - Check for uncommitted changes
   - Check for existing PR

2. **Present findings**
   ```
   Current state detected:
   - Open issues: #217, #218
   - Current branch: main
   - Working directory: clean
   - No existing PR for this branch
   
   Suggested workflow:
   1. Create new issue OR use existing #217
   2. Create branch issue-217/description
   3. Make changes
   4. Commit
   5. Create PR
   6. Verify CI
   ```

3. **Offer options**
   - Use existing issue
   - Create new issue
   - Skip to branch creation
   - Resume from current step

### State Persistence

The agent should track:
- Current issue number
- Current branch name
- Current PR number
- Last completed step

This allows resuming workflows and preventing duplicate work.

## Example Detection Flow

```
User: /workflow

Agent:
[Analyzing repository state...]

Found:
✓ 2 open issues by you: #220, #221
✓ Currently on branch: main
✓ Working directory: clean
✓ No PR exists yet

Options:
1. Use existing issue #220 [TASK] Setup agent template
2. Use existing issue #221 [BUG] Fix encoding
3. Create new issue
4. Start from branch creation

Which would you like to do?
```

## Commands for State Detection

### Quick State Check
```bash
#!/bin/bash
# Quick workflow state check

echo "=== Workflow State ==="

# Check current branch
echo -n "Current branch: "
git branch --show-current

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  Uncommitted changes detected"
    git status --short
else
    echo "✓ Working directory clean"
fi

# Check for open issues
open_issues=$(gh issue list --limit=3 --state=open --json number,title --jq '.[] | "#\(.number): \(.title)"' 2>/dev/null || echo "")
if [ -n "$open_issues" ]; then
    echo "Open issues:"
    echo "$open_issues"
else
    echo "No open issues found"
fi

# Check for existing PR
pr_info=$(gh pr list --state=open --head="$(git branch --show-current)" --json number,title --jq '.[0] | "#\(.number): \(.title)"' 2>/dev/null || echo "")
if [ -n "$pr_info" ]; then
    echo "PR for this branch: $pr_info"
else
    echo "No PR found for current branch"
fi
```

## Verification

When using state detection:
- [ ] Current branch identified
- [ ] Open issues listed
- [ ] Uncommitted changes detected
- [ ] Existing PR detected
- [ ] Smart suggestions provided
- [ ] User can choose path forward
