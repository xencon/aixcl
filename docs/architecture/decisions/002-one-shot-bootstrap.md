# ADR 002 -- One-Shot Vault Bootstrap Containers

| Field | Value |
|-------|-------|
| Status | Accepted |
| Decided | 2026-06 (issue #1338) |
| Authority | services/docker-compose.yml (vault-agent-*-bootstrap) |

## Context

When the AIXCL stack starts, bootstrap containers must write initial service
passwords into Vault KV. The original design kept these containers running
with an infinite loop (`while true; do sleep 30; fetch_bootstrap_password; done`).

This created two problems:
1. The Vault root token was held in a long-lived container environment -- a
   security risk if the container is inspected or its env exported.
2. On stack restart, the bootstrap containers re-ran the bootstrap logic
   unnecessarily, sometimes overwriting credentials that services were using.

## Decision

Bootstrap containers are one-shot:

- The bootstrap script runs once, writes the credential to Vault KV, then exits 0.
- On failure, the script exits non-zero.
- The compose service uses `restart: on-failure` so Docker/Podman retries only
  on failure. On success, the container stays stopped.

## Rationale

- **Security**: Root token is in the container environment only for the duration
  of the bootstrap operation (seconds), not indefinitely.
- **Idempotency**: A stack restart does not re-run bootstrap for already-initialised
  services. The compose service stays stopped after successful exit 0.
- **Simplicity**: `restart: on-failure` is the standard Docker pattern for one-shot
  initialisation containers. No custom logic needed.

## What This Means for Agents

- Do NOT add `while true; do sleep 30; ...; done` to bootstrap scripts.
- Do NOT change `restart: on-failure` to `restart: unless-stopped` on bootstrap containers.
- Bootstrap containers that are stopped (not running) after stack start is CORRECT behaviour.
- If a bootstrap container is restarting repeatedly, it is failing -- check Vault connectivity.

## Affected Files

- `services/docker-compose.yml` -- `vault-agent-*-bootstrap` service definitions
- `scripts/vault/bootstrap-password-*.sh` -- the one-shot scripts
