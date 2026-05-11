#!/usr/bin/env bash
#
# Start AIXCL Devcontainer with Podman (Rootless)
#
# Usage: ./scripts/utils/start-devcontainer-podman.sh
#
# This script starts the devcontainer using rootless Podman instead of Docker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Starting AIXCL Devcontainer with Podman (Rootless)"

# Check prerequisites
check_prerequisites() {
  if ! command -v podman &> /dev/null; then
    log_error "Podman is not installed"
    exit 1
  fi

  # Check if podman socket is running
  if [[ ! -S "/run/user/$(id -u)/podman/podman.sock" ]]; then
    log_warn "Podman socket not found. Starting..."
    systemctl --user start podman.socket || {
      log_error "Failed to start Podman socket"
      exit 1
    }
  fi

  log_info "Podman socket: READY"
}

# Export environment for podman compose
setup_environment() {
  local user_id
  user_id=$(id -u)
  export DOCKER_HOST="unix:///run/user/$user_id/podman/podman.sock"
  export CONTAINER_ENGINE=podman
  log_info "DOCKER_HOST set to: $DOCKER_HOST"
}

# Start devcontainer
start_devcontainer() {
  cd "$PROJECT_ROOT"

  log_info "Building and starting devcontainer..."
  
  # Use podman compose with Podman-specific overrides
  podman compose \
    -f .devcontainer/docker-compose.podman.yml \
    up -d --build

  log_info "Devcontainer started successfully!"
  log_info ""
  log_info "To enter the container:"
  log_info "  podman exec -it aixcl-devcontainer-1 /bin/bash"
  log_info ""
  log_info "To stop:"
  log_info "  podman compose -f .devcontainer/docker-compose.podman.yml down"
}

# Main
main() {
  check_prerequisites
  setup_environment
  start_devcontainer
}

main "$@"
