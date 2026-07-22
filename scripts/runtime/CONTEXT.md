# CONTEXT: scripts/runtime/

Container entrypoint scripts -- one per service. These run INSIDE containers
as PID 1 at startup. They are mounted read-only from the host into containers
via volume mounts defined in `services/docker-compose.yml`.

## Contents

| File | Service | Notes |
|------|---------|-------|
| `ollama-entrypoint.sh` | `ollama` | Sets permissions, switches to ubuntu user, starts Ollama. |
| `grafana-entrypoint.sh` | `grafana` | First start: waits for the Vault admin password, then starts Grafana. Restart: starts directly. |
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

## Capped Entrypoint Rules (#1891/#1901/#1909)

For entrypoints doing privileged filesystem work under `cap_drop`:

- **Create before chown**: root without CAP_DAC_OVERRIDE cannot mkdir
  inside a directory it already chowned away. Create missing dirs while
  the parent is root-owned; defer later creation to the non-root phase.
- **REQUIRED ops fail fast, naming the capability** (e.g. "container
  likely lacks CAP_CHOWN"). Never `2>/dev/null || true` an operation the
  service cannot run without -- that converts a clear startup error into
  an unexplained crash-loop later.
- **OPTIONAL ops get a visible `[WARN]`** stating the consequence, never
  a silent `|| true`. (Probe no-matches like `pkill` on an absent
  process are the one exception: no-match is the normal case.)
- **Verify with the three-scenario matrix**: truly-empty volume,
  partially-initialised volume, and a withheld-capability run that must
  fail loudly. See docs/developer/adding-services.md.

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
