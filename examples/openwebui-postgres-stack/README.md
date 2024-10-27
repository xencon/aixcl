## Overview

This project leverages Docker Compose to orchestrate a multi-container application stack, which includes the Open WebUI, a PostgreSQL database, and a pgAdmin interface for database management. Here's a breakdown of each component:

### Services

1. **Open WebUI**
   - **Image**: `ghcr.io/open-webui/open-webui:ollama`
   - **Purpose**: This service runs the Open WebUI application, which is accessible on port 3000. It connects to the PostgreSQL database to store and retrieve data.
   - **Volumes**: 
     - `ollama`: Stores configuration and data specific to the Open WebUI.
     - `open-webui` and `open-webui-data`: Used for application data storage.
   - **Environment Variables**:
     - `DATA_DIR`: Specifies the directory for data storage.
     - `DATABASE_URL`: Connection string for the PostgreSQL database.
     - `NVIDIA_VISIBLE_DEVICES`: Allows access to all NVIDIA devices for GPU acceleration.
   - **Dependencies**: Waits for the PostgreSQL service to start before initializing.

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

### Volumes

- **ollama**, **open-webui**, **open-webui-data**, **postgres-data**: These named volumes ensure that data persists across container restarts, maintaining the state of the application and database.

### Usage

To start the application stack, simply run:

