## Overview

This project leverages Docker Compose to orchestrate a multi-container application stack, which includes the Open WebUI, a PostgreSQL database, a pgAdmin interface for database management, and a Watchtower service for automatic updates. Here's a breakdown of each component:

### Services

1. **Open WebUI**
   - **Image**: `ghcr.io/open-webui/open-webui:ollama`
   - **Purpose**: This service runs the Open WebUI application, which is accessible on port 3000. It connects to the PostgreSQL database to store and retrieve data.
   - **Volumes**: 
     - `ollama`: Stores configuration and data specific to the Open WebUI.
     - `open-webui` and `open-webui-data`: Used for application data storage.
     - `./start.sh`: Mounted as `/app/backend/start2.sh` to execute startup scripts.
   - **Environment Variables**:
     - `DATA_DIR`: Specifies the directory for data storage.
     - `DATABASE_URL`: Connection string for the PostgreSQL database.
     - `NVIDIA_VISIBLE_DEVICES`: Allows access to all NVIDIA devices for GPU acceleration.
     - `ADMIN_USER_EMAIL` and `ADMIN_USER_PASSWORD`: Credentials for admin access.
     - `MODELS`: Specifies the models to be used by the application. You can change the `MODELS` value in the `.env` file. Visit [Ollama's search page](https://ollama.com/search) for a list of available models.
   - **Dependencies**: Waits for the PostgreSQL service to start before initializing.
   - **Command**: Executes a script to start the application.

2. **PostgreSQL**
   - **Image**: `postgres:latest`
   - **Purpose**: Provides a robust and scalable database solution for the Open WebUI application.
   - **Environment Variables**:
     - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`: Set up the initial database and user credentials.
   - **Volumes**:
     - `postgres-data`: Persists database data across container restarts.

3. **pgAdmin**
   - **Image**: `dpage/pgadmin4`
   - **Purpose**: Offers a web-based interface for managing the PostgreSQL database, accessible on port 5050.
   - **Environment Variables**:
     - `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`: Credentials for accessing the pgAdmin interface.
   - **Dependencies**: Waits for the PostgreSQL service to start before initializing.

4. **Watchtower**
   - **Image**: `containrrr/watchtower`
   - **Purpose**: Automatically updates running Docker containers to the latest available versions.
   - **Volumes**:
     - `/var/run/docker.sock`: Required for Watchtower to interact with the Docker daemon.
   - **Command**: Monitors and updates the `open-webui` service.

### Volumes

- **ollama**, **open-webui**, **open-webui-data**, **postgres-data**: These named volumes ensure that data persists across container restarts, maintaining the state of the application and database.

### Usage

1. **Prepare Environment Variables**:
   - Copy the `.env.example` file to `.env`:
     ```bash
     cp .env.example .env
     ```
   - Fill in the required environment variables in the `.env` file with your specific values. Feel free to modify any of the values in the `.env.example` file to suit your needs.
   - To update the models used by the application, modify the `MODELS` variable in the `.env` file. You can find a list of available models at [Ollama's search page](https://ollama.com/search).

2. **Start the Application Stack**:
   - Run the following command to start all services in detached mode:
     ```bash
     docker-compose up -d
     ```

This command will start all services, allowing you to interact with the Open WebUI on port 3000, manage your database with pgAdmin on port 5050, and ensure your containers are kept up-to-date with Watchtower.
