---
name: workflow-guard
description: Validates Issue-First workflow compliance before execution
license: MIT
compatibility: opencode
metadata:
  category: workflow
  security_level: critical
  version: "1.0"
---

# Workflow Guard Skill

Validates that all actions comply with the Issue-First development workflow before execution.

## Validation Steps

### 1. Issue Requirements
- [ ] Issue exists in GitHub (open or closed)
- [ ] Issue is assigned to someone
- [ ] Issue has appropriate labels (component:* required)
- [ ] Issue title follows format: `[TYPE] Description` (no colons)

### 2. Branch Requirements
- [ ] Branch format: `issue-<number>/<short-description>`
- [ ] Branch created from `dev` (not `main`)
- [ ] No direct commits to `main` or `dev` branches

### 3. Commit Requirements
- [ ] Commit messages follow conventional format: `<type>: <description>`
- [ ] Commits reference issue: `Fixes #<number>`
- [ ] First line under 72 characters
- [ ] No breaking changes without explicit approval

### 4. Pull Request Requirements
- [ ] PR title format: `<description> (#<number>)` (no colons)
- [ ] PR references issue: `Fixes #<number>` in body
- [ ] PR has assignee set
- [ ] PR has at least one `component:*` label
- [ ] All CI checks pass (validate this with @verify agent)

### 5. Security Requirements
- [ ] Security-gate agent has scanned changes
- [ ] No secrets detected
- [ ] No CRITICAL or HIGH severity vulnerabilities
- [ ] Human approval obtained for critical actions

## Workflow State Machine

```
┌─────────┐    ┌──────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Issue  │───▶│  Branch  │───▶│ Commit  │───▶│   PR    │───▶│  Merge  │
│ Created │    │ Created  │    │ Pushed  │    │ Opened  │    │ to dev  │
└─────────┘    └──────────┘    └─────────┘    └─────────┘    └─────────┘
     │               │               │              │               │
     ▼               ▼               ▼              ▼               ▼
┌─────────┐    ┌──────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│validate │    │validate  │    │validate │    │validate │    │validate │
│issue    │    │branch    │    │commit   │    │PR       │    │merge    │
└─────────┘    └──────────┘    └─────────┘    └─────────┘    └─────────┘
```

## Critical Actions Requiring Approval

The following workflow transitions ALWAYS require human approval:

1. **Pushing to main/dev**: Direct push to protected branches
2. **Merging to main**: Final release merges
3. **Force push**: Any `git push --force` operation
4. **Workflow bypass**: Skipping required checks
5. **Emergency changes**: Changes to `.security/` or `.github/workflows/`

## Validation Commands

### Check Issue Status
```bash
gh issue view <number> --json number,title,state,assignees,labels
```

### Check Branch Origin
```bash
git log --oneline dev..HEAD | tail -1  # Should be empty (branched from dev)
git merge-base --is-ancestor dev HEAD || echo "NOT from dev"
```

### Check Commit Format
```bash
git log --oneline -1 | grep -E '^(fix|feat|docs|refactor|test|chore|ci):'
git log --oneline -1 | grep -E 'Fixes #[0-9]+'
```

### Check PR Requirements
```bash
gh pr view <number> --json assignees,labels,title,body
```

## Failure Handling

If any validation step fails:

1. **Log the failure** with full context
2. **Block execution** of the action
3. **Provide remediation** guidance
4. **Alert human** via @security-gate agent

## Example Usage

```
@orchestrator Please validate the workflow for issue #917

Agent loads this skill and runs validation:
1. Check issue #917 exists ✓
2. Check issue is assigned ✓
3. Check branch issue-917/security-first-agentic-foundation format ✓
4. Check branch from dev ✓
5. Check commits reference #917 ✓
6. Check security-gate approval ✓

Result: All validations passed. Workflow approved.
```

## Integration

This skill is automatically invoked by:
- @orchestrator agent for workflow coordination
- @security-gate agent for compliance validation
- GitHub Actions for CI/CD enforcement

## Compliance Rules

| Rule | Source | Enforcement |
|------|--------|-------------|
| Issue-first | AGENTS.md | Block execution without valid issue |
| No colons in titles | DEVELOPMENT.md | Reject malformed titles |
| Branch from dev | AGENTS.md | Reject branches from main |
| Component labels required | workflow-governance.md | Reject unlabeled PRs |
| Assignee required | workflow-governance.md | Reject unassigned PRs |

## Self-Verification

Before claiming compliance, verify:
- [ ] All AGENTS.md rules followed
- [ ] All DEVELOPMENT.md rules followed
- [ ] All platform invariants preserved
- [ ] Security gate approval obtained
- [ ] Audit trail will be complete