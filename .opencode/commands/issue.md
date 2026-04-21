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

1. Loads the template file from `ai/templates/issue/` first (`cat ai/templates/issue/task.md` for tasks, `bug_report.md` for bugs, `feature_request.md` for features)
2. Determines appropriate issue type (TASK, BUG, or FEATURE)
3. Drafts issue title and body using the template's exact section headings
4. Proposes to user for approval
5. Creates the issue using `gh issue create`
6. Enforces assignee and labels after creation:
   ```bash
   gh issue edit <number> --add-label "component:cli" --add-assignee <username>
   ```
7. Notes the issue number for branch creation

## Requirements

- `gh` CLI installed and authenticated
- Valid GitHub repository remote
- Must read template file before composing body
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
- Read `ai/templates/issue/feature_request.md` first
- Draft title `[FEATURE] Add support for multiple database providers`
- Use exact section headings from the template (Feature Overview, Problem Statement, etc.)
- Suggest `component:persistence` label
- Ask for confirmation before creation
- Output the issue number (e.g., #217)
- Run `gh issue edit` to enforce label and assignee

## Related

- `/branch` - Create branch from this issue
- `/workflow` - Run full Issue-First workflow
