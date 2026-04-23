#!/bin/bash
# Dev Container Entrypoint
# This runs when the container starts and ensures Docker is available

set -e

echo "=========================================="
echo "AIXCL Dev Container Starting"
echo "=========================================="

# Check if we're running as root (needed for DinD)
if [ "$(id -u)" != "0" ]; then
    echo "Warning: Not running as root. Docker-in-Docker may not work."
fi

# Setup Docker socket permissions if using DinD
if [ -S /var/run/docker.sock ]; then
    echo "✓ Docker socket detected"
    chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# Wait for Docker daemon to be available
attempt=0
max_attempts=30
while ! docker info >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -gt $max_attempts ]; then
        echo "⚠ Docker daemon not available after $max_attempts attempts"
        echo "  Continuing anyway - you may need to start Docker manually"
        break
    fi
    echo "Waiting for Docker daemon... (attempt $attempt/$max_attempts)"
    sleep 2
done

if docker info >/dev/null 2>&1; then
    echo "✓ Docker daemon is ready"
    docker --version
fi

# Setup user permissions for volumes
if [ -d /home/vscode/.ollama ]; then
    chown -R vscode:vscode /home/vscode/.ollama 2>/dev/null || true
fi

if [ -d /home/vscode/.cache ]; then
    chown -R vscode:vscode /home/vscode/.cache 2>/dev/null || true
fi

if [ -d /models ]; then
    chown -R vscode:vscode /models 2>/dev/null || true
fi

echo "✓ Entrypoint complete"
echo "=========================================="

# Execute the CMD from Dockerfile or override
exec "$@"
