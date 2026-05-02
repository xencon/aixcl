#!/bin/bash
# openwebui-vault-entrypoint.sh - Wrap Open WebUI to read database credentials from Vault

set -e

VAULT_CREDS_FILE="${VAULT_CREDS_FILE:-/tmp/vault-secrets/openwebui-db-creds}"
BOOTSTRAP_PASS_FILE="${BOOTSTRAP_PASS_FILE:-/run/secrets/openwebui-password}"

# Wait for Vault credentials to be available
echo "Waiting for Vault credentials..."
until [ -f "$VAULT_CREDS_FILE" ] && [ -s "$VAULT_CREDS_FILE" ]; do
    echo "Credentials file not ready yet, retrying in 2s..."
    sleep 2
done

# Read database credentials from file
DATABASE_URL=$(cat "$VAULT_CREDS_FILE")

# Read bootstrap password from Vault Agent (if available)
# This overrides any password set in .env
if [ -f "$BOOTSTRAP_PASS_FILE" ] && [ -s "$BOOTSTRAP_PASS_FILE" ]; then
    BOOTSTRAP_PASSWORD=$(cat "$BOOTSTRAP_PASS_FILE")
    export OPENWEBUI_PASSWORD="$BOOTSTRAP_PASSWORD"
    echo "Bootstrap password loaded from Vault KV"
fi

# Export for Open WebUI
export DATABASE_URL

echo "Database credentials loaded from Vault"
echo "Starting Open WebUI..."

# Call original entrypoint
exec /usr/local/bin/openwebui-entrypoint.sh "$@"
