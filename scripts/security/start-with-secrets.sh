#!/usr/bin/env bash
#
# Start AIXCL with Docker Secrets
#
# Convenience script to start the stack using Docker secrets instead of .env
# This ensures credentials are never exposed in environment variables
#
# Usage: ./scripts/security/start-with-secrets.sh [profile]
#   profile: bld, sys

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROFILE="${1:-sys}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Starting AIXCL with Docker Secrets (profile: ${PROFILE})"

# Verify secrets exist
if ! "${SCRIPT_DIR}/init-secrets.sh" --verify >/dev/null 2>&1; then
  log_warn "Secrets not initialized. Running init-secrets.sh..."
  "${SCRIPT_DIR}/init-secrets.sh"
fi

# Determine which compose files to use
COMPOSE_FILES=("-f" "${PROJECT_ROOT}/services/docker-compose.yml")
COMPOSE_FILES+=("-f" "${PROJECT_ROOT}/services/docker-compose.secrets.yml")

# Add profile-specific compose files if they exist
case "$PROFILE" in
  gpu)
    if [[ -f "${PROJECT_ROOT}/services/docker-compose.gpu.yml" ]]; then
      COMPOSE_FILES+=("-f" "${PROJECT_ROOT}/services/docker-compose.gpu.yml")
      log_info "Adding GPU support"
    fi
    ;;
  arm)
    if [[ -f "${PROJECT_ROOT}/services/docker-compose.arm.yml" ]]; then
      COMPOSE_FILES+=("-f" "${PROJECT_ROOT}/services/docker-compose.arm.yml")
      log_info "Adding ARM64 support"
    fi
    ;;
esac

cd "$PROJECT_ROOT"

# Export for docker compose
export COMPOSE_FILE="services/docker-compose.yml:services/docker-compose.secrets.yml"

log_info "Starting services with Docker secrets..."
log_info "Compose files: ${COMPOSE_FILES[*]}"

# Start the stack
docker compose "${COMPOSE_FILES[@]}" up -d

log_info "Services started successfully!"
log_info ""
log_info "Services available at:"
log_info "  - Open WebUI:  http://localhost:8080"
log_info "  - Grafana:     http://localhost:3000"
log_info "  - Prometheus:  http://localhost:9090"
log_info "  - pgAdmin:     http://localhost:5050"
log_info ""
log_info "All credentials are securely managed via Docker secrets"
log_info "To view logs: docker compose -f services/docker-compose.yml -f services/docker-compose.secrets.yml logs -f"
log_info "To stop:      docker compose -f services/docker-compose.yml -f services/docker-compose.secrets.yml down"
