---
name: add-service
description: Guided checklist for safely adding a new platform service to AIXCL, preserving all invariants
version: 1.0
---

# Skill: add-service

Use this skill when adding a new service to the AIXCL platform stack. It walks
through every required change in the correct order and flags invariant risks.

## Pre-Flight Checks

Before starting, confirm:

- [ ] A GitHub issue exists for this service addition
- [ ] The service is an operational service (monitoring, logging, automation, UI)
      NOT a replacement or extension of runtime core (Ollama, OpenCode, Postgres)
- [ ] The service does not create a dependency from runtime core -> operational services
- [ ] `docker compose -f services/docker-compose.yml config > /dev/null` passes currently

## Step 1 -- Define the Service in docker-compose.yml

Add a service entry to `services/docker-compose.yml`.

Required fields:
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

## Step 2 -- Add a Named Volume

Add the named volume to the `volumes:` section at the bottom of `docker-compose.yml`:

```yaml
volumes:
  <service-volume-name>:
```

Naming convention: `aixcl-<service-name>-<purpose>` (e.g., `aixcl-grafana-data`)

## Step 3 -- Register in the Correct Profile(s)

Edit `config/profiles/<profile>.env` to add the service name to the active
service list for each profile that should include it.

Profile decision guide:
- `bld.env`: observability, server-side tools, no end-user UI
- `sys.env`: everything in bld plus end-user UI (WebUI, admin tools)
- Both: required infrastructure (secrets, databases)

- [ ] Service added to the appropriate profile env file(s)
- [ ] If adding to `bld`, also add to `sys` (sys is a superset of bld)

## Step 4 -- Update Profile Documentation

Edit `docs/architecture/governance/02_profiles.md` to list the new service
under the correct profile's "Includes" section.

- [ ] Profile doc updated

## Step 5 -- Write a Service Contract (if significant)

For services that other services depend on, add a service contract:

- Runtime services: `docs/architecture/governance/service_contracts/runtime/<service>.md`
- Build/operational services: `docs/architecture/governance/service_contracts/bld/<service>.md`

Contract template:
```markdown
# Service Contract: <service-name>

## Provides
- <what other services can depend on>

## Requires
- <what this service depends on>

## Invariants
- <things that must always be true about this service>
```

- [ ] Service contract written (or explicitly skipped for trivial services)

## Step 6 -- Write or Mount an Entrypoint Script (if needed)

If the service needs custom startup logic:

1. Create `scripts/runtime/<service>-entrypoint.sh`
2. Add `set -euo pipefail` at the top
3. Mount it read-only in the compose service:
   ```yaml
   volumes:
     - ../scripts/runtime/<service>-entrypoint.sh:/<service>-entrypoint.sh:ro
   entrypoint: ["/<service>-entrypoint.sh"]
   ```

- [ ] `shellcheck --severity=warning --exclude=SC1091 scripts/runtime/<service>-entrypoint.sh` passes
- [ ] `bash -n scripts/runtime/<service>-entrypoint.sh` passes

## Step 7 -- Update the Service Map

Add a row to `docs/reference/service-map.md` for the new service.

- [ ] Service map updated

## Step 8 -- Run Validation

```bash
docker compose -f services/docker-compose.yml config > /dev/null
yamllint -c .yamllint.yml services/docker-compose.yml
bash scripts/checks/check-paths.sh
./scripts/checks/check-ai-elisions.sh --staged
```

- [ ] All validation passes

## Step 9 -- Commit and PR

```bash
git add services/docker-compose.yml config/profiles/ docs/ scripts/runtime/
git commit -m "feat: add <service-name> service

- Add compose service definition with host networking
- Register in <profile> profile
- Add entrypoint script
- Update service map and profile documentation

Fixes #<issue-number>"
```

PR checklist:
- [ ] Title format: `Add <service-name> service (#<N>)` (no colons)
- [ ] Labels: `Feature` + `component:infrastructure` (+ profile label if applicable)
- [ ] Assignee set at PR creation time
- [ ] CI is green

## Invariant Reminder

You MUST NOT:
- Use `latest` image tags
- Use `network_mode: bridge` or custom Docker networks
- Create a dependency from Ollama, OpenCode, or Postgres on the new service
- Skip profile registration (the CLI will not start the service without it)
