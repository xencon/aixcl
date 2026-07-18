# Development Workflow Guide

This document describes the standard development workflow for AIXCL. **All contributors, including agents, must follow this workflow.**

## Overview

We follow an **Issue-First Development** workflow:
1. Create an issue describing the problem or feature
2. Create a branch to address the issue
3. Make changes and commit
4. Push changes and create a Pull Request that references the issue
5. Review and merge

## Step-by-Step Workflow

### 1. Create an Issue First

**Always create an issue before starting work.** This ensures:
- Problems are documented and tracked
- PRs can reference the issue they're solving
- Discussion happens before implementation
- Work is traceable and organized

**Use the wrapper script** (validates the title prefix, applies the
taxonomy type label, always sets the assignee, and checks reference
style in custom bodies):

```bash
./scripts/utils/create-issue.sh "[TASK] Brief description" task "component:cli" <your-github-username> [body-file]
```

If you must use raw `gh issue create`, always pass `--label` (including
the type label from the AGENTS.md Label Taxonomy) and `--assignee` at
creation time, and use `--body-file` rather than inline `--body`.

**Best Practices:**
- Use clear, descriptive titles
- Provide context and background
- Include steps to reproduce (for bugs)
- Use plain text formatting (avoid special Unicode characters)
- **Always add appropriate labels** (see Label Guidelines below)
- **Always assign the issue** to the person working on it using `--assignee`

### 2. Create a Branch

Create a branch from `dev` with a descriptive name:

```bash
git checkout dev
git pull origin dev
git checkout -b issue-<number>/<short-description>
```

**Branch naming convention:**
- `issue-<number>/<short-description>` (e.g., `issue-217/fix-encoding-problem`)
- `feature/<name>` for new features
- `fix/<name>` for bug fixes
- `refactor/<name>` for refactoring

### 3. Make Changes and Commit

Make your changes, then commit with clear messages:

```bash
git add <files>
git commit -m "type: Brief description

- Detailed point 1
- Detailed point 2

Fixes #<issue-number>"
```

**Commit message format:**
- Use conventional commit types: `fix:`, `feat:`, `refactor:`, `docs:`, `test:`, etc.
- Reference the issue number in the commit message
- Keep the first line under 72 characters
- Use bullet points for multiple changes

**GPG-Signed Commits (Required for main/dev):**

All commits to `main` and `dev` branches must be GPG-signed. Setup is automated:

```bash
# One-time setup
./scripts/utils/setup-gpg.sh

# Commits are automatically signed after setup
git commit -m "feat: add new feature"

# Verify signature
git log --show-signature
```

See [GPG-Signed Commits Guide](./gpg-signed-commits.md) for complete documentation.

### 4. Push and Create Pull Request

Push your branch and create a PR with the wrapper script, which sets
the assignee and labels at creation time:

```bash
git push -u origin <branch-name>
./scripts/utils/create-pr.sh
```

**Never** set the assignee or labels in a second step (`gh pr edit`
after `gh pr create`). The PR validation workflow fires on the
`opened` event; a PR created without assignee and labels fails
validation permanently. See DEVELOPMENT.md Section 5 for the raw
`gh pr create` fallback with `--assignee` and `--label` flags.

**PR Best Practices:**
- Title should reference the issue without colon: `"Fix Issue title (#<number>)"`
- **Note:** Both issue titles and PR titles should NOT use colons (e.g., "Fix CLI error handling" not "Fix: CLI error handling")
- **Always assign the PR** to the author
- **Always add labels to the PR** matching the labels on the linked issue
- Description should:
  - Link to the issue: `"Fixes #<number>"` or `"Addresses #<number>"`
  - Describe what changed
  - Use plain text formatting (markdown checkboxes `- [x]` instead of Unicode)
  - Include testing notes if applicable
- **Verify CI Status**: Monitor the status checks in the GitHub PR interface. The task is not complete until all checks (Bash-CI, CodeQL, etc.) are green.

**Example PR body:**
```markdown
Fixes #217

## Changes
- [x] Fixed encoding issue in issue/PR descriptions
- [x] Updated workflow documentation
- [x] Added plain text formatting guidelines

## Testing
- Verified issue creation works correctly
- Confirmed PR formatting displays properly
```

