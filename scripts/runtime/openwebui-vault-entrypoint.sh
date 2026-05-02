#!/bin/bash
# openwebui-vault-entrypoint.sh - Wrap Open WebUI to read database credentials from Vault

set -e

VAULT_CREDS_FILE="${VAULT_CREDS_FILE:-/tmp/vault-secrets/openwebui-db-creds}"

# Wait for Vault credentials to be available
echo "Waiting for Vault credentials..."
until [ -f "$VAULT_CREDS_FILE" ] && [ -s "$VAULT_CREDS_FILE" ]; do
    echo "Credentials file not ready yet, retrying in 2s..."
    sleep 2
done

# Read credentials from file
DATABASE_URL=$(cat "$VAULT_CREDS_FILE")

# Export for Open WebUI
export DATABASE_URL

echo "Database credentials loaded from Vault"
echo "Starting Open WebUI..."

# Call original entrypoint
exec /usr/local/bin/openwebui-entrypoint.sh "$@"
