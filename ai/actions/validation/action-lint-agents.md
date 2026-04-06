---
name: Lint Agents and Actions
description: Validates AI agent files and action files for compliance with naming conventions and structure
category: validation
tool: bash
requires:
  - bash shell
  - Local repository clone
  - scripts/checks/check-agents.sh or equivalent
---

# Action: Lint Agents and Actions

Validates AI agent files and action files for compliance with naming conventions and structure.

## Commands

```bash
# Run the validation script
./scripts/checks/check-agents.sh
```

## What It Validates

### Agent Files (ai/orchestration/agent-*.md)

1. **Naming Convention**
   - Must match `agent-*.md` pattern

2. **YAML Frontmatter**
   - Must have `---` delimiters
   - Must include `name` field
   - Must include `description` field
   - Must include `role: system`

3. **Required Sections**
   - `Purpose`
   - `Canonical references`
   - `Global rules`
   - `Tool usage`
   - `Workflow steps`
   - `Safety`

4. **Required References**
   - Must reference `docs/developer/development-workflow.md`
   - Must reference `docs/architecture/governance/01_ai_guidance.md`

### Action Files (ai/actions/action-*.md)

1. **Naming Convention**
   - Must match `action-*.md` pattern

2. **YAML Frontmatter** (Recommended)
   - `name` - Human-readable action name
   - `description` - What the action does
   - `category` - Type of action (e.g., workflow, validation)
   - `tool` - Primary tool used (e.g., gh, git)
   - `requires` - Prerequisites list

## Process

1. Run `./scripts/checks/check-agents.sh`
2. Review output
3. Fix any errors
4. Re-run until all checks pass

## Error Handling

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more errors found

**Error Levels:**
- **ERROR** - Must fix before committing
- **WARN** - Should fix, but not blocking

## Examples

### Running the Check

```bash
$ ./scripts/checks/check-agents.sh
Checking AI agents, skills, and reports...

INFO: Checking agent: agent-developer-workflow.md
INFO: Checking action: action-create-issue.md
INFO: Checking action: action-commit.md
...

INFO: All checks passed!
```

### With Errors

```bash
$ ./scripts/checks/check-agents.sh
Checking AI agents, skills, and reports...

INFO: Checking agent: agent-developer-workflow.md
ERROR: agent-developer-workflow.md: Missing required section: Safety
ERROR: Found 1 error(s)
```

## Pre-Commit Hook

Consider adding to pre-commit:

```bash
#!/bin/bash
# .git/hooks/pre-commit

if git diff --cached --name-only | grep -E 'ai/(orchestration|actions)/.*\.md'; then
    echo "Running agent/action validation..."
    if ! ./scripts/checks/check-agents.sh; then
        echo "Agent validation failed. Fix errors before committing."
        exit 1
    fi
fi
```

## When to Run

- Before committing changes to agent/action files
- Before creating a PR that modifies ai/ directory
- As part of CI/CD pipeline
- After creating new agents or actions

## Troubleshooting

**Script not found:**
- Ensure you're in repository root
- Check that script exists: `ls scripts/checks/check-agents.sh`
- Make script executable: `chmod +x scripts/checks/check-agents.sh`

**Permission denied:**
- Make script executable: `chmod +x scripts/checks/check-agents.sh`

## Verification

After running:
- [ ] No ERROR messages
- [ ] All WARN messages addressed (or acknowledged)
- [ ] Script exits with code 0
- [ ] Ready to commit
