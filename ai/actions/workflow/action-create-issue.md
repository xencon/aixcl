---
name: Create Issue
description: Creates a GitHub issue following the Issue-First workflow with proper formatting and labels
category: workflow
tool: gh
requires:
  - gh CLI installed
  - GitHub authentication configured
  - Valid GitHub repository remote
---

# Action: Create Issue

Creates a GitHub issue following the AIXCL Issue-First workflow.

## Command Format

```bash
gh issue create --title "[<TYPE>] <description>" --body "<body>" --label "<labels>" --assignee "<username>"
```

## Parameters

- **TYPE**: One of `TASK`, `BUG`, `FEATURE`
- **description**: Clear, concise description (no colons)
- **body**: Description and context sections
- **labels**: Comma-separated list (e.g., `component:cli,P1`)
- **assignee**: GitHub username of person working on it

## Process

1. Determine issue type from context
2. Infer appropriate labels:
   - Component label (required): `component:cli`, `component:runtime-core`, etc.
   - Priority label (optional): `P1`, `P2`, `P3`
   - Profile label (optional): `profile:dev`, `profile:ops`, etc.
3. Draft issue title and body
4. Propose to user for approval
5. Create issue using `gh issue create`
6. Note the issue number for branch creation

## Title Formatting

**CORRECT:**
- `[TASK] Setup agent template`
- `[BUG] Fix encoding in PR descriptions`
- `[FEATURE] Add dark mode support`

**INCORRECT:**
- `[TASK]: Setup agent template` (no colons)
- `TASK: Setup agent template` (missing brackets)
- `Setup agent template [TASK]` (wrong order)

## Body Template

```markdown
## Description
[Clear description of the bug, feature, or task]

## Context/Additional Information
[Any relevant background, screenshots, or logs]
```

## Label Guidelines

**Always include:**
- One component label: `component:runtime-core`, `component:ollama`, `component:persistence`, `component:observability`, `component:ui`, `component:cli`, `component:infrastructure`, `component:testing`

**Optional:**
- Priority: `P1` (high), `P2` (medium), `P3` (low)
- Profile: `profile:usr`, `profile:dev`, `profile:ops`, `profile:sys`
- Category: `Fix`, `Enhancement`, `Refactor`, `Maintenance`

## Verification

After creation, verify:
- [ ] Issue number is noted
- [ ] Title format is correct
- [ ] Labels are applied
- [ ] Assignee is set
- [ ] Issue type is selected in GitHub UI (Bug/Feature/Task)

## Label and Assignment Validation

### Check Labels on Existing Issue

```bash
# Get issue labels
gh issue view <number> --json labels --jq '.labels[].name'

# Check if component label exists
gh issue view <number> --json labels --jq '.labels[].name' | grep -q "component:"

# Check if assigned
gh issue view <number> --json assignees --jq '.assignees[].login'
```

### Required Labels

Every issue MUST have:
- [ ] **Component label** - Identifies affected system part
  - `component:runtime-core`, `component:ollama`, `component:persistence`
  - `component:observability`, `component:ui`, `component:cli`
  - `component:infrastructure`, `component:testing`

### Recommended Labels

- [ ] **Priority label** - Indicates urgency
  - `P1` - High priority, immediate attention
  - `P2` - Medium priority
  - `P3` - Low priority

- [ ] **Profile label** - Affects deployment profiles
  - `profile:usr` - Minimal footprint
  - `profile:dev` - Developer workstation
  - `profile:ops` - Observability-focused
  - `profile:sys` - Full deployment

- [ ] **Category label** - Context for PR
  - `Fix` - Bug fix
  - `Enhancement` - Feature improvement
  - `Refactor` - Code restructuring
  - `Maintenance` - Upkeep tasks

### Assignment Rules

- [ ] Issue MUST be assigned to someone
- [ ] Use `--assignee <username>` in `gh issue create`
- [ ] If creating via GitHub web UI, assign immediately after creation
- [ ] Never leave issues unassigned

### Fix Missing Labels/Assignment

```bash
# Add labels to existing issue
gh issue edit <number> --add-label "component:cli,P1,profile:dev"

# Add assignee to existing issue
gh issue edit <number> --add-assignee <username>

# Check current labels and assignees
gh issue view <number> --json labels,assignees
```

## Post-Creation

1. Note the issue number (e.g., #217)
2. **Verify labels are applied** (at minimum one component label)
3. **Verify assignee is set**
4. Proceed to create branch: `issue-217/<description>`
5. Branch name should match issue number exactly

## Common Mistakes to Avoid

- ❌ Creating issue without component label
- ❌ Leaving issue unassigned
- ❌ Using wrong label format (no spaces: `component:cli` not `component: cli`)
- ❌ Forgetting to select issue type in GitHub UI (Bug/Feature/Task)
- ❌ Using colons in issue title

## Verification Script

```bash
#!/bin/bash
# Check issue compliance
ISSUE_NUMBER=$1

echo "Checking issue #$ISSUE_NUMBER..."

# Check labels
labels=$(gh issue view $ISSUE_NUMBER --json labels --jq '.labels[].name' 2>/dev/null)
if echo "$labels" | grep -q "component:"; then
    echo "✓ Has component label"
else
    echo "✗ Missing component label"
fi

# Check assignee
assignee=$(gh issue view $ISSUE_NUMBER --json assignees --jq '.assignees[].login' 2>/dev/null)
if [ -n "$assignee" ]; then
    echo "✓ Assigned to: $assignee"
else
    echo "✗ Not assigned"
fi

# Show all labels
echo "Labels:"
echo "$labels" | sed 's/^/  - /'
```
