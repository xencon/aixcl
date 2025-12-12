# AIXCL CLI Specification

## Command Structure

AIXCL uses a nested command structure:

```
aixcl <command> <subcommand> [options]
```

## Commands

### Stack Management

**`aixcl stack <subcommand>`**

- `start` - Start all services
- `stop` - Stop all services
- `restart` - Restart the entire stack
- `status` - Show service status (container and health)
- `logs [service] [lines]` - Show logs (all services or specific service, optional line count)
- `clean` - Remove unused Docker resources

**Examples:**
```bash
aixcl stack start
aixcl stack status
aixcl stack logs ollama 100
aixcl stack clean
```

### Service Control

**`aixcl service <action> <service-name>`**

Actions:
- `start` - Start a specific service
- `stop` - Stop a specific service
- `restart` - Restart a specific service

Services:
- `ollama` - LLM inference engine
- `open-webui` - Web interface
- `postgres` - PostgreSQL database
- `pgadmin` - Database administration
- `watchtower` - Container updates
- `prometheus` - Metrics collection
- `grafana` - Metrics visualization
- `cadvisor` - Container metrics
- `node-exporter` - System metrics
- `postgres-exporter` - Database metrics
- `nvidia-gpu-exporter` - GPU metrics (if GPU available)
- `loki` - Log aggregation
- `promtail` - Log collection
- `llm-council` - Multi-model orchestration

**Examples:**
```bash
aixcl service start postgres
aixcl service restart ollama
aixcl service stop grafana
```

### Model Management

**`aixcl models <action> [model-name ...]`**

Actions:
- `add <model> [model ...]` - Add one or more models to Ollama
- `remove <model> [model ...]` - Remove one or more models from Ollama
- `list` - List all installed models

**Examples:**
```bash
aixcl models add phi3:latest
aixcl models add phi3:latest qwen2.5:7b
aixcl models remove phi3:latest
aixcl models list
```

### Council Configuration

**`aixcl council <subcommand>`**

- `configure` - Interactive configuration of council models and chairman
- `status` - Show council configuration and operational status
- `list` - Alias for `status`

**Examples:**
```bash
aixcl council configure
aixcl council status
aixcl council list
```

### Dashboards

**`aixcl dashboard <target>`**

Targets:
- `grafana` - Open Grafana monitoring dashboard
- `openwebui` - Open Open WebUI interface
- `pgadmin` - Open pgAdmin database interface

**Examples:**
```bash
aixcl dashboard grafana
aixcl dashboard openwebui
aixcl dashboard pgadmin
```

### Utilities

**`aixcl utils <subcommand>`**

- `check-env` - Validate environment setup (Docker, dependencies, etc.)
- `bash-completion` - Install bash completion support

**Examples:**
```bash
aixcl utils check-env
aixcl utils bash-completion
```

## Help

**`aixcl help`** or **`aixcl --help`** or **`aixcl -h`**

Displays comprehensive help message with all available commands.

## Exit Codes

- `0` - Success
- `1` - Error (invalid command, service not found, etc.)

## Environment Variables

AIXCL reads configuration from `.env` file in the project root. Key variables:

- `POSTGRES_USER` - PostgreSQL username
- `POSTGRES_PASSWORD` - PostgreSQL password
- `POSTGRES_DATABASE` - PostgreSQL database name
- `COUNCIL_MODELS` - Comma-separated list of council member models
- `CHAIRMAN_MODEL` - Chairman model for final synthesis
- `BACKEND_MODE` - Backend mode (ollama or openrouter)
- `ENABLE_DB_STORAGE` - Enable database persistence (true/false)

## Continue Plugin Integration

AIXCL provides OpenAI-compatible API endpoints for Continue plugin:

- Base URL: `http://localhost:8000/v1`
- Model name: `council`
- API Key: `local` (or any value)

**Continue Configuration:**
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

## Service URLs

- **Ollama:** http://localhost:11434
- **Open WebUI:** http://localhost:8080
- **LLM Council API:** http://localhost:8000
- **Grafana:** http://localhost:3000
- **pgAdmin:** http://localhost:5050
- **Prometheus:** http://localhost:9090
