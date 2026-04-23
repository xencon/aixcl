# AIXCL Dev Container

This directory contains the [Development Container](https://containers.dev/) configuration for AIXCL, enabling consistent development environments across different machines.

## Prerequisites

Before using the dev container, ensure you have:

1. **Docker** installed and running
2. **Docker Compose** (V2 plugin preferred)
3. **VS Code** with the [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
4. **NVIDIA GPU** (optional but recommended for vLLM/llama.cpp)

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

## Quick Start

### Option 1: VS Code Remote-Containers (Recommended)

1. Open VS Code in this repository
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
3. Type "Remote-Containers: Reopen in Container"
4. Wait for the container to build and start (first time may take 5-10 minutes)

### Option 2: Command Line

```bash
# Install devcontainer CLI
npm install -g @devcontainers/cli

# Open the dev container
devcontainer open
```

### Option 3: GitHub Codespaces

1. Push this repository to GitHub
2. Click "Code" → "Codespaces" → "Create codespace on main"
3. Wait for the environment to start

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
| **Pre-configured VS Code** | Extensions and settings |

## Available Services

When you start AIXCL services, they will be available at:

| Service | Port | URL |
|---------|------|-----|
| Inference API | 11434 | http://localhost:11434 |
| Open WebUI | 8080 | http://localhost:8080 |
| Grafana | 3000 | http://localhost:3000 |
| Prometheus | 9090 | http://localhost:9090 |
| PostgreSQL | 5432 | localhost:5432 |
| pgAdmin | 5050 | http://localhost:5050 |

## Usage

### Starting AIXCL

Once the dev container is running:

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

## Troubleshooting

### Docker Daemon Not Available

If you see "Docker daemon not available" inside the container:

```bash
# Check if Docker socket is mounted
ls -la /var/run/docker.sock

# If not, restart the container
# In VS Code: Command Palette → "Remote-Containers: Rebuild Container"
```

### GPU Not Detected

If GPU is not available inside the container:

```bash
# Check host GPU
nvidia-smi

# Check container GPU
docker run --rm --gpus=all nvidia/cuda:12.0-base nvidia-smi

# If working, rebuild dev container
```

### Port Conflicts

If ports are already in use on the host:

```bash
# Check what's using the port
lsof -i :11434

# Kill the process or change AIXCL ports in .env
```

## File Structure

```
.devcontainer/
├── devcontainer.json          # Main configuration
├── docker-compose.dev.yml     # Dev-specific compose overrides
├── Dockerfile                 # Dev container image
├── scripts/
│   ├── entrypoint.sh         # Container entrypoint
│   ├── initialize.sh         # Host initialization
│   ├── post-create.sh        # First-time setup
│   └── post-start.sh         # Container start
└── README.md                 # This file
```

## Development Workflow

1. **Open in Container**: VS Code will automatically build and start the dev container
2. **Wait for Setup**: The post-create script runs automatically
3. **Start AIXCL**: Run `./aixcl stack start --profile usr`
4. **Develop**: Make changes to code, test with AIXCL running
5. **Commit**: Git works normally inside the container

## Updating the Dev Container

If you modify any files in `.devcontainer/`:

```bash
# In VS Code
Ctrl+Shift+P → "Remote-Containers: Rebuild Container"

# Or command line
devcontainer build --workspace-folder .
```

## Resources

- [Dev Container Specification](https://containers.dev/)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)
- [AIXCL Documentation](../docs/)

## Support

For issues related to:
- **Dev container setup**: Check this README and logs
- **AIXCL usage**: See main project documentation
- **Docker issues**: Verify Docker is running on host
