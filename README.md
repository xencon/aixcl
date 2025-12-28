<a href="https://youtu.be/YaBABt0TsPI">
  <img src="6551931d-3936-49b8-83ab-920cc0675ab4.png" width="600"/>
</a>

# AIXCL

**A self-hosted AI stack for running and integrating LLMs locally.**

## About AIXCL

AIXCL is a privacy focused, local-first AI development platform for individuals and teams who want full control over their models and tooling. It provides a simple CLI, a web interface, and a containerized stack to run, manage, and integrate large language models directly into your workflow.

## Technology Stack

AIXCL is built on a containerized architecture using Docker and Docker Compose, with a strict separation between core runtime and operational services:

### Runtime Core (Always Enabled)

These components define what AIXCL is and are always present in every deployment:

- **Ollama**: LLM inference engine
- **LLM-Council**: Multi-model orchestration and coordination system
- **Continue**: VS Code plugin for AI-powered code assistance

### Operational Services (Profile-Dependent)

Optional services that support, observe, or operate the runtime:

- **Persistence**: PostgreSQL (database) and pgAdmin (database administration)
- **Observability**: Prometheus (metrics), Grafana (dashboards), Loki (logs), Promtail (log shipping), cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
- **UI**: Open WebUI (web interface for model interaction)
- **Automation**: Watchtower (automatic container updates)

### Infrastructure

- **Docker & Docker Compose**: Container orchestration and service management
- **Bash CLI**: Unified command-line interface for platform control
- **Profile System**: Declarative service composition (usr, dev, ops, sys)

## Target Audience

AIXCL serves different user types through profile-based deployments:

- **End Users** (`usr` profile): Minimal footprint deployments with database persistence for personal use
- **Developers** (`dev` profile): Local development workstations with UI and database tools
- **Operators** (`ops` profile): Production servers requiring observability and monitoring
- **System** (`sys` profile): Complete deployments with full feature set and automation

## Features

- **Local LLM Execution**: Run models locally with automatic GPU detection and optimization
- **Multi-Model Orchestration**: Coordinate multiple models using LLM Council for consensus-based responses
- **IDE Integration**: VS Code integration via Continue plugin for AI-powered code assistance
- **Web Interface**: Interactive model interaction through Open WebUI (profile-dependent)
- **Conversation Persistence**: Store dialogues and interactions in PostgreSQL for context preservation
- **Observability**: Monitor system metrics, GPU usage, and container performance with Prometheus and Grafana
- **Profile-Based Deployment**: Choose service composition for your use case (usr, dev, ops, sys)
- **CLI Management**: Unified command-line interface for services, models, and configurations
- **Automatic Updates**: Keep containers up-to-date with Watchtower (profile-dependent)

## System Requirements

- **Minimum 16 GB RAM** - Required for running LLM models efficiently
- **Minimum 128 GB free disk space** - Needed for models and container images
- **Docker & Docker Compose** - Required for container orchestration

## Quick Start

Get AIXCL up and running in minutes:

**1. Clone the repository**

```bash
git clone https://github.com/xencon/aixcl.git
cd aixcl
```

**2. Verify your environment**

```bash
./aixcl utils check-env
```

This verifies Docker installation, available resources, and system compatibility.

**3. Install CLI completion (optional)**

```bash
./aixcl utils bash-completion
```

Restart your terminal or source your bash profile to activate tab completion.

**4. Start the services**

```bash
# First time: specify profile (saves to .env for future use)
./aixcl stack start --profile usr

# Subsequent times: uses PROFILE from .env automatically
./aixcl stack start
```

Available profiles:
- `usr` - User-oriented runtime (minimal footprint with database persistence)
- `dev` - Developer workstation (runtime core + UI + DB)
- `ops` - Observability-focused (runtime core + monitoring/logging)
- `sys` - System-oriented (complete stack with automation)

The system automatically creates a `.env` file from `.env.example` if needed. Monitor service status with `./aixcl stack status`.

**5. Add your first model**

```bash
./aixcl models add deepseek-coder:1.3b
```

Examples: `deepseek-coder:1.3b`, `codegemma:2b`, `qwen2.5-coder:3b`. Model downloads may take several minutes depending on your connection.

**6. Configure LLM Council (optional)**

```bash
./aixcl council configure
```

Interactive wizard guides you through selecting council members and a chairman model.

**Recommended default configuration:**
- **Chairman**: `deepseek-coder:1.3b` (776MB)
- **Council Members**: `codegemma:2b` (1.6GB), `qwen2.5-coder:3b` (1.9GB)

This configuration provides excellent performance (~24s average) with low VRAM usage (~4.3GB). See [`docs/operations/model-recommendations.md`](docs/operations/model-recommendations.md) for details.

**7. Access the web interface (if not using usr profile)**

Navigate to `http://localhost:8080` to use Open WebUI for model interaction.

## Platform Management

### Service Stack Control

Manage all services as a unified stack:

```bash
./aixcl stack start [--profile sys]      # Start all services (uses PROFILE from .env if set)
./aixcl stack stop                       # Stop all services gracefully
./aixcl stack restart [--profile sys]    # Restart all services (uses PROFILE from .env if set)
./aixcl stack status                     # Check service status
./aixcl stack logs                       # View logs for all services
./aixcl stack logs ollama                # View logs for specific service
./aixcl stack clean                      # Remove unused Docker resources
```