### 5. Review and Merge

- **Verify CI Status**: Ensure all automated checks (Linting, Security, Environment) have passed. The change is not complete until CI is green.
- Wait for code review
- Address feedback
- Once approved and status checks are passing, merge via GitHub UI or CLI

### Promotion Workflow (Dev to Main)

When releasing changes from `dev` to `main`:

1. **Ensure all CI checks pass on `dev`:**
   ```bash
   git checkout dev
   git pull origin dev
   ```

2. **Create a release issue (optional but recommended):**
   ```bash
   cat > /tmp/release-issue.md << 'EOF'
   ## Release X.Y.Z
   
   ## Deliverables
   - [ ] Changelog updated
   - [ ] All tests passing on dev
   - [ ] Documentation updated
   EOF
   gh issue create --title "Release X.Y.Z" --body-file /tmp/release-issue.md --label "component:infrastructure,Maintenance" --assignee <your-github-username>
   ```

3. **Create promotion PR:**
   ```bash
   gh pr create --title "Release X.Y.Z (#<release-issue>)" --body "Fixes #<release-issue>" --base main --head dev --assignee <your-github-username> --label "component:infrastructure"
   ```

4. **Merge after final review and status checks**

## Changelog Policy

**CHANGELOG updates happen at release time, not at merge time.**

This project uses the `[Unreleased]` section in `CHANGELOG.md` strictly as a placeholder. Individual feature or fix PRs **must not** edit `CHANGELOG.md`. This avoids:
- Merge conflicts on the `[Unreleased]` section from parallel PRs
- Wasted administrative commits and CI cycles for every merged change
- Documenting changes that may later be reverted or superseded

**How it works:**
1. Changes merge to `dev` with no CHANGELOG edit
2. Issues and PRs serve as the canonical pre-release history
3. When cutting a release, the release author compiles all merged PRs since the last version
4. The CHANGELOG is updated in the promotion PR (`dev` -> `main`) that creates the release
5. The `[Unreleased]` section is replaced with the new version header and date

**Rationale:** Issues and PRs already provide full traceability. The CHANGELOG is a release artifact for end-users, not a running development log.

## Human in the Loop Checklist Policy

The agent MUST distinguish between agent-completed items and human-verification items.

| Party | Fills [x] | Example |
|-------|-----------|---------|
| Agent | Items the agent performed | "Issue referenced", "Branch named correctly" |
| Human | Items requiring manual verification | "Behavior works as expected", "No regressions observed" |

The human sees `[ ]` on verification items and ticks them during code review. The checklist serves as a gate, not passive decoration.

## Label Guidelines

**The label taxonomy is defined once, in AGENTS.md Section 3 (Label Taxonomy) -- that section is canonical; do not invent labels outside it.**

In summary: exactly one type label (`Bug`, `Feature`, `Task`), at least one `component:*` label (required), optional priority (`P1`-`P3`), optional profile (`profile:bld`, `profile:sys`), and optional category (`Fix`, `Enhancement`, `Refactor`, `Maintenance`).

`./scripts/utils/create-issue.sh` applies the type label automatically from its type argument. Labels applied by GitHub automation (e.g. `dependencies` on Dependabot PRs) are tolerated but never added by hand.

### Checking Available Labels

```bash
# List all labels
gh label list

# List labels for a specific issue
gh issue view <number> --json labels
```

## Formatting Guidelines

**IMPORTANT: Use plain text formatting to avoid encoding issues.**

### DO:
- Use markdown checkboxes: `- [x]` for completed items
- Use standard markdown: `**bold**`, `*italic*`, `` `code` ``
- Use plain ASCII characters
- Use numbered lists: `1.`, `2.`, `3.`

### DON'T:
- Use Unicode checkmarks (for example, `\\u2713`, `\\u2714`, or checkmark emoji) as they can appear garbled
- Use emoji in technical documentation
- Use special Unicode characters that may not render consistently

## Line Endings

All text files in this repository must use **Unix-style line endings (LF)**, not Windows-style (CRLF).

### Why This Matters
- Cross-platform compatibility
- Consistent diffs and reviews
- Git best practices

