# CONTEXT: vault/agent-config/

HCL configuration files for Vault Agent instances. Each file corresponds to
a named container in `services/docker-compose.yml`. These run INSIDE containers.

## Contents

| File | Container | Purpose |
|------|-----------|---------|
| `agent.hcl` | `vault-agent-postgres` | Long-lived agent: fetches dynamic postgres credentials, writes to `/tmp/aixcl-secrets/`. |
| `postgres-bootstrap.hcl` | `vault-agent-postgres-bootstrap` | One-shot bootstrap: writes initial postgres password to Vault KV. Exits after completion. |
| `openwebui.hcl` | `vault-agent-openwebui` | Long-lived agent: fetches OpenWebUI credentials. |
| `openwebui-bootstrap.hcl` | `vault-agent-openwebui-bootstrap` | One-shot bootstrap: writes OpenWebUI password to Vault KV. Exits after completion. |
| `pgexporter.hcl` | `vault-agent-pgexporter` | Long-lived agent: fetches postgres-exporter read-only credentials. |

## Container Mapping

Each HCL file is mounted into its container via `services/docker-compose.yml`.
If you add a new HCL file, you MUST also add a corresponding service entry in
the compose file. The names must stay in sync.

## Bootstrap vs Long-Lived Agents

| Type | Restart policy | Exit behaviour |
|------|---------------|---------------|
| Bootstrap (`*-bootstrap.hcl`) | `restart: on-failure` | Exits 0 on success; Docker does not restart |
| Long-lived (`agent.hcl`, `openwebui.hcl`, `pgexporter.hcl`) | `restart: unless-stopped` | Runs continuously, renews leases |

Do not confuse these two patterns. Bootstrap configs must remain one-shot.

## Agent Guidance

**You MAY:**
- Add a new bootstrap HCL file when adding a service that needs an initial secret in Vault KV
- Add a new long-lived agent HCL file when adding a service that needs dynamic credentials

**You MUST NOT:**
- Add a sleep loop or continuous polling to a bootstrap config
- Change the auth method (AppRole) without updating all configs consistently

## Cross-References

- `services/docker-compose.yml` -- container definitions that mount these files
- `scripts/vault/` -- host-side bootstrap scripts called by bootstrap containers
- `vault/vault.hcl` -- Vault server configuration
- `docs/developer/vault-integration.md` -- full Vault integration architecture
- `docs/architecture/decisions/002-one-shot-bootstrap.md` -- bootstrap design rationale
