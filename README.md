# AIXCL

## Overview
This project sets up a multi-container application using Docker Compose. It includes services for Ollama, Open WebUI, PostgreSQL, PgAdmin, and Watchtower. The setup is designed to provide a robust environment for web-based UI and data management.

## Services

### Ollama
- **Description**: Ollama is a service that manages models. It uses a script located in the `scripts` folder to initialize.
- **Image**: `ollama/ollama:latest`
- **Environment Variables**:
  - `MODELS_BASE`: Base models directory.

### Open WebUI
- **Description**: A web-based UI service that interacts with a PostgreSQL database.
- **Image**: `ghcr.io/open-webui/open-webui:latest`
- **Environment Variables**:
  - `DATA_DIR`: Directory for data storage.
  - `DATABASE_URL`: Connection string for PostgreSQL.
  - `NVIDIA_VISIBLE_DEVICES`: GPU devices visibility.
  - `WEBUI_NAME`: Name of the web UI.
  - `OLLAMA_BASE_URL`: Base URL for Ollama service.
  - `OPENWEBUI_EMAIL`: Email for authentication.
  - `OPENWEBUI_PASSWORD`: Password for authentication.
  - **New**: `WEBUI_SECRET_KEY`: Secret key for securing the web UI.

### PostgreSQL
- **Description**: A PostgreSQL database service for data storage.
- **Image**: `postgres:latest`
- **Environment Variables**:
  - `POSTGRES_USER`: Database user.
  - `POSTGRES_PASSWORD`: Database password.
  - `POSTGRES_DB`: Database name.

### PgAdmin
- **Description**: A web-based database management tool for PostgreSQL.
- **Image**: `dpage/pgadmin4`
- **Environment Variables**:
  - `PGADMIN_DEFAULT_EMAIL`: Default email for PgAdmin.
  - `PGADMIN_DEFAULT_PASSWORD`: Default password for PgAdmin.

### Watchtower
- **Description**: A service to automatically update Docker containers.
- **Image**: `containrrr/watchtower`

## Setup Instructions

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/yourusername/yourproject.git
   cd yourproject
   ```

2. **Environment Configuration**:
   - Create a `.env` file in the root directory and set the necessary environment variables:
     ```env
     POSTGRES_USER=your_postgres_user
     POSTGRES_PASSWORD=your_postgres_password
     POSTGRES_DATABASE=your_postgres_database
     PGADMIN_EMAIL=your_pgadmin_email
     PGADMIN_PASSWORD=your_pgadmin_password
     MODELS_BASE=your_models_base
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
   - **Open WebUI**: Navigate to `http://localhost:3000` in your web browser.
   - **PgAdmin**: Navigate to `http://localhost:5050` in your web browser.

## Usage

- **Access Open WebUI**: Navigate to `http://localhost:3000` in your web browser.
- **Access PgAdmin**: Navigate to `http://localhost:5050` in your web browser.

## Scripts

- **ollama.sh**: Script to initialize the Ollama service.
- **openwebui.sh**: Script to start the Open WebUI service.
- **aixcl**: Main script to manage the Docker Compose deployment.

## Volumes

- `ollama`: Stores Ollama data.
- `open-webui`: Stores Open WebUI backend data.
- `open-webui-data`: Stores additional Open WebUI data.
- `postgres-data`: Stores PostgreSQL data.

## License
This project is licensed under the MIT License.

## Contributing

We welcome contributions from the community! Please read our [Contributing Guidelines](./CONTRIBUTING.md) to get started.

## New Features
- **WebUI Secret Key**: Added support for a secret key to enhance security for the Open WebUI.
- **Improved Health Checks**: Enhanced health checks for services to ensure they are running correctly.

## Known Issues
- **Performance**: Some users may experience performance issues with high concurrency settings. Adjust `WEBUI_CONCURRENCY` in the Docker Compose file as needed.
