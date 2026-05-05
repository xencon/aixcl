## AI-Related File Naming Conventions

This document defines naming and directory conventions for AI-related markdown files in this repository. The goal is to make agents, skills, MCP-related docs, and AI-generated reports easy to discover and safe to use across different AI tools.

These conventions complement the development workflow in `docs/developer/development-workflow.md` and the architectural guidance in `docs/architecture/governance/01_ai_guidance.md`.

### Agents

- **Location**: `.opencode/agents/`
- **Filename pattern**: `agent-<domain>.md`
  - Examples:
    - `agent-context.md`
    - `agent-security-gate.md`
    - `agent-audit-logger.md`

Agent files:
- Contain YAML frontmatter with `name` and `description`.
- Encode AIXCL-specific constraints (Issue-First workflow, governance rules, plain ASCII markdown).
- Are intended to be used by multiple AI tools (e.g., OpenCode CLI, Cursor, Copilot-style agents).

### Skills (Optional)

Skills are optional narrowly scoped capabilities. If used:

- **Location**: `.opencode/skills/<name>/SKILL.md`
- **Filename pattern**: directory-based (`<name>/SKILL.md`)
  - Examples:
    - `workflow-guard/SKILL.md`
    - `security-scan/SKILL.md`

Skill files define narrowly scoped capabilities that agents can rely on, such as a specific refactoring or check.

### Rules

- **Location**: `.opencode/rules/`
- **Filename pattern**: `<topic>.md`
  - Examples:
    - `workflow.md`
    - `formatting.md`
    - `security.md`

Rules are automatically loaded by OpenCode via the `instructions` array in `opencode.json`.

### MCP Documentation

If MCP servers or tools are documented in markdown prompts or specs:

- **Location**: `.opencode/mcp/`
- **Filename patterns**:
  - MCP servers: `mcp-server-<name>.md`
  - MCP tools: `mcp-tool-<name>.md`
  - Examples:
    - `mcp-server-github.md`
    - `mcp-server-local-shell.md`
    - `mcp-tool-aixcl-cli.md`

These files describe how MCP components should behave but do not replace the actual MCP server or tool configuration files.

### AI-Generated Reports

- **Location**: `docs/reference/`
- **Filename pattern**: `ai-report-<topic>.md`
  - Example:
    - `ai-report-issues-compliance-analysis.md`

AI reports are outputs produced by agents or analysis tools. They are not agent or skill definitions and should not be treated as such by tooling.
