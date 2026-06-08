# AIXCL - Claude Code Project Instructions

@AGENTS.md

## Claude Code-Specific Notes

- Use plan mode (`/mode planning`) before making architectural changes to `lib/cli/profile.sh` or `services/docker-compose.yml`
- When working with shell scripts, run `shellcheck` before committing
- For security-related changes, consult `.claude/rules/security.md`
- All custom commands are available under `.claude/commands/`
- This project uses the [Agent Skills open standard](https://agentskills.io). Skill files in `.claude/skills/` are portable across compatible tools
