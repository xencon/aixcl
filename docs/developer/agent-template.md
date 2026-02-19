## Agent markdown template

This document describes a generic, tool-agnostic template for AI agent markdown files in this repository. Agents should follow this structure so they work consistently across different AI tools while respecting the AIXCL development workflow and governance.

See also:

- `docs/developer/development-workflow.md`
- `docs/architecture/governance/01_ai_guidance.md`
- `docs/developer/ai-file-naming.md`

### Frontmatter

Each agent file starts with YAML frontmatter:

```yaml
---
name: Agent Name
description: Short, plain-text description of what the agent does in this repo.
role: system
tags:
  - aixcl
  - workflow
  - cli
---
```

- **name**: Human-readable name (used in UIs and logs).
- **description**: One or two sentences about the agent’s purpose.
- **role**: Usually `system` so tools can treat the content as system-level instructions.
- **tags**: Optional; helps tools categorize agents.

### Recommended sections

Agents should use the following sections in order. Tools may choose to use all or part of this structure.

#### Purpose

Explain what the agent does in this repository, in one or two short paragraphs.

Example:

> You orchestrate the full AIXCL Issue-First development workflow from this repository. You help create issues, branches, commits, and pull requests while following the documented workflow and governance rules.

#### Canonical references

List the repo docs that are normative for this agent. Always include:

- `docs/developer/development-workflow.md`
- `docs/architecture/governance/01_ai_guidance.md`

Example:

- Always follow `docs/developer/development-workflow.md` for the Issue-First workflow.
- Always follow `docs/architecture/governance/01_ai_guidance.md` and related invariants.

#### Global rules

Define cross-cutting rules that apply to everything the agent does. For AIXCL, include at least:

- Always use the Issue-First workflow:
  - Create an issue.
  - Create a branch from `main`.
  - Make changes and commit with conventional commit format.
  - Push and create a PR that references the issue.
  - Assign and label the PR to match the issue.
- Use only plain ASCII markdown:
  - Use `- [x]` checkboxes.
  - Do not use emoji or Unicode checkmarks.
- Do not use colons in issue or PR titles.
- Prefer small, reversible changes and explicit behavior.

#### Tool usage (generic)

Describe how the agent should use tools in a way that can be mapped to different runtimes (Continue CLI, Cursor, MCP tools, etc.):

- Assume access to tools that can:
  - Run shell commands in the repo (e.g. `git`, `gh`, `./aixcl`).
  - Read and edit files in the workspace.
- When tools are available:
  - Prefer calling tools to actually run commands instead of only printing them.
- When tools are not available:
  - Present commands clearly in `bash` code blocks as suggestions.
- Avoid destructive operations (e.g. `git push --force`, `git reset --hard`) unless explicitly requested by the user.

#### Workflow or behavior steps

Define the main steps the agent should follow to do its job. For example, a workflow agent might have:

1. Create issue.
2. Create branch.
3. Make changes and commit.
4. Push and create PR.
5. Review and merge (human step).

Each step can include sub-bullets with more detail. Keep the content repo-specific and aligned with the development workflow.

#### Safety and governance

Explicitly encode key governance and architecture constraints:

- Do not remove, replace, or conditionally disable runtime core components (Ollama, Council, Continue).
- Do not introduce dependencies from runtime core to operational services.
- Do not merge runtime logic with monitoring, logging, or admin tooling.
- Do not collapse service boundaries or add hidden coupling.
- When in doubt:
  - Prefer documenting concerns in issues or PR descriptions.
  - Avoid changing behavior if it might violate invariants.

