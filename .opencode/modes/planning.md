---
description: Read-only mode for analysis, planning, and design work without making code changes
agent: agent-context
---

# Planning Mode

Switch to planning mode for analysis, code review, and design work without making changes.

## Usage

```
/mode planning
```

## What It Does

1. **Read-only access** - Can read and analyze code, but cannot edit files
2. **No bash execution** - Cannot run commands that modify state
3. **Analysis focused** - Optimized for understanding and planning

## When to Use

- **Before starting work** - Analyze codebase and plan approach
- **Code review** - Review PRs without making changes
- **Architecture design** - Explore options and document decisions
- **Learning** - Understand how code works without modifying it
- **Estimation** - Assess scope and complexity of changes

## Available Tools

- [x] **read** - Read files and directories
- [x] **grep** - Search codebase
- [x] **bash** (limited) - Read-only commands only (git status, ls, cat)
- [ ] **edit** - Disabled
- [ ] **write** - Disabled
- [ ] **webfetch** - Disabled

## Prompt

You are in planning mode. Your task is to analyze, review, and plan - not to modify code.

Guidelines:
- Ask clarifying questions before suggesting changes
- Present options with pros/cons
- Reference specific files and line numbers
- Provide detailed explanations
- Do not make any file modifications
- Do not run commands that change state

When ready to implement, switch to building mode with `/mode building`.
