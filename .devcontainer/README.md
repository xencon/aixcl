# AIXCL Dev Container

This directory contains the [Development Container](https://containers.dev/) configuration for AIXCL, enabling consistent development environments across different machines.

## Prerequisites

Before using the dev container, ensure you have:

1. **Docker** installed and running
2. **Docker Compose** (V2 plugin preferred)
3. **NVIDIA GPU** (optional but recommended for vLLM/llama.cpp)

### For GPU Support

If you have an NVIDIA GPU:

```bash
# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## Quick Start

### Option 1: Docker Compose (Recommended)

**Best for:** Direct control, familiar Docker workflow, minimal dependencies.

```bash
# 1. Navigate to repository
cd ~/src/github.com/xencon/aixcl

# 2. Build and start the dev container
docker compose -f .devcontainer/docker-compose.dev.yml up -d

# 3. Enter the container
docker exec -it devcontainer-devcontainer-1 /bin/bash

# 4. Switch to vscode user (recommended)
su - vscode

# 5. Navigate to workspace
cd /workspace

# 6. Start AIXCL
./aixcl stack start --profile usr

# 7. Verify services
./aixcl stack status
```

**Cleanup:**
```bash
# Stop the dev container
docker compose -f .devcontainer/docker-compose.dev.yml down

# Or stop and remove volumes
docker compose -f .devcontainer/docker-compose.dev.yml down -v
```

---

### Option 2: VS Code Remote-Containers

**Best for:** IDE integration and GUI tooling.

1. Open repository in VS Code
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
3. Type "Remote-Containers: Reopen in Container"
4. Wait for the container to build and start (first time may take 5-10 minutes)
5. VS Code reconnects inside the container automatically

---

### Option 3: Dev Container CLI

**Best for:** Command-line users who want full spec support.

```bash
# Install devcontainer CLI
npm install -g @devcontainers/cli

# Build and start
devcontainer up --workspace-folder .

# Enter container
devcontainer exec --workspace-folder . /bin/bash

# Stop
devcontainer down --workspace-folder .
```

---

### Option 4: GitHub Codespaces

**Best for:** Cloud-based development, no local setup required.

1. Push this repository to GitHub
2. Click "Code" → "Codespaces" → "Create codespace"
3. Wait for the environment to start (2-3 minutes)
4. Use VS Code in browser or connect via SSH

---

## What's Included

The dev container provides:

| Component | Purpose |
|-----------|---------|
| **Ubuntu 22.04** | Base operating system |
| **Docker-in-Docker** | Run AIXCL containers inside dev container |
| **NVIDIA CUDA Toolkit** | GPU support for vLLM/llama.cpp |
| **Python 3 + pip** | Model download tools |
| **huggingface-hub** | HuggingFace model downloads |
| **jq** | JSON processing |
| **zsh + Oh My Zsh** | Enhanced shell |
| **OpenCode CLI** | AI-powered code assistant |
| **GitHub CLI** | GitHub integration |

---

## OpenCode Integration

The dev container comes with [OpenCode CLI](https://opencode.ai/) pre-installed, connecting to the AIXCL inference engine.

### Using OpenCode CLI

```bash
# Start OpenCode CLI (connects to AIXCL inference engine at localhost:11434)
opencode

# In OpenCode, you can use commands like:
# /explain - Explain code
# /fix - Fix issues
# /test - Generate tests
# /doc - Generate documentation
```

### Starting OpenCode

1. Ensure AIXCL services are running: `./aixcl stack status`
2. OpenCode automatically connects to `http://localhost:11434/v1`
3. Start OpenCode: `opencode`

---

## Usage

### Starting AIXCL

Once in the dev container:

```bash
# Check environment
./aixcl utils check-env

# Auto-detect best engine
./aixcl engine auto

# Start services
./aixcl stack start --profile usr

# Check status
./aixcl stack status
```

### Adding Models

```bash
# For Ollama
./aixcl models add qwen2.5-coder:0.5b

# For vLLM (requires GPU)
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct

# For llama.cpp (requires GPU)
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf
```

### Testing

```bash
# Run all tests
./tests/run-tests.sh

# Run specific test
./tests/run-tests.sh --test test-00-preflight.sh

# Run quick tests (skip model downloads)
./tests/run-tests.sh --quick
```

---

## Configuration

### Environment Variables

The dev container sets these environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `OLLAMA_HOST` | `127.0.0.1:11434` | Ollama API endpoint |
| `HUGGINGFACE_HUB_CACHE` | `/home/vscode/.cache/huggingface` | HF model cache |
| `DOCKER_BUILDKIT` | `1` | Enable BuildKit |

### Persistence

The following data persists across container restarts:

| Volume | Path | Contents |
|--------|------|----------|
| `aixcl-ollama-data` | `/home/vscode/.ollama` | Ollama models |
| `aixcl-hf-cache` | `/home/vscode/.cache/huggingface` | HF models |
| `aixcl-llamacpp-data` | `/models` | llama.cpp models |
| `aixcl-pgdata` | `/var/lib/postgresql/data` | PostgreSQL data |

---

## Troubleshooting

### Docker Daemon Not Available

If you see "Docker daemon not available" inside the container:

```bash
# Check if Docker socket is mounted
ls -la /var/run/docker.sock

# If using Docker Compose method, ensure container has access:
docker compose -f .devcontainer/docker-compose.dev.yml ps
```

### GPU Not Detected

If GPU is not available inside the container:

```bash
# Check host GPU
nvidia-smi

# Check container GPU
docker exec aixcl-devcontainer-devcontainer-1 nvidia-smi

# If not working, rebuild with GPU support
docker compose -f .devcontainer/docker-compose.dev.yml down
docker compose -f .devcontainer/docker-compose.dev.yml up -d
```

### Port Conflicts

If ports are already in use on the host:

```bash
# Check what's using the port
lsof -i :11434

# Kill the process or change AIXCL ports in .env
```

---

## File Structure

```
.devcontainer/
├── devcontainer.json          # Main configuration (supports all methods)
├── docker-compose.dev.yml     # Docker Compose method (recommended)
├── Dockerfile                 # Dev container image definition
├── scripts/
│   ├── entrypoint.sh         # Container startup
│   ├── initialize.sh         # Host initialization
│   ├── post-create.sh        # First-time setup
│   └── post-start.sh         # Container resume
└── README.md                 # This file
```

---

## Development Workflow (Docker Compose Method)

1. **Start container:**
   ```bash
   docker compose -f .devcontainer/docker-compose.dev.yml up -d
   ```

2. **Enter container:**
   ```bash
   docker exec -it aixcl-devcontainer-devcontainer-1 /bin/bash
   su - vscode
   cd /workspace
   ```

3. **Start AIXCL:**
   ```bash
   ./aixcl stack start --profile usr
   ```

4. **Use OpenCode:**
   ```bash
   opencode
   ```

5. **Develop:** Edit files on host or in container (changes sync automatically)

6. **Commit:** Git works normally inside container

7. **Stop when done:**
   ```bash
   ./aixcl stack stop
   exit
   docker compose -f .devcontainer/docker-compose.dev.yml down
   ```

---

## Method Comparison

| Method | Best For | Learning Curve | Features |
|--------|----------|----------------|----------|
| **Docker Compose** | Direct control, CI/CD | Low | Full control, familiar syntax |
| **VS Code** | IDE integration | Medium | Port forwarding, debugging |
| **Dev Container CLI** | Spec compliance | Medium | Full lifecycle management |
| **Codespaces** | Cloud development | Low | No local setup needed |

---

## Resources

- [Dev Container Specification](https://containers.dev/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)
- [AIXCL Documentation](../docs/)

---

## Support

For issues related to:
- **Dev container setup:** Check this README and logs
- **AIXCL usage:** See main project documentation  
- **Docker issues:** Verify Docker is running on host
- **GPU issues:** Verify NVIDIA Container Toolkit is installed
