# AIXCL - Claude Code Project Instructions

@AGENTS.md

## Claude Code-Specific Notes

- When working with shell scripts, run `shellcheck` before committing
- For security-related changes, consult `.claude/rules/security.md`
- All custom commands are available under `.claude/commands/`
- This project uses the [Agent Skills open standard](https://agentskills.io). Skill files in `.claude/skills/` are portable across compatible tools

## Session Guardrails

Recurring correction points from session history -- follow these without being reminded:

- **GPG signing**: never disable or bypass signing. When a signed commit is needed and pinentry is unavailable, stage the changes and hand the exact `git commit` command to the operator (see [docs/developer/gpg-signed-commits.md](docs/developer/gpg-signed-commits.md))
- **Stack operations**: use `./aixcl stack` for start/stop/status/logs. Never start or modify a stopped or purged stack unless explicitly asked
- **Releases**: sequential patch bumps only (`v1.1.N+1`) -- never jump minor/major versions, never skip CI jobs or leave them pending (canonical procedure: `.claude/skills/release/SKILL.md`)
- **Fork sync**: before reporting a branch "already up to date", verify against the actual upstream base: `git fetch upstream && git log --oneline dev..upstream/dev`
