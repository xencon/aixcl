# AIXCL Usage Guide

## Quick Start

### 1. Check Environment

```bash
./aixcl.sh utils check-env
```

This validates:
- Docker installation and daemon
- Docker Compose
- NVIDIA GPU support (if available)
- System resources (disk space, memory)

### 2. Start Services

```bash
./aixcl.sh stack start
```

This will:
- Create `.env` file from `.env.example` if needed
- Generate pgAdmin configuration
- Pull latest Docker images
- Start all services
- Wait for services to be ready

### 3. Add Models

```bash
./aixcl.sh models add phi3:latest qwen2.5:7b
```

### 4. Configure Council

```bash
./aixcl.sh council configure
```

Interactive setup to select:
- Chairman model (synthesizes final response)
- Council members (provide initial opinions)

### 5. Check Status

```bash
./aixcl.sh stack status
```

Shows:
- Container status (running/stopped)
- Service health (API responses)
- Service logs for failed services

## Common Workflows

### Starting Development Session

```bash
# Start everything
./aixcl.sh stack start

# Check everything is running
./aixcl.sh stack status

# Open dashboards
./aixcl.sh dashboard openwebui
./aixcl.sh dashboard grafana
```

### Adding New Models

```bash
# List current models
./aixcl.sh models list

# Add new model
./aixcl.sh models add codellama:7b

# Update council configuration
./aixcl.sh council configure
```

### Troubleshooting

```bash
# Check service logs
./aixcl.sh stack logs ollama 50
./aixcl.sh stack logs llm-council 100

# Restart a specific service
./aixcl.sh service restart postgres

# Restart entire stack
./aixcl.sh stack restart

# Clean up and start fresh
./aixcl.sh stack clean
./aixcl.sh stack start
```

### Continue Plugin Setup

1. **Start services:**
   ```bash
   ./aixcl.sh stack start
   ```

2. **Verify LLM Council is running:**
   ```bash
   ./aixcl.sh stack status
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
./aixcl.sh service start grafana

# Stop a service
./aixcl.sh service stop prometheus

# Restart a service
./aixcl.sh service restart ollama
```

### Viewing Logs

```bash
# All services (follow mode)
./aixcl.sh stack logs

# Specific service, last 50 lines
./aixcl.sh stack logs ollama 50

# Specific service, last 100 lines, follow
./aixcl.sh stack logs postgres 100
```

## Council Management

### Interactive Configuration

```bash
./aixcl.sh council configure
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
./aixcl.sh council status
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
./aixcl.sh dashboard grafana

# Open WebUI (chat interface)
./aixcl.sh dashboard openwebui

# pgAdmin (database administration)
./aixcl.sh dashboard pgadmin
```

### Check Service Health

```bash
./aixcl.sh stack status
```

This comprehensive status check shows:
- **Container Status:** Which containers are running
- **Service Health:** HTTP endpoints responding correctly
- **Logs:** Recent log entries for failed services

## Maintenance

### Clean Up Resources

```bash
./aixcl.sh stack clean
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

# Restart services
./aixcl.sh stack restart
```

## Tips

1. **Always check status first:**
   ```bash
   ./aixcl.sh stack status
   ```

2. **Use logs for debugging:**
   ```bash
   ./aixcl.sh stack logs <service> 100
   ```

3. **Test Continue integration:**
   ```bash
   bash tests/test_continue_integration.sh
   ```

4. **Keep models updated:**
   ```bash
   ./aixcl.sh models list
   # Remove old, add new
   ```

5. **Backup database before clean:**
   ```bash
   # pgAdmin or direct pg_dump
   docker exec postgres pg_dump -U webui webui > backup.sql
   ```
