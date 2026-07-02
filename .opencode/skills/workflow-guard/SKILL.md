---
name: workflow-guard
description: Validates Issue-First workflow compliance before execution
license: MIT
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  security_level: critical
  version: "1.1"
---

# Skill: workflow-guard

## Purpose

Validates that all actions comply with the Issue-First development workflow
before execution.

## When to Run

Before starting any code change, fix, or feature -- and again before
creating a PR.

## Validation Steps

### 1. Issue Requirements
- [ ] Issue exists in GitHub (open or closed)
- [ ] Issue is assigned to someone
- [ ] Issue has appropriate labels (component:* required)
- [ ] Issue title follows format: `[TYPE] Description` (no colons)
- [ ] **Issue body is clean** -- no shell command output, no backtick artifacts, no garbled CLI text
  - *Prevention*: When creating via `gh issue create`, always use `--body-file` with a file, or a quoted HEREDOC (`cat << 'EOF'`). Never use inline `--body` with multiline strings containing backticks.
  - *Detection*: If body contains strings like "Error:", "Usage:", log timestamps (e.g., "2024-01-01T..."), or container IDs (64-char hex), reject as garbled.

### 2. Branch Requirements
- [ ] Branch format: `issue-<number>/<short-description>`
- [ ] Branch created from `dev` (not `main`)
- [ ] No direct commits to `main` or `dev` branches

### 3. Commit Requirements
- [ ] Commit messages follow conventional format: `<type>: <description>`
- [ ] Commits reference issue: `Fixes #<number>`
- [ ] First line under 72 characters
- [ ] No breaking changes without explicit approval
- [ ] Diff verified: no unexplained mass deletions, no AI-elision placeholder text
  - *Detection*: `./scripts/checks/check-ai-elisions.sh --staged` (or `--range <base> <head>` for pushed commits)
  - *Background*: an AI-assisted edit once replaced a 639-line module with a stub whose final line claimed the remainder of the module was unchanged, and it was committed; the script catches both the phrase pattern and the deletion pattern

### 4. Pull Request Requirements
- [ ] PR title format: `<description> (#<number>)` (no colons)
- [ ] PR references issue: `Fixes #<number>` in body
- [ ] PR has assignee set
- [ ] PR has at least one `component:*` label
- [ ] All CI checks pass (validate this with @verify agent)
- [ ] Agent identification block present in PR body (agent-authored PRs only)
  ```bash
  echo "$PR_BODY" | bash scripts/checks/check-agent-id-block.sh
  ```

### 5. Security Requirements
- [ ] Security-gate agent has scanned changes
- [ ] No secrets detected
- [ ] No CRITICAL or HIGH severity vulnerabilities
- [ ] Human approval obtained for critical actions

## Workflow State Machine

```
+---------+    +----------+    +---------+    +---------+    +---------+
|  Issue  |--->|  Branch  |--->| Commit  |--->|   PR    |--->|  Merge  |
| Created |    | Created  |    | Pushed  |    | Opened  |    | to dev  |
+---------+    +----------+    +---------+    +---------+    +---------+
     |               |               |              |               |
     v               v               v              v               v
+---------+    +----------+    +---------+    +---------+    +---------+
|validate |    |validate  |    |validate |    |validate |    |validate |
|issue    |    |branch    |    |commit   |    |PR       |    |merge    |
+---------+    +----------+    +---------+    +---------+    +---------+
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

### Check Issue Body Cleanliness (prevent backtick injection)
```bash
# Check for garbled body: shell output, error messages, container IDs, timestamps
gbody=$(gh issue view <number> --json body -q '.body')
# Reject if body contains shell artifacts
if echo "$gbody" | grep -Eq '(Error:|Usage:|podman stop|^[a-f0-9]{64}$|20[0-9]{2}-[0-9]{2}-[0-9]{2}T)'; then
  echo "REJECT: Issue body appears garbled (backtick command substitution or shell output injected)"
  echo "Remediation: Recreate with --body-file or quoted HEREDOC"
  exit 1
fi
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
1. Check issue #917 exists [x]
2. Check issue is assigned [x]
3. Check branch issue-917/security-first-agentic-foundation format [x]
4. Check branch from dev [x]
5. Check commits reference #917 [x]
6. Check security-gate approval [x]

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
| Clean issue body | workflow-guard skill | Reject garbled body (backtick injection) |
| Branch from dev | AGENTS.md | Reject branches from main |
| Component labels required | DEVELOPMENT.md | Reject unlabeled PRs |
| Assignee required | DEVELOPMENT.md | Reject unassigned PRs |

## Self-Verification

Before claiming compliance, verify:
- [ ] All AGENTS.md rules followed
- [ ] All DEVELOPMENT.md rules followed
- [ ] All platform invariants preserved
- [ ] Security gate approval obtained
- [ ] Audit trail will be complete
