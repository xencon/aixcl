#!/usr/bin/env bash
# State Capture Utility for AIXCL Tests
# Captures system state before tests for restoration

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/tests/.backup"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

capture_state() {
    local test_name="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_subdir="${BACKUP_DIR}/${test_name}_${timestamp}"
    
    mkdir -p "$backup_subdir"
    
    # Capture .env file
    if [[ -f "${SCRIPT_DIR}/.env" ]]; then
        cp "${SCRIPT_DIR}/.env" "$backup_subdir/.env.backup"
        echo ".env"
    else
        echo "none"
    fi > "$backup_subdir/manifest.txt"
    
    # Capture opencode.json
    if [[ -f "${SCRIPT_DIR}/opencode.json" ]]; then
        cp "${SCRIPT_DIR}/opencode.json" "$backup_subdir/opencode.json.backup"
        echo "opencode.json" >> "$backup_subdir/manifest.txt"
    fi
    
    # Capture running containers
    docker ps --format '{{.Names}}' > "$backup_subdir/containers.backup" 2>/dev/null || true
    
    # Capture INFERENCE_ENGINE from current .env or fallback
    local current_engine
    current_engine=$(grep "^INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d'=' -f2 || echo "ollama")
    echo "$current_engine" > "$backup_subdir/engine.backup"
    
    echo "$backup_subdir"
}

get_last_backup() {
    local test_name="$1"
    local latest_backup
    latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "${test_name}_*" | sort -r | head -1)
    echo "$latest_backup"
}

list_backups() {
    echo "Available backups in $BACKUP_DIR:"
    ls -la "$BACKUP_DIR" 2>/dev/null || echo "No backups found"
}

cleanup_old_backups() {
    local max_backups="${1:-10}"
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d | wc -l)
    
    if [[ $backup_count -gt $max_backups ]]; then
        find "$BACKUP_DIR" -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | head -n -"${max_backups}" | cut -d' ' -f2- | xargs rm -rf
    fi
}

export -f capture_state get_last_backup list_backups cleanup_old_backups
export BACKUP_DIR SCRIPT_DIR