**Note:** Set `PROFILE=<profile>` in `.env` file to use a default profile. Then `stack start` and `stack restart` will use that profile automatically without needing the `--profile` flag.
```

### Individual Service Control

Manage specific services independently:

```bash
./aixcl service start postgres    # Start a specific service
./aixcl service restart ollama    # Restart a service
./aixcl service stop grafana      # Stop a service
```

### Model Management

```bash
./aixcl models add llama3:latest     # Add a model
./aixcl models remove llama3:latest  # Remove a model
./aixcl models list                  # List installed models
```

Models are downloaded from Ollama's registry.

### LLM Council Configuration

Configure multi-model orchestration for consensus-based responses:

```bash
./aixcl council configure  # Interactive setup wizard
./aixcl council status     # View current configuration
```

### Web Dashboards

Access web interfaces for different aspects of the platform:

```bash
./aixcl dashboard openwebui  # http://localhost:8080 - Model interaction UI
./aixcl dashboard grafana    # http://localhost:3000 - Monitoring dashboard
./aixcl dashboard pgadmin    # http://localhost:5050 - Database administration
```

### Verification

Run the platform test suite to verify your installation:

```bash
# List available test targets
./tests/platform-tests.sh --list

# Test by profile (recommended)
./tests/platform-tests.sh --profile usr     # Runtime core + PostgreSQL
./tests/platform-tests.sh --profile dev     # Core + database + UI
./tests/platform-tests.sh --profile ops     # Core + monitoring + logging
./tests/platform-tests.sh --profile sys     # All services

# Test by component (targeted testing)
./tests/platform-tests.sh --component runtime-core
./tests/platform-tests.sh --component database
./tests/platform-tests.sh --component ui
./tests/platform-tests.sh --component api
```

The test suite checks service health, API endpoints, database connectivity, and integration points.

## Architecture

AIXCL maintains strict architectural invariants to preserve platform integrity:

- **Runtime Core**: Fixed, non-negotiable components (Ollama, LLM-Council, Continue) that define the product
- **Operational Services**: Optional services that support, observe, or operate the runtime
- **Service Contracts**: Dependency rules and boundaries for each service
- **Profiles**: Declarative service compositions (see Target Audience section)

The runtime core must be runnable without any operational services, and operational services may depend on the runtime core but never vice versa.

For detailed architectural documentation, see [`docs/architecture/governance/`](./docs/architecture/governance/).

## Component Documentation

### Runtime Core Components

- **Ollama**: LLM inference engine with performance optimizations for multi-model orchestration
  - See [`docs/operations/ollama-performance-tuning.md`](docs/operations/ollama-performance-tuning.md) for tuning guide
  - Optimized for parallel requests, model keep-alive, and GPU utilization

- **LLM-Council**: Multi-model orchestration system for consensus-based responses
  - Component docs: [`llm-council/README.md`](llm-council/README.md)
  - Testing: [`llm-council/TESTING.md`](llm-council/TESTING.md)
  - Performance optimizations: [`llm-council/PERFORMANCE_OPTIMIZATIONS.md`](llm-council/PERFORMANCE_OPTIMIZATIONS.md)

- **Continue**: VS Code plugin integration for AI-powered code assistance
  - Configured via `.continue/config.json` to use LLM-Council API endpoint

### Performance Tuning

AIXCL includes comprehensive performance optimizations for running multiple LLM models efficiently:

**Ollama Optimizations:**
- Parallel request handling (`OLLAMA_NUM_PARALLEL=8`) for concurrent council queries
- Model keep-alive (`OLLAMA_KEEP_ALIVE=600`) to prevent reload delays
- Maximum loaded models (`OLLAMA_MAX_LOADED_MODELS=3`) for GPU memory management
- Explicit GPU configuration for optimal utilization

**Model Recommendations:**
- **Default Configuration** (8GB GPUs): `deepseek-coder:1.3b` (chairman), `codegemma:2b` + `qwen2.5-coder:3b` (council)
  - Performance: ~24s average, 68.1% keep-alive improvement, ~4.3GB VRAM
- **Alternative Configurations**: Available for 12GB+ and 16GB+ GPUs with larger models
- See [`docs/operations/model-recommendations.md`](docs/operations/model-recommendations.md) for complete details

**Performance Test Results:**
- Experimental testing of model configurations and optimization impact
- See [`docs/operations/performance-test-results.md`](docs/operations/performance-test-results.md) for detailed analysis

For complete performance tuning documentation, see [`docs/operations/`](docs/operations/).

## Documentation

Comprehensive documentation is organized in the [`docs/`](./docs/) directory:

- **User Guides** ([`docs/user/`](./docs/user/)): Setup and usage guides
- **Developer Guides** ([`docs/developer/`](./docs/developer/)): Contributing and development workflow
- **Operations** ([`docs/operations/`](./docs/operations/)): Performance tuning and operations guides
- **Architecture** ([`docs/architecture/`](./docs/architecture/)): Governance, profiles, and service contracts
- **Reference** ([`docs/reference/`](./docs/reference/)): Command reference and security policy

See [`docs/README.md`](./docs/README.md) for the complete documentation index.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.
