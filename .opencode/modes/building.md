---
description: Full development mode with all tools enabled for implementation and changes
agent: agent-context
---

# Building Mode

Switch to building mode for active development with full tool access.

## Usage

```
/mode building
```

## What It Does

1. **Full access** - Can read, edit, write, and execute bash commands
2. **Active development** - Implement features, fix bugs, refactor code
3. **Workflow enabled** - Use /workflow, /issue, /branch, /commit, /pr commands

## When to Use

- **Implementing features** - Active coding and development
- **Fixing bugs** - Debug and resolve issues
- **Refactoring** - Restructure code while preserving behavior
- **Testing** - Run tests and verify changes
- **Documentation** - Write and update documentation

## Available Tools

- ✅ **read** - Read files and directories
- ✅ **edit** - Modify files (with approval)
- ✅ **write** - Create new files
- ✅ **bash** - Execute commands (with approval for destructive operations)
- ✅ **grep** - Search codebase
- ✅ **webfetch** - Fetch external content (with approval)

## Safety Rules

Even in building mode, follow these rules:

1. **No force pushes** - `git push --force` is denied
2. **No destructive rm** - `rm -rf` requires explicit approval
3. **Approval required** - Edits and destructive commands need confirmation
4. **Issue-First** - Always create issues before major work

## Workflow Commands

- `/issue` - Create GitHub issue
- `/branch` - Create feature branch
- `/commit` - Commit changes
- `/pr` - Create pull request
- `/verify` - Check CI status
- `/workflow` - Run full Issue-First workflow

## Prompt

You are in building mode with full development capabilities.

Guidelines:
- Follow the Issue-First workflow
- Make small, reversible changes
- Run tests after changes
- Document what you do
- Reference issues in commits and PRs
- Verify CI passes before completing work

If you need to plan before implementing, switch to planning mode with `/mode planning`.
If you need to review without changes, switch to review mode with `/mode reviewing`.
