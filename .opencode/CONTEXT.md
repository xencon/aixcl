# CONTEXT: .opencode/

OpenCode configuration for the local agent. IMPORTANT: OpenCode derives
commands and agent IDs from EVERY markdown filename in `commands/` and
`agents/` -- never place documentation files (CONTEXT.md, README.md,
notes) inside those two directories, or they register as a bogus
`/CONTEXT` command or `CONTEXT` agent. Document them here instead.

## Layout

| Directory | Purpose |
|-----------|---------|
| `agents/` | Agent definitions; filename = agent ID, `name:` frontmatter MUST NOT be present (enforced by `scripts/checks/check-agents.sh`, issue #1703) |
| `commands/` | Slash commands; filename = command name; use `` !`cmd` `` shell injection to ground the agent in verified state |
| `rules/` | Behavioral constraints, byte-identical mirror of `.claude/rules/` (enforced by `check-agents.sh`) |
| `skills/` | Agent Skills, byte-identical mirror of `.claude/skills/` |
| `memory/` | Seed memory for the local agent -- PUBLIC repo content, never secrets |

## Agents

| File | Mode | Purpose |
|------|------|---------|
| `agents/agent-context.md` | primary | Worker for the `agent:qwen` issue queue -- operational guidance, tool discipline, memory conventions |
| `agents/reviewer.md` | subagent | Read-only reviewer: `edit` denied, inspection-only bash allowlist |

## Commands

| File | Command | Purpose |
|------|---------|---------|
| `commands/next-task.md` | `/next-task` | Injects the single oldest open `agent:qwen` issue as the one and only work item |
| `commands/pr-ready.md` | `/pr-ready` | Gates PR creation on verified signed commits ahead of `upstream/dev`; hands the commit to the human if none exist |
| `commands/finish-pr.md` | `/finish-pr` | Verifies a PR is actually MERGED before branch cleanup and issue close |

## Agent Guidance

**You MAY:**
- Add commands that inject verified state (command output) rather than prose instructions
- Add read-only subagents; adjust prompts or permissions with maintainer approval
- Tighten hard gates (empty-state -> STOP conditions)

**You MUST NOT:**
- Place any non-command markdown in `commands/` or non-agent markdown in `agents/`
- Add `name:` frontmatter to agent files
- Remove or soften command hard gates (STOP / END TURN) -- prose alone does not transfer reliably to the local model
- Grant `reviewer` write access, or point any agent `model` at a non-local provider
- Edit one side of the `rules/`/`skills/` mirrors without the other
- Commit secrets or machine-specific paths to `memory/` -- this repo is public

## Runtime Config

`opencode.json` at the repository root is GITIGNORED runtime config. The
canonical template is `config/opencode.json.example` -- every config change
goes to BOTH files (edit the template, apply locally).

## Cross-References

- `AGENTS.md` -- operating contract (loaded via the `instructions` array)
- `config/opencode.json.example` -- provider, model, permissions, instructions
- `docs/developer/opencode-setup.md` -- human setup guide
- `.claude/` -- Claude Code counterpart (rules/skills mirrored; commands tool-specific)
