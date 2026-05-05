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
- Git configuration
- GitHub CLI authentication
- OpenCode configuration
- Required permissions

## 2. Start OpenCode

Navigate to your repository and start OpenCode:

```bash
cd /path/to/aixcl
opencode
```

The `agent-context` agent will automatically load with full project context.

## 3. Modes

| Mode | Command | Use When |
|------|---------|----------|
| Planning | `/mode planning` | Read-only analysis |
| Building | `/mode building` | Full development |
| Reviewing | `/mode reviewing` | Code review |

Switch modes at any time. Each mode controls whether the agent can modify files.

## 4. Quick Examples

### Create an Issue

```
Create a new issue for adding dark mode to the UI. Label it component:ui and assign me.
```

The agent will:
1. Read the `.github/ISSUE_TEMPLATE/feature_request.md` template first
2. Draft the title and body
3. Ask you to confirm
4. Run `gh issue create` with proper labels and assignee
5. Note the issue number for branch creation

### Create a Branch

```
Create a branch for issue 219 from dev.
```

The agent will run `git checkout -b issue-219/add-dark-mode`.

### Commit and PR

```
Commit these changes with conventional format referencing issue 219, then create a PR.
```

The agent will commit and run `gh pr create` with proper title, body, and labels.

## 5. Tips & Best Practices

### Issue-First Rule

**ALWAYS** create an issue before starting work. Every PR must reference an issue.

### Title Formatting

- **Issues**: `[TYPE] Description` (e.g., `[TASK] Setup agent`)
- **PRs**: `Description (#<number>)` (e.g., `Setup agent (#217)`)
- **No colons** in titles

### ASCII Only

Use markdown checkboxes `- [x]`. No Unicode checkmarks or emoji.

### CI is the Gate

Your task is NOT complete until all CI checks pass. Ask the agent: `Check CI status for PR 217.`

### Small Commits

```
git commit -m "fix: Add null check for user input

Fixes #220"
```

Not: `git commit -m "fixed stuff"`

## 6. Troubleshooting

### GitHub CLI Not Authenticated

```bash
gh auth login
```

### No Issue Created

Make sure to create an issue before creating a branch:

```
Create an issue for the login timeout bug, label it component:cli.
```

Then note the issue number and ask for the branch.

### CI Failing

```
Check CI status for PR 217.
```

## 7. Validation

Before committing changes to `.opencode/`:

```bash
./scripts/checks/check-agents.sh
```

## 8. Documentation

- **AGENTS.md** - Operating contract
- **DEVELOPMENT.md** - Workflow rules
- **.opencode/rules/** - OpenCode behavioral rules
- **.opencode/agents/** - Agent definitions

---

**Remember**: Security over convenience. Determinism over creativity. Minimal scope changes.
