# AIXCL

## Overview
AIXCL is a simple Docker-based platform that helps you integrate Large Language Models (LLMs) into your development workflow. It sets up Ollama, Open WebUI, and supporting services with minimal effort. These can be directly accessed via your IDE using the [continue](https://continue.dev) plugin.

### What does it do?
- Run LLMs locally on your machine
- Provide a friendly web interface to interact with models
- Help you code, generate documentation, and review your work
- Simplify model management with easy-to-use commands

## Quick Start

```bash
# Clone the repository
git clone https://github.com/xencon/aixcl.git
cd aixcl

# Start the services (automatically creates .env from .env.example if needed)
./aixcl start

# Add models you want to use
./aixcl add starcoder2:latest nomic-embed-text:latest

# Access the web interface
# Open http://localhost:8080 in your browser
```

## CLI Commands

```
Usage: ./aixcl {start|stop|restart|logs|clean|stats|status|add|remove|list|help|install-completion|check-env}
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
  help                 Show this help menu
  install-completion   Install bash completion for aixcl
  check-env            Check environment dependencies
```

## Services

| Service | Description | URL |
|---------|-------------|-----|
| **Ollama** | Runs LLMs locally | [ollama.com](https://ollama.com) |
| **Open WebUI** | Web interface for interacting with models | [http://localhost:8080](http://localhost:8080) |
| **PostgreSQL** | Database for storing conversations and settings | - |
| **pgAdmin** | Database management tool | [http://localhost:5050](http://localhost:5050) |
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

The `.env` file is automatically created from `.env.example` when you run `./aixcl start` for the first time. You can then edit it with your preferred settings:

**Required variables:**
```
POSTGRES_USER=your_postgres_user
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DATABASE=your_postgres_database
PGADMIN_EMAIL=your_pgadmin_email
PGADMIN_PASSWORD=your_pgadmin_password
OPENWEBUI_EMAIL=your_openwebui_email
OPENWEBUI_PASSWORD=your_openwebui_password
```

### Environment File Options

- **`.env`** - Main configuration file (automatically created from `.env.example`)
- **`.env.example`** - Template configuration file (used to create `.env`)
- **`.env.local`** - Local overrides (optional, ignored by git)
- **`docker-compose.override.yml`** - Local Docker Compose overrides (optional, ignored by git)

**Manual Setup (if needed):**
If you prefer to create the `.env` file manually, you can copy it from the example:
```bash
cp .env.example .env
# Edit .env with your preferred settings
```

The `.env.local` file can be used to override settings from `.env` without modifying the main configuration file. This is useful for local development or when you want to keep sensitive data separate from the main configuration.

## Contributing

We welcome contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License
This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

## Have fun!
