# OpenCode Integration for AIXCL

OpenCode is the recommended local-first AI coding assistant for AIXCL. It connects directly to your inference engine (Ollama by default) via the OpenAI-compatible API and provides chat, autocomplete, and agentic workflows -- entirely on-device.

## Quick Start

```bash
# Ensure the stack is running
./aixcl stack start --profile dev
./aixcl stack status

# Start OpenCode from the repo root
opencode
```

The `agent-context` agent and our workflow commands load automatically from `opencode.json`.

## Configuration (`opencode.json`)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md",
    "DEVELOPMENT.md",
    "ai/governance/workflow-governance.md",
    "docs/architecture/governance/00_invariants.md",
    "docs/architecture/governance/01_ai_guidance.md",
    "docs/developer/development-workflow.md"
  ],
  "default_agent": "agent-context",
  "provider": {
    "aixcl-local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "AIXCL",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "Qwen/Qwen2.5-Coder-0.5B-Instruct": {
          "name": "Qwen/Qwen2.5-Coder-0.5B-Instruct"
        }
      }
    }
  },
  "model": "aixcl-local/Qwen/Qwen2.5-Coder-0.5B-Instruct"
}
```

## Custom Commands

Markdown files in `.opencode/commands/` define slash commands discovered by OpenCode.

| Command | File | Purpose |
|---------|------|---------|
| `/workflow` | `commands/workflow.md` | Run the full Issue-First workflow |
| `/issue` | `commands/issue.md` | Create a GitHub issue |
| `/branch` | `commands/branch.md` | Create a feature branch from dev |
| `/commit` | `commands/commit.md` | Commit changes with conventional format |
| `/pr` | `commands/pr.md` | Create a pull request |
| `/verify` | `commands/verify.md` | Check CI status |
| `/actions` | `commands/actions.md` | List available actions |
| `/lint` | `commands/lint.md` | Validate agents and actions |
| `/platform` | `commands/platform.md` | Live platform health report |
| `/status` | `commands/status.md` | Quick triage command |
| `/report` | `commands/report.md` | Workflow progress report |
| `/release` | `commands/release.md` | Create a GitHub release |

## Custom Agents

Agents in `.opencode/agents/` provide specialized behavior.

| Agent | Role | Purpose |
|-------|------|---------|
| `agent-context.md` | Primary | Full project context, Issue-First workflow, governance rules |
| `security-gate.md` | Subagent | Pre-action security validation |
| `audit-logger.md` | Subagent | Immutable audit trail recorder |
| `blast-radius-controller.md` | Subagent | Failure isolation in adversarial environments |

## Skills

Skills are reusable capabilities in `.opencode/skills/<name>/SKILL.md`.

| Skill | Purpose |
|-------|---------|
| `workflow-guard` | Validates Issue-First workflow compliance before execution |

Load a skill with the `skill` tool:
```
skill({ name: "workflow-guard" })
```

## Modes

Modes switch the agent's posture without changing agents.

| Mode | File | Use When |
|------|------|----------|
| Planning | `modes/planning.md` | Read-only analysis |
| Building | `modes/building.md` | Full development |
| Reviewing | `modes/reviewing.md` | Code review |

Switch modes with `/mode planning`, `/mode building`, or `/mode reviewing`.

## Troubleshooting

- **Connection refused**: Ensure `./aixcl stack status` shows the engine as healthy.
- **Model not found**: Verify the model name matches `./aixcl models list`.
- **Agent not following rules**: Confirm `AGENTS.md` and `DEVELOPMENT.md` exist at the repo root.

## References

- [OpenCode Commands](https://opencode.ai/docs/commands/)
- [OpenCode Agents](https://opencode.ai/docs/agents/)
- [OpenCode Skills](https://opencode.ai/docs/skills/)
- [OpenCode Permissions](https://opencode.ai/docs/permissions/)
