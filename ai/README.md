# AI Agentic Workflow Drop-in Folder

This directory contains AI workflow artifacts for the AIXCL project.

## Structure

```
ai/
├── actions/              # Executable workflow actions
│   ├── workflow/         # Core workflow actions
│   │   └── action-*.md   # Issue, branch, commit, PR, verify, state
│   ├── validation/       # Validation actions
│   │   └── action-*.md   # Lint, check
│   └── utilities/        # Utility actions
│       └── action-*.md   # Guidelines, docs
├── governance/           # Workflow governance and constraints
│   └── *.md              # Behavioral policy and non-negotiable constraints
├── orchestration/        # Agent definitions and workflow orchestration
│   └── agent-*.md        # Full agent definitions with YAML frontmatter
├── templates/            # Output templates
│   ├── issue/            # Issue templates (bug, feature, task)
│   └── pr/               # Pull request templates
└── README.md             # This file
```

## Directory Contents

### `actions/` (formerly `skills/`)

Executable workflow actions organized by category:

#### Workflow Actions (`actions/workflow/`)

Core Issue-First development actions:
- `action-create-issue.md` - Create GitHub issues with proper labels
- `action-create-branch.md` - Create feature branches
- `action-commit.md` - Commit with conventional format
- `action-create-pr.md` - Create pull requests
- `action-verify-ci.md` - Verify CI status
- `action-detect-workflow-state.md` - Smart state detection

#### Validation Actions (`actions/validation/`)

Quality assurance actions:
- `action-lint-agents.md` - Validate agent/action file structure

#### Utility Actions (`actions/utilities/`)

Support and guideline actions:
- `action-icon-usage.md` - ASCII-only character guidelines
- `action-workflow-visualization.md` - Visual workflow documentation

All actions include YAML frontmatter with metadata:
```yaml
---
name: Action Name
description: What this action does
category: workflow
tool: primary-tool
requires:
  - prerequisite 1
  - prerequisite 2
---
```

### `governance/`

Behavioral constraints and workflow policy:
- `workflow-governance.md` - Non-negotiable constraints and formatting rules
- `documentation-strategy.md` - Documentation guidelines

### `orchestration/`

Agent definitions for the AIXCL workflow:
- `agent-developer-workflow.md` - Full Issue-First workflow agent definition
- `state-machine.yaml` - Workflow state definitions

### `templates/`

Structured output templates for GitHub:

**Issue templates:**
- `bug_report.md` - Bug report structure
- `feature_request.md` - Feature request structure
- `task.md` - Task investigation structure

**PR templates:**
- `pull_request.md` - Pull request structure

## Authority Hierarchy

When conflicts arise, AI assistants follow this order:

1. **AGENTS.md** (root) - Operating contract and authority hierarchy
2. **DEVELOPMENT.md** (root) - Development workflow rules
3. **ai/governance/** - Behavioral constraints and workflow policy
4. **ai/actions/** - Executable workflow actions
5. **ai/templates/** - Structured output templates
6. **ai/orchestration/** - Agent definitions and workflow steps
7. **docs/architecture/governance/** - Platform invariants and service contracts
8. **docs/developer/** - Developer guides and workflow documentation

## Naming Conventions

- **Actions**: `action-*.md` (lowercase, hyphenated)
- **Agents**: `agent-*.md` (lowercase, hyphenated)
- **Categories**: `workflow/`, `validation/`, `utilities/` (lowercase, plural)

## OpenCode Integration

This project uses OpenCode's `.opencode/` directory for agent configuration:

### Agents (`/.opencode/agents/`)
- `agent-context.md` - Primary agent with full context

### Modes (`.opencode/modes/`)
- `planning.md` - Read-only analysis mode
- `building.md` - Full development mode
- `reviewing.md` - Code review mode

### Commands (`.opencode/commands/`)

| Command | Description |
|---------|-------------|
| `/issue` | Create GitHub issue |
| `/branch` | Create feature branch |
| `/commit` | Commit changes |
| `/pr` | Create pull request |
| `/verify` | Verify CI status |
| `/workflow` | Run full Issue-First workflow |
| `/lint` | Validate agents/actions |
| `/actions` | List available actions |
| `/mode` | Switch working mode |

See the root `opencode.json` for complete configuration details.

## Quick Start

See `QUICKSTART.md` in the repository root for getting started.

## Validation

Before committing changes to this directory:

```bash
# Run agent/action validation
./scripts/checks/check-agents.sh

# Run full environment check
./scripts/checks/check-environment.sh
```

## File Format

### Action File Template

```markdown
---
name: Action Name
description: Brief description of what this action does
category: workflow
tool: gh
requires:
  - prerequisite 1
  - prerequisite 2
---

# Action: Action Name

Description of the action...

## Commands

```bash
command here
```

## Process

1. Step 1
2. Step 2

## Verification

- [ ] Check 1
- [ ] Check 2
```

### Agent File Template

```markdown
---
name: Agent Name
description: Brief description of what this agent does
role: system
tags:
  - tag1
  - tag2
---

## Purpose

What this agent does...

## Canonical references

- Reference to docs...

## Global rules

- Rule 1
- Rule 2

## Tool usage

How to use tools...

## Workflow steps

1. Step 1
2. Step 2

## Safety

Safety considerations...
```

## Contributing

When adding new files:

1. Follow naming conventions (`action-*.md`, `agent-*.md`)
2. Include YAML frontmatter with metadata
3. Place in appropriate category (`workflow/`, `validation/`, `utilities/`)
4. Run validation script
5. Update this README if needed
6. Commit with conventional format

See `DEVELOPMENT.md` in the repository root for full contribution guidelines.
