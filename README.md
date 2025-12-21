# AIXCL

**Transform your development workflow with local LLM integration.** AIXCL is a container-based platform that seamlessly integrates Large Language Models (LLMs) into your software development process. Get started in minutes with automatic GPU detection, intuitive web interfaces, and powerful CLI tools.

## What is AIXCL?

AIXCL delivers a complete local LLM development environment that puts you in control:

- **Run LLMs locally** on your machine with automatic GPU detection
- **Interact with models** through a web UI and configure your server
- **Manage everything** via a powerful CLI for services, models, and the LLM council
- **Enhance your IDE** with AI-powered code assistance using the Continue plugin
- **Preserve context** with database integration for saving dialogues and future training

## Understanding AIXCL Architecture

AIXCL follows a strict governance model that cleanly separates **Runtime Core** from **Operational Services**:

### Runtime Core (Always Enabled)

The core runtime defines what AIXCL is and is always present in every deployment:

- **Ollama**: LLM inference engine that powers model execution
- **LLM-Council**: Multi-model orchestration and coordination system
- **Continue**: VS Code plugin for AI-powered code assistance

These components are non-negotiable and must be present in every deployment.

### Operational Services (Profile-Dependent)

Operational services support, observe, or operate the runtime and can be enabled based on your needs:

- **Persistence**: PostgreSQL database and pgAdmin management interface
- **Observability**: Prometheus, Grafana, Loki, Promtail, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
- **UI**: Open WebUI for model interaction
- **Automation**: Watchtower for automatic container updates

Operational services are optional and can be enabled based on deployment profiles (core, dev, ops, full).

For detailed architectural documentation, see [`aixcl_governance/`](./aixcl_governance/).

## System Requirements

Before you begin, ensure your system meets these requirements:

- **Minimum 16 GB RAM** - Required for running LLM models efficiently
- **Minimum 128 GB free disk space** - Needed for models and container images

## Quick Start Guide: Your First Steps

Follow these steps to get AIXCL up and running on your system:

**Step 1: Clone the repository**

Start by cloning the AIXCL repository to your local machine:

```bash
git clone https://github.com/xencon/aixcl.git
cd aixcl
```

**Step 2: Verify your environment**

Check that your system meets all requirements and has the necessary dependencies installed:

```bash
./aixcl utils check-env
```

This command verifies Docker installation, available resources, and system compatibility. Address any issues it reports before proceeding.

**Step 3: Install CLI completion (optional but recommended)**

Enable bash shell completion for a smoother CLI experience:

```bash
./aixcl utils bash-completion
```

After running this, restart your terminal or source your bash profile to activate tab completion.

**Step 4: Start the services**

Launch all AIXCL services. The system automatically creates a `.env` file from `.env.example` if one doesn't exist:

```bash
./aixcl stack start
```

This command starts all core services. Wait for all containers to be healthy before proceeding. You can monitor progress with `./aixcl stack status`.

**Step 5: Add your first model**

Download and configure the LLM models you want to use. Replace `<model:latest>` with your preferred model:

```bash
./aixcl models add <model:latest>
```

For example: `./aixcl models add llama3:latest` or `./aixcl models add mistral:latest`. The model download may take several minutes depending on your internet connection.

**Step 6: Configure LLM Council**

Set up the multi-model orchestration system through an interactive configuration wizard:

```bash
./aixcl council configure
```

Follow the prompts to select models and configure the council chairman. This enables advanced multi-model coordination features.

**Step 7: Access the web interface**

Open your browser and navigate to:

```
http://localhost:8080
```

You should see the Open WebUI interface where you can interact with your models, view conversation history, and manage your LLM setup.

## Managing Your AIXCL Platform

Once AIXCL is running, use these commands to manage your platform effectively.

### Managing the Service Stack

Control all services as a unified stack:

**Start all services**

```bash
./aixcl stack start
```

Brings up all configured services. Use this after system reboots or when restarting your development environment.

**Stop all services**

```bash
./aixcl stack stop
```

Gracefully shuts down all services while preserving data and state.

**Restart all services**

```bash
./aixcl stack restart
```

Useful after configuration changes or when troubleshooting service issues.

**Check service status**

