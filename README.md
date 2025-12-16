# AIXCL

AIXCL is a container-based platform that helps you integrate Large Language Models (LLMs) into your software development workflow. It ships with Ollama, Open WebUI, and LLM Council, along with other auxiliary services. It offers integration with common IDEs using the [Continue](https://continue.dev) plugin.

## What is AIXCL?

AIXCL provides a complete local LLM development environment:
- Run LLMs locally on your machine (with automatic GPU detection)
- Web UI to interact with models and configure the server
- CLI for services control, managing models and the LLM council
- IDE integration via the Continue plugin for AI-powered code assistance
- Database integration for saving dialogues and future training context

## Architecture

AIXCL follows a strict governance model that separates **Runtime Core** from **Operational Services**:

### Runtime Core (Strict - Always Enabled)
The core runtime defines what AIXCL is and is always present:
- **Ollama**: LLM inference engine
- **LLM-Council**: Multi-model orchestration and coordination
- **Continue**: VS Code plugin for AI-powered code assistance

These components are non-negotiable and must be present in every deployment.

### Operational Services (Guided - Profile-Dependent)
Operational services support, observe, or operate the runtime:
- **Persistence**: PostgreSQL, pgAdmin
- **Observability**: Prometheus, Grafana, Loki, Promtail, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
- **UI**: Open WebUI
- **Automation**: Watchtower

Operational services are optional and can be enabled based on deployment profiles (core, dev, ops, full).

For detailed architectural documentation, see [`aixcl_governance/`](./aixcl_governance/). 

## System Requirements

- Minimum 16 GB RAM
- Minimum 128 GB free disk space

## Getting Started

```bash
# Clone the repository
git clone https://github.com/xencon/aixcl.git
cd aixcl

# Check system requirements and dependencies
./aixcl utils check-env

# Install CLI completion for bash shell
./aixcl utils bash-completion

# Start the services (automatically creates .env from .env.example if needed)
./aixcl stack start

# Add models you want to use
./aixcl models add <model:latest>

# Configure LLM Council (interactive setup)
./aixcl council configure

# Access the web interface
# Open http://localhost:8080 in your browser
```

## Platform Management

### Stack Control

```bash
# Start all services
./aixcl stack start

# Stop all services
./aixcl stack stop

# Restart all services
./aixcl stack restart

# Check service status
./aixcl stack status

# View logs (all services or specific service)
./aixcl stack logs
./aixcl stack logs ollama

# Clean up unused Docker resources
./aixcl stack clean
```

### Service Control

```bash
# Control individual services (start|stop|restart)
./aixcl service start postgres
./aixcl service restart ollama
./aixcl service stop grafana
```

### Model Management

```bash
# Add models
./aixcl models add <model:latest>

# Remove models
./aixcl models remove <model:latest>

# List installed models
./aixcl models list
```

### LLM Council

```bash
# Configure council models and chairman (interactive)
./aixcl council configure

# View council configuration and status
./aixcl council status
```

### Dashboards

```bash
# Open dashboards in your browser
./aixcl dashboard openwebui    # Web UI (http://localhost:8080)
./aixcl dashboard grafana      # Monitoring (http://localhost:3000)
./aixcl dashboard pgadmin      # Database admin (http://localhost:5050)
```

### Testing

```bash
# Run comprehensive end-to-end tests
bash tests/end-to-end-tests.sh

# Test Open WebUI service
bash tests/test_webui.sh
```

## Governance

AIXCL maintains strict architectural invariants to preserve platform integrity. The governance model defines:

- **Runtime Core**: Fixed, non-negotiable components that define the product
- **Operational Services**: Optional services that support the runtime
- **Service Contracts**: Dependency rules and boundaries for each service
- **Profiles**: Declarative compositions of operational services

See [`aixcl_governance/`](./aixcl_governance/) for complete architectural documentation, service contracts, and AI assistant guidance.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.
