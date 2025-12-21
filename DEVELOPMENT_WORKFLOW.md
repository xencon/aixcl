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
gh issue create --title "Brief description" --body "Detailed description of the problem or feature"
```

**Best Practices:**
- Use clear, descriptive titles
- Provide context and background
- Include steps to reproduce (for bugs)
- Use plain text formatting (avoid special Unicode characters)

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
1. Always create an issue first using 'gh issue create'
2. Create a branch with format 'issue-<number>/<description>'
3. Make changes and commit with conventional commit format
4. Push branch and create PR that references the issue
5. Use plain text formatting (markdown checkboxes - [x], not Unicode)
6. Reference the issue number in commits and PRs
```

## Quick Reference Commands

```bash
# Create issue
gh issue create --title "Title" --body "Description"

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

