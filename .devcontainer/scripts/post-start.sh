#!/bin/bash
# Post-Start Command - Runs inside container each time it starts
# This keeps services running

set -e

echo "=========================================="
echo "AIXCL Dev Container - Post-Start"
echo "=========================================="

# Change to workspace directory
cd /workspace || exit 1

# Ensure we're using the vscode user
if [ "$(whoami)" != "vscode" ]; then
    exec su - vscode -c "cd /workspace && /workspace/.devcontainer/scripts/post-start.sh"
fi

# Check if Docker is available
if ! docker info >/dev/null 2>&1; then
    echo "⚠ Docker daemon not available"
    echo "  Services cannot be started automatically"
    exit 0
fi

# Check if AIXCL services are already running
echo "Checking AIXCL services..."
if ./aixcl stack status 2>/dev/null | grep -q "running"; then
    echo "✓ AIXCL services already running"
    ./aixcl stack status
else
    echo "AIXCL services not running"
    echo ""
    echo "To start services, run:"
    echo "  ./aixcl stack start --profile usr"
    echo ""
    echo "Or use:"
    echo "  ./aixcl engine auto  # Auto-detect best engine"
    echo "  ./aixcl stack start  # Start with detected engine"
fi

echo ""
echo "=========================================="
echo "Dev container is ready!"
echo "=========================================="
