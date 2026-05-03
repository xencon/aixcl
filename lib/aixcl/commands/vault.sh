#!/usr/bin/env bash
# Vault management commands for AIXCL
# Provides first-class Vault initialization and management

# SCRIPT_DIR is set by the main aixcl script
# Use it to locate vault command scripts

function cmd_vault() {
    local subcommand="${1:-}"
    shift || true
    
    case "$subcommand" in
        init)
            cmd_vault_init "$@"
            ;;
        status)
            cmd_vault_status "$@"
            ;;
        credentials| creds)
            cmd_vault_credentials "$@"
            ;;
        passwords| password)
            cmd_vault_passwords "$@"
            ;;
        rotate)
            cmd_vault_rotate "$@"
            ;;
        logs)
            cmd_vault_logs "$@"
            ;;
        *)
            echo "AIXCL Vault Management"
            echo ""
            echo "Usage: ./aixcl vault <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init         Initialize Vault (idempotent)"
            echo "  status       Check Vault health and initialization state"
            echo "  credentials  View generated dynamic credentials"
            echo "  passwords    View static bootstrap passwords (from Vault KV)"
            echo "  rotate       Manually trigger credential rotation"
            echo "  logs [n]     View Vault container logs (default: 50 lines)"
            echo ""
            echo "Examples:"
            echo "  ./aixcl vault init          # Initialize Vault on first run"
            echo "  ./aixcl vault status        # Check if Vault is ready"
            echo "  ./aixcl vault credentials   # View service credentials"
            echo "  ./aixcl vault passwords     # View bootstrap passwords"
            echo "  ./aixcl vault logs          # View last 50 log lines"
            echo "  ./aixcl vault logs 100      # View last 100 log lines"
            echo ""
            return 1
            ;;
    esac
}

function cmd_vault_init() {
    # Run the idempotent initialization
    local init_script="${SCRIPT_DIR}/lib/aixcl/commands/vault-init.sh"
    if [ -f "$init_script" ]; then
        "$init_script" "$@"
    else
        echo "Error: vault-init.sh not found at $init_script"
        return 1
    fi
}

function cmd_vault_status() {
    # Run the status check
    local status_script="${SCRIPT_DIR}/lib/aixcl/commands/vault-status.sh"
    if [ -f "$status_script" ]; then
        "$status_script" "$@"
    else
        echo "Error: vault-status.sh not found at $status_script"
        return 1
    fi
}

function cmd_vault_credentials() {
    # Source existing vault commands
    local vault_commands="${SCRIPT_DIR}/scripts/vault/vault-commands.sh"
    if [ -f "$vault_commands" ]; then
        # shellcheck source=/dev/null
        source "$vault_commands"
        vault_credentials
    else
        echo "Error: vault-commands.sh not found"
        return 1
    fi
}

function cmd_vault_rotate() {
    echo "Triggering manual credential rotation..."
    
    # Check if Vault is accessible
    if ! vault status >/dev/null 2>&1; then
        echo "Error: Vault is not running or not accessible"
        echo "Run: ./aixcl vault init"
        return 1
    fi
    
    # Restart vault agents to trigger immediate rotation
    local agents
    agents=$(podman ps --format "{{.Names}}" | grep "vault-agent" || true)
    
    if [ -n "$agents" ]; then
        echo "Restarting Vault agents for immediate rotation..."
        while IFS= read -r agent; do
            echo "  Restarting $agent..."
            podman restart "$agent" >/dev/null 2>&1 || true
        done <<< "$agents"
        echo "Agents restarted. Credentials will be updated within 30 seconds."
    else
        echo "No Vault agents running. They will pick up new credentials on next TTL refresh."
    fi
    
    return 0
}

