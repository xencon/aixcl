#!/bin/sh
# postgres-exporter Vault entrypoint
# Reads PostgreSQL credentials from Vault secrets and constructs DATA_SOURCE_NAME.
# Requires POSTGRES_USER and POSTGRES_DATABASE to be set in environment.
# IMPORTANT: The official postgres_exporter binary is at /bin/postgres_exporter.

set -eu

echo "=== PostgreSQL Exporter Vault Entrypoint ==="

# --- Mandatory environment variables ---
# POSTGRES_USER and POSTGRES_DATABASE must be provided by docker-compose or .env.
# If they are missing, fail fast instead of falling back to a default.
if [ -z "${POSTGRES_USER:-}" ]; then
    echo "[ERROR] POSTGRES_USER is not set. Provide it in docker-compose or .env."
    exit 1
fi
if [ -z "${POSTGRES_DATABASE:-}" ]; then
    echo "[ERROR] POSTGRES_DATABASE is not set. Provide it in docker-compose or .env."
    exit 1
fi

# --- Read password from Vault secrets ---
PGPASSWORD=""
for i in $(seq 1 60); do
    if [ -f /run/secrets/postgres-password ] && [ -s /run/secrets/postgres-password ]; then
        PGPASSWORD="$(tr -d '\n' < /run/secrets/postgres-password)"
        echo "[Vault] PostgreSQL password loaded from /run/secrets/postgres-password"
        break
    fi
    echo "[Vault] Waiting for postgres-password secret... ($i/30)"
    sleep 2
done

if [ -z "$PGPASSWORD" ]; then
    echo "[Vault] ERROR: /run/secrets/postgres-password not found or empty after 60 seconds"
    exit 1
fi

# --- Resolve optional connection parameters ---
PGHOST="${POSTGRES_HOST:-127.0.0.1}"
PGPORT="${POSTGRES_PORT:-5432}"

# --- Build DATA_SOURCE_NAME ---
export DATA_SOURCE_NAME="postgresql://${POSTGRES_USER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${POSTGRES_DATABASE}?sslmode=disable"

echo "[Vault] DATA_SOURCE_NAME configured (password redacted)"

# --- Security: unset plaintext password from this shell ---
unset PGPASSWORD
unset POSTGRES_PASSWORD

# --- Start the official postgres_exporter ---
exec /bin/postgres_exporter
