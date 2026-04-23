#!/bin/bash
# Post-Create Command - Runs inside container after first creation
# This is where we set up AIXCL for the first time

set -e

echo "=========================================="
echo "AIXCL Dev Container - Post-Create Setup"
echo "=========================================="

# Change to workspace directory
cd /workspace || exit 1

# Ensure we're using the vscode user
if [ "$(whoami)" != "vscode" ]; then
    echo "Switching to vscode user..."
    exec su - vscode -c "cd /workspace && /workspace/.devcontainer/scripts/post-create.sh"
fi

echo "Running as: $(whoami)"

# Make aixcl executable
chmod +x ./aixcl

# Check environment
echo ""
echo "Checking AIXCL environment..."
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
    grep "^PROFILE" .env 2>/dev/null || echo "PROFILE: not set (will use 'usr')"
else
    echo "No .env file found"
fi

echo ""
echo "=========================================="
echo "Post-create setup complete!"
echo ""
echo "Quick start commands:"
echo "  ./aixcl stack start --profile usr    # Start AIXCL services"
echo "  ./aixcl stack status                 # Check service status"
echo "  ./aixcl engine auto                  # Auto-detect engine"
echo "  ./aixcl models add qwen2.5-coder:0.5b # Add a model"
echo ""
echo "Services will be available at:"
echo "  - API: http://localhost:11434"
echo "  - Open WebUI: http://localhost:8080"
echo "=========================================="
