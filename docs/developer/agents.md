# Agents and Initialization

This document explains how AI agents are registered and initialized in this repository. It builds on:

- `docs/developer/development-workflow.md`
- `docs/architecture/governance/01_ai_guidance.md`
- `docs/developer/ai-file-naming.md`
- `docs/developer/agent-template.md`

## Agent Configuration

Agents are configured in `opencode.json` at the repository root. This file defines:

- Default agent to use
- Agent definitions and their configuration
- Permissions for each agent
- Initial context documentation

Example from `opencode.json`:

```json
{
  "default_agent": "agent-context",
  "agent": {
    "agent-context": {
      "mode": "primary",
      "description": "AIXCL primary agent with full project context",
      "prompt": "{file:.opencode/agents/agent-context.md}",
      "permission": {
        "read": "allow",
        "edit": "ask",
        "bash": {
          "*": "ask"
        }
      }
    }
  }
}
```

### Configuration Fields

- **default_agent**: The agent ID to use when no specific agent is requested
- **agent.{id}**: Agent definition where `{id}` is the agent identifier
  - **mode**: Agent mode (`primary`, `secondary`, etc.)
  - **description**: Short description of agent purpose
  - **prompt**: Path to the agent markdown file (can use `{file:}` syntax)
  - **permission**: Tool permissions for this agent

## Agent File Locations

Agent markdown files are stored in two locations:

1. **`.opencode/agents/`**: Primary agents for OpenCode integration
   - Example: `agent-context.md`

2. **`ai/orchestration/`**: Workflow orchestration agents
   - Example: `agent-developer-workflow.md`

## Initialization Process

When running an agent:

1. OpenCode reads `opencode.json` to find the default agent or requested agent
2. Loads the agent markdown file from the `prompt` field
3. Loads all files listed in the `instructions` array as context
4. Applies permission settings from the agent configuration

### Initial Context

The `instructions` array in `opencode.json` lists files that provide initial context:

```json
{
  "instructions": [
    "AGENTS.md",
    "DEVELOPMENT.md",
    "ai/governance/workflow-governance.md",
    "docs/architecture/governance/00_invariants.md",
    "docs/architecture/governance/01_ai_guidance.md",
    "docs/developer/development-workflow.md",
    "ai/actions/*.md"
  ]
}
```

This ensures that all agents see the same workflow, governance, and naming guidance without each tool needing hard-coded paths.

## Developer Workflow Agent

The developer workflow agent is defined in `ai/orchestration/agent-developer-workflow.md`. It:

- Encodes the AIXCL Issue-First development workflow
- References the governance and workflow docs directly in its markdown
- Can be invoked via OpenCode CLI: `opencode --agent ai/orchestration/agent-developer-workflow.md`

## Custom Agents

You can add custom agents by:

1. Creating a new agent markdown file in `.opencode/agents/` or `ai/orchestration/`
2. Adding the agent definition to `opencode.json` under the `agent` field
3. Following the template in `docs/developer/agent-template.md`

## See Also

- `docs/developer/agent-template.md` - Template for creating new agents
- `docs/developer/ai-file-naming.md` - Naming conventions for AI files
- `docs/architecture/governance/01_ai_guidance.md` - AI behavioral guidance
