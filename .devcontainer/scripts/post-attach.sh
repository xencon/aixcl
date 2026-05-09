#!/bin/bash
# Post-Attach Command - Runs inside container after user attaches
# Consolidates post-create (first setup) and post-start (recurring) logic

set -e

echo "=========================================="
echo "AIXCL Dev Container - Setup"
echo "=========================================="

# Change to workspace directory
cd /workspace || exit 1

# Ensure we're using the vscode user
if [ "$(whoami)" != "vscode" ]; then
    echo "Switching to vscode user..."
    exec su - vscode -c "cd /workspace && /workspace/.devcontainer/scripts/post-attach.sh"
fi

echo "Running as: $(whoami)"

# Make aixcl executable
chmod +x ./aixcl

# First-time setup (only run once)
FIRST_RUN_MARKER="/home/vscode/.aixcl-first-run-done"
if [ ! -f "$FIRST_RUN_MARKER" ]; then
    echo ""
    echo "First-time setup..."
    
    # Check environment
    if ./aixcl utils check-env; then
        echo "✓ Environment check passed"
    else
        echo "⚠ Environment check had warnings (see above)"
    fi
    
    # Show current configuration
    echo ""
    echo "Current AIXCL Configuration:"
    echo "----------------------------"
    if [ -f .env ]; then
        grep "^INFERENCE_ENGINE" .env 2>/dev/null || echo "INFERENCE_ENGINE: not set (will use default)"
        grep "^PROFILE" .env 2>/dev/null || echo "PROFILE: not set (will use 'sys')"
    else
        echo "No .env file found"
    fi
    
    # Mark first run complete
    touch "$FIRST_RUN_MARKER"
fi

# Check if Docker is available
if ! docker info >/dev/null 2>&1; then
    echo ""
    echo "⚠ Docker daemon not available"
    echo "  Services cannot be started automatically"
    exit 0
fi

# Check if AIXCL services are running
echo ""
echo "Checking AIXCL services..."
if ./aixcl stack status 2>/dev/null | grep -q "running"; then
    echo "✓ AIXCL services already running"
    ./aixcl stack status
else
    echo "AIXCL services not running"
    echo ""
    echo "To start services, run:"
    echo "  ./aixcl stack start --profile sys"
    echo ""
    echo "Or auto-detect and start:"
    echo "  ./aixcl engine auto && ./aixcl stack start"
fi

echo ""
echo "=========================================="
echo "Quick start commands:"
  echo "  ./aixcl stack start --profile sys    # Start AIXCL services"
echo "  ./aixcl stack status                 # Check service status"
echo "  opencode                             # Start OpenCode CLI"
echo ""
echo "Services will be available at:"
echo "  - API: http://localhost:11434"
echo "  - Open WebUI: http://localhost:8080"
echo "=========================================="
