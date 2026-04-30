---
description: Lists all available actions in the ai/actions/ directory
agent: agent-context
---

# /actions Command

Lists all available actions in the ai/actions/ directory with descriptions.

## Usage

Run this slash command:
```
/actions
```

## What It Does

1. Scans ai/actions/ directory
2. Reads YAML frontmatter from each action-*.md file
3. Displays action name, description, and category
4. Shows usage requirements
5. Groups actions by category

## Output

```
Available Actions:

Workflow Actions:
- create-issue: Creates a GitHub issue following the Issue-First workflow
- create-branch: Creates a feature branch from dev
- commit: Commits changes using conventional commit format
- create-pr: Creates a GitHub pull request
- verify-ci: Verifies CI status and ensures all checks pass

Validation Actions:
- lint-agents: Validates agent and action files for compliance

Style Actions:
- icon-usage: Guidelines for using icons and special characters
```

## Requirements

- Access to ai/actions/ directory
- Read permissions on action files

## Using Actions

Actions are automatically loaded by the agent-context when needed. To use a specific action, simply ask the agent to perform that task, e.g.:

"Create an issue for this feature"
"Commit my changes with issue reference"
"Create a PR for the current branch"

## Custom Actions

To add a new action:

1. Create file: `ai/actions/action-<name>.md`
2. Add YAML frontmatter with name, description, category
3. Document the action steps
4. Run `/lint` to validate
5. Commit the new action

## Example

```
/actions
```

This will display all available actions with their descriptions.

## Related

- `/workflow` - Full development workflow
- `/lint` - Validate agents and actions
