# AIXCL

## Overview
AIXCL is a simple Docker-based platform that helps you integrate Large Language Models (LLMs) into your development workflow. It sets up Ollama, Open WebUI, and supporting services with minimal effort. These can be directly accessed via your IDE using the [continue](https://continue.dev) plugin.

### What does it do?
- Run LLMs locally on your machine (with automatic GPU detection)
- Provide a friendly web interface to interact with models
- Help you code, generate documentation, and review your work
- Simplify model management with easy-to-use commands
- Automatically configure database connections and services
- Enhanced security with input validation and secure file operations

## Quick Start

```bash
# Clone the repository
git clone https://github.com/xencon/aixcl.git
cd aixcl

# Start the services (automatically creates .env from .env.example if needed)
./aixcl start

# Add models you want to use
./aixcl add starcoder2:latest nomic-embed-text:latest

# Access the LLM engine web interface
# Open http://localhost:8080 in your browser

# Access the databse admin web interface
# Open http://localhost:5050 in your browser
```

## CLI Commands

```
Usage: ./aixcl {start|stop|restart|logs|clean|stats|status|add|remove|list|metrics|dashboard|help|install-completion|check-env}
Commands:
  start                Start the Docker Compose deployment
  stop                 Stop the Docker Compose deployment
  restart              Restart all services
  logs                 Show logs for all containers
  clean                Remove unused Docker containers, images, and volumes
  stats                Show resource usage statistics
  status               Check services status
  add <model-name>     Add one or more Ollama models
  remove <model-name>  Remove one or more Ollama models
  list                 List all installed models
  metrics              Open Prometheus metrics dashboard
  dashboard            Open Grafana monitoring dashboard
  help                 Show this help menu
  install-completion   Install bash completion for aixcl
  check-env            Check environment dependencies
```

## Features

### 🚀 Automatic GPU Detection
AIXCL automatically detects NVIDIA GPUs and configures Ollama to use them:
- Seamlessly switches between CPU and GPU modes
- No manual configuration required
- Checks for NVIDIA drivers and container toolkit
- Uses `docker-compose.gpu.yml` override when GPU is available

### 🔐 Enhanced Security
Recent security improvements include:
- Command injection prevention with proper input validation
- Secure environment variable handling
- Path sanitization to prevent directory traversal
- Safe file operations with atomic writes and backups
- Restrictive file permissions (600) for sensitive configuration files

### 🔧 Automatic Configuration
- **Auto-creates `.env` file** from `.env.example` on first run
- **pgAdmin server connection** automatically configured with database credentials
- Secure credential handling with automatic cleanup on service stop

## Services

| Service | Description | URL |
|---------|-------------|-----|
| **Ollama** | Runs LLMs locally (with GPU support when available) | [ollama.com](https://ollama.com) |
| **Open WebUI** | Web interface for interacting with models | [http://localhost:8080](http://localhost:8080) |
| **PostgreSQL** | Database for storing conversations and settings | - |
| **pgAdmin** | Database management tool (auto-configured) | [http://localhost:5050](http://localhost:5050) |
| **Prometheus** | Metrics collection and monitoring | [http://localhost:9090](http://localhost:9090) |
| **Grafana** | Visualization and analytics dashboards | [http://localhost:3000](http://localhost:3000) |
| **cAdvisor** | Container metrics exporter | [http://localhost:8081](http://localhost:8081) |
| **Node Exporter** | System-level metrics exporter | - |
| **Postgres Exporter** | PostgreSQL metrics exporter | - |
| **Watchtower** | Keeps containers up-to-date | - |

## Model Management

### Adding Models
```bash
# Add a single model
./aixcl add starcoder2:latest

# Add multiple models at once
./aixcl add starcoder2:latest nomic-embed-text:latest
```

### Removing Models
```bash
# Remove a single model
./aixcl remove starcoder2:latest

# Remove multiple models at once
./aixcl remove starcoder2:latest nomic-embed-text:latest
```

### Listing Models
```bash
./aixcl list
```

## Monitoring & Metrics

AIXCL includes comprehensive monitoring capabilities using Prometheus and Grafana to help you understand system performance, resource utilization, and LLM query patterns.

### Quick Access

```bash
# Open Prometheus metrics interface
./aixcl metrics

# Open Grafana dashboards
./aixcl dashboard
```

### What's Monitored

AIXCL provides comprehensive monitoring with **33 dashboard panels** across three dashboards, tracking system, container, and database metrics in real-time.

#### System Metrics (via Node Exporter)
- **CPU Usage**: Track overall CPU utilization and per-core usage
- **Memory**: Monitor RAM usage, available memory, and swap
- **Disk I/O**: View disk usage, read/write rates, and IOPS
- **Network**: Track network traffic, bandwidth usage, errors, and drops
- **System Load**: Monitor 1m, 5m, and 15m load averages
- **System Uptime**: Track system availability

#### Container Metrics (via cAdvisor)
- **Resource Usage**: CPU and memory consumption per container
- **Memory Limits**: Track usage as percentage of configured limits
- **Network I/O**: Per-container network traffic
- **Disk I/O**: Per-container disk read/write rates and IOPS
- **Container Health**: Running status, uptime, and restart counts
- **Process Count**: Monitor number of processes per container
- Monitor all AIXCL services: Ollama, Open WebUI, PostgreSQL, pgAdmin, Prometheus, Grafana

#### Database Metrics (via Postgres Exporter)
- **Query Performance**: Track query execution times and operation rates
- **Connection Pool**: Monitor active connections and connection limits
- **Cache Hit Ratio**: Measure database cache efficiency
- **Transaction Rates**: View commits, rollbacks, and transaction throughput
- **Database Size**: Track database growth over time
- **Block I/O**: Monitor disk vs buffer reads and I/O timing
- **Conflicts & Deadlocks**: Track database conflicts and deadlock rates
- **Temporary Files**: Monitor temp file usage and size
- **Row Statistics**: Track rows returned vs fetched

#### LLM Performance
While Ollama doesn't natively expose Prometheus metrics, you can monitor:
- **Container Resource Usage**: CPU/memory usage during model inference
- **Database Query Patterns**: Open WebUI conversation storage patterns
- **Response Times**: Via PostgreSQL query duration logs

### Pre-built Dashboards

AIXCL includes three fully populated, pre-configured Grafana dashboards with live data:

1. **System Overview** (`/d/aixcl-system`) - **9 panels**
   - CPU usage and system load average (1m, 5m, 15m)
   - Memory usage and availability
   - Disk usage, I/O rates, and IOPS
   - Network I/O, errors, and packet drops
   - System uptime tracking

2. **Docker Containers** (`/d/aixcl-docker`) - **10 panels**
   - Per-container CPU and memory usage
   - Memory usage as percentage of limits
   - Container disk I/O rates and IOPS
   - Container network traffic
   - Container status, uptime, and restart counts
   - Process count per container

3. **PostgreSQL Performance** (`/d/aixcl-postgres`) - **14 panels**
   - Active connections and max connection limits
   - Database size and transaction rates
   - Query operations (inserts, updates, deletes)
   - Cache hit ratio and block I/O statistics
   - Transaction activity (commits, rollbacks)
   - Database conflicts and deadlocks
   - Rows returned vs fetched
   - Block I/O timing
   - Temporary file usage

**All dashboards refresh every 30 seconds** and display the last hour of data by default (configurable).

### Accessing Monitoring Tools

| Tool | URL | Default Credentials |
|------|-----|---------------------|
| **Grafana** | [http://localhost:3000](http://localhost:3000) | admin / admin |
| **Prometheus** | [http://localhost:9090](http://localhost:9090) | No authentication |
| **cAdvisor** | [http://localhost:8081](http://localhost:8081) | No authentication |

**Note**: Change Grafana default password on first login for security.

### Configuration

**Ready to Use**: All monitoring is pre-configured with Prometheus datasource connected and dashboards populated with live data.

Monitoring configuration files are located in:
- `prometheus/prometheus.yml` - Prometheus scrape configuration (15s intervals)
- `grafana/provisioning/datasources/` - Datasource configuration
- `grafana/provisioning/dashboards/` - Pre-built dashboard definitions

You can customize these files to:
- Adjust scrape intervals and retention
- Add custom metrics and exporters
- Modify dashboard layouts and queries
- Configure alerting rules and notifications

For detailed information about the monitoring setup, see [DATASOURCE-CONNECTION-SUMMARY.md](./DATASOURCE-CONNECTION-SUMMARY.md).

## Bash Completion

AIXCL includes bash completion support to make using the CLI faster and easier:

```bash
# Install bash completion
./aixcl install-completion

# Now you can use tab completion
./aixcl [TAB]          # Shows all commands
./aixcl add [TAB]      # Shows available models
./aixcl logs [TAB]     # Shows available service logging
```

For more details, see [BASH_COMPLETION.md](./BASH_COMPLETION.md).

## Environment Configuration

The `.env` file is **automatically created** from `.env.example` when you run `./aixcl start` for the first time. You can then edit it with your preferred settings.

**Required variables:**
```
# Database
POSTGRES_USER=your_postgres_user
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DATABASE=your_postgres_database

# pgAdmin
PGADMIN_EMAIL=your_pgadmin_email
PGADMIN_PASSWORD=your_pgadmin_password

# Open WebUI
OPENWEBUI_EMAIL=your_openwebui_email
OPENWEBUI_PASSWORD=your_openwebui_password

# Grafana (Monitoring)
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your_grafana_password
```

### Environment File Options

- **`.env`** - Main configuration file (automatically created from `.env.example`)
- **`.env.example`** - Template configuration file (used to create `.env`)
- **`.env.local`** - Local overrides (optional, ignored by git)
- **`docker-compose.override.yml`** - Local Docker Compose overrides (optional, ignored by git)

### Automatic pgAdmin Configuration

When you start AIXCL, it automatically:
1. Generates `pgadmin-servers.json` with your database credentials from `.env`
2. Sets secure file permissions (600) to protect sensitive data
3. Configures pgAdmin with a pre-connected server named "AIXCL"
4. Cleans up the configuration file when services stop for security

**Manual Setup (if needed):**
If you prefer to create the `.env` file manually, you can copy it from the example:
```bash
cp .env.example .env
# Edit .env with your preferred settings
```

The `.env.local` file can be used to override settings from `.env` without modifying the main configuration file. This is useful for local development or when you want to keep sensitive data separate from the main configuration.

## GPU Support

AIXCL automatically detects and configures NVIDIA GPU support:

### Prerequisites for GPU Usage
- NVIDIA GPU with compatible drivers
- NVIDIA Container Toolkit installed
- Docker configured for GPU support

### Automatic Detection
When you run `./aixcl start`, the system:
1. Checks for NVIDIA GPU availability using `nvidia-smi`
2. Verifies Docker GPU support
3. Automatically adds `docker-compose.gpu.yml` if GPU is detected
4. Runs Ollama with GPU acceleration enabled

### Manual GPU Check
```bash
# Check environment dependencies including GPU support
./aixcl check-env
```

The `check-env` command will show:
- ✅ NVIDIA drivers status
- ✅ NVIDIA Container Toolkit status
- ⚠️ Warnings if GPU support is optional but not available

### GPU Architecture
- `docker-compose.yml` - Base configuration (CPU mode)
- `docker-compose.gpu.yml` - GPU override (automatically applied when GPU detected)
- Clean separation ensures CPU-only systems work seamlessly

## Contributing

We welcome contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License
This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

## Have fun!
