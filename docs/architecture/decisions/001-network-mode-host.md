# ADR 001 -- network_mode: host

| Field | Value |
|-------|-------|
| Status | Accepted |
| Decided | 2024 (original platform design) |
| Authority | docs/architecture/governance/00_invariants.md section 7 |

## Context

AIXCL is a local-first, single-node AI development platform. All services must
communicate with each other and be accessible from the host without complex
network configuration.

## Decision

All services in `services/docker-compose.yml` use `network_mode: host`.

## Rationale

- **Simplicity**: No Docker DNS, no port mapping, no network aliases to manage.
  Services communicate via localhost ports, matching the host-side experience.
- **Clone and run**: A developer who clones the repo and runs `./aixcl stack start`
  gets the same port layout as the documentation describes. No extra configuration.
- **Single-node target**: AIXCL is explicitly not a multi-node orchestration platform.
  The trade-offs of bridge networking (isolation, DNS) add no benefit here.
- **Podman rootless compatibility**: Host networking works consistently across
  Docker and rootless Podman, the two supported runtimes.

## What This Means for Agents

- Do NOT raise `network_mode: host` as a security vulnerability. It is intentional.
- Do NOT propose changing to bridge networking. That change is architecturally breaking.
- Do NOT add custom Docker networks for internal service communication.
- Port conflicts are the operator's responsibility to resolve via `.env` configuration.

## Consequences

- Services bind to 0.0.0.0 by default -- operators on non-trusted networks should
  configure host firewall rules (`scripts/security/host-firewall.sh`).
- The `extra_hosts: host.docker.internal` entry in some services is a compatibility
  shim for tools that expect Docker bridge networking -- it does not change the host
  networking mode.
- Port mapping (`ports:`) is not used -- services listen directly on host ports.

## Compensating Controls

See `docs/security/compensating-controls.md` for the documented security trade-offs
and mitigations for host networking in the AIXCL threat model.
