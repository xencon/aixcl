#!/bin/bash
# Initialize Command - Runs on host before container creation
# This script runs on your local machine, not in the container

set -e

echo "=========================================="
echo "AIXCL Dev Container - Initialization"
echo "=========================================="

# Check prerequisites
echo "Checking prerequisites..."

# Check Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi
echo "✓ Docker installed"

# Check Docker Compose
docker compose version >/dev/null 2>&1 || docker-compose version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Docker Compose not found. Please install Docker Compose."
    exit 1
fi
echo "✓ Docker Compose available"

# Check for GPU support (optional but recommended)
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✓ NVIDIA GPU detected"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -1
else
    echo "⚠ NVIDIA GPU not detected. GPU-dependent features (vLLM, etc.) will not work."
fi

# Check port availability
ports=(11434 8080 3000 9090 5432 5050)
echo "Checking port availability..."
for port in "${ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tln 2>/dev/null | grep -q ":$port "; then
        echo "⚠ Port $port is already in use"
    else
        echo "✓ Port $port available"
    fi
done

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✓ Created .env from .env.example"
        echo "⚠ Please review and customize .env for your environment"
    else
        echo "⚠ No .env.example found. You may need to create .env manually."
    fi
fi

echo ""
echo "=========================================="
echo "Initialization complete!"
echo "You can now open this folder in VS Code with Remote-Containers"
echo "Or run: devcontainer open"
echo "=========================================="
