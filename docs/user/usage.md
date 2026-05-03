# AIXCL Usage Guide

## Architecture Overview

AIXCL follows a governance model that separates **Runtime Core** from **Operational Services**:

### Runtime Core (Strict - Always Enabled)
These services define what AIXCL is and are always present:
- **Inference Engine** (Ollama, vLLM, llama.cpp): LLM inference engine
- **OpenCode**: VS Code plugin for AI-powered code assistance

Runtime core services are non-negotiable and must be running for AIXCL to function.

### Operational Services (Guided - Profile-Dependent)
These services support, observe, or operate the runtime:
- **Persistence**: PostgreSQL (database), pgAdmin (database admin)
- **Observability**:
  - Prometheus (metrics)
  - Grafana (dashboards)
  - Loki (logs)
  - Loki (log aggregation)
  - cAdvisor (container metrics)
  - node-exporter (host metrics)
  - postgres-exporter (database metrics)
  - nvidia-gpu-exporter (GPU metrics)
- **UI**: Open WebUI (web interface)

Operational services are optional and can be enabled based on deployment profiles (usr, dev, ops, sys).

For detailed architectural documentation, service contracts, and profiles, see [`architecture/governance/`](../architecture/governance/).

## Quick Start

### 1. Check Environment

```bash
./aixcl utils check-env
```

This validates:
- Docker installation and daemon
- Docker Compose
- NVIDIA GPU support (if available)
- System resources (disk space, memory)

### 2. Start Services

```bash
# First time: specify profile
./aixcl stack start --profile sys

# Subsequent times: uses PROFILE from .env file
./aixcl stack start
```

This will:
- Create `.env` file from `.env.example` if needed
- Save profile to `.env` file (PROFILE=sys) for future use
- Generate pgAdmin configuration
- Pull latest Docker images
- Start all services
- Wait for services to be ready

**Note:** After the first run, you can set `PROFILE=<profile>` in `.env` file to use a default profile. Then `./aixcl stack start` will use that profile automatically.

### 3. Configure the Engine

```bash
# Auto-detect optimal engine based on hardware (vLLM for GPU, llama.cpp for ARM, Ollama for general)
./aixcl engine auto

# Manually assign an inference engine
./aixcl engine set vllm
```

### 4. Add Models

```bash
# Recommended default models (Qwen 2.5 Coder - optimized for coding tasks)
./aixcl models add qwen2.5-coder:0.5b
./aixcl models add qwen2.5-coder:1.5b
./aixcl models add qwen2.5-coder:3b

# Add models directly from Hugging Face (GGUF supported via hf.co/ prefix)
./aixcl models add hf.co/bartowski/Qwen2.5-Coder-0.5B-Instruct-GGUF:Q4_K_M
```

### 5. Check Status

```bash
./aixcl stack status
```

Shows:
- Container status (OK running / DOWN stopped)
- Service health checks (visual indicators only)
- Service logs for failed services
- Runtime core vs operational services separation

## Common Workflows

### Starting Development Session

```bash
# Start everything (uses PROFILE from .env if set, or specify --profile)
./aixcl stack start [--profile sys]

# Check everything is running
./aixcl stack status
```

### Adding New Models

```bash
# List current models
./aixcl models list

# Add example starter models (Qwen 2.5 Coder series)
./aixcl models add qwen2.5-coder:0.5b
./aixcl models add qwen2.5-coder:1.5b
./aixcl models add qwen2.5-coder:3b

# For larger GPUs (16GB+), you can use larger models:
./aixcl models add qwen2.5-coder:7b
./aixcl models add qwen2.5-coder:14b
```

You can add or remove multiple models in one command: `./aixcl models add a b c`, `./aixcl models remove a b`.

**Recommended Models by Size:**

AIXCL supports Qwen 2.5 Coder instruct models across three engines (Ollama, vLLM, llama.cpp).
All sizes are optimized for coding tasks with excellent performance characteristics.

| Model | Size | Use Case | Download |
|-------|------|----------|----------|
| `qwen2.5-coder:0.5b` | ~400MB | Ultra-lightweight, default | `./aixcl models add qwen2.5-coder:0.5b` |
| `qwen2.5-coder:1.5b` | ~1GB | Lightweight, OpenCode recommended | `./aixcl models add qwen2.5-coder:1.5b` |
| `qwen2.5-coder:3b` | ~2GB | Balanced performance | `./aixcl models add qwen2.5-coder:3b` |
| `qwen2.5-coder:7b` | ~4.5GB | Medium, higher quality | `./aixcl models add qwen2.5-coder:7b` |
| `qwen2.5-coder:14b` | ~9GB | Large, best quality | `./aixcl models add qwen2.5-coder:14b` |

