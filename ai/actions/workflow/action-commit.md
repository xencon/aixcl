---
name: Commit Changes
description: Commits changes using conventional commit format with issue reference
category: workflow
tool: git
requires:
  - git installed
  - Changes staged or ready to stage
  - Issue number available
---

# Action: Commit Changes

Commits changes using conventional commit format with proper issue reference.

## Commands

```bash
# Stage changes
git add .

# Commit with conventional format
git commit -m "<type>: <short description>

<longer description if needed>

Fixes #<issue-number>"
```

## Commit Types

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code style changes (formatting, semicolons, etc.)
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks
- `ci` - CI/CD changes

## Format Rules

### Short Description
- First line under 72 characters
- Use imperative mood ("Add feature" not "Added feature")
- Be concise but descriptive

### Body (Optional)
- Add blank line after short description
- Explain what and why, not how
- Use bullet points for multiple changes

### Issue Reference
- Always include `Fixes #<number>` or `Addresses #<number>`
- Place at end of commit message
- Can reference multiple issues: `Fixes #123, fixes #456`

## Examples

**Simple:**
```
feat: Add dark mode toggle

Fixes #217
```

**Detailed:**
```
fix: Resolve encoding issue in PR descriptions

- Updated markdown parser to handle special characters
- Added validation for non-ASCII characters
- Updated tests to cover edge cases

Fixes #218
```

**Multiple changes:**
```
refactor: Simplify configuration loading

- Extracted parser into separate module
- Added type hints for better IDE support
- Removed redundant validation logic

Fixes #220
Addresses #219
```

## Verification

Before committing:
- [ ] All changes intended for commit are staged
- [ ] Commit type is appropriate
- [ ] Short description is under 72 characters
- [ ] Issue number is referenced
- [ ] No sensitive data in commit

## Best Practices

1. **Commit early and often** - Small commits are easier to review and revert
2. **One logical change per commit** - Don't bundle unrelated changes
3. **Write good commit messages** - Future you will thank present you
4. **Always reference issues** - Traceability is key
