[![Open in GitHub Codespaces](https://img.shields.io/badge/Open%20in%20GitHub%20Codespaces-blue?logo=github)](https://codespaces.new/xencon/aixcl)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)](#)
# AIXCL

## Overview
AIXCL is a simple container based platform that helps you integrate Large Language Models (LLMs) into your development workflow. It ships with Ollama, Open WebUI and LMM Coumncil as well as other auxiliary services. It offers integration with common IDE's by using the [continue](https://continue.dev) plugin.

### What does it do?
- Run LLMs locally on your machine (with automatic GPU detection)
- Provide a friendly web ui to interact with models and configure the server
- Provide a powerful cli to manage models and the llm council
- Help you code, generate documentation, and review your work
- Automatically configure database connections and services
- Enhanced security with input validation and secure file operations

## System Requirements
- Minimum 16 GB RAM
- Minimum 128 GB free disk space

## Quick Start

```bash
# Clone the repository
git clone https://github.com/xencon/aixcl.git
cd aixcl

# Check system requirements and dependencies
./aixcl check-env

# Install CLI completion for bash shell
./aixcl install-completion

# Start the services (automatically creates .env from .env.example if needed)
./aixcl start

# Add models you want to use
./aixcl models add starcoder2:latest nomic-embed-text:latest

# List installed models
./aixcl models list

# Configure LLM Council (interactive setup)
./aixcl council configure

# View current council configuration
./aixcl council list

# Access the LLM engine web interface
# Open http://localhost:8080 in your browser

# Access the databse admin web interface
# Open http://localhost:5050 in your browser
```

## CLI Commands

```
Usage: ./aixcl {start|stop|restart|logs|clean|status|models|dashboard|council|help|install-completion|check-env}
Commands:
  start                Start the Docker Compose deployment
  stop                 Stop the Docker Compose deployment
  restart              Restart all services
  logs                 Show logs for all containers
  clean                Remove unused Docker containers, images, and volumes
  status               Check services status
  models [...]         Manage Ollama models
  dashboard [...]      Open a web dashboard (grafana, openwebui, pgadmin)
  council [...]        Configure or list LLM Council models
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

### 🤝 Multi-Model LLM Orchestration (LLM-Council)
AIXCL includes [LLM-Council](https://github.com/karpathy/llm-council), a multi-model orchestration framework that provides consensus-based responses:
- **3-Stage Process**: First opinions from multiple models → Review stage → Final consensus response
- **Chairman Model**: Uses `<model>` to review and synthesize responses
- **Base Models**: Configured with `<model>` and `<model>`...
- **IDE Integration**: Works seamlessly with the Continue plugin for enhanced code assistance
- **Streaming Support**: Real-time streaming responses with OpenAI-compatible Server-Sent Events (SSE) format
- **Markdown Formatting**: Automatic formatting of bullet points, numbered lists, and markdown structure for optimal rendering
- **Persistent Context**: Maintains conversation history across sessions using PostgreSQL
- **Database Storage**: Automatic conversation persistence with PostgreSQL integration
- **OpenAI-Compatible API**: Available at `http://localhost:8000/v1/chat/completions` for programmatic access

The LLM-Council service automatically starts with the AIXCL stack and integrates with Ollama for local model inference.

#### Streaming Responses
LLM-Council supports streaming responses for real-time display in clients like the Continue plugin:
- Character-based chunking (50 characters) for smooth real-time updates
- Proper OpenAI-compatible Server-Sent Events (SSE) format
- Automatic streaming when requested, or force streaming via configuration
- Configurable via `FORCE_STREAMING` environment variable

#### Markdown Formatting
Responses are automatically formatted for optimal rendering in markdown viewers:
- Normalizes bullet points (`*`, `-`, `•`) to standard markdown format
- Normalizes numbered lists (`1.` and `1)`) formats
- Ensures proper spacing around lists and headers
- Preserves code blocks and indented content
- Configurable via `ENABLE_MARKDOWN_FORMATTING` environment variable (default: `true`)

## Services

| Service | Description | URL |
|---------|-------------|-----|
| **Ollama** | Runs LLMs locally (with GPU support when available) | [ollama.com](https://ollama.com) |
| **LLM-Council** | Multi-model LLM orchestration framework for consensus-based responses | [http://localhost:8000](http://localhost:8000) (API: `/v1/chat/completions`) |
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
./aixcl models add starcoder2:latest

# Add multiple models at once
./aixcl models add starcoder2:latest nomic-embed-text:latest
```

### Removing Models
```bash
# Remove a single model
./aixcl models remove starcoder2:latest

# Remove multiple models at once
./aixcl models remove starcoder2:latest nomic-embed-text:latest
```

### Listing Models
```bash
./aixcl models list
```

## LLM Council Configuration

The LLM-Council service uses a multi-model consensus approach where multiple models collaborate to provide better responses. You can configure which models participate in the council and which model acts as the chairman.

### Listing Current Council Configuration

View the currently configured council models:

```bash
# List current council configuration (default action)
./aixcl council

# Or explicitly
./aixcl council list
```

This displays:
- **Chairman Model**: The model that synthesizes final responses
- **Council Members**: List of models that participate in the consensus process
- **Total Models**: Count of all models in the council
- **Service Status**: Whether the LLM-Council service is running

### Configuring the Council

Configure which models participate in the council and select the chairman:

```bash
./aixcl council configure
```

This interactive command:
1. Shows all available models from Ollama
2. Lets you select the chairman model
3. Lets you select council members (minimum 1 member + chairman, maximum 5 total models)
4. Updates the `.env` file with your selections
5. Optionally restarts the LLM-Council service to apply changes

The configuration is stored in your `.env` file:
- `COUNCIL_MODELS`: Comma-separated list of council member models
- `CHAIRMAN_MODEL`: The chairman model that synthesizes responses

**Note**: After configuring the council, restart the services to apply changes:
```bash
./aixcl restart
```

## Monitoring & Metrics

AIXCL includes comprehensive monitoring capabilities using Prometheus and Grafana to help you understand system performance, resource utilization, and LLM query patterns.

### Quick Access

```bash
# Open Open WebUI dashboard
./aixcl dashboard openwebui

# Open Grafana dashboards
./aixcl dashboard grafana

# Open pgAdmin dashboard
./aixcl dashboard pgadmin
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

AIXCL includes four fully populated, pre-configured Grafana dashboards with live data:

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

4. **GPU Metrics** (`/d/aixcl-gpu`) - **10 panels** (NVIDIA GPUs)
   - GPU utilization percentage
   - GPU memory usage and allocation
   - GPU temperature monitoring
   - GPU power consumption
   - GPU memory used/free tracking
   - GPU clock speeds (SM and memory)
   - Memory copy utilization
   - PCIe throughput (TX/RX)
   - GPU information and specifications

**All dashboards refresh automatically** (GPU dashboard: 10s, others: 30s) and display the last hour of data by default (configurable).

**Note**: The GPU Metrics dashboard requires NVIDIA GPUs and drivers. On systems without NVIDIA GPUs, the dashboard will show no data but other monitoring features will continue to work normally.

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

For detailed information about the monitoring setup, see [MONITORING.md](./MONITORING.md).

## Bash Completion

AIXCL includes bash completion support to make using the CLI faster and easier:

```bash
# Install bash completion
./aixcl install-completion

# Now you can use tab completion
./aixcl [TAB]          # Shows all commands
./aixcl models add [TAB]   # Shows available models
./aixcl models list        # Lists installed models
./aixcl council [TAB]      # Shows council subcommands (configure, list)
./aixcl logs [TAB]         # Shows available service logging
```

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

**Optional LLM-Council variables:**
```
# Force streaming mode (always return streaming responses)
FORCE_STREAMING=false

# Enable markdown formatting (format bullet points, lists, etc.)
ENABLE_MARKDOWN_FORMATTING=true

# Enable PostgreSQL storage for Continue conversations
ENABLE_DB_STORAGE=true

# PostgreSQL connection (optional, defaults to localhost:5432)
# These are already set for Open WebUI, but can be overridden for LLM-Council
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

# Council models (comma-separated)
COUNCIL_MODELS=qwen2.5-coder:7b,granite-code:3b

# Chairman model (synthesizes final response)
CHAIRMAN_MODEL=gemma3:4b
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

## Database Persistence

AIXCL includes automatic PostgreSQL-based persistence for LLM-Council conversations, ensuring your conversation history is maintained across sessions and service restarts.

### Features

- **Automatic Schema Creation**: Database tables are created automatically on first startup
- **Continue Plugin Integration**: Conversations from the Continue IDE plugin are automatically stored
- **Conversation Tracking**: Each conversation is uniquely identified and can be retrieved by ID
- **Message History**: Full conversation history with stage data (Stage 1, 2, 3 responses) is preserved
- **Source Tracking**: Conversations are tagged by source (`openwebui` or `continue`) for easy filtering

### Configuration

Database persistence is enabled by default. To disable it, set in your `.env` file:
```
ENABLE_DB_STORAGE=false
```

The system automatically uses the same PostgreSQL database configured for Open WebUI, so no additional setup is required.

### Database Utilities

Utility scripts for database management are available in `scripts/db/`:
- Migration scripts for schema updates
- Query scripts for inspecting stored conversations
- See `scripts/db/README.md` for details

### Testing

Test scripts are available in `llm-council/scripts/test/`:
- `test_db_connection.py` - Comprehensive database connection and operation tests
- `test_api.sh` - API endpoint integration tests
- See `llm-council/scripts/test/README.md` for usage instructions

## Continue Plugin Integration

AIXCL is designed to work seamlessly with the [Continue](https://continue.dev) IDE plugin for AI-powered code assistance. The LLM-Council service provides an OpenAI-compatible API that Continue can use directly.

### Configuration

1. **Install Continue Plugin** in your IDE (VS Code, JetBrains, etc.)

2. **Configure Continue** to use LLM-Council by adding this to your Continue config (`.continue/config.json`):

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

3. **Start AIXCL** services:
   ```bash
   ./aixcl start
   ```

4. **Select the Council model** in Continue's model selector

### Features

- **Multi-Model Consensus**: Get responses from multiple models reviewed and synthesized by a chairman model
- **Streaming Support**: Real-time streaming responses for immediate feedback
- **Markdown Formatting**: Automatically formatted responses with proper bullet points and numbered lists
- **File Context**: Continue automatically includes file context in requests, which LLM-Council processes correctly
- **Persistent Conversation History**: All conversations are automatically saved to PostgreSQL and persist across sessions
- **Conversation Continuity**: Continue conversations are tracked and can be resumed using conversation IDs

### Configuration Options

You can customize LLM-Council behavior via environment variables in your `.env` file:

- `FORCE_STREAMING=true` - Always return streaming responses (useful if Continue works better with streaming)
- `ENABLE_MARKDOWN_FORMATTING=false` - Disable automatic markdown formatting (if you prefer raw responses)
- `COUNCIL_MODELS=model1,model2` - Configure which models participate in the council (comma-separated)
- `CHAIRMAN_MODEL=model` - Set the model that synthesizes final responses

**Easy Configuration**: Use the interactive configuration command instead of manually editing `.env`:
```bash
./aixcl council configure  # Interactive setup
./aixcl council list       # Verify your configuration
```

See the example configuration in `.continue/config.json.example` for a complete setup.

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
