## Agents and initialization

This document explains how AI agents are registered and initialized in this repository. It builds on:

- `docs/developer/development-workflow.md`
- `docs/architecture/governance/01_ai_guidance.md`
- `docs/developer/ai-file-naming.md`
- `docs/developer/agent-template.md`

### Agent registry

Agents are declared in a registry file so tools and scripts can discover them in a consistent way:

- **Registry file:** `.continue/agents/registry.yaml`

Example entry:

```yaml
agents:
  - id: developer-workflow
    file: .continue/agents/agent-developer-workflow.md
    description: Runs the AIXCL issue-first developer workflow end-to-end.
    default_model: Deepseek Coder
    init_docs:
      - docs/developer/development-workflow.md
      - docs/architecture/governance/01_ai_guidance.md
      - docs/developer/ai-file-naming.md
      - docs/developer/agent-template.md
```

- **id**: Stable identifier used by tools (for example `developer-workflow`).
- **file**: Path to the agent markdown file.
- **description**: Short description of what the agent does.
- **default_model**: Optional hint about which model to use.
- **init_docs**: List of core documentation files that should be available to the agent as context when it runs.

### Initialization expectations

When running an agent, tools should:

1. Look up the agent by `id` in `.continue/agents/registry.yaml`.
2. Load the agent markdown file from the `file` field.
3. Include the `init_docs` files as high-priority context (for example via a docs provider or equivalent mechanism).

This ensures that all agents see the same workflow, governance, and naming guidance without each tool needing hard-coded paths.

### Developer workflow agent

The developer workflow agent is registered with id `developer-workflow` and file `.continue/agents/agent-developer-workflow.md`. It:

- Encodes the AIXCL Issue-First development workflow.
- References the governance and workflow docs directly in its markdown.
- Is suitable for use from tools such as Continue CLI, Cursor, or other orchestrators that can read the registry and agent file.

