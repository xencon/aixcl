# CONTEXT: lib/core/

Shared utility functions sourced by command scripts in `lib/aixcl/commands/`.
Do not duplicate logic from here -- source these files instead.

## Contents

| File | Purpose | When to use it |
|------|---------|---------------|
| `app_parser.sh` | Parses `apps/<name>/app.yaml` into `APP_*` shell variables. Uses `compgen -v APP_` to unset stale vars before each load -- prevents cross-manifest contamination. | Any command that reads app manifests. |
| `app_provision.sh` | App provisioning logic: volumes, secrets injection. | `app.sh` start/stop flows. |
| `color.sh` | Terminal colour constants (`RED`, `GREEN`, `YELLOW`, `NC`). | Any command with coloured output. |
| `common.sh` | Shared utility functions: error handling, argument parsing. | General use. |
| `docker_utils.sh` | Docker/Podman abstraction. Detects which runtime is present and exports wrapper functions. | **Always use this instead of calling `docker` or `podman` directly.** |
| `env_check.sh` | Validates host prerequisites (Python3-yaml, jq, curl, container runtime). | `utils check-env` and pre-start validation. |
| `logging.sh` | Structured logging (`log_info`, `log_warn`, `log_error`). | Preferred over raw `echo` in commands. |
| `pgadmin_utils.sh` | pgAdmin-specific helpers (config file generation). | `stack.sh` pgAdmin setup path. |
| `service_utils.sh` | Service health check helpers (wait-for-ready, container status). | Stack start/stop sequencing. |

## Agent Guidance

**You MAY:**
- Add new utility functions here when they are shared across two or more commands
- Extend existing functions

**You MUST NOT:**
- Call `docker` or `podman` directly in command files -- use `docker_utils.sh`
- Use `eval` on user-supplied input -- `app_parser.sh` only evals Python-generated output
- Add command-specific logic here -- keep this directory as pure shared utilities

## Pre-Commit

```bash
shellcheck --severity=warning --exclude=SC1091 lib/core/<file>.sh
bash -n lib/core/<file>.sh
```

## Cross-References

- `lib/aixcl/commands/` -- consumers of these utilities
- `etc/app-scaffold/app.yaml` -- defines the schema `app_parser.sh` parses
- `docs/architecture/decisions/005-python3-yaml-parser.md` -- why Python3 for YAML
