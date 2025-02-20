# AIXCL

## Overview
This project sets up a multi-container application using Docker Compose. It includes services for Ollama, Open WebUI, PostgreSQL, PgAdmin, and Watchtower. The setup is designed to provide a opensource development platform for integrating Large Language Models (LLMs) into your software development life.

### LLM Integration
AIXCL helps developers use Large Language Models (LLMs) in their projects. LLMs can assist with tasks like writing code, generating documentation, and reviewing code for errors. This project provides a simple way to set up and run the necessary services, allowing developers to focus on building applications while leveraging the power of AI. By using AIXCL, you can easily experiment with different models and integrate them into your development process.

## CLI Wrapper
The `aixcl` script is a command-line interface (CLI) wrapper that simplifies the management of the Docker Compose deployment for the AIXCL project. It provides a set of commands to control the lifecycle of the application services and manage LLM models.

### Available Commands
- `start`: Launches all services defined in the Docker Compose file
- `stop`: Gracefully stops all running services
- `restart`: Combines stop and start commands to restart all services
- `logs`: Shows real-time logs from all containers
- `clean`: Removes unused Docker containers, images, and volumes
- `stats`: Monitors GPU resources and usage
- `status`: Checks and displays the health status of all services
- `install-model <model-name>`: Downloads and installs a specific Ollama model

### Examples
```bash
# Start all services
./aixcl start

# Check service status
./aixcl status

# Install a specific model
./aixcl install-model starcoder2:latest

# View logs from all services
./aixcl logs

# Monitor GPU usage
./aixcl stats

# Stop all services
./aixcl stop
```

## Services

### Ollama
- **Description**: Ollama is a service that manages models. It uses a script located in the `scripts` folder to initialize.
- **Image**: `ollama/ollama:latest`

### Open WebUI
- **Description**: A web-based UI service that interacts with a PostgreSQL database.
- **Image**: `ghcr.io/open-webui/open-webui:latest`

### PostgreSQL
- **Description**: A PostgreSQL database service for data storage.
- **Image**: `postgres:latest`

### PgAdmin
- **Description**: A web-based database management tool for PostgreSQL.
- **Image**: `dpage/pgadmin4`

### Watchtower
- **Description**: A service to automatically update Docker containers.
- **Image**: `containrrr/watchtower`

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

## Scripts

- **openwebui.sh**: Starts the Open WebUI service.
- **aixcl**: Platform initialization script to manage the Docker Compose deployment.

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
