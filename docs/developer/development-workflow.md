# Development Workflow Guide

This document describes the standard development workflow for AIXCL. **All contributors, including AI assistants, must follow this workflow.**

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

**Using GitHub CLI:**
```bash
# Note: GitHub CLI doesn't support setting issue type directly
# Set the type in GitHub UI, then add labels:
gh issue create --title "Brief description" --body "Detailed description of the problem or feature" --label "component:cli" --assignee <your-github-username>
```

**Best Practices:**
- Use clear, descriptive titles
- Provide context and background
- Include steps to reproduce (for bugs)
- Use plain text formatting (avoid special Unicode characters)
- **Always add appropriate labels** (see Label Guidelines below)
- **Always assign the issue** to the person working on it using `--assignee`

### 2. Create a Branch

Create a branch from `main` with a descriptive name:

```bash
git checkout main
git pull origin main
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

### 4. Push and Create Pull Request

Push your branch and create a PR:

```bash
git push -u origin <branch-name>
gh pr create --title "Title referencing issue" --body "Description linking to issue #<number>"

# Always assign yourself and add matching labels to the PR
gh pr edit <number> --add-assignee <your-github-username> --add-label "component:cli"
```

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

- Wait for code review
- Address feedback
- Once approved, merge via GitHub UI or CLI

## Label Guidelines

**GitHub Issue Types and Labels are required for all issues.** GitHub has native issue types that are separate from labels. Both help organize issues, track work, and make it easier to find related issues.

### GitHub Issue Types (Required - Select One)

GitHub provides native issue types that must be set for each issue. These are separate from labels:

- **Bug** - An unexpected problem or behavior
- **Feature** - A request, idea, or new functionality
- **Task** - A specific piece of work

**Note:** You cannot create custom issue types in GitHub. Use labels for additional categorization (see below).

### Label Categories

Labels are organized into categories using prefixes:

#### Component Labels (Select All That Apply)
- `component:runtime-core` - Runtime core services (Ollama, LLM-Council, Continue)
- `component:ollama` - Ollama LLM inference engine
- `component:llm-council` - LLM Council multi-model orchestration
- `component:persistence` - Database and persistence services (PostgreSQL, pgAdmin)
- `component:observability` - Monitoring and observability (Prometheus, Grafana, Loki, Promtail)
- `component:ui` - User interface components (Open WebUI)
- `component:cli` - Command-line interface and tooling
- `component:infrastructure` - Infrastructure and deployment (Docker, profiles, configuration)
- `component:testing` - Tests and test infrastructure

#### Priority Labels (Optional - Select One)
- `priority:high` - High priority issue requiring immediate attention
- `priority:medium` - Medium priority issue
- `priority:low` - Low priority issue

#### Profile Labels (Select All That Apply)
- `profile:usr` - Affects usr profile (minimal footprint)
- `profile:dev` - Affects dev profile (developer workstation)
- `profile:ops` - Affects ops profile (observability-focused)
- `profile:sys` - Affects sys profile (full deployment)

#### Category Labels (Select All That Apply)
- `Fix` - A fix for a bug or issue (use with Bug issue type)
- `Enhancement` - Improvement to existing functionality (use with Feature issue type)
- `Refactor` - Code refactoring without changing functionality (use with Task issue type)
- `Maintenance` - Maintenance tasks and housekeeping (use with Task issue type)
- `documentation` - Improvements or additions to documentation (GitHub default)

**Note:** "Task" is an issue type, not a label. Use the Task issue type for tasks, refactoring, and maintenance work. Do not create a "Task" label as it's redundant with the issue type.

#### Other Labels
- `dependencies` - Dependency updates and management
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `question` - Further information is requested

### How to Add Labels

**When creating an issue:**
```bash
# Add labels during creation (set issue type in GitHub UI)
gh issue create --title "Title" --body "Description" --label "component:cli,priority:high"

