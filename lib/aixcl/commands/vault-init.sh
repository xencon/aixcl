#!/usr/bin/env bash
#
# Vault initialization command - Idempotent and safe to run multiple times
# Part of AIXCL CLI: ./aixcl vault init
#

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-aixcl-dev-token}"
AIXCL_VERBOSE="${AIXCL_VERBOSE:-0}"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }
log_verbose() { [ "$AIXCL_VERBOSE" -eq 1 ] && echo "[DEBUG] $1" || true; }

export VAULT_ADDR
export VAULT_TOKEN

# Check if Vault is running
is_vault_running() {
    if command -v podman >/dev/null 2>&1; then
        podman ps --format "{{.Names}}" | grep -q "^vault$"
    elif command -v docker >/dev/null 2>&1; then
        docker ps --format "{{.Names}}" | grep -q "^vault$"
    else
        return 1
    fi
}

# Generate a random password
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c "${length}"
}

# Check if KV store is enabled
is_kv_enabled() {
    local secrets
    secrets=$(curl -sf "${VAULT_ADDR}/v1/sys/mounts" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    
    if echo "$secrets" | grep -q "^kv/"; then
        log_verbose "KV secrets engine already enabled"
        return 0
    fi
    return 1
}

# Enable KV secrets engine v2 (idempotent)
enable_kv_engine() {
    if is_kv_enabled; then
        log_info "KV secrets engine already enabled (skipping)"
        return 0
    fi
    
    log_info "Enabling KV secrets engine v2..."
    local result
    result=$(curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/kv" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"type": "kv", "options": {"version": "2"}}' 2>/dev/null || echo "exists")
    
    if [ "$result" != "exists" ]; then
        log_info "KV secrets engine v2 enabled"
    else
        log_warn "KV engine may already be enabled (continuing)"
    fi
}

# Generate a secure random password
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c "${length}"
}

# Check if bootstrap password exists in KV
bootstrap_password_exists() {
    local service="$1"
    local password_data
    password_data=$(curl -sf "${VAULT_ADDR}/v1/kv/data/bootstrap/${service}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    
    if [ -n "$password_data" ] && echo "$password_data" | jq -e '.data.data.password' >/dev/null 2>&1; then
        log_verbose "Bootstrap password for ${service} already exists"
        return 0
    fi
    return 1
}

# Store bootstrap password in KV
store_bootstrap_password() {
    local service="$1"
    local password="$2"
    local description="$3"
    local email="${4:-admin@example.com}"
    local username="${5:-admin}"
    
    log_info "Storing bootstrap password for ${service}..."
    
    curl -sf -X POST "${VAULT_ADDR}/v1/kv/data/bootstrap/${service}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"password\": \"${password}\", \"email\": \"${email}\", \"username\": \"${username}\", \"description\": \"${description}\", \"created\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" 2>/dev/null || {
        log_warn "Failed to store bootstrap password for ${service}"
        return 1
    }
    
    log_info "Bootstrap password for ${service} stored in Vault KV"
}

# Initialize bootstrap passwords
init_bootstrap_passwords() {
    log_info "Initializing bootstrap passwords..."
    
    # Check if we need to migrate from .env
    local env_file
    if [ -n "${SCRIPT_DIR:-}" ] && [ -f "${SCRIPT_DIR}/.env" ]; then
        env_file="${SCRIPT_DIR}/.env"
    elif [ -f ".env" ]; then
        env_file=".env"
    else
        env_file=""
    fi
    # Read admin identity from .env if available
    local admin_email="${AIXCL_ADMIN_EMAIL:-admin@example.com}"
    local admin_user="${AIXCL_ADMIN_USER:-admin}"
    
    log_info "Admin identity: ${admin_user} / ${admin_email}"
    
    # PostgreSQL bootstrap password
    if ! bootstrap_password_exists "postgres"; then
        local random_password
        random_password=$(generate_password 32)
        store_bootstrap_password "postgres" "$random_password" "PostgreSQL admin/bootstrap password" "$admin_email" "$admin_user"
        log_info "Generated PostgreSQL bootstrap password: ${random_password}"
    else
        log_info "PostgreSQL bootstrap password already exists in Vault KV (skipping)"
    fi
    
    # Open WebUI bootstrap password
    if ! bootstrap_password_exists "openwebui"; then
        local random_password
        random_password=$(generate_password 32)
        store_bootstrap_password "openwebui" "$random_password" "Open WebUI admin password" "$admin_email" "$admin_user"
        log_info "Generated Open WebUI bootstrap password: ${random_password}"
    else
        log_info "Open WebUI bootstrap password already exists in Vault KV (skipping)"
    fi
    
    # pgAdmin bootstrap password
    if ! bootstrap_password_exists "pgadmin"; then
        # Generate random password for pgAdmin
        local random_password
        random_password=$(generate_password 32)
        store_bootstrap_password "pgadmin" "$random_password" "pgAdmin admin password" "$admin_email" "$admin_user"
        
        # Show the generated password
        log_info "Generated pgAdmin bootstrap password: ${random_password}"
    else
        log_info "pgAdmin bootstrap password already exists in Vault KV (skipping)"
    fi
    
    # Grafana bootstrap password
    if ! bootstrap_password_exists "grafana"; then
        local random_password
        random_password=$(generate_password 32)
        store_bootstrap_password "grafana" "$random_password" "Grafana admin password" "$admin_email" "$admin_user"
        
        # Show the generated password
        log_info "Generated Grafana bootstrap password: ${random_password}"
    else
        log_info "Grafana bootstrap password already exists in Vault KV (skipping)"
    fi
    
    log_info "Bootstrap passwords initialized"
}

# Wait for Vault to be ready using REST API
wait_for_vault() {
    log_info "Waiting for Vault to be ready..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        local health
        health=$(curl -sf "${VAULT_ADDR}/v1/sys/health" 2>/dev/null | jq -r '.sealed // "unreachable"')
        
        if [ "$health" = "false" ]; then
            log_verbose "Vault is ready (unsealed)"
            return 0
        fi
        
        # Check for dev mode
        local version
        version=$(curl -sf "${VAULT_ADDR}/v1/sys/health" 2>/dev/null | jq -r '.version // ""')
        if [ -n "$version" ]; then
            log_verbose "Vault is ready (dev mode)"
            return 0
        fi
        
        sleep 2
        retries=$((retries - 1))
    done
    log_error "Vault failed to become ready within 60 seconds"
    return 1
}

# Check if database engine is enabled
is_database_enabled() {
    local secrets
    secrets=$(curl -sf "${VAULT_ADDR}/v1/sys/mounts" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    
    if echo "$secrets" | grep -q "^database/"; then
        log_verbose "Database secrets engine already enabled"
        return 0
    fi
    return 1
}

# Enable database secrets engine (idempotent)
enable_database_engine() {
    if is_database_enabled; then
        log_info "Database secrets engine already enabled (skipping)"
        return 0
    fi
    
    log_info "Enabling database secrets engine..."
    local result
    result=$(curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/database" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"type": "database"}' 2>/dev/null || echo "exists")
    
    if [ "$result" != "exists" ]; then
        log_info "Database secrets engine enabled"
    else
        log_warn "Database engine may already be enabled (continuing)"
    fi
}

# Check if PostgreSQL connection exists
is_postgres_configured() {
    local config
    config=$(curl -sf "${VAULT_ADDR}/v1/database/config/postgresql" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    
    if [ -n "$config" ] && echo "$config" | jq -e '.data' >/dev/null 2>&1; then
        log_verbose "PostgreSQL connection already configured"
        return 0
    fi
    return 1
}

# Configure PostgreSQL connection (idempotent)
configure_postgres_connection() {
    if is_postgres_configured; then
        log_info "PostgreSQL connection already configured (skipping)"
        return 0
    fi
    
    log_info "Configuring PostgreSQL connection..."
    
    # Check if PostgreSQL is running
    if ! (podman ps --format "{{.Names}}" | grep -q "^postgres$" || \
          docker ps --format "{{.Names}}" | grep -q "^postgres$" 2>/dev/null); then
        log_warn "PostgreSQL container not running - will configure Vault anyway"
        log_warn "You may need to re-run init after PostgreSQL starts"
    fi
    
    # Fetch the actual PostgreSQL bootstrap password
    local postgres_password
    local postgres_user="${POSTGRES_USER:-admin}"
    
    # Source 1: Vault KV (primary - survives restarts if Vault data persists)
    postgres_password=$(curl -sf "${VAULT_ADDR}/v1/kv/data/bootstrap/postgres" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data.data.password // empty')
    if [ -n "$postgres_password" ]; then
        log_info "Retrieved PostgreSQL bootstrap password from Vault KV"
    fi
    
    # Source 2: Read from PostgreSQL container secrets volume (fallback)
    if [ -z "$postgres_password" ] && command -v podman >/dev/null 2>&1; then
        postgres_password=$(podman exec postgres cat /run/secrets/postgres-password 2>/dev/null | tr -d '\n' || true)
        if [ -n "$postgres_password" ]; then
            log_info "Retrieved PostgreSQL bootstrap password from container secrets volume"
        fi
    fi
    
    if [ -z "$postgres_password" ] && command -v docker >/dev/null 2>&1; then
        postgres_password=$(docker exec postgres cat /run/secrets/postgres-password 2>/dev/null | tr -d '\n' || true)
        if [ -n "$postgres_password" ]; then
            log_info "Retrieved PostgreSQL bootstrap password from container secrets volume"
        fi
    fi
    
    if [ -z "$postgres_password" ]; then
        log_warn "Could not retrieve PostgreSQL bootstrap password"
        log_warn "Falling back to 'admin' — this will likely fail if bootstrap already ran"
        postgres_password="admin"
    fi
    
    curl -sf -X POST "${VAULT_ADDR}/v1/database/config/postgresql" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"plugin_name\": \"postgresql-database-plugin\",
            \"allowed_roles\": \"aixcl-app,aixcl-admin,aixcl-readonly\",
            \"connection_url\": \"postgresql://{{username}}:{{password}}@127.0.0.1:5432/webui?sslmode=disable\",
            \"username\": \"${postgres_user}\",
            \"password\": \"${postgres_password}\"
        }" 2>/dev/null || {
        log_warn "Failed to configure PostgreSQL connection (may already exist)"
    }
}

# Check if role exists
role_exists() {
    local role_name="$1"
    local role_data
    role_data=$(curl -sf "${VAULT_ADDR}/v1/database/roles/$role_name" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    
    if [ -n "$role_data" ] && echo "$role_data" | jq -e '.data' >/dev/null 2>&1; then
        log_verbose "Role '$role_name' already exists"
        return 0
    fi
    return 1
}

# Create dynamic role for application (idempotent)
create_app_role() {
    if role_exists "aixcl-app"; then
        log_info "Application role already exists (skipping)"
        return 0
    fi
    
    log_info "Creating application role (short-lived credentials)..."
    
    curl -sf -X POST "${VAULT_ADDR}/v1/database/roles/aixcl-app" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "db_name": "postgresql",
            "creation_statements": "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT USAGE, CREATE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
            "default_ttl": "1h",
            "max_ttl": "24h"
        }' 2>/dev/null || {
        log_warn "Failed to create app role (may already exist)"
    }
}

# Create admin role for maintenance (idempotent)
create_admin_role() {
    if role_exists "aixcl-admin"; then
        log_info "Admin role already exists (skipping)"
        return 0
    fi
    
    log_info "Creating admin role (maintenance credentials)..."
    
    curl -sf -X POST "${VAULT_ADDR}/v1/database/roles/aixcl-admin" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "db_name": "postgresql",
            "creation_statements": "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
            "default_ttl": "15m",
            "max_ttl": "1h"
        }' 2>/dev/null || {
        log_warn "Failed to create admin role (may already exist)"
    }
}

# Create readonly role for monitoring (idempotent)
create_readonly_role() {
    if role_exists "aixcl-readonly"; then
        log_info "Readonly role already exists (skipping)"
        return 0
    fi
    
    log_info "Creating readonly role (monitoring credentials)..."
    
    curl -sf -X POST "${VAULT_ADDR}/v1/database/roles/aixcl-readonly" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "db_name": "postgresql",
            "creation_statements": "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
            "default_ttl": "1h",
            "max_ttl": "24h"
        }' 2>/dev/null || {
        log_warn "Failed to create readonly role (may already exist)"
    }
}