See [`docs/operations/model-recommendations.md`](../operations/model-recommendations.md) for complete details.

### Troubleshooting

**Models Not Appearing in Open WebUI (vLLM/llama.cpp)**

When using vLLM or llama.cpp engines with Open WebUI v0.8.12+, models must be manually configured via Direct Connections:

| Step | Action |
|------|--------|
| 1 | Go to Open WebUI → Settings → Connections |
| 2 | Scroll to "Direct Connections" section |
| 3 | Click "Add Connection" |
| 4 | Set URL: `http://127.0.0.1:11434/v1` |
| 5 | Leave API Key empty (for local models) |
| 6 | Enable "Direct Connections" toggle |
| 7 | Save and refresh the page |

**Note:** This is required because Open WebUI v0.8.12 changed how models are discovered. Ollama engine users don't need this step.

```bash
# Check service logs for the engine
./aixcl stack logs engine 50

# Restart the engine
./aixcl restart engine

# Restart a specific service
./aixcl service restart postgres

# Restart entire stack (uses PROFILE from .env if set)
./aixcl stack restart [--profile sys]

# Restart specific services only (no profile needed)
./aixcl stack restart engine

# Clean up and start fresh
./aixcl utils clean
./aixcl stack start [--profile sys]
```


## Service Management

### Individual Service Control

```bash
# Start a service
./aixcl service start grafana

# Stop a service
./aixcl service stop prometheus

# Restart a service
./aixcl service restart engine
```

### Viewing Logs

```bash
# All services (follow mode)
./aixcl stack logs

# Specific service, last 50 lines (default; n in range 1-10000), then follow
./aixcl stack logs engine 50

# Specific service, last 100 lines, follow
./aixcl stack logs postgres 100
```



### Check Service Health

```bash
./aixcl stack status
```

This comprehensive status check shows:
- **Container Status:** Text labels (OK running / DOWN stopped) for each service
- **Service Health:** Health check results displayed with visual indicators only
- **Logs:** Recent log entries for failed services
- **Runtime vs Operational:** Status output distinguishes between runtime core (critical) and operational services (informational)
- **Health Summary:** Counts of healthy services by category

Note: Runtime core services (Inference Engine) health is critical. Operational services health is informational and graceful degradation is acceptable. Status uses text labels (OK/DOWN/WARN) and notes when services are not in the active profile.

## Maintenance

### Exporting for Systemd (Headless)

> **Note**: Podman Quadlet support is experimental. The `export-quadlet` command generates files but has not been fully tested with Podman. See [#864](https://github.com/xencon/aixcl/issues/864) for current status.

For production or headless environments, you can export your AIXCL stack as native Systemd Quadlet files:

```bash
./aixcl stack export-quadlet
```

This generates `.container` and `.network` files in `export/quadlets/`. To install:
1. Copy the files to `/etc/containers/systemd/` (system-wide) or `~/.config/containers/systemd/` (user-specific).
2. Run `systemctl daemon-reload` (or `systemctl --user daemon-reload`).
3. Start your services with `systemctl start aixcl-ollama`, etc.

This provides robust reboot persistence and standard service lifecycle management via `systemctl`.

### Clean Up Resources

```bash
./aixcl utils clean
```

This removes unused Docker resources without stopping running services:
- Dangling images (untagged, not referenced)
- Unused images (not referenced by running containers)
- Stopped containers
- Unused volumes

Note: Running containers and their images are preserved.

### Update Services

Services are updated manually:

```bash
# Pull latest images
cd services
docker-compose pull

# Restart services (uses PROFILE from .env if set)
./aixcl stack restart [--profile sys]
```

## Tips

1. **Always check status first:**
   ```bash
   ./aixcl stack status
   ```

2. **Use logs for debugging:**
   ```bash
   ./aixcl stack logs engine 100
   ```

3. **Check Status regularly:**
   ```bash
   ./aixcl stack status
   ```

4. **Keep models updated:**
   ```bash
   ./aixcl models list
   # Remove old, add new
   ```

5. **Backup database before clean:**
   ```bash
   # pgAdmin or direct pg_dump
   docker-compose exec postgres pg_dump -U webui webui > backup.sql
   ```
