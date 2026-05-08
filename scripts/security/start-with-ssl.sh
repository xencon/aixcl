#!/usr/bin/env bash
#
# Start AIXCL with PostgreSQL SSL
#
# Convenience script to start the stack using PostgreSQL SSL encryption
# This ensures database connections are encrypted in transit
#
# Prerequisites:
#   ./scripts/security/init-postgres-ssl.sh
#
# Usage: ./scripts/security/start-with-ssl.sh [profile]
#   profile: bld, sys

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROFILE="${1:-dev}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Starting AIXCL with PostgreSQL SSL (profile: ${PROFILE})"

# Verify SSL certificates exist
CERT_DIR="${PROJECT_ROOT}/.security/postgres-certs"
if [[ ! -f "${CERT_DIR}/server-cert.pem" ]] || [[ ! -f "${CERT_DIR}/server-key.pem" ]]; then
  log_warn "SSL certificates not found. Generating..."
  "${SCRIPT_DIR}/init-postgres-ssl.sh"
fi

# Verify certificates
if ! "${SCRIPT_DIR}/init-postgres-ssl.sh" --verify >/dev/null 2>&1; then
  log_error "SSL certificate verification failed"
  exit 1
fi

# Determine which compose files to use
COMPOSE_FILES=("-f" "${PROJECT_ROOT}/services/docker-compose.yml")
COMPOSE_FILES+=("-f" "${PROJECT_ROOT}/services/docker-compose.postgres-ssl.yml")

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

log_info "Starting services with PostgreSQL SSL..."
log_info "SSL certificates: ${CERT_DIR}"
log_info "SSL mode: require (encryption mandatory)"

# Start the stack
docker compose "${COMPOSE_FILES[@]}" up -d

log_info "Services started successfully with SSL encryption!"
log_info ""
log_info "Database connections are now encrypted (sslmode=require)"
log_info "Certificate valid for 365 days from generation"
log_info ""
log_info "To view logs: docker compose -f services/docker-compose.yml -f services/docker-compose.postgres-ssl.yml logs -f"
log_info "To stop:      docker compose -f services/docker-compose.yml -f services/docker-compose.postgres-ssl.yml down"