# Or add labels after creation
gh issue edit <number> --add-label "component:cli"
```

**Note:** GitHub CLI doesn't support setting the issue type (Bug/Feature/Task) directly. Set the type in the GitHub web interface, then use CLI for labels.

**Issue Type and Label Selection Guidelines:**
1. **Always select one GitHub issue type** - Bug, Feature, or Task (set via GitHub's Type field)
   - **Note:** "Task" is an issue type only, not a label. Do not create or use a "Task" label.
2. **Select relevant component labels** - Helps identify which part of the system is affected
3. **Select category labels if applicable** - Fix, Enhancement, Refactor, Maintenance for additional context
4. **Select priority if applicable** - Helps prioritize work
5. **Select profile labels if issue is profile-specific** - Helps identify deployment impact
6. **Use other labels as appropriate** - `good first issue`, `help wanted`, etc.

**Examples:**
- Bug in CLI: Type: **Bug**, Labels: `component:cli`
- New feature for observability: Type: **Feature**, Labels: `component:observability`
- Fix for database issue: Type: **Bug**, Labels: `Fix,component:persistence`
- Task for infrastructure: Type: **Task**, Labels: `component:infrastructure`
- Enhancement affecting all profiles: Type: **Feature**, Labels: `Enhancement,profile:usr,profile:dev,profile:ops,profile:sys`
- High priority bug: Type: **Bug**, Labels: `component:runtime-core,priority:high`
- Dependency update: Type: **Task**, Labels: `dependencies,Maintenance`

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

## Handling Automated PRs

**GitHub Code Quality AI findings and automated fixes:**
- Automated PRs from GitHub Code Quality (Copilot Autofix) may bypass the Issue-First workflow
- These PRs should still be reviewed carefully before merging
- After merging automated PRs, create a documentation issue to track the work completed
- This ensures traceability even when automation creates PRs directly

**Example:** If automated PRs #351-355 are merged, create issue #356 documenting them.

## AI Assistant Instructions

When working with AI assistants (like Cursor, GitHub Copilot, etc.), include this prompt:

```
Follow the development workflow documented in this document:
1. Always create an issue first using 'gh issue create' with appropriate labels and assignee
2. Create a branch with format 'issue-<number>/<description>'
3. Make changes and commit with conventional commit format
4. Push branch and create PR that references the issue
5. Assign the PR and add matching labels to it
6. Use plain text formatting (markdown checkboxes - [x], not Unicode)
7. Reference the issue number in commits and PRs
8. Add labels to issues (type, component, priority, profile as applicable)
9. For automated PRs, document them retroactively with an issue
```

## Quick Reference Commands

```bash
# Create issue with labels and assignee (set issue type in GitHub UI)
# Note: Both issue and PR titles should NOT include colon (e.g., "Fix CLI error handling" not "Fix: CLI error handling")
gh issue create --title "Fix CLI error handling" --body "Description" --label "component:cli,priority:high" --assignee <your-github-username>

# Or add labels/assignee after creation
gh issue edit <number> --add-label "component:cli" --add-assignee <your-github-username>

# Create branch
git checkout -b issue-<number>/<description>

# Commit
git add .
git commit -m "type: Description

Fixes #<number>"

# Push and create PR
git push -u origin issue-<number>/<description>
gh pr create --title "Fix Title (#<number>)" --body "Fixes #<number>

## Changes
- [x] Change 1
- [x] Change 2"

# Assign and label the PR (matching the issue labels)
gh pr edit <number> --add-assignee <your-github-username> --add-label "component:cli,priority:high"
```

## Why This Workflow?

- **Traceability**: Every PR links to an issue explaining why it exists
- **Documentation**: Issues serve as documentation of problems and solutions
- **Organization**: Easier to track what's being worked on
- **Discussion**: Issues allow discussion before implementation
- **Consistency**: Standardized process works across all contributors

## Questions?

If you're unsure about the workflow, check:
- This document (`development-workflow.md`)
- [`contributing.md`](./contributing.md) for general contribution guidelines
- Existing issues and PRs for examples

