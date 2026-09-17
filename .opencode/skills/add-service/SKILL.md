---
name: add-service
description: >
  Guided checklist for safely adding a new operational service to the AIXCL
  stack, preserving all platform invariants (host networking, pinned images,
  runtime/operational boundary, profile registration). Use when adding a
  service to docker-compose, wiring a new container into the stack, or asked
  to "add a service", "add <tool> to the stack", "new compose service".
argument-hint: <service name and purpose>
compatibility: OpenCode, Claude Code
metadata:
  category: platform
  version: "1.3"
---

# Skill: add-service

## Purpose

Add a new operational service to the AIXCL platform stack, walking through
every required change in the correct order and flagging invariant risks.

**Templates and exact commands for every step:**
[references/checklist-detail.md](references/checklist-detail.md)

## When to Run

When a new operational service (monitoring, logging, automation, UI) is
being added to the stack.

## Pre-Flight Checks

Before starting, confirm:

- [ ] A GitHub issue exists for this service addition
- [ ] The service is an operational service (monitoring, logging, automation, UI)
      NOT a replacement or extension of runtime core (Ollama, OpenCode, Postgres)
- [ ] The service does not create a dependency from runtime core -> operational services
- [ ] `docker compose -f services/docker-compose.yml config > /dev/null` passes currently

## Steps

1. **Define the service in `services/docker-compose.yml`** -- pinned image,
   `network_mode: host`, named volume. Template and validation commands in
   the reference.
2. **Add a named volume** to the `volumes:` section, naming convention
   `aixcl-<service-name>-<purpose>`.
3. **Register in the correct profile(s)** -- edit `config/profiles/<profile>.env`.
   `bld.env`: observability/server-side tools with no end-user UI. `sys.env`:
   everything in bld plus end-user UI. Both: required infrastructure. If
   adding to `bld`, also add to `sys` (sys is a superset of bld).
4. **Update profile documentation** in `docs/architecture/governance/02_profiles.md`.
5. **Write a service contract** (if other services will depend on this one)
   -- template in the reference, or explicitly skip for trivial services.
6. **Write or mount an entrypoint script** (if custom startup logic is
   needed) -- template and shellcheck/bash -n validation in the reference.
7. **Run validation:**
   ```bash
   docker compose -f services/docker-compose.yml config > /dev/null
   yamllint -c .yamllint.yml services/docker-compose.yml
   bash scripts/checks/check-paths.sh
   ./scripts/checks/check-ai-elisions.sh --staged
   ```
8. **Commit and PR** -- commit message and PR checklist templates in the
   reference.

## Invariant Reminder

You MUST NOT:
- Use `latest` image tags
- Use `network_mode: bridge` or custom Docker networks
- Create a dependency from Ollama, OpenCode, or Postgres on the new service
- Skip profile registration (the CLI will not start the service without it)
