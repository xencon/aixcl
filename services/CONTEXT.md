# CONTEXT: services/

Docker Compose definitions for the entire AIXCL platform stack.

## Contents

| File | Purpose |
|------|---------|
| `docker-compose.yml` | **Primary.** Full platform stack. All services use `network_mode: host` (invariant). |
| `docker-compose.arm.yml` | ARM64 image overrides. Applied on top of primary with `-f`. |
| `docker-compose.gpu.yml` | NVIDIA GPU resource configuration. Applied on top of primary. |
| `docker-compose.gpu-podman.yml` | GPU variant for rootless Podman CDI device access. |
| `docker-compose.postgres-ssl.yml` | SSL-enabled postgres override (self-signed certs). |
| `docker-compose.secrets.yml` | Docker secrets injection variant (alternative to Vault). |

## Invariants -- Read Before Editing

**network_mode: host** is used by all services in `docker-compose.yml`. This
is a documented architectural invariant, not a security oversight. Do NOT
change to bridge networking or add custom Docker networks.
See `docs/architecture/governance/00_invariants.md` section 7 and
`docs/architecture/decisions/001-network-mode-host.md`.

**vault-agent-*-bootstrap containers** use `restart: on-failure`. This is
intentional one-shot design. Do NOT change to `unless-stopped`.
See `docs/architecture/decisions/002-one-shot-bootstrap.md`.

## Validate Before Committing

```bash
docker compose -f services/docker-compose.yml config > /dev/null
yamllint -c .yamllint.yml services/docker-compose.yml
```

## Adding a Service

Use the `add-service` skill for the full checklist -- adding a service requires
changes in at least three places (compose file, profile env, service contract).

```
.claude/skills/add-service/SKILL.md
```

Also read: `docs/developer/adding-services.md`

## Agent Guidance

**You MAY:**
- Add operational services (monitoring, logging, automation)
- Modify entrypoint scripts, environment variables, volume mounts for existing services
- Add variant compose files for new hardware profiles

**You MUST NOT:**
- Change `network_mode: host` to any other value
- Change `restart: on-failure` on bootstrap containers to `unless-stopped`
- Add dependencies from runtime core services (ollama, postgres) to operational services
- Remove or disable runtime core services

## Cross-References

- `scripts/runtime/` -- entrypoint scripts mounted into containers
- `scripts/vault/` -- bootstrap scripts run by vault-agent-*-bootstrap containers
- `vault/agent-config/` -- HCL configs for Vault Agent containers
- `lib/cli/profile.sh` -- determines which services the CLI starts
- `config/profiles/` -- profile env files
- `docs/reference/service-map.md` -- service registry (service, profile, port, health check)
- `docs/architecture/governance/02_profiles.md` -- profile invariants
