#!/bin/sh
# shellcheck shell=sh
# Vault Agent using vault binary

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_DEV_TOKEN:-aixcl-dev-token}"
export VAULT_ADDR VAULT_TOKEN

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

fetch_credentials() {
    log "Fetching credentials..."
    
    # Use vault binary to read credentials
    output=$(vault read -format=json database/creds/aixcl-app 2>&1)
    vault_exit=$?
    
    if [ $vault_exit -ne 0 ]; then
        log "Failed to fetch credentials: $output"
        return 1
    fi
    
    # Extract using basic shell string manipulation (no jq needed)
    username=$(echo "$output" | grep '"username"' | sed 's/.*: "\(.*\)".*/\1/' | tr -d '[:space:],"')
    password=$(echo "$output" | grep '"password"' | sed 's/.*: "\(.*\)".*/\1/' | tr -d '[:space:],"')
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        log "Failed to parse credentials"
        return 1
    fi
    
    mkdir -p /tmp/vault-secrets
    echo "postgresql://${username}:${password}@127.0.0.1:5432/webui?sslmode=disable" > /tmp/vault-secrets/pgexporter-creds
    log "Generated credentials for ${username}"
}

# Wait for Vault to be initialized with retry logic
log "Waiting for Vault database role to be available..."
retries=30
while [ $retries -gt 0 ]; do
    if vault read database/roles/aixcl-app >/dev/null 2>&1; then
        log "Vault role is ready"
        break
    fi
    log "Vault role not ready yet, retrying... ($retries left)"
    sleep 5
    retries=$((retries - 1))
done

if [ $retries -eq 0 ]; then
    log "ERROR: Vault role not available after retries"
    exit 1
fi

# Initial fetch
fetch_credentials

# Keep refreshing every 45 minutes
while true; do
    sleep 2700
    fetch_credentials
done
