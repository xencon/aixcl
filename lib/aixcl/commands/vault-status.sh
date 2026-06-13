#!/usr/bin/env bash
#
# Vault status command - Check Vault health and initialization state
# Part of AIXCL CLI: ./aixcl vault status
#

set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)}"

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

# Load root token from GPG-encrypted store if not already in environment
_VAULT_TOKEN_FILE="${SCRIPT_DIR}/.security/vault-root-token.gpg"
if [ -z "${VAULT_TOKEN:-}" ] && [ -f "$_VAULT_TOKEN_FILE" ]; then
    if ! VAULT_TOKEN=$(gpg --quiet --decrypt "$_VAULT_TOKEN_FILE" 2>/dev/null); then
        VAULT_TOKEN=""
        echo "[!] Warning: could not decrypt ${_VAULT_TOKEN_FILE}; continuing without a token." >&2
        if [ ! -t 0 ]; then
            echo "    No TTY for GPG pinentry. Set VAULT_TOKEN in the environment," >&2
            echo "    or decrypt with: gpg --pinentry-mode loopback --decrypt <file>" >&2
        else
            echo "    Check your GPG key (gpg --list-secret-keys) or set VAULT_TOKEN." >&2
        fi
    fi
fi
VAULT_TOKEN="${VAULT_TOKEN:-}"

export VAULT_ADDR
export VAULT_TOKEN

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if Vault container is running
check_container() {
    local container_runtime="unknown"
    local is_running=false
    
    if command -v podman >/dev/null 2>&1; then
        if podman ps --format "{{.Names}}" | grep -q "^vault$"; then
            container_runtime="podman"
            is_running=true
        fi
    fi
    
    if [ "$is_running" = false ] && command -v docker >/dev/null 2>&1; then
        if docker ps --format "{{.Names}}" | grep -q "^vault$" 2>/dev/null; then
            container_runtime="docker"
            is_running=true
        fi
    fi
    
    if [ "$is_running" = true ]; then
        echo -e "Container Status:     ${GREEN}Running${NC} ($container_runtime)"
        return 0
    else
        echo -e "Container Status:     ${RED}Not Running${NC}"
        return 1
    fi
}

# Check Vault API health using REST API
check_vault_health() {
    local health_status
    health_status=$(curl -sf "${VAULT_ADDR}/v1/sys/health?sealedok=true&uninitok=true" 2>/dev/null || echo '{}')

    if [ -z "$health_status" ] || [ "$health_status" = '{}' ]; then
        echo -e "Vault API:            ${RED}Not Responding${NC}"
        return 1
    fi

    local initialized sealed
    initialized=$(echo "$health_status" | jq -r 'if has("initialized") then (.initialized | tostring) else "false" end' 2>/dev/null)
    sealed=$(echo "$health_status" | jq -r 'if has("sealed") then (.sealed | tostring) else "unknown" end' 2>/dev/null || echo "unknown")

    if [ "$initialized" = "false" ]; then
        echo -e "Vault API:            ${YELLOW}Not Initialized (run: ./aixcl vault init)${NC}"
        return 1
    elif [ "$sealed" = "true" ]; then
        echo -e "Vault API:            ${YELLOW}Sealed (run: ./aixcl vault unseal)${NC}"
        return 1
    elif [ "$sealed" = "false" ]; then
        echo -e "Vault API:            ${GREEN}Healthy (Unsealed)${NC}"
        return 0
    else
        echo -e "Vault API:            ${YELLOW}Unknown State${NC}"
        return 1
    fi
}