function cmd_vault_passwords() {
    # Display bootstrap passwords from Vault KV
    local vault_addr="${VAULT_ADDR:-http://127.0.0.1:8200}"
    local vault_token="${VAULT_TOKEN:-aixcl-dev-token}"
    
    # Check if Vault is accessible
    local health
    health=$(curl -sf "${vault_addr}/v1/sys/health" 2>/dev/null | jq -r '.version // ""')
    if [ -z "$health" ]; then
        echo "Error: Vault is not running or not accessible"
        echo "Run: ./aixcl vault init"
        return 1
    fi
    
    echo ""
    echo "=========================================="
    echo "  Bootstrap Passwords (Vault KV)"
    echo "=========================================="
    echo ""
    
    # PostgreSQL password
    local postgres_data
    postgres_data=$(curl -sf "${vault_addr}/v1/kv/data/bootstrap/postgres" \
        -H "X-Vault-Token: ${vault_token}" 2>/dev/null || true)
    
    if [ -n "$postgres_data" ] && echo "$postgres_data" | jq -e '.data.data.password' >/dev/null 2>&1; then
        local postgres_pass postgres_desc postgres_created
        postgres_pass=$(echo "$postgres_data" | jq -r '.data.data.password')
        postgres_desc=$(echo "$postgres_data" | jq -r '.data.data.description // "PostgreSQL bootstrap password"')
        postgres_created=$(echo "$postgres_data" | jq -r '.data.metadata.created_time // "unknown"')
        
        echo "PostgreSQL:"
        echo "  Username: admin"
        echo "  Password: ${postgres_pass}"
        echo "  Description: ${postgres_desc}"
        echo "  Created: ${postgres_created}"
        echo ""
    else
        echo "PostgreSQL: Not initialized"
        echo "  Run: ./aixcl vault init"
        echo ""
    fi
    
    # Open WebUI password
    local openwebui_data
    openwebui_data=$(curl -sf "${vault_addr}/v1/kv/data/bootstrap/openwebui" \
        -H "X-Vault-Token: ${vault_token}" 2>/dev/null || true)
    
    if [ -n "$openwebui_data" ] && echo "$openwebui_data" | jq -e '.data.data.password' >/dev/null 2>&1; then
        local openwebui_pass openwebui_desc openwebui_created
        openwebui_pass=$(echo "$openwebui_data" | jq -r '.data.data.password')
        openwebui_desc=$(echo "$openwebui_data" | jq -r '.data.data.description // "Open WebUI admin password"')
        openwebui_created=$(echo "$openwebui_data" | jq -r '.data.metadata.created_time // "unknown"')
        
        echo "Open WebUI:"
        echo "  Username: admin"
        echo "  Password: ${openwebui_pass}"
        echo "  Description: ${openwebui_desc}"
        echo "  Created: ${openwebui_created}"
        echo ""
    else
        echo "Open WebUI: Not initialized"
        echo "  Run: ./aixcl vault init"
        echo ""
    fi
    
    # pgAdmin password
    local pgadmin_data
    pgadmin_data=$(curl -sf "${vault_addr}/v1/kv/data/bootstrap/pgadmin" \
        -H "X-Vault-Token: ${vault_token}" 2>/dev/null || true)
    
    if [ -n "$pgadmin_data" ] && echo "$pgadmin_data" | jq -e '.data.data.password' >/dev/null 2>&1; then
        local pgadmin_pass pgadmin_desc pgadmin_created
        pgadmin_pass=$(echo "$pgadmin_data" | jq -r '.data.data.password')
        pgadmin_desc=$(echo "$pgadmin_data" | jq -r '.data.data.description // "pgAdmin admin password"')
        pgadmin_created=$(echo "$pgadmin_data" | jq -r '.data.metadata.created_time // "unknown"')
        
        echo "pgAdmin:"
        echo "  Username: admin"
        echo "  Password: ${pgadmin_pass}"
        echo "  Description: ${pgadmin_desc}"
        echo "  Created: ${pgadmin_created}"
        echo ""
    else
        echo "pgAdmin: Not initialized"
        echo "  Run: ./aixcl vault init"
        echo ""
    fi
    
    echo "=========================================="
    echo ""
    echo "NOTE: These are bootstrap passwords for initial setup."
    echo "      Change them after first login for security."
    echo ""
}

function cmd_vault_logs() {
    # Show Vault container logs, consistent with stack logs behavior
    local tail_count="${1:-50}"
    local container_name="vault"
    
    # Validate tail count
    if [[ ! "$tail_count" =~ ^[0-9]+$ ]] || [[ "$tail_count" -lt 1 ]] || [[ "$tail_count" -gt 10000 ]]; then
        echo "Error: Log line count must be a number between 1 and 10000"
        return 1
    fi
    
    # Check if container exists (running or stopped)
    local actual_container
    actual_container=$("${DOCKER_BIN:-docker}" ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^${container_name}$|_[0-9a-f]+_${container_name}$|^[0-9a-f]+_${container_name}$" | head -1)
    
    if [ -n "$actual_container" ]; then
        echo "Fetching logs for Vault (last $tail_count lines)..."
        echo ""
        "${DOCKER_BIN:-docker}" logs --tail="$tail_count" "$actual_container" 2>/dev/null || echo "  (no logs available)"
    else
        echo "Error: Vault container not found"
        echo ""
        echo "Vault may not be running. Start the stack with:"
        echo "  ./aixcl stack start --profile sys"
        return 1
    fi
}

# Export the main command
export -f cmd_vault
export -f cmd_vault_init
export -f cmd_vault_status
export -f cmd_vault_credentials
export -f cmd_vault_passwords
export -f cmd_vault_rotate
export -f cmd_vault_logs
