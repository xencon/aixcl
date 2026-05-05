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

The `agent-context` agent and governance rules load automatically from `opencode.json`.

## Configuration (`opencode.json`)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md",
    "DEVELOPMENT.md",
    ".opencode/rules/*.md",
    "docs/architecture/governance/00_invariants.md",
    "docs/architecture/governance/01_ai_guidance.md",
    "docs/developer/development-workflow.md"
  ],
  "default_agent": "agent-context",
  "permission": {
    "edit": "ask",
    "bash": {
      "*": "ask",
      "git status*": "allow",
      "git diff*": "allow",
      "git log*": "allow",
      "git add*": "allow",
      "ls*": "allow",
      "cat*": "allow",
      "grep*": "allow",
      "gh repo*": "allow",
      "gh issue*": "allow",
      "git commit*": "ask",
      "git push*": "ask",
      "rm -rf*": "deny",
      "git push --force*": "deny",
      "./scripts/checks/check-agents.sh*": "allow"
    },
    "webfetch": "ask",
    "skill": "allow"
  },
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

## Extending OpenCode

Custom agents, skills, and rules can be added to the repo without modifying `opencode.json`:

- **Custom agents:** `.opencode/agents/<name>.md`
- **Custom skills:** `.opencode/skills/<name>/SKILL.md`
- **Custom rules:** `.opencode/rules/<topic>.md`

## Agents

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
- **Agent not following rules**: Confirm `AGENTS.md` and `DEVELOPMENT.md` exist at the repo root and are listed in `opencode.json`.

## References

- [OpenCode Agents](https://opencode.ai/docs/agents/)
- [OpenCode Skills](https://opencode.ai/docs/skills/)
- [OpenCode Permissions](https://opencode.ai/docs/permissions/)