### Automatic Handling
The repository includes a `.gitattributes` file that automatically converts line endings for most contributors.

### Manual Conversion (if needed)
If you accidentally commit files with CRLF line endings, convert them before submitting a PR:

```bash
# Convert a single file
sed -i 's/\r$//' <filename>

# Convert all files in a directory
find . -type f -name "*.md" -exec sed -i 's/\r$//' {} \;
```

### CI Check
The CI workflow automatically checks for CRLF line endings and will fail the build if any are found.

**GitHub Code Quality Agent findings and automated fixes:**
- Automated PRs from GitHub Code Quality (Copilot Autofix) may bypass the Issue-First workflow
- These PRs should still be reviewed carefully before merging
- After merging automated PRs, create a documentation issue to track the work completed
- This ensures traceability even when automation creates PRs directly

**Example:** If automated PRs #351-355 are merged, create issue #356 documenting them.

## Running the workflow with OpenCode CLI

A single agent runs this workflow end-to-end (issue, branch, commit, PR, assign and label). Use it from the repo root with OpenCode CLI and approve `gh`/`git` tool calls when prompted:

```bash
opencode
```

See [opencode-setup.md](./opencode-setup.md) for installation and configuration instructions.

## Agent Instructions

```
Follow the development workflow documented in this document:
1. Always create an issue first using './scripts/utils/create-issue.sh' with appropriate labels and assignee
2. Read the template file first before composing any issue or PR body
3. Use /tmp for all generated body files and drafts (never commit generated artifacts)
4. Create a branch with format 'issue-<number>/<description>' from dev
5. Make changes and commit with conventional commit format
6. Push branch and create PR with './scripts/utils/create-pr.sh' (assignee and labels are set at creation time, never via a later 'gh pr edit')
8. Use plain text formatting (markdown checkboxes - [x], not Unicode)
9. Reference the issue number in commits and PRs
10. Add labels to issues (type, component, priority, profile as applicable)
11. Verify CI status: Monitor GitHub Actions and ensure all checks are green before finalizing the task
12. For automated PRs, document them retroactively with an issue
13. Follow Human in the Loop policy: Agent fills [x] for agent-completed items, Human fills [x] for verification items
```

## Quick Reference Commands

```bash
# Create issue (validates title, applies type label, sets assignee)
# Note: No colons in issue or PR titles (e.g., "Fix CLI error handling" not "Fix: CLI error handling")
./scripts/utils/create-issue.sh "[BUG] Fix CLI error handling" bug "component:cli,P1" <your-github-username>

# Create branch
git checkout -b issue-<number>/<description>

# Commit
git add <files>
git commit -m "type: Description

Fixes #<number>"

# Push and create PR (assignee and labels set at creation time)
git push -u origin issue-<number>/<description>
./scripts/utils/create-pr.sh
```

## Why This Workflow?

- **Traceability**: Every PR links to an issue explaining why it exists
- **Documentation**: Issues serve as documentation of problems and solutions
- **Organization**: Easier to track what's being worked on
- **Discussion**: Issues allow discussion before implementation
- **Consistency**: Standardized process works across all contributors

## Checking Agent and Skill Files

When creating or modifying agent files (`.opencode/agents/agent-*.md`), skills, rules, commands, or agent reports (`docs/reference/ai-report-*.md`), run the lint check script before committing:

```bash
./scripts/checks/check-agents.sh
```

This script validates:
- Agent naming convention (`agent-*.md`) and frontmatter (`description` required, `name` forbidden -- it overrides the filename-derived agent id)
- `SKILL.md` frontmatter (`name` and `description` required)
- Byte-identical mirror parity between `.claude/rules/` and `.opencode/rules/`, and between `.claude/skills/` and `.opencode/skills/`
- Body parity for commands present in both `.claude/commands/` and `.opencode/commands/` (frontmatter may differ per tool)
- AI report naming convention (`ai-report-*.md`)

The same checks run automatically in CI on pull requests that touch these paths (`check-opencode.yml`).

## Questions?

If you're unsure about the workflow, check:
- This document (`development-workflow.md`)
- [CONTRIBUTING.md](../../CONTRIBUTING.md) for general contribution guidelines
- Existing issues and PRs for examples
