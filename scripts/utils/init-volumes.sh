#!/usr/bin/env bash
# Initialize external volumes for AIXCL
# This script creates external named volumes that are shared across contexts
# (local Docker, devcontainer, GitHub Codespaces)

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# List of AIXCL external volumes
VOLUMES=(
  "aixcl-ollama-data"
  "aixcl-hf-cache"
  "aixcl-vllm-data"
  "aixcl-llamacpp-data"
  "aixcl-open-webui"
  "aixcl-open-webui-data"
  "aixcl-pgdata"
  "aixcl-prometheus"
  "aixcl-grafana"
  "aixcl-loki"
  "aixcl-alertmanager-data"
  "aixcl-pgadmin-storage"
  "aixcl-pgadmin"
  "aixcl-pgadmin-config"
)

echo "AIXCL Volume Initialization"
echo "============================"
echo ""
echo "This script creates external Docker volumes for AIXCL."
echo "These volumes are shared across:"
echo "  - Local Docker (./aixcl stack start)"
echo "  - Devcontainer (docker compose -f .devcontainer/docker-compose.dev.yml)"
echo "  - GitHub Codespaces"
echo ""

# Detect Docker/Podman
DOCKER_BIN="${DOCKER_BIN:-docker}"
if command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
  DOCKER_BIN="podman"
fi

echo "Using container engine: $DOCKER_BIN"
echo ""

# Check if Docker/Podman is available
if ! command -v "$DOCKER_BIN" &> /dev/null; then
  echo -e "${RED}Error: $DOCKER_BIN not found${NC}"
  echo "Please install Docker or Podman"
  exit 1
fi

# Check if Docker daemon is running
if ! $DOCKER_BIN info &> /dev/null; then
  echo -e "${RED}Error: $DOCKER_BIN daemon is not running${NC}"
  echo "Please start the Docker/Podman daemon"
  exit 1
fi

# Create volumes
CREATED_COUNT=0
EXISTING_COUNT=0

for volume in "${VOLUMES[@]}"; do
  if $DOCKER_BIN volume inspect "$volume" &> /dev/null; then
    echo -e "${GREEN}[✓]${NC} Volume exists: $volume"
    EXISTING_COUNT=$((EXISTING_COUNT + 1))
  else
    echo -e "${YELLOW}[ ]${NC} Creating volume: $volume"
    if $DOCKER_BIN volume create "$volume" &> /dev/null; then
      echo -e "${GREEN}[✓]${NC} Created volume: $volume"
      CREATED_COUNT=$((CREATED_COUNT + 1))
    else
      echo -e "${RED}[✗]${NC} Failed to create volume: $volume"
      exit 1
    fi
  fi
done

echo ""
echo "Summary"
echo "======="
echo -e "Created: ${GREEN}$CREATED_COUNT${NC} new volumes"
echo -e "Existing: ${GREEN}$EXISTING_COUNT${NC} volumes"
echo ""
echo "All AIXCL volumes are ready!"
echo ""
echo "You can now run:"
echo "  ./aixcl stack start --profile <profile>"
echo ""
echo "Or for devcontainer:"
echo "  docker compose -f .devcontainer/docker-compose.dev.yml up -d"
echo ""
