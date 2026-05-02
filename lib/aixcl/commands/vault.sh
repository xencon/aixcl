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
        rotate)
            cmd_vault_rotate "$@"
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
            echo "  rotate       Manually trigger credential rotation"
            echo ""
            echo "Examples:"
            echo "  ./aixcl vault init          # Initialize Vault on first run"
            echo "  ./aixcl vault status        # Check if Vault is ready"
            echo "  ./aixcl vault credentials   # View service credentials"
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

# Export the main command
export -f cmd_vault
export -f cmd_vault_init
export -f cmd_vault_status
export -f cmd_vault_credentials
export -f cmd_vault_rotate
