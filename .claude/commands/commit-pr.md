---
description: Commit changes and create a PR following AIXCL Issue-First workflow
disable-model-invocation: true
allowed-tools: Bash(git add *), Bash(git commit *), Bash(git push *), Bash(gh pr create *)
---

## Context

- Current branch: !`git branch --show-current`
- Current status: !`git status --short`
- Recent commits: !`git log --oneline -5`

## Your Task

Based on the above changes:

1. **Stage all changes** (if not already staged):
   ```bash
   git add .
   ```

2. **Create a conventional commit**:
   - Format: `<type>: <description> (under 72 chars)`
   - Reference issue: `Fixes #<issue-number>`
   - Use `./scripts/utils/create-pr.sh` wrapper if available, or craft manually
   - Example: `feat: Add CLAUDE.md for Claude Code compatibility`

3. **Push the branch to origin**:
   ```bash
   git push -u origin <branch-name>
   ```

4. **Create a pull request** using `gh pr create` with:
   - Title: `<description> (#<issue-number>)` (NO colons)
   - Body: `Fixes #<issue-number>`
   - Assignee: set at creation time (required by `pr-validation.yml`)
   - Label: at least one `component:*` label (required by `pr-validation.yml`)

   **IMPORTANT**: Pass `--assignee` and `--label` at creation time. Do NOT create then edit. The PR Validation workflow fires on the `opened` event. If assignee/label are not present at creation, the check will fail permanently.

   ```bash
   gh pr create --title "Description (#999)" --body "Fixes #999" --assignee <username> --label "component:infrastructure"
   ```

5. **Verify CI**: Monitor GitHub Actions and ensure all checks pass before completing.

## Safety Rules

- `git push --force` is **DENIED**
- `rm -rf` operations require explicit human approval
- Always reference the issue number in commits and PRs
- All CI checks must be green before the task is complete
