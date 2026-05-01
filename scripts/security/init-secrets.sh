#!/bin/bash
#
# Docker Secrets Management for AIXCL
# Phase 1.6: Secure credential management without plaintext .env
#
# Usage:
#   ./scripts/security/init-secrets.sh              # Initialize all secrets
#   ./scripts/security/init-secrets.sh --rotate   # Rotate all secrets
#   ./scripts/security/init-secrets.sh --clean    # Remove all secrets (DANGER)
#   ./scripts/security/init-secrets.sh --verify   # Verify secrets exist
#
# Security: Secrets are stored in Docker's secrets backend, not in files
#          This script generates secrets using /dev/urandom (cryptographically secure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Secret definitions
SECRETS=(
  "postgres_user:postgres"
  "postgres_password:32"
  "pgadmin_email:pgadmin@localhost"
  "pgadmin_password:32"
  "openwebui_email:admin@localhost"
  "openwebui_password:32"
  "grafana_admin_user:grafana"
  "grafana_admin_password:32"
)

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Generate cryptographically secure random string
# Usage: generate_secret [length] or generate_secret [static_value]
generate_secret() {
  local value="$1"
  
  # If value is numeric, treat as length for random generation
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    # Use /dev/urandom for cryptographically secure random generation
    # Filter to alphanumeric characters for compatibility
    head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c "$value"
  else
    # Static value (email, username, etc.)
    echo "$value"
  fi
}

# Create Docker secret from value
create_secret() {
  local name="$1"
  local value="$2"
  
  # Remove existing secret if rotating
  if docker secret ls -q -f "name=${name}" | grep -q .; then
    log_warn "Secret ${name} exists, removing..."
    docker secret rm "${name}" 2>/dev/null || true
  fi
  
  # Create new secret
  echo -n "$value" | docker secret create "${name}" - 2>/dev/null || {
    log_error "Failed to create secret: ${name}"
    return 1
  }
  
  log_info "Created secret: ${name}"
}

# Create derived secrets (composite values like DATABASE_URL)
# Note: These use the values we just created, not reading from Docker
create_derived_secrets() {
  log_info "Creating derived secrets..."
  
  # Create derived secrets using environment (already set by init_secrets)
  local pg_user pg_pass pg_db
  pg_user="${POSTGRES_USER:-admin}"
  pg_pass="${POSTGRES_PASSWORD:-}"
  pg_db="${POSTGRES_DATABASE:-webui}"
  
  # Create DATABASE_URL (with SSL mode=require)
  local db_url="postgresql://${pg_user}:${pg_pass}@127.0.0.1:5432/${pg_db}?sslmode=require"
  create_secret "database_url" "$db_url"
  
  # Create postgres_exporter DSN (with SSL mode=require)
  local exporter_dsn="postgresql://${pg_user}:${pg_pass}@127.0.0.1:5432/${pg_db}?sslmode=require"
  create_secret "postgres_exporter_dsn" "$exporter_dsn"
}

# Initialize all secrets
init_secrets() {
  log_info "Initializing Docker secrets for AIXCL..."
  
  # Check if Docker is available
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
  fi
  
  # Check if we can access Docker
  if ! docker info &> /dev/null; then
    log_error "Cannot connect to Docker daemon. Are you in the docker group?"
    exit 1
  fi
  
  # Check if swarm mode is active (required for secrets)
  if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    log_warn "Docker Swarm mode is not active. Initializing..."
    docker swarm init --advertise-addr 127.0.0.1 2>/dev/null || {
      log_warn "Swarm init may have failed - this is OK if already in swarm"
    }
  fi
  
  log_info "Creating secrets..."
  
  # Create each secret
  for secret_def in "${SECRETS[@]}"; do
    IFS=':' read -r name value <<< "$secret_def"
    
    # Check if value should be read from .env
    local env_var
    env_var=$(echo "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    
    if [[ -f "$ENV_FILE" ]]; then
      local env_value
      env_value=$(grep -E "^${env_var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | head -1 || true)
      
      # For passwords, generate new secure value if not in .env or if --rotate
      if [[ "$value" =~ ^[0-9]+$ ]]; then
        if [[ -z "$env_value" ]] || [[ "${ROTATE:-false}" == "true" ]]; then
          value=$(generate_secret "$value")
          log_info "Generated new password for ${name}"
        else
          value="$env_value"
          log_info "Using existing value from .env for ${name}"
        fi
      else
        # For non-passwords (emails, usernames), prefer .env if available
        if [[ -n "$env_value" ]]; then
          value="$env_value"
          log_info "Using existing value from .env for ${name}"
        fi
      fi
    else
      # No .env file, generate everything
      value=$(generate_secret "$value")
    fi
    
    # Export credential variables for derived secrets function
    case "$name" in
      postgres_user) export POSTGRES_USER="$value" ;;
      postgres_password) export POSTGRES_PASSWORD="$value" ;;
      pgadmin_email) export PGADMIN_EMAIL="$value" ;;
      pgadmin_password) export PGADMIN_PASSWORD="$value" ;;
      openwebui_email) export OPENWEBUI_EMAIL="$value" ;;
      openwebui_password) export OPENWEBUI_PASSWORD="$value" ;;
      grafana_admin_user) export GRAFANA_ADMIN_USER="$value" ;;
      grafana_admin_password) export GRAFANA_ADMIN_PASSWORD="$value" ;;
    esac
    
    create_secret "$name" "$value"
  done
  
  # Create derived secrets
  create_derived_secrets
  
  log_info "All secrets initialized successfully!"
  log_info ""
  log_info "To use secrets, run:"
  log_info "  docker compose -f services/docker-compose.yml -f services/docker-compose.secrets.yml up"
  log_info ""
  log_info "Or use the convenience script:"
  log_info "  ./scripts/security/start-with-secrets.sh"
}

