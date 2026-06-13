#!/bin/sh
# Vault Agent for PostgreSQL bootstrap password (KV store)
# Fetches static bootstrap password and username from Vault KV and writes to file
# shellcheck shell=sh

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-${VAULT_DEV_TOKEN:-}}"
export VAULT_ADDR VAULT_TOKEN

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Extract a field value from a JSON string using basic shell (no jq)
extract_field() {
    _json="$1"
    _field="$2"
    echo "$_json" | grep -o '"'"$_field"'"[^,}]*' | head -1 | sed 's/"'"$_field"'"[[:space:]]*:[[:space:]]*"//;s/"$//'
}

fetch_bootstrap_password() {
    log "Fetching PostgreSQL bootstrap password from Vault KV..."

    # Use wget to read from KV store (curl not available in Vault image)
    response=$(wget -qO- "${VAULT_ADDR}/v1/kv/data/bootstrap/postgres" \
        --header="X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null)
    wget_exit=$?

    if [ $wget_exit -ne 0 ] || [ -z "$response" ]; then
        log "Failed to fetch bootstrap data from Vault KV"
        return 1
    fi

    # Extract password, email, and username from KV response
    password=$(extract_field "$response" "password")
    email=$(extract_field "$response" "email")
    username=$(extract_field "$response" "username")

    if [ -z "$password" ]; then
        log "Failed to parse bootstrap password from response"
        return 1
    fi

    # Write to shared volume
    mkdir -p /run/secrets || {
        log "ERROR: Cannot create /run/secrets directory"
        return 1
    }

    if ! echo "$password" > /run/secrets/postgres-password; then
        log "ERROR: Cannot write /run/secrets/postgres-password"
        return 1
    fi
    if ! chmod 644 /run/secrets/postgres-password; then
        log "ERROR: Cannot chmod /run/secrets/postgres-password"
        return 1
    fi

    # Write email and username if available (for entrypoint consumption)
    if [ -n "$email" ]; then
        if ! echo "$email" > /run/secrets/postgres-email; then
            log "ERROR: Cannot write /run/secrets/postgres-email"
            return 1
        fi
        if ! chmod 644 /run/secrets/postgres-email; then
            log "ERROR: Cannot chmod /run/secrets/postgres-email"
            return 1
        fi
        log "Bootstrap email written to /run/secrets/postgres-email"
    fi

    if [ -n "$username" ]; then
        if ! echo "$username" > /run/secrets/postgres-username; then
            log "ERROR: Cannot write /run/secrets/postgres-username"
            return 1
        fi
        if ! chmod 644 /run/secrets/postgres-username; then
            log "ERROR: Cannot chmod /run/secrets/postgres-username"
            return 1
        fi
        log "Bootstrap username written to /run/secrets/postgres-username"
    fi

    log "Bootstrap password written to /run/secrets/postgres-password"
}

# Wait for Vault to be available
log "Waiting for Vault..."
retries=60
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

# Fetch once and exit. restart: on-failure in compose retries on error.
# On success (exit 0) the container stops cleanly; the root token is
# no longer held in a long-running process environment.
if ! fetch_bootstrap_password; then
    log "ERROR: Bootstrap failed, exiting non-zero so compose can retry"
    exit 1
fi
log "Bootstrap complete"
