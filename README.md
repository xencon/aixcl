# AIXCL

A container-based platform for integrating Large Language Models (LLMs) into your development workflow. Includes Ollama, Open WebUI, LLM-Council, and comprehensive monitoring tools.

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/xencon/aixcl.git
cd aixcl
```

### 2. Check Environment
```bash
./aixcl check-env
```
Verifies Docker, dependencies, GPU support, and system resources.

### 3. Install Bash Completion (Optional)
```bash
./aixcl bash-completion
```
Enables tab completion for all commands and services.

### 4. Start the Platform
```bash
./aixcl start
```
Automatically creates `.env` from `.env.example` if needed. Starts all services.

### 5. Manage Models
```bash
# Add models
./aixcl models add starcoder2:latest nomic-embed-text:latest

# List installed models
./aixcl models list

# Remove models
./aixcl models remove starcoder2:latest
```

### 6. Configure LLM Council
```bash
# Interactive configuration
./aixcl council configure

# View current configuration
./aixcl council status
```

## Troubleshooting

### Check Service Status
```bash
./aixcl status
```
Shows running status and health checks for all services.

### View Logs
```bash
# All services
./aixcl logs

# Specific service
./aixcl logs <service-name>
./aixcl logs loki 100  # Last 100 lines
```

### Service Control
```bash
# Start/stop individual services
./aixcl service start <service-name>
./aixcl service stop <service-name>
./aixcl service restart <service-name>

# Restart entire platform
./aixcl restart
```

### Common Issues

**Services not starting:**
- Check Docker: `docker ps -a`
- Verify ports available: `netstat -tuln | grep -E '8000|8080|5432|5050'`
- Check disk space: `df -h`

**Database connection issues:**
- Verify PostgreSQL running: `docker ps | grep postgres`
- Check environment variables: `docker exec llm-council env | grep POSTGRES`
- Test connection: `docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -c "SELECT 1;"`

**GPU not detected:**
- Run `./aixcl check-env` to verify NVIDIA drivers and container toolkit
- Check `nvidia-smi` output
- Verify `docker-compose.gpu.yml` is being used

## Services

### Core LLM Services

| Service | Description | Web Endpoint |
|---------|-------------|--------------|
| **Ollama** | Local LLM inference engine with GPU support | API: `http://localhost:11434` |
| **LLM-Council** | Multi-model orchestration for consensus-based responses | `http://localhost:8000`<br>API: `http://localhost:8000/v1/chat/completions` |
| **Open WebUI** | Web interface for interacting with models | `http://localhost:8080` |

### Data Services

| Service | Description | Web Endpoint |
|---------|-------------|--------------|
| **PostgreSQL** | Database for conversations and settings | Internal: `localhost:5432` |
| **pgAdmin** | Database management interface | `http://localhost:5050` |

### Monitoring Services

| Service | Description | Web Endpoint |
|---------|-------------|--------------|
| **Prometheus** | Metrics collection and storage | `http://localhost:9090` |
| **Grafana** | Visualization and analytics dashboards | `http://localhost:3000`<br>Default: `admin/admin` |
| **cAdvisor** | Container metrics exporter | `http://localhost:8081/metrics` |
| **Node Exporter** | System-level metrics exporter | `http://localhost:9100/metrics` |
| **Postgres Exporter** | PostgreSQL metrics exporter | `http://localhost:9187/metrics` |
| **NVIDIA GPU Exporter** | GPU metrics exporter (NVIDIA only) | `http://localhost:9400/metrics` |

### Logging Services

| Service | Description | Web Endpoint |
|---------|-------------|--------------|
| **Loki** | Log aggregation system | `http://localhost:3100` |
| **Promtail** | Log shipper for Loki | Internal only |

### Utility Services

| Service | Description | Web Endpoint |
|---------|-------------|--------------|
| **Watchtower** | Automatic container updates | Internal only |

## CLI Commands

```
Stack Management:
  start                Start all services
  stop                 Stop all services
  restart              Restart all services
  status               Show service status
  logs [service] [n]   View logs (all or specific service, optional line count)
  clean                Remove unused Docker resources

Service Control:
  service <action> <name>  Control individual service (start|stop|restart)
                           Services: ollama open-webui postgres pgadmin watchtower
                           llm-council prometheus grafana cadvisor node-exporter
                           postgres-exporter nvidia-gpu-exporter loki promtail

Models & Configuration:
  models <action> [name]   Manage LLM models (add|remove|list)
  council <action>         Configure LLM Council (configure|status)

Utilities:
  dashboard [name]         Open dashboard (grafana|openwebui|pgadmin)
  check-env                Verify environment setup
  bash-completion          Install bash completion
  help                     Show this help
```

## System Requirements

- **Minimum**: 16 GB RAM, 128 GB free disk space
- **Recommended**: 32 GB RAM, 256 GB free disk space
- Docker and Docker Compose required
- NVIDIA GPU optional (automatically detected if available)

## License

Apache License 2.0 - see [LICENSE](./LICENSE) file for details.