# Check if policy exists
policy_exists() {
    local policy_name="$1"
    local policy_data
    policy_data=$(curl -sf "${VAULT_ADDR}/v1/sys/policy/$policy_name" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    
    if [ -n "$policy_data" ] && echo "$policy_data" | jq -e '.data' >/dev/null 2>&1; then
        log_verbose "Policy '$policy_name' already exists"
        return 0
    fi
    return 1
}

# Create policies (idempotent)
create_policies() {
    # App policy
    if ! policy_exists "aixcl-app"; then
        log_info "Creating aixcl-app policy..."
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policy/aixcl-app" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "policy": "path \"database/creds/aixcl-app\" { capabilities = [\"read\"] }\npath \"database/creds/aixcl-readonly\" { capabilities = [\"read\"] }\npath \"database/creds/aixcl-admin\" { capabilities = [\"deny\"] }"
            }' 2>/dev/null || log_warn "Failed to create aixcl-app policy"
    else
        log_info "aixcl-app policy already exists (skipping)"
    fi
    
    # Admin policy
    if ! policy_exists "aixcl-admin"; then
        log_info "Creating aixcl-admin policy..."
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policy/aixcl-admin" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "policy": "path \"database/creds/*\" { capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"] }\npath \"database/roles/*\" { capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"] }\npath \"database/config/*\" { capabilities = [\"read\"] }"
            }' 2>/dev/null || log_warn "Failed to create aixcl-admin policy"
    else
        log_info "aixcl-admin policy already exists (skipping)"
    fi
    
    # Readonly policy for exporters
    if ! policy_exists "aixcl-readonly"; then
        log_info "Creating aixcl-readonly policy..."
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policy/aixcl-readonly" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "policy": "path \"database/creds/aixcl-readonly\" { capabilities = [\"read\"] }"
            }' 2>/dev/null || log_warn "Failed to create aixcl-readonly policy"
    else
        log_info "aixcl-readonly policy already exists (skipping)"
    fi
}

