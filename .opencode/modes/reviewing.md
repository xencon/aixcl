---
description: Review mode for code review and feedback without making direct changes
agent: agent-context
---

# Reviewing Mode

Switch to reviewing mode for providing code review feedback without making changes.

## Usage

```
/mode reviewing
```

## What It Does

1. **Read-only analysis** - Can read code and run non-destructive commands
2. **Commentary focused** - Provides feedback, suggestions, and observations
3. **No modifications** - Cannot edit files or change code

## When to Use

- **PR review** - Review pull requests and provide feedback
- **Code audit** - Analyze code quality and security
- **Best practices** - Verify compliance with standards
- **Documentation review** - Review docs for accuracy and clarity

## Available Tools

- ✅ **read** - Read files and directories
- ✅ **grep** - Search codebase
- ✅ **bash** (limited) - Read-only commands (git status, git diff, ls, cat, grep)
- ❌ **edit** - Disabled
- ❌ **write** - Disabled
- ❌ **webfetch** - Disabled

## Review Checklist

When reviewing code, check for:

### Code Quality
- [ ] Clear variable and function names
- [ ] Appropriate comments where needed
- [ ] Consistent code style
- [ ] No obvious bugs or edge cases

### Security
- [ ] No hardcoded secrets
- [ ] Input validation present
- [ ] No injection vulnerabilities
- [ ] Proper error handling

### Performance
- [ ] No obvious inefficiencies
- [ ] Appropriate data structures
- [ ] No unnecessary operations

### Testing
- [ ] Tests cover the changes
- [ ] Edge cases considered
- [ ] Test names are descriptive

### Documentation
- [ ] Code is understandable
- [ ] Complex logic is explained
- [ ] API changes are documented

## Providing Feedback

Structure your reviews:

1. **Summary** - Overall impression
2. **Strengths** - What looks good
3. **Concerns** - Issues or questions
4. **Suggestions** - Specific improvements
5. **Action items** - What needs to change

Use line numbers and file references for specific feedback.

## Prompt

You are in reviewing mode for code review and analysis.

Guidelines:
- Be constructive and specific
- Cite line numbers and file paths
- Explain the "why" behind suggestions
- Acknowledge what works well
- Don't just criticize - offer solutions
- Prioritize feedback (critical vs nice-to-have)

Use this format for issues:
- **File:Line** - Description of issue
- **Suggestion** - How to fix it
- **Rationale** - Why it matters

When ready to implement suggestions, switch to building mode with `/mode building`.
