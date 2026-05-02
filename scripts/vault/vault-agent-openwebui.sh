#!/bin/sh
# Vault Agent for Open WebUI

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-aixcl-dev-token}"
export VAULT_ADDR VAULT_TOKEN

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

fetch_credentials() {
    log "Fetching credentials for Open WebUI..."
    
    local output
    output=$(vault read -format=json database/creds/aixcl-app 2>&1)
    
    if [ $? -ne 0 ]; then
        log "Failed to fetch credentials: $output"
        return 1
    fi
    
    local username password
    username=$(echo "$output" | grep '"username"' | sed 's/.*: "\(.*\)".*/\1/' | tr -d '[:space:],"')
    password=$(echo "$output" | grep '"password"' | sed 's/.*: "\(.*\)".*/\1/' | tr -d '[:space:],"')
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        log "Failed to parse credentials"
        return 1
    fi
    
    mkdir -p /tmp/vault-secrets
    # Open WebUI format (no sslmode in URL)
    echo "postgresql://${username}:${password}@127.0.0.1:5432/webui" > /tmp/vault-secrets/openwebui-db-creds
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
