# AIXCL Documentation

Documentation organized by audience. Keep it lean -- if something can be regenerated or is operator-only, it belongs in the [wiki](https://github.com/xencon/aixcl/wiki), not the repo.

## Structure

| Directory | Audience | Key Files |
|-----------|----------|-----------|
| `user/` | End users | [`usage.md`](user/usage.md) - Commands and service URLs, [`apps.md`](user/apps.md) - App framework guide |
| `developer/` | Contributors | [`development-workflow.md`](developer/development-workflow.md), [`opencode-setup.md`](developer/opencode-setup.md), [`adding-services.md`](developer/adding-services.md), [`adding-apps.md`](developer/adding-apps.md), [`app-builder-guide.md`](developer/app-builder-guide.md) |
| `architecture/governance/` | Architects | [`00_invariants.md`](architecture/governance/00_invariants.md), [`02_profiles.md`](architecture/governance/02_profiles.md), [`service_contracts/`](architecture/governance/service_contracts/) |
| `operations/` | Operators | [`security-runbook.md`](operations/security-runbook.md), [`incident-response.md`](operations/incident-response.md) |
| `reference/` | All | [`manpage.txt`](reference/manpage.txt) |

## Root-Level Contracts

These files are canonical and loaded by all agents:
- `AGENTS.md` -- Operating contract
- `DEVELOPMENT.md` -- Workflow rules
- `CONTRIBUTING.md` -- External contributor guide
- `SECURITY.md` -- Security policy

## Multi-Agent CLI Support

This repository supports both OpenCode and Claude Code agentic CLIs. Tool-specific configuration lives in `.opencode/` and `.claude/` respectively. Both tools share the same governance rules (Issue-First workflow, platform invariants) defined in `AGENTS.md` and `DEVELOPMENT.md`.
