#!/bin/bash
# setup-rootless-env.sh - Configure persistent rootless Podman environment
# Run this script once to set up your shell for rootless Podman

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Setting up rootless Podman environment..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run as root"
    exit 1
fi

# Enable linger (survives logout)
echo -e "${YELLOW}Enabling user lingering (survives logout)...${NC}"
loginctl enable-linger "$USER"
echo -e "${GREEN}Linger enabled${NC}"

# Check if already in .bashrc
if grep -q "DOCKER_BIN=podman" ~/.bashrc; then
    echo -e "${YELLOW}Podman environment already configured in ~/.bashrc${NC}"
else
    echo -e "${YELLOW}Adding Podman environment to ~/.bashrc...${NC}"
    cat >> ~/.bashrc << 'EOF'

# AIXCL Rootless Podman Configuration
export DOCKER_BIN=podman
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
EOF
    echo -e "${GREEN}Environment variables added to ~/.bashrc${NC}"
fi

# Source for current session
echo -e "${YELLOW}Sourcing environment for current session...${NC}"
export DOCKER_BIN=podman
export DOCKER_HOST="unix:///run/user/$(id - u)/podman/podman.sock"

# Verify podman socket
echo -e "${YELLOW}Verifying Podman socket...${NC}"
if [ ! -S "$DOCKER_HOST" ]; then
    echo "Starting Podman socket..."
    systemctl --user start podman.socket 2>/dev/null || podman system service --time=0 unix://"$DOCKER_HOST" &�&�
    sleep 2
fi

echo -e "${GREEN}Rootless Podman environment configured!${NC}"
echo ""
echo "Environment variables:"
echo "  DOCKER_BIN=$DOCKER_BIN"
echo "  DOCKER_HOST=$DOCKER_HOST"
echo ""
echo "To verify:"
echo "  ./aixcl stack status"
echo ""
echo "Note: Run 'source ~/.bashrc' or open a new terminal for changes to take effect"