# Check if database engine is initialized
check_database_engine() {
    local secrets
    secrets=$(curl -sf "${VAULT_ADDR}/v1/sys/mounts" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    
    if echo "$secrets" | grep -q "^database/"; then
        echo -e "Database Engine:      ${GREEN}Enabled${NC}"
        return 0
    else
        echo -e "Database Engine:      ${RED}Not Initialized${NC}"
        return 1
    fi
}

# Check if PostgreSQL is connected
check_postgres_connection() {
    local config
    config=$(curl -sf "${VAULT_ADDR}/v1/database/config/postgresql" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    
    if [ -n "$config" ] && echo "$config" | jq -e '.data' >/dev/null 2>&1; then
        echo -e "PostgreSQL Config:    ${GREEN}Connected${NC}"
        return 0
    else
        echo -e "PostgreSQL Config:    ${RED}Not Configured${NC}"
        return 1
    fi
}

# Check if roles are created
check_roles() {
    local roles_ok=true
    local role_list=""
    
    for role in aixcl-app aixcl-admin aixcl-readonly; do
        local role_data
        role_data=$(curl -sf "${VAULT_ADDR}/v1/database/roles/$role" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
        
        if [ -n "$role_data" ] && echo "$role_data" | jq -e '.data' >/dev/null 2>&1; then
            role_list="$role_list ${GREEN}✓${NC} $role"
        else
            role_list="$role_list ${RED}✗${NC} $role"
            roles_ok=false
        fi
    done
    
    if [ "$roles_ok" = true ]; then
        echo -e "Dynamic Roles:        ${GREEN}All Configured${NC}"
        echo -e "                      $role_list"
        return 0
    else
        echo -e "Dynamic Roles:        ${YELLOW}Partial${NC}"
        echo -e "                      $role_list"
        return 1
    fi
}

# Check if policies exist
check_policies() {
    local policies_ok=true
    local policy_list=""
    
    for policy in aixcl-app aixcl-admin aixcl-readonly; do
        local policy_data
        policy_data=$(curl -sf "${VAULT_ADDR}/v1/sys/policy/$policy" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
        
        if [ -n "$policy_data" ] && echo "$policy_data" | jq -e '.data' >/dev/null 2>&1; then
            policy_list="$policy_list ${GREEN}✓${NC} $policy"
        else
            policy_list="$policy_list ${RED}✗${NC} $policy"
            policies_ok=false
        fi
    done
    
    if [ "$policies_ok" = true ]; then
        echo -e "Vault Policies:       ${GREEN}All Configured${NC}"
        echo -e "                      $policy_list"
        return 0
    else
        echo -e "Vault Policies:       ${YELLOW}Partial${NC}"
        echo -e "                      $policy_list"
        return 1
    fi
}

# Check AppRole auth
check_approle() {
    local auths
    auths=$(curl -sf "${VAULT_ADDR}/v1/sys/auth" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    
    if echo "$auths" | grep -q "approle/"; then
        echo -e "AppRole Auth:         ${GREEN}Enabled${NC}"
        return 0
    else
        echo -e "AppRole Auth:         ${RED}Not Enabled${NC}"
        return 1
    fi
}

# Check Vault agents
check_vault_agents() {
    local agents
    agents=$(podman ps --format "{{.Names}}" 2>&1 | grep "vault-agent" || true)
    
    if [ -n "$agents" ]; then
        local count
        count=$(echo "$agents" | wc -l)
        echo -e "Vault Agents:         ${GREEN}$count running${NC}"
        echo "$agents" | sed 's/^/                      - /'
        return 0
    else
        echo -e "Vault Agents:         ${YELLOW}None running${NC}"
        return 1
    fi
}

# Check generated credentials
check_credentials() {
    if [ -d "/tmp/aixcl-secrets" ]; then
        local cred_files
        cred_files=$(ls -1 /tmp/aixcl-secrets/ 2>&1 | wc -l)
        if [ "$cred_files" -gt 0 ]; then
            echo -e "Generated Creds:      ${GREEN}$cred_files files${NC}"
            ls -1 /tmp/aixcl-secrets/ 2>&1 | sed 's/^/                      - /'
            return 0
        fi
    fi
    echo -e "Generated Creds:      ${YELLOW}None found${NC}"
    return 0
}

# Overall initialization status
check_initialization_status() {
    echo ""
    echo "=========================================="
    echo "  Initialization Status"
    echo "=========================================="
    
    local all_checks_passed=true
    
    # Run all checks
    check_container || all_checks_passed=false
    check_vault_health || all_checks_passed=false
    check_database_engine || all_checks_passed=false
    check_postgres_connection || all_checks_passed=false
    check_roles || all_checks_passed=false
    check_policies || all_checks_passed=false
    check_approle || all_checks_passed=false
    check_vault_agents || all_checks_passed=false
    check_credentials || all_checks_passed=false
    
    echo ""
    
    if [ "$all_checks_passed" = true ]; then
        echo -e "${GREEN}✓ Vault is fully initialized and ready${NC}"
        echo ""
        echo "Next steps:"
        echo "  ./aixcl vault credentials    # View service credentials"
        echo "  ./aixcl stack status         # Check all services"
        return 0
    else
        echo -e "${YELLOW}⚠ Vault needs initialization${NC}"
        echo ""
        echo "Run: ./aixcl vault init"
        return 1
    fi
}

# Show detailed Vault info
show_vault_info() {
    echo ""
    echo "Vault Configuration:"
    echo "  Address: $VAULT_ADDR"
    echo "  Token:   ${VAULT_TOKEN:0:8}... (loaded from .security/)"
    echo ""
    
    # Try to get version from health endpoint
    local version
    version=$(curl -sf "${VAULT_ADDR}/v1/sys/health" 2>/dev/null | jq -r '.version // "Unknown"')
    echo "Version: $version"
}

# Main
main() {
    echo "AIXCL Vault Status"
    echo ""
    
    show_vault_info
    check_initialization_status
}

main "$@"
