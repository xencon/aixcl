#!/usr/bin/env bash
# Vault Agent for PostgreSQL bootstrap password (KV store)
# Fetches static bootstrap password from Vault KV and writes to file
# shellcheck shell=bash

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-aixcl-dev-token}"
export VAULT_ADDR VAULT_TOKEN

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

fetch_bootstrap_password() {
    log "Fetching PostgreSQL bootstrap password from Vault KV..."
    
    # Use wget to read from KV store (curl not available in Vault image)
    local response
    response=$(wget -qO- "${VAULT_ADDR}/v1/kv/data/bootstrap/postgres" \
        --header="X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        log "Failed to fetch bootstrap password from Vault KV"
        return 1
    fi
    
    # Extract password using basic shell (no jq needed)
    # Handle both "password": "value" and "password":"value" formats
    local password
    password=$(echo "$response" | grep -o '"password"[^,}]*' | head -1 | sed 's/"password"[[:space:]]*:[[:space:]]*"//;s/"$//')
    
    if [ -z "$password" ]; then
        log "Failed to parse bootstrap password from response"
        return 1
    fi
    
    # Write to shared volume
    mkdir -p /run/secrets
    echo "$password" > /run/secrets/postgres-password
    # PostgreSQL runs as user 999 (postgres), make file readable
    chmod 644 /run/secrets/postgres-password
    
    log "Bootstrap password written to /run/secrets/postgres-password"
}

# Wait for Vault to be available
log "Waiting for Vault..."
retries=30
while [ $retries -gt 0 ]; do
    if wget -qO- "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1; then
        log "Vault is ready"
        break
    fi
    log "Vault not ready yet, retrying... ($retries left)"
    sleep 2
    retries=$((retries - 1))
done

if [ $retries -eq 0 ]; then
    log "ERROR: Vault not available after retries"
    exit 1
fi

# Initial fetch
fetch_bootstrap_password

# Keep checking every 30 seconds (password rarely changes)
while true; do
    sleep 30
    # Re-fetch to ensure file exists (in case volume was reset)
    if [ ! -f /run/secrets/postgres-password ]; then
        fetch_bootstrap_password
    fi
done
