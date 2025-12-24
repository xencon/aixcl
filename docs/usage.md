# AIXCL Usage Guide

## Architecture Overview

AIXCL follows a governance model that separates **Runtime Core** from **Operational Services**:

### Runtime Core (Strict - Always Enabled)
These services define what AIXCL is and are always present:
- **Ollama**: LLM inference engine
- **LLM-Council**: Multi-model orchestration and coordination
- **Continue**: VS Code plugin for AI-powered code assistance

Runtime core services are non-negotiable and must be running for AIXCL to function.

### Operational Services (Guided - Profile-Dependent)
These services support, observe, or operate the runtime:
- **Persistence**: PostgreSQL (database), pgAdmin (database admin)
- **Observability**: Prometheus (metrics), Grafana (dashboards), Loki (logs), Promtail (log shipping), cAdvisor (container metrics), node-exporter (host metrics), postgres-exporter (database metrics), nvidia-gpu-exporter (GPU metrics)
- **UI**: Open WebUI (web interface)
- **Automation**: Watchtower (automatic container updates)

Operational services are optional and can be enabled based on deployment profiles (usr, dev, ops, sys).

For detailed architectural documentation, service contracts, and profiles, see [`aixcl_governance/`](../aixcl_governance/).

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

### 3. Add Models

```bash
./aixcl models add phi3:latest qwen2.5:7b
```

### 4. Configure Council

```bash
./aixcl council configure
```

Interactive setup to select:
- Chairman model (synthesizes final response)
- Council members (provide initial opinions)

### 5. Check Status

```bash
./aixcl stack status
```

Shows:
- Container status (✅ running / ❌ stopped)
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

# Open dashboards
./aixcl dashboard openwebui
./aixcl dashboard grafana
```

### Adding New Models

```bash
# List current models
./aixcl models list

# Add new model
./aixcl models add codellama:7b

# Update council configuration
./aixcl council configure
```

### Troubleshooting

```bash
# Check service logs
./aixcl stack logs ollama 50
./aixcl stack logs llm-council 100

# Restart a specific service
./aixcl service restart postgres

# Restart entire stack (uses PROFILE from .env if set)
./aixcl stack restart [--profile sys]

# Clean up and start fresh
./aixcl stack clean
./aixcl stack start [--profile sys]
```

### Continue Plugin Setup

1. **Start services:**
   ```bash
   # First time: specify profile
   ./aixcl stack start --profile sys
   # Subsequent times: uses PROFILE from .env
   ./aixcl stack start
   ```

2. **Verify LLM Council is running:**
   ```bash
   ./aixcl stack status
   ```

3. **Configure Continue plugin** (in `.continue/config.json`):
   ```json
   {
     "models": [
       {
         "model": "council",
         "title": "LLM-Council (Multi-Model)",
         "provider": "openai",
         "apiBase": "http://localhost:8000/v1",
         "apiKey": "local"
       }
     ]
   }
   ```

4. **Test integration:**
   ```bash
   bash tests/test_continue_integration.sh
   ```

## Service Management

### Individual Service Control

```bash
# Start a service
./aixcl service start grafana

# Stop a service
./aixcl service stop prometheus

# Restart a service
./aixcl service restart ollama
```

### Viewing Logs

```bash
# All services (follow mode)
./aixcl stack logs

# Specific service, last 50 lines
./aixcl stack logs ollama 50

# Specific service, last 100 lines, follow
./aixcl stack logs postgres 100
```

## Council Management

### Interactive Configuration

```bash
./aixcl council configure
```

This interactive wizard:
1. Lists available models from Ollama
2. Prompts for chairman selection
3. Prompts for council members (1-4 additional models)
4. Shows configuration summary
5. Updates `.env` file
6. Optionally restarts LLM-Council service

### Check Council Status

```bash
./aixcl council status
```

Shows:
- Current configuration (chairman, members)
- Operational status of each model
- Service status (LLM-Council, Ollama)
- Summary statistics

## Monitoring

### View Dashboards

```bash
# Grafana (metrics and monitoring)
./aixcl dashboard grafana

# Open WebUI (chat interface)
./aixcl dashboard openwebui

# pgAdmin (database administration)
./aixcl dashboard pgadmin
```

### Check Service Health

```bash
./aixcl stack status
```

This comprehensive status check shows:
- **Container Status:** Visual indicators (✅ running / ❌ stopped) for each service
- **Service Health:** Health check results displayed with visual indicators only
- **Logs:** Recent log entries for failed services
- **Runtime vs Operational:** Status output distinguishes between runtime core (critical) and operational services (informational)
- **Health Summary:** Counts of healthy services by category

Note: Runtime core services (ollama, llm-council) health is critical. Operational services health is informational and graceful degradation is acceptable. Status uses visual indicators (✅/❌) without text labels to avoid confusion.

## Maintenance

### Clean Up Resources

```bash
./aixcl stack clean
```

This removes:
- Stopped containers
- Unused images
- Unused volumes
- PostgreSQL containers and volumes (careful!)

### Update Services

Services are automatically updated by Watchtower, or manually:

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
   ./aixcl stack logs <service> 100
   ```

3. **Test Continue integration:**
   ```bash
   bash tests/test_continue_integration.sh
   ```

4. **Keep models updated:**
   ```bash
   ./aixcl models list
   # Remove old, add new
   ```

5. **Backup database before clean:**
   ```bash
   # pgAdmin or direct pg_dump
   docker exec postgres pg_dump -U webui webui > backup.sql
   ```
