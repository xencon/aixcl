# Agent Definitions

## Active
- `agent-context.md` - Main context agent (loaded by opencode.json)

## Adding Agents

Agent definitions are stored here and loaded by OpenCode. Any new agent must:

- Follow the naming convention `agent-<name>.md`
- Include required YAML frontmatter (`name`, `description`, `role: system`)
- Reference canonical governance documents (`AGENTS.md`, `DEVELOPMENT.md`, `docs/architecture/governance/01_ai_guidance.md`)
- Be mirrored to `.claude/agents/` if the same agent is used by Claude Code

Run `bash scripts/checks/check-agents.sh` after adding or modifying agents.
