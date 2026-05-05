# Issue-First Workflow

## Core Rule
Always create an issue before starting work. Every code change, fix, or feature must be traceable to a GitHub issue.

## Step-by-Step

1. **Create Issue**
   - Title format: `[TYPE] Description` (e.g., `[TASK]`, `[BUG]`, `[FEATURE]`)
   - NO colons in titles
   - Use plain ASCII markdown (`- [x]` checkboxes, not Unicode)
   - Add labels: component (required), priority (optional), profile (optional)
   - Always assign the issue

2. **Create Branch**
   - Format: `issue-<number>/<short-description>`
   - Example: `issue-217/fix-encoding-problem`
   - Always branch from `dev`

3. **Make Changes**
   - Small, reversible steps
   - Follow project conventions
   - Run lint checks if modifying agent/action files

4. **Commit**
   - Format: `<type>: <description>` (under 72 chars)
   - Reference issue: `Fixes #<issue-number>`
   - Use bullet points for multiple changes

5. **Push and Create PR**
   - Title format: `<description> (#<number>)` (no colons)
   - PR body must reference issue: `Fixes #<number>`
   - Add matching labels to PR
   - Always assign the PR

6. **Verify CI**
   - Check GitHub Actions status
   - All status checks must be green before completing

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code |
| `dev` | Active development, feature integration |

Correct flow: `Feature Branch -> dev -> main`
