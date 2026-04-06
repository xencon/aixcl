---
description: Validates agent files and action files for compliance with naming conventions
agent: agent-context
---

# /lint Command

Validates AI agent files and action files for compliance with naming conventions and structure.

## Usage

```
/lint
```

## What It Does

1. Runs `./scripts/checks/check-agents.sh`
2. Validates agent files (ai/orchestration/agent-*.md):
   - Naming convention (agent-*.md)
   - YAML frontmatter (name, description, role)
   - Required sections (Purpose, Global rules, etc.)
   - References to core docs
3. Validates action files (ai/actions/action-*.md):
   - Naming convention (action-*.md)
   - YAML frontmatter presence
4. Reports errors and warnings
5. Confirms validation passes

## Requirements

- bash shell
- Repository cloned locally
- `scripts/checks/check-agents.sh` exists

## Exit Codes

- `0` - All checks passed
- `1` - Errors found

## Example

```
/lint
```

Output:
```
Checking AI agents, skills, and reports...

INFO: Checking agent: agent-developer-workflow.md
INFO: Checking action: action-create-issue.md
INFO: Checking action: action-commit.md
...

INFO: All checks passed!
```

## When to Run

- Before committing changes to ai/ directory
- Before creating PRs
- After creating new agents or actions
- As part of CI/CD validation

## Fixing Errors

If errors found:
1. Review error messages
2. Fix identified issues
3. Re-run /lint
4. Commit when clean

## Related

- `/workflow` - Full development workflow
