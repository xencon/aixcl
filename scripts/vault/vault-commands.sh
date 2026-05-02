#!/bin/bash
# vault-commands.sh - Vault integration commands for AIXCL
# Usage: Source this file or run commands directly

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-aixcl-dev-token}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if Vault is running
vault_status() {
    local health_response
    health_response=$(curl -sf "${VAULT_ADDR}/v1/sys/health" 2>/dev/null || echo '{}')
    
    # In dev mode, Vault responds with version even when "sealed"
    local version
    version=$(echo "$health_response" | jq -r '.version // ""')
    if [ -n "$version" ]; then
        log_info "Vault is running (version: $version)"
        return 0
    fi
    
    local sealed
    sealed=$(echo "$health_response" | jq -r '.sealed // "unreachable"')
    
    case "$sealed" in
        "false")
            log_info "Vault is running and unsealed"
            return 0
            ;;
        "true")
            log_error "Vault is sealed"
            return 1
            ;;
        *)
            log_error "Vault is not responding at ${VAULT_ADDR}"
            return 1
            ;;
    esac
}

# Get database credentials from Vault
vault_credentials() {
    if ! vault_status; then
        return 1
    fi
    
    log_info "Fetching database credentials from Vault..."
    
    local creds
    creds=$(curl -sf "${VAULT_ADDR}/v1/database/creds/aixcl-app" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null)
    
    if [ -z "$creds" ]; then
        log_error "Failed to get credentials. Is Vault initialized?"
        return 1
    fi
    
    local username password lease_id ttl
    username=$(echo "$creds" | jq -r '.data.username')
    password=$(echo "$creds" | jq -r '.data.password')
    lease_id=$(echo "$creds" | jq -r '.lease_id')
    ttl=$(echo "$creds" | jq -r '.lease_duration')
    
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║           Database Credentials (Vault)                 ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Username: $username"
    echo "  Password: $password"
    echo "  TTL: ${ttl}s ($(($ttl / 60)) minutes)"
    echo "  Lease ID: $lease_id"
    echo ""
    echo "  Connection String:"
    echo "  postgresql://$username:$password@127.0.0.1:5432/webui?sslmode=disable"
    echo ""
    echo "  To connect via psql:"
    echo "  psql -U $username -d webui -h 127.0.0.1"
    echo ""
    echo "  Credentials auto-expire after ${ttl}s"
    echo ""
}

# Get admin credentials (shorter TTL)
vault_admin_credentials() {
    if ! vault_status; then
        return 1
    fi
    
    log_info "Fetching ADMIN database credentials from Vault..."
    
    local creds
    creds=$(curl -sf "${VAULT_ADDR}/v1/database/creds/aixcl-admin" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null)
    
    if [ -z "$creds" ]; then
        log_error "Failed to get admin credentials"
        return 1
    fi
    
    local username password lease_id ttl
    username=$(echo "$creds" | jq -r '.data.username')
    password=$(echo "$creds" | jq -r '.data.password')
    lease_id=$(echo "$creds" | jq -r '.lease_id')
    ttl=$(echo "$creds" | jq -r '.lease_duration')
    
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║        Admin Database Credentials (Vault)             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Username: $username"
    echo "  Password: $password"
    echo "  TTL: ${ttl}s ($(($ttl / 60)) minutes) - SHORT LIVED!"
    echo "  Lease ID: $lease_id"
    echo ""
    echo "  These credentials have full admin privileges"
    echo ""
}

# Force credential rotation
vault_rotate() {
    if ! vault_status; then
        return 1
    fi
    
    log_info "Forcing credential rotation..."
    
    # Revoke all leases for database/creds
    local leases
    leases=$(curl -sf "${VAULT_ADDR}/v1/sys/leases/lookup/database/creds/aixcl-app" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data.keys[]' 2>/dev/null)
    
    if [ -n "$leases" ]; then
        for lease in $leases; do
            curl -sf -X PUT "${VAULT_ADDR}/v1/sys/leases/revoke" \
                -H "X-Vault-Token: ${VAULT_TOKEN}" \
                -d "{\"lease_id\": \"$lease\"}" > /dev/null 2>&1
        done
        log_info "Revoked $(echo "$leases" | wc -w) active leases"
    fi
    
    log_info "New credentials will be generated on next service request"
}

# Initialize Vault (one-time setup)
vault_init() {
    log_info "Initializing Vault..."
    
    if vault_status >/dev/null 2>&1; then
        log_warn "Vault is already initialized"
        return 0
    fi
    
    log_info "Starting Vault container..."
    # Vault should be started via docker-compose
    # This just configures it
    
    sleep 5
    
    # Enable database secrets engine
    curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/database" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -d '{"type": "database"}' > /dev/null 2>&1 || {
        log_warn "Database engine may already be enabled"
    }
    
    log_info "Vault initialization complete"
}

# Show Vault status
vault_info() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                 Vault Status                           ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    if ! curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
        log_error "Vault is not running"
        echo ""
        echo "  Start Vault with: ./aixcl stack start vault"
        return 1
    fi
    
    local health
    health=$(curl -sf "${VAULT_ADDR}/v1/sys/health" | jq -r '.')
    
    echo "  Status: Running"
    echo "  Address: ${VAULT_ADDR}"
    echo "  Version: $(echo "$health" | jq -r '.version')"
    echo "  Sealed: $(echo "$health" | jq -r '.sealed')"
    echo ""
    echo "  Commands available:"
    echo "    ./aixcl vault credentials     - Get database credentials"
    echo "    ./aixcl vault admin          - Get admin credentials"
    echo "    ./aixcl vault rotate         - Force credential rotation"
    echo "    ./aixcl vault info           - Show this status"
    echo ""
}

# Main dispatcher
case "${1:-}" in
    status|info)
        vault_info
        ;;
    credentials|creds)
        vault_credentials
        ;;
    admin)
        vault_admin_credentials
        ;;
    rotate)
        vault_rotate
        ;;
    init)
        vault_init
        ;;
    *)
        echo "Usage: ./aixcl vault [command]"
        echo ""
        echo "Commands:"
        echo "  status      - Show Vault status"
        echo "  credentials - Get database credentials"
        echo "  admin       - Get admin credentials (short TTL)"
        echo "  rotate      - Force credential rotation"
        echo "  init        - Initialize Vault (one-time)"
        echo ""
        ;;
esac
