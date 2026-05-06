#!/usr/bin/env bash
# Vault management commands for AIXCL
# Provides first-class Vault initialization and management

# SCRIPT_DIR is set by the main aixcl script
# Use it to locate vault command scripts

function cmd_vault() {
    local subcommand="${1:-}"
    shift || true
    
    case "$subcommand" in
        start)
            cmd_vault_start "$@"
            ;;
        stop)
            cmd_vault_stop "$@"
            ;;
        restart)
            cmd_vault_restart "$@"
            ;;
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
            echo "Lifecycle Commands:"
            echo "  start        Start the Vault container"
            echo "  stop         Stop the Vault container"
            echo "  restart      Restart the Vault container"
            echo ""
            echo "Query Commands:"
            echo "  init         Initialize Vault (idempotent)"
            echo "  status       Check Vault health and initialization state"
            echo "  credentials  View generated dynamic credentials"
            echo "  passwords    View static bootstrap passwords (from Vault KV)"
            echo "  rotate       Manually trigger credential rotation"
            echo "  logs [n]     View Vault container logs (default: 50 lines)"
            echo ""
            echo "Examples:"
            echo "  ./aixcl vault start         # Start Vault container"
            echo "  ./aixcl vault stop          # Stop Vault container"
            echo "  ./aixcl vault restart       # Restart Vault container"
            echo "  ./aixcl vault init          # Initialize Vault on first run"
            echo "  ./aixcl vault status        # Check if Vault is ready"
            echo "  ./aixcl vault credentials   # View service credentials"
            echo "  ./aixcl vault passwords     # View bootstrap passwords"
            echo "  ./aixcl vault logs          # View last 50 log lines"
            echo ""
            return 1
            ;;
    esac
}

function cmd_vault_start() {
    container_start "vault"
}

function cmd_vault_stop() {
    container_stop "vault"
}

function cmd_vault_restart() {
    container_restart "vault"
}

function cmd_vault_init() {
    if ! vault_is_enabled_in_profile; then
        echo "Vault is not enabled in the current profile."
        echo "Use --profile ops or --profile sys to enable Vault."
        return 1
    fi
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
    if ! vault_is_enabled_in_profile; then
        echo "Vault is not enabled in the current profile."
        echo "Use --profile ops or --profile sys to enable Vault."
        return 1
    fi
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
    if ! vault_is_enabled_in_profile; then
        echo "Vault is not enabled in the current profile."
        echo "Use --profile ops or --profile sys to enable Vault."
        return 1
    fi
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

function cmd_vault_passwords() {
    if ! vault_is_enabled_in_profile; then
        echo "Vault is not enabled in the current profile."
        echo "Use --profile ops or --profile sys to enable Vault."
        return 1
    fi
    # Source existing vault commands
    local vault_commands="${SCRIPT_DIR}/scripts/vault/vault-commands.sh"
    if [ -f "$vault_commands" ]; then
        # shellcheck source=/dev/null
        source "$vault_commands"
        vault_passwords
    else
        echo "Error: vault-commands.sh not found"
        return 1
    fi
}

function cmd_vault_rotate() {
    if ! vault_is_enabled_in_profile; then
        echo "Vault is not enabled in the current profile."
        echo "Use --profile ops or --profile sys to enable Vault."
        return 1
    fi
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

# Check if Vault is enabled in the current profile
# Reads PROFILE from .env file and checks if vault is in the service list
vault_is_enabled_in_profile() {
    local profile=""
    local env_file="${SCRIPT_DIR}/.env"
    if [ -f "$env_file" ]; then
        profile=$(grep -E "^[[:space:]]*PROFILE[[:space:]]*=" "$env_file" 2>/dev/null | head -1 | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
    fi
    [ -z "$profile" ] && profile="sys"
    
    # Check if profile contains vault service
    local profile_services
    profile_services=$(get_profile_services_for_profile "$profile" 2>/dev/null)
    if echo "$profile_services" | grep -qw "vault"; then
        return 0
    fi
    return 1
}

# Export the main command
export -f cmd_vault
export -f cmd_vault_start
export -f cmd_vault_stop
export -f cmd_vault_restart
export -f cmd_vault_init
export -f cmd_vault_status
export -f cmd_vault_credentials
export -f cmd_vault_passwords
export -f cmd_vault_rotate
export -f cmd_vault_logs
