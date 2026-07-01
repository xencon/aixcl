# CONTEXT: scripts/runtime/

Container entrypoint scripts -- one per service. These run INSIDE containers
as PID 1 at startup. They are mounted read-only from the host into containers
via volume mounts defined in `services/docker-compose.yml`.

## Contents

| File | Service | Notes |
|------|---------|-------|
| `ollama-entrypoint.sh` | `ollama` | Sets permissions, switches to ubuntu user, starts Ollama. |
| `grafana-entrypoint.sh` | `grafana` | Waits for Prometheus, then starts Grafana. |
| `openwebui-entrypoint.sh` | `openwebui` | Standard OpenWebUI startup. |
| `openwebui-vault-entrypoint.sh` | `openwebui` (vault profile) | Fetches credentials from Vault before starting OpenWebUI. |
| `pgadmin-entrypoint.sh` | `pgadmin` | Configures pgAdmin servers.json, starts pgAdmin. |
| `postgres-exporter-entrypoint.sh` | `postgres-exporter` | Waits for postgres, starts exporter. |
| `postgres-secret-entrypoint.sh` | `postgres` | Injects secrets from Docker secrets into postgres env. |

## Key Constraints

- These scripts run as PID 1 inside containers. `set -euo pipefail` is required.
- Host-side tooling (systemd, host paths outside mounts) is NOT available.
- Do not add host-path references. Only paths inside the container or
  mounted volumes are accessible.
- `docker_utils.sh` is NOT available here -- these scripts are container-side.

## Agent Guidance

**You MAY:**
- Modify entrypoint logic for a specific service
- Add wait-for-dependency patterns (see `grafana-entrypoint.sh` as reference)

**You MUST NOT:**
- Reference host-only paths or host-only tools
- Call `docker` or `podman` from inside an entrypoint (containers cannot
  manage sibling containers this way in the host-networking model)

## Cross-References

- `services/docker-compose.yml` -- volume mounts and `entrypoint:` references
- `scripts/vault/vault-agent-openwebui.sh` -- called by openwebui-vault-entrypoint.sh
- `docs/developer/adding-services.md` -- guide for adding a new service with entrypoint