# Check if AppRole is enabled
is_approle_enabled() {
    local auths
    auths=$(curl -sf "${VAULT_ADDR}/v1/sys/auth" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    
    if echo "$auths" | grep -q "^approle/"; then
        log_verbose "AppRole auth already enabled"
        return 0
    fi
    return 1
}

# Enable AppRole auth for services (idempotent)
enable_approle_auth() {
    if is_approle_enabled; then
        log_info "AppRole authentication already enabled (skipping)"
    else
        log_info "Enabling AppRole authentication..."
        curl -sf -X POST "${VAULT_ADDR}/v1/sys/auth/approle" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"type": "approle"}' 2>/dev/null || log_warn "AppRole may already be enabled"
    fi
    
    # Create/update AppRoles
    log_info "Configuring AppRoles for services..."
    
    curl -sf -X POST "${VAULT_ADDR}/v1/auth/approle/role/aixcl-open-webui" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"token_policies": "aixcl-app", "token_ttl": "1h", "token_max_ttl": "24h"}' 2>/dev/null || log_verbose "Open WebUI AppRole configured"
    
    curl -sf -X POST "${VAULT_ADDR}/v1/auth/approle/role/aixcl-postgres-exporter" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"token_policies": "aixcl-readonly", "token_ttl": "1h", "token_max_ttl": "24h"}' 2>/dev/null || log_verbose "Postgres Exporter AppRole configured"
}

