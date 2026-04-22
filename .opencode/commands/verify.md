---
description: Verifies CI status and ensures all GitHub Actions checks pass
agent: agent-context
---

# /verify Command

Verifies GitHub Actions CI status and ensures all checks pass before considering work complete.

## Usage

Run this slash command:
```
/verify
```

Or with PR number:

```
/verify 42
```

## What It Does

1. Lists recent CI workflow runs for current branch or PR
2. Monitors check status
3. Reports any failures
4. Confirms all checks pass
5. Task is complete when CI is green

## Checks Monitored

- Lint and format validation
- Test suites (unit/integration)
- Security scans
- Documentation checks
- Agent validation (./scripts/checks/check-agents.sh)

## Requirements

- `gh` CLI installed
- Active PR created
- CI workflows configured in repository

## Status Output

```
gh pr checks <number>

All checks were successful
0 failing, 3 successful, 0 pending

lint (successful)           3m ago  2m
test (successful)           3m ago  5m
security-scan (successful)  3m ago  1m
```

## Handling Failures

If CI fails:
1. View detailed logs: `gh run view <run-id> --log`
2. Identify failure cause
3. Fix locally on your branch
4. Commit and push fixes
5. Re-run /verify

## Requirements

- All checks must pass (green)
- No pending jobs
- Code review approved (if required)

## Example

```
/verify
```

This will:
- Check CI status for current PR
- Report status of all checks
- Wait for completion if still running
- Confirm when all checks pass

## Related

- `/pr` - Create pull request
- `/workflow` - Run full Issue-First workflow
