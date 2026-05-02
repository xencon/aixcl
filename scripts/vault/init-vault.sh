#!/usr/bin/env bash
#
# Initialize HashiCorp Vault for AIXCL
# Sets up PostgreSQL dynamic credentials and policies
#
# Usage: ./scripts/vault/init-vault.sh [vault-address] [root-token]

set -euo pipefail

VAULT_ADDR="${1:-http://127.0.0.1:8200}"
VAULT_TOKEN="${2:-aixcl-dev-token}"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }

export VAULT_ADDR
export VAULT_TOKEN

# Wait for Vault to be ready
wait_for_vault() {
  log_info "Waiting for Vault to be ready..."
  local retries=30
  while [[ $retries -gt 0 ]]; do
    if vault status 2>&1 | grep -q "Sealed.*false"; then
      log_info "Vault is ready (unsealed)"
      return 0
    fi
    if vault status 2>&1 | grep -q "Dev.*mode"; then
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

# Configure PostgreSQL connection
configure_postgres_connection() {
  log_info "Configuring PostgreSQL connection..."
  
  vault write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="aixcl-app,aixcl-admin" \
    connection_url="postgresql://{{username}}:{{password}}@127.0.0.1:5432/webui?sslmode=disable" \
    username="admin" \
    password="admin"
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
  
  local creds
  creds=$(vault read -format=json database/creds/aixcl-app 2>/dev/null) || {
    log_error "Failed to generate credentials"
    return 1
  }
  
  local username password
  username=$(echo "$creds" | jq -r '.data.username')
  # shellcheck disable=SC2034
  password=$(echo "$creds" | jq -r '.data.password')
  
  log_info "Generated credentials:"
  log_info "  Username: $username"
  log_info "  Password: [REDACTED]"
  log_info "  TTL: 1 hour (auto-expires)"
  
  # Revoke test credentials
  vault lease revoke "$(echo "$creds" | jq -r '.lease_id')" >/dev/null 2>&1 || true
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
    test_credentials
    
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
