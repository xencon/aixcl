# AIXCL Usage Guide

For installation and quick start, see [README.md](/README.md).

## Profile-Specific Services

| Profile | Purpose | Services |
|---------|---------|----------|
| **bld** | Monitoring | Ollama, Vault, PostgreSQL, Prometheus, Grafana, Loki, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter |
| **sys** | Full stack | bld + Open WebUI, pgAdmin |

Deprecated (not supported):
- `usr` -- DEPRECATED (Vault now required for database secrets)
- `dev` -- DEPRECATED (Vault now required for database secrets)

## Service URLs (sys profile)

| Service | URL |
|---------|-----|
| Open WebUI | http://localhost:8080 |
| pgAdmin | http://localhost:5050 |
| Grafana | http://localhost:3000 |
| Vault UI | http://localhost:8200 |
| Prometheus | http://localhost:9090 |
| Ollama API | http://localhost:11434 |

## Common Commands

| Task | Command |
|------|---------|
| Check status | `./aixcl stack status` |
| View logs | `./aixcl stack logs <service> [n] [-f]` |
| Stop stack | `./aixcl stack stop` |
| Add model | `./aixcl models add <model>` |
| List models | `./aixcl models list` |
| Vault status | `./aixcl vault status` |
| Vault unseal | `./aixcl vault unseal` |
| Vault init | `./aixcl vault init` |
| Vault passwords | `./aixcl vault passwords` |
| Vault credentials | `./aixcl vault credentials` |
| Vault logs | `./aixcl vault logs [n]` |

## Architecture

AIXCL separates **Runtime Core** (always enabled) from **Operational Services** (profile-dependent).

- **Runtime Core**: Inference Engine + OpenCode (VS Code plugin)
- **Operational Services**: PostgreSQL, Open WebUI, monitoring stack

See [`architecture/governance/`](../architecture/governance/) for invariants and service contracts.
