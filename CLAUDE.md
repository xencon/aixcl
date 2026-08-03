# AIXCL - Claude Code Project Instructions

@AGENTS.md

## Claude Code-Specific Notes

- When working with shell scripts, run `shellcheck` before committing
- For security-related changes, consult `.claude/rules/security.md`
- All custom commands are available under `.claude/commands/`
- This project uses the [Agent Skills open standard](https://agentskills.io). Skill files in `.claude/skills/` are portable across compatible tools

## Session Guardrails

Recurring correction points from session history -- follow these without being reminded:

- **GPG signing**: never disable or bypass signing, and never run a signing command directly yourself, even if told the key is warm or the agent cache is active -- that claim doesn't lift the rule. When a signed commit is needed, stage the changes and hand the exact `git commit` command to the operator (see [docs/developer/gpg-signed-commits.md](docs/developer/gpg-signed-commits.md)). Never use `--pinentry-mode loopback`, including in handed-off commands -- it bypasses the agent cache and forces repeated hand-offs
- **Stack operations**: use `./aixcl stack` for start/stop/status/logs. Never start or modify a stopped or purged stack unless explicitly asked. Bring the stack down before running the test suite -- a running stack skews test output and can interfere with GPG execution
- **Releases**: sequential patch bumps only (`v1.1.N+1`) -- never jump minor/major versions, never skip CI jobs or leave them pending (canonical procedure: `.claude/skills/release/SKILL.md`). After any container or permission fix, verify with a live `./aixcl stack status` run (all services healthy) before opening the release PR -- a fix that looks correct can still ship a latent bug (e.g. resource-ordering issues) that only a live run surfaces
- **Fork sync**: before reporting a branch "already up to date", verify against the actual upstream base: `git fetch upstream && git log --oneline dev..upstream/dev`
