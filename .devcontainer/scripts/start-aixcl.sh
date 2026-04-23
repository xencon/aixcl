#!/bin/bash
# Start AIXCL in dev container with Docker-in-Docker fixes

set -e

echo "=========================================="
echo "Starting AIXCL in Dev Container"
echo "=========================================="

# Check if we're in a dev container
if [ -f /.dockerenv ] && [ -S /var/run/docker.sock ]; then
    echo "Dev container detected - applying Docker-in-Docker fixes..."
    
    # Copy the fix compose file to services directory
    if [ -f /workspace/.devcontainer/docker-compose.dev-fix.yml ]; then
        echo "Installing Docker-in-Docker fix..."
        cp /workspace/.devcontainer/docker-compose.dev-fix.yml /workspace/services/
        export COMPOSE_FILE="services/docker-compose.yml:services/docker-compose.dev-fix.yml"
        echo "COMPOSE_FILE set to: $COMPOSE_FILE"
    fi
else
    echo "Not in dev container - running normally"
fi

# Change to workspace
cd /workspace

# Run the actual aixcl command
echo ""
echo "Running: ./aixcl stack start $*"
./aixcl stack start "$@"
