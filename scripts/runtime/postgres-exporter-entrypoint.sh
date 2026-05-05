#!/bin/sh
# postgres-exporter Vault entrypoint
# Reads PostgreSQL password from Vault secrets and constructs DATA_SOURCE_NAME

set -e

echo "=== PostgreSQL Exporter Vault Entrypoint ==="

# Read password from Vault secrets
PGPASSWORD=""
if [ -f /run/secrets/postgres-password ] && [ -s /run/secrets/postgres-password ]; then
    PGPASSWORD=$(cat /run/secrets/postgres-password | tr -d '\n')
    echo "[Vault] PostgreSQL password loaded from /run/secrets/postgres-password"
else
    echo "[Vault] ERROR: /run/secrets/postgres-password not found or empty"
    exit 1
fi

# Resolve other variables with defaults
PGUSER="${POSTGRES_USER:-admin}"
PGDATABASE="${POSTGRES_DATABASE:-webui}"
PGHOST="${POSTGRES_HOST:-127.0.0.1}"
PGPORT="${POSTGRES_PORT:-5432}"

# Build DATA_SOURCE_NAME for postgres_exporter
export DATA_SOURCE_NAME="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=disable"

echo "[Vault] DATA_SOURCE_NAME configured (password redacted)"

# Unset plaintext password from environment
unset PGPASSWORD
unset POSTGRES_PASSWORD

# Start the official postgres_exporter
exec /postgres_exporter
