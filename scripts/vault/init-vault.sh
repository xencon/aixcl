#!/bin/sh
# shellcheck shell=sh
#
# Initialize HashiCorp Vault for AIXCL (container-side script)
# This script runs inside the Vault container (hashicorp/vault:1.18) which
# uses busybox /bin/sh and does NOT have /bin/bash or jq.
#
# Usage in docker-compose:
#   command: /usr/local/bin/init-vault.sh

set -eu

VAULT_ADDR="${1:-http://127.0.0.1:8200}"
VAULT_TOKEN="${2:-${VAULT_DEV_TOKEN:-aixcl-dev-token}}"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }

export VAULT_ADDR
export VAULT_TOKEN

# Wait for Vault to be ready
wait_for_vault() {
  log_info "Waiting for Vault to be ready..."
  local retries=60
  while [ $retries -gt 0 ]; do
    output=$(vault status 2>&1 || true)
    if echo "$output" | grep -q "Sealed.*false"; then
      log_info "Vault is ready (unsealed)"
      return 0
    fi
    if echo "$output" | grep -q "Dev.*mode"; then
      log_info "Vault is ready (dev mode)"
      return 0
    fi
    sleep 2
    retries=$((retries - 1))
  done
  log_error "Vault failed to start"
  return 1
}

# Enable database secrets engine
enable_database_engine() {
  log_info "Enabling database secrets engine..."
  vault secrets enable database || log_warn "Database engine already enabled"
}

# Read PostgreSQL bootstrap password from Vault KV with retry
get_postgres_password() {
  local password=""
  local retries=60
  log_info "Waiting for bootstrap password in Vault KV..."
  while [ $retries -gt 0 ]; do
    password=$(vault kv get -field=password kv/bootstrap/postgres 2>/dev/null || true)
    if [ -n "$password" ]; then
      echo "$password"
      return 0
    fi
    log_warn "KV not ready yet, retrying... ($retries left)"
    sleep 2
    retries=$((retries - 1))
  done
  log_error "Could not read bootstrap password from Vault KV after 60 seconds"
  log_error "Ensure bootstrap agents have written to kv/bootstrap/postgres"
  return 1
}

# Configure PostgreSQL connection
configure_postgres_connection() {
  log_info "Configuring PostgreSQL connection..."

  local postgres_password
  if ! postgres_password=$(get_postgres_password); then
    log_error "Could not read bootstrap password from Vault KV"
    log_error "Ensure bootstrap agents have written to kv/bootstrap/postgres"
    log_error "Failing fast — no hardcoded fallback available"
    return 1
  fi

  vault write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="aixcl-app,aixcl-admin" \
    connection_url="postgresql://{{username}}:{{password}}@127.0.0.1:5432/webui?sslmode=disable" \
    username="admin" \
    password="$postgres_password"
}

# Create dynamic role for application
create_app_role() {
  log_info "Creating application role (short-lived credentials)..."

  vault write database/roles/aixcl-app \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
      GRANT USAGE, CREATE ON SCHEMA public TO \"{{name}}\"; \
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
}

# Create admin role for maintenance
create_admin_role() {
  log_info "Creating admin role (maintenance credentials)..."

  vault write database/roles/aixcl-admin \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="15m" \
    max_ttl="1h"
}

# Create policies
create_policies() {
  log_info "Creating Vault policies..."

  # App policy - can read own credentials
  vault policy write aixcl-app - << EOF
path "database/creds/aixcl-app" {
  capabilities = ["read"]
}

path "database/creds/aixcl-admin" {
  capabilities = ["deny"]
}
EOF

  # Admin policy - can create and manage
  vault policy write aixcl-admin - << EOF
path "database/creds/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "database/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "database/config/*" {
  capabilities = ["read"]
}
EOF
}

# Enable AppRole auth for services
enable_approle_auth() {
  log_info "Enabling AppRole authentication..."
  vault auth enable approle || log_warn "AppRole already enabled"

  # Create AppRoles for services
  vault write auth/approle/role/aixcl-open-webui \
    token_policies="aixcl-app" \
    token_ttl="1h" \
    token_max_ttl="24h"

  vault write auth/approle/role/aixcl-postgres-exporter \
    token_policies="aixcl-app" \
    token_ttl="1h" \
    token_max_ttl="24h"
}

# Generate credentials to test
test_credentials() {
  log_info "Testing credential generation..."

  local output
  output=$(vault read -format=json database/creds/aixcl-app 2>/dev/null || true)

  if [ -z "$output" ]; then
    log_warn "Failed to generate credentials (PostgreSQL may not be ready yet)"
    return 1
  fi

  local username password
  # Parse JSON without jq (busybox compatible)
  username=$(echo "$output" | grep '"username"' | sed 's/.*: "\(.*\)".*/\1/' | tr -d '[:space:],"')
  password=$(echo "$output" | grep '"password"' | sed 's/.*: "\(.*\)".*/\1/' | tr -d '[:space:],"')

  log_info "Generated credentials:"
  log_info "  Username: $username"
  log_info "  Password: [REDACTED]"
  log_info "  TTL: 1 hour (auto-expires)"

  # Revoke test credentials
  local lease_id
  lease_id=$(echo "$output" | grep '"lease_id"' | sed 's/.*: "\(.*\)".*/\1/' | tr -d '[:space:],"')
  if [ -n "$lease_id" ]; then
    vault lease revoke "$lease_id" >/dev/null 2>&1 || true
  fi
}

# Enable audit logging
enable_audit_logging() {
  log_info "Enabling audit logging..."

  vault audit enable file file_path=/vault/logs/audit.log || log_warn "Audit already enabled"
  log_info "Audit logs: /vault/logs/audit.log"
}

# Main
case "${1:-}" in
  --test)
    # Just test connection
    wait_for_vault
    vault status
    ;;
  --creds)
    # Generate and show credentials
    wait_for_vault
    vault read database/creds/aixcl-app
    ;;
  *)
    wait_for_vault
    enable_database_engine
    configure_postgres_connection
    create_app_role
    create_admin_role
    create_policies
    enable_approle_auth
    enable_audit_logging
    test_credentials || true

    log_info ""
    log_info "=== Vault Initialization Complete ==="
    log_info ""
    log_info "Dynamic credentials are now available:"
    log_info "  vault read database/creds/aixcl-app"
    log_info ""
    log_info "Credentials auto-expire after TTL (no manual cleanup)"
    log_info "Audit logging enabled for compliance"
    ;;
esac
