# CONTEXT: scripts/vault/

Vault integration scripts: bootstrap password population, agent wrappers,
and the shared vault-commands library sourced by CLI commands.

## Contents

| File | Purpose | Execution context |
|------|---------|-----------------|
| `vault-commands.sh` | Shared Vault command library. Sourced by `lib/aixcl/commands/vault*.sh`. Provides `vault_status`, `vault_credentials`, `vault_rotate`, etc. | Host (sourced) |
| `vault-agent.sh` | Vault Agent wrapper for postgres credential fetching. | Host |
| `vault-agent-openwebui.sh` | Vault Agent wrapper for OpenWebUI credential fetching. | Host |
| `bootstrap-password-postgres.sh` | One-shot bootstrap: writes postgres password to Vault KV. | Container (vault-agent-postgres-bootstrap) |
| `bootstrap-password-grafana.sh` | One-shot bootstrap: writes Grafana password to Vault KV. | Container (vault-agent-grafana-bootstrap) |
| `bootstrap-password-openwebui.sh` | One-shot bootstrap: writes OpenWebUI password to Vault KV. | Container (vault-agent-openwebui-bootstrap) |
| `bootstrap-password-pgadmin.sh` | One-shot bootstrap: writes pgAdmin password to Vault KV. | Container (vault-agent-pgadmin-bootstrap) |
| `init/` | Vault initialisation scripts. Run once at Vault setup time by `./aixcl vault init`. | Host |

## Bootstrap Design -- One-Shot, Not Looping

Bootstrap scripts exit 0 on success and non-zero on failure. They do NOT
loop or sleep. The compose service uses `restart: on-failure` to handle
retries. This is intentional:

- Container exits 0 on success -- Docker does not restart it
- Container exits non-zero on failure -- Docker retries automatically
- Root token is never held in a long-lived container environment

Do NOT add `while true; do sleep 30; ...; done` tails to these scripts.
Do NOT change the compose restart policy to `unless-stopped`.

See `docs/architecture/decisions/002-one-shot-bootstrap.md` for the full rationale.

## Agent Guidance

**You MAY:**
- Add new bootstrap scripts following the one-shot pattern
- Extend `vault-commands.sh` with new vault operations

**You MUST NOT:**
- Add loops or sleep tails to bootstrap scripts
- Change bootstrap container restart policy
- Call Vault API with the root token from long-lived processes

## Cross-References

- `lib/aixcl/commands/vault*.sh` -- CLI commands that source vault-commands.sh
- `services/docker-compose.yml` -- defines vault-agent-*-bootstrap containers
- `docs/architecture/decisions/002-one-shot-bootstrap.md` -- design rationale
- `docs/architecture/decisions/003-vault-token-escape-hatch.md` -- VAULT_TOKEN usage