# Rotate all secrets
rotate_secrets() {
  log_warn "Rotating all secrets. This will invalidate existing sessions!"
  read -p "Are you sure? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Aborted"
    exit 0
  fi
  
  export ROTATE=true
  init_secrets
  
  log_info "Secrets rotated successfully!"
  log_warn "You must restart all services to apply new secrets"
}

# Clean up all secrets
clean_secrets() {
  log_warn "This will DELETE all Docker secrets!"
  read -p "Are you absolutely sure? Type 'DELETE' to confirm: " -r
  if [[ "$REPLY" != "DELETE" ]]; then
    log_info "Aborted"
    exit 0
  fi
  
  log_info "Removing all AIXCL secrets..."
  
  for secret_def in "${SECRETS[@]}"; do
    IFS=':' read -r name _ <<< "$secret_def"
    if docker secret ls -q -f "name=${name}" | grep -q .; then
      docker secret rm "${name}" 2>/dev/null || true
      log_info "Removed: ${name}"
    fi
  done
  
  # Remove derived secrets
  for derived in database_url postgres_exporter_dsn; do
    if docker secret ls -q -f "name=${derived}" | grep -q .; then
      docker secret rm "${derived}" 2>/dev/null || true
      log_info "Removed: ${derived}"
    fi
  done
  
  log_info "All secrets removed"
}

# Verify secrets exist
verify_secrets() {
  log_info "Verifying Docker secrets..."
  
  local all_exist=true
  
  for secret_def in "${SECRETS[@]}"; do
    IFS=':' read -r name _ <<< "$secret_def"
    if docker secret ls -q -f "name=${name}" | grep -q .; then
      log_info "[OK] ${name} exists"
    else
      log_error "[MISSING] ${name}"
      all_exist=false
    fi
  done
  
  # Check derived secrets
  for derived in database_url postgres_exporter_dsn; do
    if docker secret ls -q -f "name=${derived}" | grep -q .; then
      log_info "[OK] ${derived} exists"
    else
      log_error "[MISSING] ${derived}"
      all_exist=false
    fi
  done
  
  if $all_exist; then
    log_info "All secrets verified successfully!"
    return 0
  else
    log_error "Some secrets are missing. Run: ./scripts/security/init-secrets.sh"
    return 1
  fi
}

# Show usage
usage() {
  cat << EOF
AIXCL Docker Secrets Management

Usage: $0 [OPTION]

Options:
  (none)        Initialize all secrets (default)
  --rotate      Rotate all secrets (generates new passwords)
  --clean       Remove all secrets (DANGER - data loss)
  --verify      Verify all secrets exist
  --help        Show this help message

Examples:
  $0                    # First-time setup
  $0 --rotate          # Rotate compromised credentials
  $0 --verify          # Check secrets before starting services

Security Notes:
  - Secrets are stored in Docker's encrypted secrets backend
  - Passwords are generated using /dev/urandom (CSPRNG)
  - Existing .env values are preserved during migration
  - Derived secrets (DATABASE_URL) are created automatically
EOF
}

# Main
case "${1:-}" in
  --rotate)
    rotate_secrets
    ;;
  --clean)
    clean_secrets
    ;;
  --verify)
    verify_secrets
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "")
    init_secrets
    ;;
  *)
    log_error "Unknown option: $1"
    usage
    exit 1
    ;;
esac
