#!/bin/sh
# Vault Agent using vault binary

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-aixcl-dev-token}"
export VAULT_ADDR VAULT_TOKEN

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

fetch_credentials() {
    log "Fetching credentials..."
    
    # Use vault binary to read credentials
    local output
    output=$(vault read -format=json database/creds/aixcl-app 2>&1)
    
    if [ $? -ne 0 ]; then
        log "Failed to fetch credentials: $output"
        return 1
    fi
    
    # Extract using basic shell string manipulation (no jq needed)
    local username password
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

# Initial fetch
fetch_credentials

# Keep refreshing every 45 minutes
while true; do
    sleep 2700
    fetch_credentials
done
