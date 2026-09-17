# Add-service checklist detail

## Contents

- Compose service template
- Service contract template
- Entrypoint script requirements
- Commit and PR templates

## Compose service template (Step 1)

Add a service entry to `services/docker-compose.yml`. Required fields:

```yaml
  <service-name>:
    image: <registry>/<image>:<pinned-version>    # Always pin the version
    container_name: <service-name>
    network_mode: host                             # INVARIANT -- do not change
    restart: unless-stopped                        # or on-failure for one-shot
    volumes:
      - <named-volume>:/data                       # use named volumes, not bind mounts
```

Rules:
- [ ] `network_mode: host` is present (invariant)
- [ ] Image version is pinned (no `latest` tags)
- [ ] Named volume is used for persistent data (not a bind mount to host path)
- [ ] If the service needs an entrypoint script, place it in `scripts/runtime/`

Validate:
```bash
docker compose -f services/docker-compose.yml config > /dev/null
yamllint -c .yamllint.yml services/docker-compose.yml
```

## Named volume (Step 2)

Add the named volume to the `volumes:` section at the bottom of `docker-compose.yml`:

```yaml
volumes:
  <service-volume-name>:
```

Naming convention: `aixcl-<service-name>-<purpose>` (e.g., `aixcl-grafana-data`)

## Service contract template (Step 5)

For services that other services depend on, add a service contract:

- Runtime services: `docs/architecture/governance/service_contracts/runtime/<service>.md`
- Build/operational services: `docs/architecture/governance/service_contracts/bld/<service>.md`

Template:
```markdown
# Service Contract: <service-name>

## Provides
- <what other services can depend on>

## Requires
- <what this service depends on>

## Invariants
- <things that must always be true about this service>
```

Write one, or explicitly skip it for trivial services.

## Entrypoint script (Step 6, if needed)

If the service needs custom startup logic:

1. Create `scripts/runtime/<service>-entrypoint.sh`
2. Add `set -euo pipefail` at the top
3. Mount it read-only in the compose service:
   ```yaml
   volumes:
     - ../scripts/runtime/<service>-entrypoint.sh:/<service>-entrypoint.sh:ro
   entrypoint: ["/<service>-entrypoint.sh"]
   ```

Then validate:
```bash
shellcheck --severity=warning --exclude=SC1091 scripts/runtime/<service>-entrypoint.sh
bash -n scripts/runtime/<service>-entrypoint.sh
```

## Commit and PR templates (Step 8)

```bash
git add services/docker-compose.yml config/profiles/ docs/ scripts/runtime/
git commit -m "feat: add <service-name> service

- Add compose service definition with host networking
- Register in <profile> profile
- Add entrypoint script
- Update profile documentation

Fixes #<issue-number>"
```

PR checklist:
- [ ] Title format: `Add <service-name> service (#<N>)` (no colons)
- [ ] Labels: `Feature` + `component:infrastructure` (+ profile label if applicable)
- [ ] Assignee set at PR creation time
- [ ] CI is green
