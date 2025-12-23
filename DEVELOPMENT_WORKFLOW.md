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
gh issue create --title "Brief description" --body "Detailed description of the problem or feature" --label "type:bug,component:cli"
```

**Best Practices:**
- Use clear, descriptive titles
- Provide context and background
- Include steps to reproduce (for bugs)
- Use plain text formatting (avoid special Unicode characters)
- **Always add appropriate labels** (see Label Guidelines below)

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
```

**PR Best Practices:**
- Title should reference the issue: `"Fix: Issue title (#<number>)"`
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

**Labels are required for all issues.** Labels help organize issues, track work, and make it easier to find related issues.

### Label Categories

Labels are organized into categories using prefixes:

#### Type Labels (Required - Select One)

These labels should be created in GitHub's label sections if they don't exist. These correspond to GitHub's issue types:

- `Bug` - An unexpected problem or behavior (GitHub issue type)
- `Feature` - A request, idea, or new functionality (GitHub issue type)
- `Task` - A specific piece of work (GitHub issue type)
- `Fix` - A fix for a bug or issue (custom issue type)
- `Enhancement` - Improvement to existing functionality
- `Refactor` - Code refactoring without changing functionality
- `Maintenance` - Maintenance tasks and housekeeping
- `documentation` - Improvements or additions to documentation (GitHub default)

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

#### Other Labels
- `dependencies` - Dependency updates and management
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `question` - Further information is requested

### How to Add Labels

**When creating an issue:**
```bash
# Add labels during creation
gh issue create --title "Title" --body "Description" --label "Bug,component:cli,priority:high"

# Or add labels after creation
gh issue edit <number> --add-label "Bug,component:cli"
```

**Label Selection Guidelines:**
1. **Always select one type label** - This categorizes the issue
2. **Select relevant component labels** - Helps identify which part of the system is affected
3. **Select priority if applicable** - Helps prioritize work
4. **Select profile labels if issue is profile-specific** - Helps identify deployment impact
5. **Use other labels as appropriate** - `good first issue`, `help wanted`, etc.

**Examples:**
- Bug in CLI: `Bug,component:cli`
- New feature for observability: `Feature,component:observability`
- Fix for database issue: `Fix,component:persistence`
- Task for infrastructure: `Task,component:infrastructure`
- Enhancement affecting all profiles: `Enhancement,profile:usr,profile:dev,profile:ops,profile:sys`
- High priority bug: `Bug,component:runtime-core,priority:high`
- Dependency update: `dependencies,Maintenance`

### Checking Available Labels

```bash
# List all labels
gh label list

# List labels for a specific issue
gh issue view <number> --json labels
```

## Formatting Guidelines

**IMPORTANT: Use plain text formatting to avoid encoding issues.**

### ✅ DO:
- Use markdown checkboxes: `- [x]` for completed items
- Use standard markdown: `**bold**`, `*italic*`, `` `code` ``
- Use plain ASCII characters
- Use numbered lists: `1.`, `2.`, `3.`

### ❌ DON'T:
- Use Unicode checkmarks: `✓`, `✔`, `✅` (these can appear garbled)
- Use emoji in technical documentation
- Use special Unicode characters that may not render consistently

## AI Assistant Instructions

When working with AI assistants (like Cursor, GitHub Copilot, etc.), include this prompt:

```
Follow the development workflow documented in DEVELOPMENT_WORKFLOW.md:
1. Always create an issue first using 'gh issue create' with appropriate labels
2. Create a branch with format 'issue-<number>/<description>'
3. Make changes and commit with conventional commit format
4. Push branch and create PR that references the issue
5. Use plain text formatting (markdown checkboxes - [x], not Unicode)
6. Reference the issue number in commits and PRs
7. Add labels to issues (type, component, priority, profile as applicable)
```

## Quick Reference Commands

```bash
# Create issue with labels
gh issue create --title "Title" --body "Description" --label "Bug,component:cli,priority:high"

# Or add labels after creation
gh issue edit <number> --add-label "Bug,component:cli"

# Create branch
git checkout -b issue-<number>/<description>

# Commit
git add .
git commit -m "type: Description

Fixes #<number>"

# Push and create PR
git push -u origin issue-<number>/<description>
gh pr create --title "Fix: Title (#<number>)" --body "Fixes #<number>

## Changes
- [x] Change 1
- [x] Change 2"
```

## Why This Workflow?

- **Traceability**: Every PR links to an issue explaining why it exists
- **Documentation**: Issues serve as documentation of problems and solutions
- **Organization**: Easier to track what's being worked on
- **Discussion**: Issues allow discussion before implementation
- **Consistency**: Standardized process works across all contributors

## Questions?

If you're unsure about the workflow, check:
- This document (`DEVELOPMENT_WORKFLOW.md`)
- `CONTRIBUTING.md` for general contribution guidelines
- Existing issues and PRs for examples

