#!/usr/bin/env bash
# init-vault-api.sh - Initialize Vault via API calls

set -e

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-aixcl-dev-token}"

echo "Initializing Vault..."

# Wait for Vault to be ready
echo "Waiting for Vault..."
until curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; do
    sleep 2
done
echo "Vault is ready"

# Enable database secrets engine
echo "Enabling database secrets engine..."
curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/database" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"type": "database"}' || echo "Database engine may already be enabled"

# Configure PostgreSQL connection
echo "Configuring PostgreSQL connection..."
curl -sf -X POST "${VAULT_ADDR}/v1/database/config/postgresql" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "plugin_name": "postgresql-database-plugin",
        "allowed_roles": "aixcl-app",
        "connection_url": "postgresql://{{username}}:{{password}}@127.0.0.1:5432/webui?sslmode=disable",
        "username": "admin",
        "password": "admin"
    }' || echo "Failed to configure PostgreSQL"

# Create application role
echo "Creating aixcl-app role..."
curl -sf -X POST "${VAULT_ADDR}/v1/database/roles/aixcl-app" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "db_name": "postgresql",
        "creation_statements": "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
        "default_ttl": "1h",
        "max_ttl": "24h"
    }' || echo "Failed to create role"

echo "Vault initialization complete!"
echo ""
echo "Test credentials:"
curl -sf "${VAULT_ADDR}/v1/database/creds/aixcl-app" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" | jq -r '.data | "Username: \(.username)\nTTL: \(3600)s"' || echo "Failed to generate credentials"
