---
description: Creates a GitHub issue following the Issue-First workflow
agent: agent-context
---

# /issue Command

Creates a GitHub issue following the AIXCL Issue-First workflow.

## Usage

```
/issue
```

Or with arguments:

```
/issue Create a new feature for user authentication
```

## What It Does

1. Loads the action-create-issue.md action file
2. Determines appropriate issue type (TASK, BUG, or FEATURE)
3. Infers component, priority, and profile labels
4. Drafts issue title and body
5. Proposes to user for approval
6. Creates the issue using `gh issue create`
7. Notes the issue number for branch creation

## Requirements

- `gh` CLI installed and authenticated
- Valid GitHub repository remote
- Active issue number needed for next steps

## Next Steps

After creating the issue, use:
- `/branch` - Create branch from issue
- `/commit` - Commit changes
- `/pr` - Create pull request
- `/verify` - Verify CI status

## Example

```
/issue We need to add support for multiple database providers
```

This will:
- Infer `[FEATURE]` type
- Suggest `component:persistence` label
- Ask for confirmation before creation
- Output the issue number (e.g., #217)

## Related

- `/branch` - Create branch from this issue
- `/workflow` - Run full Issue-First workflow
