# File Naming and Metadata Conventions

This document defines naming, directory, and metadata conventions for markdown files in this repository, with emphasis on the AI-related surfaces (agents, skills, rules, reports). The goal is to make files easy to discover and safe to use for both humans and AI tools.

These conventions complement the development workflow in `docs/developer/development-workflow.md` and the architectural guidance in `docs/architecture/governance/01_ai_guidance.md`.

## General Naming Rules

- **New documentation files use kebab-case**: `adding-services.md`, `threat-model.md`
- **Existing numbered series keep their established style** -- do not rename files to change convention; renames break inbound links for no benefit:
  - Governance docs keep `NN_snake_case`: `00_invariants.md`, `01_ai_guidance.md`
  - Architecture decision records keep `NNN-kebab-case`: `001-network-mode-host.md`
- **Any NEW numbered series must use kebab-case** with zero-padded prefixes: `001-topic-name.md`
- Per-directory documentation: `CONTEXT.md` (agent-facing contract) or `README.md` (human-facing, top-level directories only) -- see AGENTS.md Section 10

## Frontmatter Policy

YAML frontmatter is used ONLY where a tool or specification consumes it. Do not add frontmatter to plain documentation -- it costs context tokens and has no consumer.

| File type | Frontmatter | Consumed by |
|-----------|-------------|-------------|
| Skills (`SKILL.md`) | Required: `name`, `description` | Agent Skills standard (agentskills.io) |
| OpenCode commands | Required: `description`; optional `agent` | OpenCode |
| OpenCode agents | Required: `description`, `mode`; **`name` MUST NOT be present** | OpenCode |
| Issue templates | Required: GitHub template fields | GitHub |
| `AGENTS.md` / `DEVELOPMENT.md` | Markdown-table header (repo-local convention) | Humans |
| All other docs | None | -- |

## Agents

- **Location**: `.opencode/agents/`
- **Filename pattern**: the filename (minus `.md`) IS the agent ID -- e.g. `agent-context.md`, `reviewer.md`

Agent files:
- Contain YAML frontmatter with `description` and `mode`.
- **MUST NOT contain a `name:` field** -- OpenCode derives the agent ID from the filename, and a `name:` field overrides it and breaks command dispatch (issue #1703; enforced by `scripts/checks/check-agents.sh`).
- Defer to `AGENTS.md` for all policy; contain only agent-specific operational guidance.
- Never place non-agent markdown (CONTEXT.md, notes) in this directory -- OpenCode registers every markdown file here as an agent. Same rule for `.opencode/commands/`.

## Skills

- **Location**: `.claude/skills/<name>/SKILL.md` and `.opencode/skills/<name>/SKILL.md` (byte-identical mirrors -- edit both sides)
- **Filename pattern**: directory-based (`<name>/SKILL.md`), directory name in kebab-case
  - Examples: `housekeeping/SKILL.md`, `release/SKILL.md`

Skill files follow the [Agent Skills open standard](https://agentskills.io): keep SKILL.md lean and move bulky reference material to separate `references/` files loaded on demand (progressive disclosure). The catalog and authoring conventions live in `.claude/skills/CONTEXT.md` (mirrored); update it in the same PR that adds, renames, or removes a skill. Audit skill changes with the `reviewing-skills` skill before merging.

## Rules

- **Location**: `.claude/rules/` and `.opencode/rules/` (byte-identical mirrors -- edit both sides)
- **Filename pattern**: `<topic>.md` -- e.g. `workflow.md`, `formatting.md`, `security.md`

Rules are loaded automatically every session (Claude Code natively; OpenCode via the `instructions` array in `opencode.json`). Because they cost context every session, rules must not restate policy that lives in `AGENTS.md` -- summarize and point instead.

## AI-Generated Reports

- **Location**: `docs/reference/`
- **Filename pattern**: `ai-report-<topic>.md`
  - Example: `ai-report-structured-knowledge-architectures.md`

AI reports are analysis outputs, not agent or skill definitions, and are subject to the lean repository policy -- prefer the wiki for material that will not stay current.
