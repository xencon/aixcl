# AIXCL

## Overview
This project sets up a multi-container application using Docker Compose. It includes services for Ollama, Open WebUI, PostgreSQL, PgAdmin, and Watchtower. The setup is designed to provide an open-source development platform for integrating Large Language Models (LLMs) into your software development life.

### LLM Integration
AIXCL helps developers use Large Language Models (LLMs) in their projects. LLMs can assist with tasks like writing code, generating documentation, and reviewing code for errors. This project provides a simple way to set up and run the necessary services, allowing developers to focus on building applications while leveraging the power of AI. By using AIXCL, you can easily experiment with different models and integrate them into your development process.

## CLI Wrapper
The `aixcl` script is a command-line interface (CLI) wrapper that simplifies the management of the Docker Compose deployment for the AIXCL project. It provides a set of commands to control the lifecycle of the application services and manage LLM models.

### Available Commands
```
Usage: ./aixcl {start|stop|restart|logs|clean|stats|status|add|remove|list}
Commands:
  start                Start the Docker Compose deployment
  stop                 Stop the Docker Compose deployment
  restart              Restart all services
  logs                 Show logs for all containers
  clean                Remove unused Docker containers, images, and volumes
  stats                Show resource usage statistics
  status               Check services status
  add <model-name>     Add a specific Ollama model
  remove <model-name>  Remove a specific Ollama model
  list                 List all installed models
```

## Services

### Ollama
- **Description**: Ollama is a service that manages models. It uses a script located in the `scripts` folder to initialize.
- **Image**: `ollama/ollama:latest`
- **Home Page**: [Ollama](https://ollama.com)

### Open WebUI
- **Description**: A web-based UI service that interacts with a PostgreSQL database.
- **Image**: `ghcr.io/open-webui/open-webui:latest`
- **Home Page**: [Open WebUI](https://github.com/open-webui/open-webui)

### PostgreSQL
- **Description**: A PostgreSQL database service for data storage.
- **Image**: `postgres:latest`
- **Home Page**: [PostgreSQL](https://www.postgresql.org)

### PgAdmin
- **Description**: A web-based database management tool for PostgreSQL.
- **Image**: `dpage/pgadmin4`
- **Home Page**: [PgAdmin](https://www.pgadmin.org)

### Watchtower
- **Description**: A service to automatically update Docker containers.
- **Image**: `containrrr/watchtower`
- **Home Page**: [Watchtower](https://containrrr.dev/watchtower/)

## Setup Instructions

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/xencon/aixcl.git
   cd aixcl
   ```

2. **Environment Configuration**:
   - Copy the `.env.example` file to `.env` in the root directory and set the necessary environment variables:
     ```env
     POSTGRES_USER=your_postgres_user
     POSTGRES_PASSWORD=your_postgres_password
     POSTGRES_DATABASE=your_postgres_database
     PGADMIN_EMAIL=your_pgadmin_email
     PGADMIN_PASSWORD=your_pgadmin_password
     OPENWEBUI_EMAIL=your_openwebui_email
     OPENWEBUI_PASSWORD=your_openwebui_password
     WEBUI_SECRET_KEY=your_secret_key  # New: Add a secret key for the web UI
     ```

3. **Run the Deployment**:
   - Use the `aixcl` script to start the Docker Compose deployment:
   ```bash
   ./aixcl start
   ```

4. **Accessing Services**:
   - **Open WebUI**: Navigate to `http://localhost:8080` in your web browser.
   - **PgAdmin**: Navigate to `http://localhost:5050` in your web browser.

## Volumes

- `ollama`: Stores Ollama data.
- `open-webui`: Stores Open WebUI backend data.
- `open-webui-data`: Stores additional Open WebUI data.
- `postgres-data`: Stores PostgreSQL data.

## License
This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

## Contributing

We welcome contributions from the community! Please read our [Contributing Guidelines](./CONTRIBUTING.md) to get started.

## New Features
- **WebUI Secret Key**: Added support for a secret key to enhance security for the Open WebUI.
- **Improved Health Checks**: Enhanced health checks for services to ensure they are running correctly.
- **Model Management**: Added the ability to remove models using the `remove-model` command.