```bash
./aixcl stack status
```

Displays the current state of all services, showing which are running, stopped, or unhealthy.

**View service logs**

Monitor what's happening across your platform:

```bash
# View logs for all services
./aixcl stack logs

# View logs for a specific service
./aixcl stack logs ollama
```

Logs help diagnose issues and monitor system behavior. Press `Ctrl+C` to exit log viewing.

**Clean up unused resources**

```bash
./aixcl stack clean
```

Removes unused Docker images, containers, and networks to free up disk space. Run this periodically to maintain a clean environment.

### Controlling Individual Services

Manage specific services without affecting the entire stack:

```bash
# Start a specific service
./aixcl service start postgres

# Restart a service (useful after configuration changes)
./aixcl service restart ollama

# Stop a service
./aixcl service stop grafana
```

This granular control lets you update or troubleshoot individual components without disrupting your entire workflow.

### Working with LLM Models

Manage the LLM models available in your AIXCL installation:

**Add models**

Download and install new models:

```bash
./aixcl models add <model:latest>
```

Examples: `./aixcl models add llama3:latest`, `./aixcl models add mistral:7b`. The system downloads models from Ollama's registry.

**Remove models**

Free up disk space by removing unused models:

```bash
./aixcl models remove <model:latest>
```

**List installed models**

See all models currently available in your installation:

```bash
./aixcl models list
```

This shows model names, sizes, and download dates to help you manage your model collection.

### Configuring LLM Council

The LLM Council enables multi-model orchestration and coordination:

**Configure council settings**

Run the interactive setup wizard to configure models and select a chairman:

```bash
./aixcl council configure
```

The wizard guides you through selecting models for council members and choosing a chairman model. This enables advanced features like model voting and consensus-based responses.

**View council status**

Check your current council configuration and see which models are active:

```bash
./aixcl council status
```

Displays council members, chairman selection, and current operational status.

### Accessing Web Dashboards

AIXCL provides several web interfaces for different aspects of the platform:

```bash
# Open WebUI - Main interface for model interaction
./aixcl dashboard openwebui    # http://localhost:8080

# Grafana - Monitoring and observability dashboard
./aixcl dashboard grafana      # http://localhost:3000

# pgAdmin - Database administration interface
./aixcl dashboard pgadmin      # http://localhost:5050
```

These commands open the respective dashboards in your default browser. Each dashboard provides different capabilities:
- **Open WebUI**: Chat with models, manage conversations, configure model settings
- **Grafana**: Monitor system metrics, GPU usage, container performance
- **pgAdmin**: Manage databases, run queries, view conversation storage

### Verifying Your Installation

Ensure everything is working correctly with the platform test suite:

**Run platform tests**

The test suite supports profile-based and component-based testing. Run without arguments to see available options:

```bash
./tests/platform-tests.sh
```

**Test by profile** (recommended for most users):

```bash
# Test core profile (runtime core only)
./tests/platform-tests.sh --profile core

# Test dev profile (runtime core + database + UI)
./tests/platform-tests.sh --profile dev

# Test ops profile (runtime core + database + monitoring + logging)
./tests/platform-tests.sh --profile ops

# Test full profile (all services)
./tests/platform-tests.sh --profile full
```

**Test by component** (for targeted testing):

```bash
# Test runtime core components
./tests/platform-tests.sh --component runtime-core

# Test database components
./tests/platform-tests.sh --component database

# Test UI components
./tests/platform-tests.sh --component ui

# Test API endpoints
./tests/platform-tests.sh --component api
```

**List all available targets:**

```bash
./tests/platform-tests.sh --list
```

The test suite checks service health, API endpoints, database connectivity, and integration points. Address any failures before using AIXCL in production.

## Governance and Architecture

AIXCL maintains strict architectural invariants to preserve platform integrity. The governance model defines:

- **Runtime Core**: Fixed, non-negotiable components that define the product
- **Operational Services**: Optional services that support the runtime
- **Service Contracts**: Dependency rules and boundaries for each service
- **Profiles**: Declarative compositions of operational services

See [`aixcl_governance/`](./aixcl_governance/) for complete architectural documentation, service contracts, and AI assistant guidance.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.
