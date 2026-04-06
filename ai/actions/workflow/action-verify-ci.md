---
name: Verify CI Status
description: Checks GitHub Actions CI status and ensures all checks pass before completing work
category: workflow
tool: gh
requires:
  - gh CLI installed
  - Pull request created
  - Access to GitHub repository
---

# Action: Verify CI Status

Checks GitHub Actions CI status and ensures all checks pass before considering work complete.

## Commands

```bash
# List recent runs for a branch
gh run list --branch=<branch-name> --limit=5

# View specific workflow run
gh run view <run-id>

# View PR status (includes CI)
gh pr view <pr-number>

# Check PR checks status
gh pr checks <pr-number>
```

## What to Check

1. **All workflows completed** - No pending jobs
2. **All checks passed** - Green status on all required checks
3. **No failures** - No red X marks
4. **Required reviews** - Code review approval if required

## Common CI Checks in AIXCL

Based on repository structure, typical checks may include:

- **Lint / Format checks** - Code style validation
- **Test suites** - Unit/integration tests
- **Security scans** - Dependency vulnerabilities, secrets scanning
- **Documentation** - Link checking, markdown linting
- **Agent validation** - `./scripts/checks/check-agents.sh`

## Process

1. After creating PR, wait a few moments for CI to start
2. Run `gh run list` to see active runs
3. Monitor progress (can take several minutes)
4. Verify all checks show as completed and passing
5. If failures, investigate and fix
6. Re-run checks after fixes

## Handling Failures

If CI fails:

1. **View logs**: `gh run view <run-id> --log`
2. **Identify the failure** - Which check failed and why
3. **Fix locally** - Make changes on your branch
4. **Commit fix** - Use same conventional commit format
5. **Push** - Changes trigger new CI run
6. **Verify** - Confirm all checks pass

## Required Status

**IMPORTANT**: The task is NOT complete until:
- All CI checks are green
- Required reviews are obtained
- No outstanding failures

## Verification Checklist

Before marking task complete:
- [ ] All CI workflows completed
- [ ] All status checks passed (green)
- [ ] No test failures
- [ ] No lint/format errors
- [ ] Code review approved (if required)
- [ ] Ready to merge

## Example Output

```
gh pr checks 42

Some checks are still pending
0 failed, 1 successful, 2 pending

X codeql-analysis (successful)        3m ago  2m
  lint (pending)                       3m ago  0m
  test (pending)                       3m ago  0m
```

Wait for all to be "successful" before proceeding.
