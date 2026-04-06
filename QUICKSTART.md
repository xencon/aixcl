# AIXCL Quick Start Guide

Get up and running with the AIXCL Issue-First development workflow in minutes.

## Prerequisites

- [Git](https://git-scm.com/) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated
- [OpenCode](https://opencode.ai/) installed

## 1. Validate Your Environment

Before starting, run the environment validation:

```bash
./scripts/checks/check-environment.sh
```

This checks:
- ✓ Git configuration
- ✓ GitHub CLI authentication
- ✓ OpenCode configuration
- ✓ AI directory structure
- ✓ Required permissions

## 2. Start OpenCode

Navigate to your repository and start OpenCode:

```bash
cd /path/to/aixcl
opencode
```

The `agent-context` agent will automatically load with full project context.

## 3. Available Commands

### Workflow Commands (Issue-First)

| Command | Description | Step |
|-----------|-------------|------|
| `/workflow` | Run complete Issue-First workflow | All |
| `/issue` | Create a GitHub issue | 1 |
| `/branch` | Create feature branch from issue | 2 |
| `/commit` | Commit changes with proper format | 4 |
| `/pr` | Create pull request | 5 |
| `/verify` | Verify CI status | 6 |

### Mode Commands

| Command | Description | Use When |
|---------|-------------|----------|
| `/mode planning` | Read-only analysis mode | Analyzing code, planning changes |
| `/mode building` | Full development mode | Writing code, making changes |
| `/mode reviewing` | Code review mode | Reviewing PRs, providing feedback |

### Utility Commands

| Command | Description |
|---------|-------------|
| `/actions` | List all available actions |
| `/lint` | Validate agent and action files |

## 4. Quick Examples

### Example 1: Full Workflow

Start a complete Issue-First workflow:

```
/workflow Add user authentication feature
```

This will:
1. Create issue `[FEATURE] Add user authentication`
2. Create branch `issue-123/add-user-authentication`
3. Guide you through implementation
4. Commit with proper format
5. Create PR
6. Verify CI

### Example 2: Individual Steps

Create an issue first:

```
/issue We need to fix the login timeout bug
```

Then create a branch:

```
/branch 217
```

Make your changes, then commit:

```
/commit fix: Resolve login timeout bug

- Increased timeout from 30s to 60s
- Added retry logic

Fixes #217
```

Create a PR:

```
/pr Fix login timeout bug
```

Check CI status:

```
/verify
```

### Example 3: Resume Work

If you have existing work:

```
/workflow
```

The agent will detect your current state:
- Open issues you created
- Current branch
- Uncommitted changes
- Existing PRs

And suggest the next step.

## 5. Common Workflows

### Bug Fix Workflow

```
/issue Fix critical bug in payment processing
/branch 218
[fix the bug]
/commit fix: Resolve payment processing error
/pr Fix payment processing bug
/verify
```

### Feature Development

```
/issue Add dark mode toggle to UI
/branch 219
[implement feature]
/commit feat: Add dark mode toggle

- Implemented theme switching
- Added user preference storage
- Updated UI components

Fixes #219
/pr Add dark mode support
/verify
```

### Documentation Update

```
/issue Update API documentation with new endpoints
/branch 220
[update docs]
/commit docs: Update API documentation

- Added new endpoints section
- Updated authentication docs
- Fixed broken links

Fixes #220
/pr Update API documentation
/verify
```

## 6. Modes in Action

### Planning Mode

Before writing code, analyze and plan:

```
/mode planning

How should I structure the authentication middleware?
```

The agent will:
- Read existing code
- Analyze patterns
- Suggest approaches
- NOT modify any files

### Building Mode

Switch to building mode when ready:

```
/mode building

Now implement the authentication middleware following the plan.
```

The agent will:
- Create/modify files
- Run tests
- Commit changes
- Full development capabilities

### Reviewing Mode

Review your work:

```
/mode reviewing

Review this PR for best practices.
```

The agent will:
- Analyze code
- Provide feedback
- Suggest improvements
- NOT modify files

## 7. Tips & Best Practices

### Issue-First Rule

**ALWAYS** create an issue before starting work. Every PR must reference an issue.

### Title Formatting

- **Issues**: `[TYPE] Description` (e.g., `[TASK] Setup agent`)
- **PRs**: `Description (#<number>)` (e.g., `Setup agent (#217)`)

### Labels Matter

Every issue must have:
- [ ] At least one component label (e.g., `component:cli`)
- [ ] An assignee (you)

### No Colons in Titles

**CORRECT:**
- `[TASK] Setup agent template`
- `Setup agent template (#217)`

**INCORRECT:**
- `[TASK]: Setup agent template`
- `Setup: agent template (#217)`

### CI is the Gate

Your task is NOT complete until all CI checks pass. Use `/verify` to check status.

### Small Commits

Make small, focused commits:

```
git commit -m "fix: Add null check for user input

Fixes #220"
```

Not:

```
git commit -m "fixed stuff"
```

## 8. Troubleshooting

### Command Not Found

If `/workflow` or other commands don't work:

1. Check you're in the AIXCL repository root
2. Verify `.opencode/commands/` exists
3. Restart OpenCode

### GitHub CLI Not Authenticated

```bash
gh auth login
```

### No Issue Created

Make sure to create an issue before creating a branch:

```
/issue Add new feature
```

Then note the issue number and use it for the branch.

### CI Failing

```
/verify
```

Check the logs, fix the issues, and commit again.

## 9. Validation

Before committing changes to the `ai/` directory:

```
/lint
```

Or run directly:

```bash
./scripts/checks/check-agents.sh
```

## 10. Documentation

- **AGENTS.md** - Operating contract and authority hierarchy
- **DEVELOPMENT.md** - Development workflow rules
- **ai/README.md** - AI directory structure and conventions
- **ai/actions/** - All available actions
- **.opencode/agents/** - Agent definitions
- **.opencode/commands/** - Command definitions

## Next Steps

1. ✅ Run `./scripts/checks/check-environment.sh`
2. ✅ Start OpenCode: `opencode`
3. ✅ Try: `/workflow Add your first feature`
4. ✅ Check out `/actions` to see all available actions

## Getting Help

- List available actions: `/actions`
- Check environment: `./scripts/checks/check-environment.sh`
- Review workflow: `ai/actions/action-workflow-visualization.md`

---

**Remember**: Security over convenience. Determinism over creativity. Minimal scope changes.
