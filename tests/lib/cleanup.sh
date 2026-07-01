#!/usr/bin/env bash
# Cleanup Utility for AIXCL Tests
# Restores system state after tests

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

restore_state() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_warn "Backup directory not found: $backup_dir"
        return 1
    fi

    log_info "Restoring state from: $backup_dir"

    # Restore .env file
    if [[ -f "$backup_dir/.env.backup" ]]; then
        cp "$backup_dir/.env.backup" "${SCRIPT_DIR}/.env"
        log_info "Restored .env file"
    else
        rm -f "${SCRIPT_DIR}/.env"
        log_info "Removed .env file (no backup)"
    fi

    # Restore opencode.json
    if [[ -f "$backup_dir/opencode.json.backup" ]]; then
        cp "$backup_dir/opencode.json.backup" "${SCRIPT_DIR}/opencode.json"
        log_info "Restored opencode.json"
    fi

    # Restore original engine
    if [[ -f "$backup_dir/engine.backup" ]]; then
        local original_engine
        original_engine=$(cat "$backup_dir/engine.backup")
        if [[ -n "$original_engine" ]]; then
            "$AIXCL_BIN" engine set "$original_engine" > /dev/null 2>&1 || true
            log_info "Restored engine: $original_engine"
        fi
    fi

    log_success "State restored"
}

cleanup_test_containers() {
    log_info "Cleaning up test containers..."

    # Use aixcl stack stop for proper shutdown (not docker stop)
    # This ensures proper signal handling and port release
    "$AIXCL_BIN" stack stop > /dev/null 2>&1 || true
    log_info "Executed: aixcl stack stop"

    # Fallback: ensure containers are removed if stack stop didn't work
    local containers
    containers=$(docker ps -q --filter "name=ollama" 2>/dev/null || true)
    if [[ -n "$containers" ]]; then
        echo "$containers" | xargs -r docker stop > /dev/null 2>&1 || true
        echo "$containers" | xargs -r docker rm > /dev/null 2>&1 || true
        log_info "Force removed remaining containers"
    fi

    # Wait for port 11434 to be released with active polling
    log_info "Waiting for port 11434 to be released..."
    local waited=0
    local max_wait=60
    while [[ $waited -lt $max_wait ]]; do
        if ! ss -tln | grep -q ":11434 "; then
            log_info "Port 11434 is free (released after ${waited}s)"
            return 0
        fi
        ((waited++))
    done

    log_warn "Port 11434 still in use after ${max_wait}s"
    return 1
}

cleanup_test_models() {
    local engine="${1:-ollama}"
    log_info "Cleaning up test models for $engine..."

    case "$engine" in
        ollama)
            # Remove test models from ollama
            if docker ps | grep -q ollama; then
                docker exec ollama ollama rm qwen2.5-coder:0.5b 2>/dev/null || true
            fi
            ;;
    esac
}

cleanup_all() {
    log_info "Running full cleanup..."

    # Stop stack
    "$AIXCL_BIN" stack stop > /dev/null 2>&1 || true

    # Remove containers
    cleanup_test_containers

    # Clean up backup files older than 7 days
    find "${SCRIPT_DIR}/tests/.backup" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

    log_success "Cleanup complete"
}

export -f restore_state cleanup_test_containers cleanup_test_models cleanup_all
