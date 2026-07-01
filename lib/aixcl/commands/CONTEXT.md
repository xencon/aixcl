# CONTEXT: lib/aixcl/commands/

One shell script per top-level `./aixcl` CLI command. Most frequently modified
directory in the codebase.

## Contents

| File | Command | Key behaviour notes |
|------|---------|-------------------|
| `app.sh` | `./aixcl app` | App lifecycle (start, stop, build, status). Uses `_app_resolve_start_order()` (Kahn's topological sort) to honour `depends_on` in manifests -- do not bypass by iterating services sequentially. |
| `engine.sh` | `./aixcl engine` | Inference engine selection: Ollama. |
| `models.sh` | `./aixcl models` | Model management (add, list, remove). |
| `stack.sh` | `./aixcl stack` | Platform stack lifecycle. Checks `VAULT_TOKEN` env var before GPG decrypt -- this is the CI/agent escape hatch; set it to skip GPG entirely. |
| `utils.sh` | `./aixcl utils` | Environment check and utility commands. |
| `vault-init.sh` | `./aixcl vault init` | One-time Vault initialisation. |
| `vault-status.sh` | `./aixcl vault status` | Vault health check. Loads GPG token with `[ ! -t 0 ]` TTY guard (POSIX, not `tty` command). |
| `vault-unseal.sh` | `./aixcl vault unseal` | Vault unseal procedure. |
| `vault.sh` | `./aixcl vault` | Vault sub-command dispatcher. |

## Agent Guidance

**You MAY:**
- Add new commands by creating a file here and registering in `../dispatcher.sh`
- Modify command behaviour within existing semantics

**You MUST NOT:**
- Bypass `_app_resolve_start_order()` in `app.sh` -- dependency ordering is an invariant
- Remove the `VAULT_TOKEN` escape hatch in `stack.sh` -- agents and CI depend on it
- Call `docker` or `podman` directly -- use functions from `../../core/docker_utils.sh`
- Use `tty` command for TTY detection -- use `[ ! -t 0 ]` (POSIX portable)

## Pre-Commit

```bash
shellcheck --severity=warning --exclude=SC1091 lib/aixcl/commands/<file>.sh
bash -n lib/aixcl/commands/<file>.sh
./scripts/checks/check-ai-elisions.sh --staged
```

## Cross-References

- `lib/core/app_parser.sh` -- manifest parsing used by app.sh
- `lib/core/docker_utils.sh` -- runtime detection (Docker vs Podman)
- `lib/aixcl/dispatcher.sh` -- registers commands
- `completion/aixcl.bash` -- update when adding a new command
- `etc/app-scaffold/app.yaml` -- canonical manifest schema
- `docs/developer/adding-apps.md` -- app development guide
- `docs/architecture/decisions/003-vault-token-escape-hatch.md` -- VAULT_TOKEN design
- `docs/architecture/decisions/004-topological-sort-depends-on.md` -- depends_on design
