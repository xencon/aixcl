# AIXCL Usage Guide

## Quick Start

### 1. Initialize (first run only)

```bash
./aixcl utils check-env
./aixcl stack init
```

`init` generates `.env`, admin credentials, and Vault secrets. It is safe to re-run.

### 2. Start the Stack

```bash
# First time (or to switch profile)
./aixcl stack start --profile sys

# After that (remembers profile in .env)
./aixcl stack start
```

### 3. Verify Health

```bash
./aixcl stack status
```

Wait until all services show `OK running`.

### 4. Add Models

```bash
./aixcl models add qwen2.5-coder:1.5b
```

Then chat via [Open WebUI](http://localhost:8080) (first user = admin), `opencode`, or `curl http://localhost:11434/v1/chat/completions`.

---

## Services by Profile

| Profile | Purpose | Services |
|---------|---------|----------|
| **usr** | Minimal footprint | Ollama, PostgreSQL |
| **dev** | Workstation | usr + Open WebUI, pgAdmin |
| **ops** | Monitoring | usr + Prometheus, Grafana, Loki, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter |
| **sys** | Full stack | All services |

## Access Points (sys profile)

| Service | URL | Notes |
|---------|-----|-------|
| Open WebUI | http://localhost:8080 | First user becomes admin |
| pgAdmin | http://localhost:5050 | Email/password from `vault credentials` |
| Grafana | http://localhost:3000 | Email/password from `vault credentials` |
| Vault UI | http://localhost:8200 | Token: `aixcl-dev-token` |
| Prometheus | http://localhost:9090 | No auth (localhost only) |
| Ollama API | http://localhost:11434 | OpenAI-compatible endpoint |

Get current credentials:
```bash
./aixcl vault credentials
```

## Common Commands

| Task | Command |
|------|---------|
| Check status | `./aixcl stack status` |
| View logs | `./aixcl stack logs <service> <n>` |
| Stop stack | `./aixcl stack stop` |
| Add model | `./aixcl models add <model>` |
| List models | `./aixcl models list` |
| Clean resources | `./aixcl utils clean` |
| Export systemd | `./aixcl stack export-quadlet` |

---

## Troubleshooting

### Services Won't Start

```bash
# Check for port conflicts
sudo lsof -i :11434 -i :8080 -i :8200

# Full reset (removes containers and volumes)
./aixcl stack stop
./aixcl utils clean
./aixcl stack init
./aixcl stack start --profile sys
```

### Vault Not Ready

```bash
./aixcl vault status
# Check logs if unsealed
./aixcl stack logs vault
```

### Model Not in WebUI

If using vLLM or llama.cpp, add a Direct Connection in Open WebUI Settings > Connections pointing to `http://127.0.0.1:11434/v1`. Ollama users don't need this.

---

## Architecture

AIXCL separates **Runtime Core** (always enabled) from **Operational Services** (profile-dependent).

- **Runtime Core**: Inference Engine + OpenCode (VS Code plugin)
- **Operational Services**: PostgreSQL, Open WebUI, monitoring stack

See [`architecture/governance/`](../architecture/governance/) for invariants and service contracts.