# Check if audit logging is enabled
is_audit_enabled() {
    local audits
    audits=$(curl -sf "${VAULT_ADDR}/v1/sys/audit" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    
    if echo "$audits" | grep -q "^file/"; then
        log_verbose "Audit logging already enabled"
        return 0
    fi
    return 1
}

# Enable audit logging (idempotent)
enable_audit_logging() {
    if is_audit_enabled; then
        log_info "Audit logging already enabled (skipping)"
        return 0
    fi
    
    log_info "Enabling audit logging..."
    curl -sf -X PUT "${VAULT_ADDR}/v1/sys/audit/file" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"type": "file", "options": {"file_path": "/vault/logs/audit.log"}}' 2>/dev/null || log_warn "Audit may already be enabled"
    log_info "Audit logs: /vault/logs/audit.log"
}

# Test credential generation
test_credentials() {
    log_info "Testing credential generation..."
    
    local creds
    creds=$(curl -sf "${VAULT_ADDR}/v1/database/creds/aixcl-app" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    
    if [ -z "$creds" ] || ! echo "$creds" | jq -e '.data' >/dev/null 2>&1; then
        log_warn "Failed to generate test credentials (PostgreSQL may not be ready)"
        log_warn "This is OK if PostgreSQL hasn't started yet - Vault is initialized"
        return 0
    fi
    
    local username
    username=$(echo "$creds" | jq -r '.data.username' 2>/dev/null || echo "unknown")
    
    log_info "Generated test credentials successfully:"
    log_info "  Username: $username"
    log_info "  Password: [REDACTED]"
    log_info "  TTL: 1 hour (auto-expires)"
    
    # Revoke test credentials
    local lease_id
    lease_id=$(echo "$creds" | jq -r '.lease_id' 2>/dev/null || true)
    if [ -n "$lease_id" ] && [ "$lease_id" != "null" ]; then
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/leases/revoke" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"lease_id\": \"$lease_id\"}" >/dev/null 2>&1 || true
    fi
}

# Show initialization summary
show_summary() {
    log_info ""
    log_info "=========================================="
    log_info "  Vault Initialization Complete"
    log_info "=========================================="
    log_info ""
    log_info "Dynamic credentials are now available:"
    log_info "  ./aixcl vault credentials"
    log_info ""
    log_info "Bootstrap passwords stored in Vault KV:"
    log_info "  ./aixcl vault passwords    # View static bootstrap credentials"
    log_info ""
    log_info "Service credentials auto-rotate:"
    log_info "  - Open WebUI: Every 1 hour"
    log_info "  - Postgres Exporter: Every 1 hour"
    log_info ""
    log_info "Audit logging enabled for compliance"
    log_info ""
    
    # Show credential locations
    if [ -d "/tmp/aixcl-secrets" ]; then
        log_info "Generated credentials stored in:"
        ls -1 /tmp/aixcl-secrets/ 2>&1 | sed 's/^/  - /' || true
        log_info ""
    fi
    
    # Warn about .env passwords if they still exist
    local env_file=""
    if [ -n "${SCRIPT_DIR:-}" ]; then
        env_file="${SCRIPT_DIR}/.env"
    fi
    if [ -n "$env_file" ] && [ -f "$env_file" ]; then
        if grep -q "^POSTGRES_PASSWORD=\|^OPENWEBUI_PASSWORD=" "$env_file" 2>/dev/null; then
            log_warn "NOTE: Passwords still exist in .env file"
            log_warn "      Run the following to complete migration:"
            log_warn "      1. ./aixcl vault passwords    # Verify passwords work"
            log_warn "      2. Remove POSTGRES_PASSWORD and OPENWEBUI_PASSWORD from .env"
            log_warn "      3. Restart stack: ./aixcl stack restart"
            log_info ""
        fi
    fi
}

# Main initialization
main() {
    log_info "Starting Vault initialization..."
    log_info "Vault address: $VAULT_ADDR"
    
    # Check if Vault is running
    if ! is_vault_running; then
        log_error "Vault container is not running"
        log_error "Start the stack first: ./aixcl stack start --profile sys"
        return 1
    fi
    
    # Wait for Vault
    if ! wait_for_vault; then
        log_error "Vault is not responding"
        log_error "Check status: podman logs vault"
        return 1
    fi
    
    # Run initialization steps (all idempotent)
    enable_database_engine
    enable_kv_engine
    configure_postgres_connection
    create_app_role
    create_admin_role
    create_readonly_role
    create_policies
    enable_approle_auth
    enable_audit_logging
    init_bootstrap_passwords
    test_credentials
    
    show_summary
    
    return 0
}

# Run main function
main "$@"
