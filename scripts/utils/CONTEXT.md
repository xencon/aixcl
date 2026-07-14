# CONTEXT: scripts/utils/

Developer and operator tooling: setup scripts, workflow wrappers, and
maintenance utilities. These run on the HOST (unlike `scripts/runtime/`,
which runs inside containers).

## Contents

| File | Purpose |
|------|---------|
| `create-issue.sh` | Issue creation wrapper -- targets xencon/aixcl, template-based or custom body (custom bodies validated for reference style), assignee at creation. Required by DEVELOPMENT.md. |
| `create-pr.sh` | PR creation wrapper -- fork-aware `--head`, title/branch/body validation, assignee and labels at creation time. Required by DEVELOPMENT.md. |
| `sync-mirrors.sh` | One-command `.claude/` <-> `.opencode/` skills and rules sync, then parity verification. Run after editing either side. |
| `init-volumes.sh` | Creates the external Docker volumes shared across contexts. |
| `validate-volume-consistency.sh` | Checks volume declarations across compose files. |
| `setup-gpg.sh` | One-time GPG signing setup per developer. |
| `setup-hooks.sh` | Installs the git pre-commit/pre-push hooks. |
| `setup-podman-rootless.sh` | Podman rootless + CDI GPU setup. |
| `start-devcontainer-podman.sh` | Devcontainer bring-up under Podman. |
| `trace-llm-call.sh` | LLM call tracing wrapper for app builders (JSON-lines + optional Loki push). |
| `cleanup-stale-artifacts.sh` | Removes stale generated artifacts. |

## Key Constraints

- Everything here must be non-interactive safe: agents have no TTY, so
  prompts (`read -p`) are forbidden -- fail hard with remediation text.
- GitHub-writing scripts default to the canonical repo
  (`AIXCL_UPSTREAM_REPO`, default `xencon/aixcl`) and must pass assignee
  and labels at creation time (PR validation races otherwise).
- Release mechanics live in `./aixcl release` (lib/aixcl/commands/
  release.sh), not here -- these scripts are building blocks it composes.

## Agent Guidance

**You MAY:**
- Add new host-side developer tooling following the non-interactive rule
- Extend wrappers with validation that mirrors CI checks

**You MUST NOT:**
- Add interactive prompts
- Duplicate logic that belongs in `scripts/checks/` (validation) or
  `lib/aixcl/commands/` (CLI-fronted workflow)

## Cross-References

- `scripts/checks/CONTEXT.md` -- CI validation scripts (fronted by `./aixcl checks`)
- `lib/aixcl/commands/` -- CLI command modules that compose these tools
- `DEVELOPMENT.md` -- wrapper usage requirements
