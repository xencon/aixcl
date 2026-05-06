#!/bin/sh
# postgres-secret-entrypoint.sh — PostgreSQL entrypoint wrapper
# Ensures the admin password is always synced from Vault-generated secret.
#
# Problem: The official PostgreSQL docker-entrypoint.sh only runs initdb on
# the first volume creation. On subsequent restarts, the database exists but
# the password may have changed (Vault generates new dynamic passwords).
#
# Solution: Start postgres temporarily via pg_ctl, ALTER USER the password,
# then start normally via the official docker-entrypoint.sh.
#
# Usage in docker-compose.yml:
#   entrypoint: ["/usr/local/bin/postgres-secret-entrypoint.sh"]
#   command:
#     postgres
#     -c listen_addresses=127.0.0.1
#     ...
#
# Note: Must be run as UID 999 or root (matching postgres:17.9 image).

set -e

PG_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

# Read the Vault-generated password if available (mounted via aixcl-vault-secrets)
# On first start the bootstrap agent may not have written the secret yet,
# so we poll for up to 60 seconds before proceeding.
VAULT_PASS=""
if [ -f /run/secrets/postgres-password ] && [ -s /run/secrets/postgres-password ]; then
    VAULT_PASS=$(cat /run/secrets/postgres-password | tr -d '\n')
    echo "[Vault] PostgreSQL password loaded from /run/secrets/postgres-password"
else
    echo "[Vault] Waiting for Vault to generate PostgreSQL bootstrap password..."
    vault_ready=false
    for i in $(seq 1 30); do
        if [ -f /run/secrets/postgres-password ] && [ -s /run/secrets/postgres-password ]; then
            VAULT_PASS=$(cat /run/secrets/postgres-password | tr -d '\n')
            echo "[Vault] PostgreSQL password loaded after $((i * 2)) seconds"
            vault_ready=true
            break
        fi
        echo "[Vault] Waiting for Vault bootstrap password... ($i/30)"
        sleep 2
    done
    if [ "$vault_ready" = false ]; then
        echo "[Vault] ERROR: Vault bootstrap password not available after 60 seconds"
        echo "[Vault] Check that vault-agent-postgres-bootstrap is running and Vault is initialized"
        exit 1
    fi
fi

# If Vault password is set AND database already exists, update the admin password.
# First-init: docker-entrypoint.sh handles it via POSTGRES_PASSWORD env var.
# Subsequent starts: we must update the password in the DB.
if [ -n "$VAULT_PASS" ] && [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
    echo "[Vault] Database already initialized (PGDATA exists). Syncing password..."

    # The DB is running as user 999 (postgres). pg_ctl must run as that user.
    # The official image entrypoint does not start postgres until after initdb,
    # so here we start it ourselves, update the password, then stop it.

    # Temporarily set the password env vars so pg_ctl can start successfully.
    # If the old password is still in POSTGRES_PASSWORD (e.g. from .env),
    # pg_hba.conf checks md5/scram and the server will accept.
    # Then we connect via TCP (not socket — to avoid peer auth issues) to ALTER USER.

    # Save original values
    OLD_POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

    # Set Vault password so the server starts with the correct secrets
    export POSTGRES_PASSWORD="$VAULT_PASS"
    export PGPASSWORD="$VAULT_PASS"

    echo "[Vault] Starting PostgreSQL temporarily for password sync..."
    pg_ctl -D "$PGDATA" start -o "-h 127.0.0.1" -l /tmp/pg_sync.log

    # Wait for PostgreSQL to be ready via TCP
    pg_ready=false
    for i in $(seq 1 30); do
        if pg_isready -h 127.0.0.1 -p 5432 -U "${POSTGRES_USER:-admin}" >/dev/null 2>&1; then
            pg_ready=true
            break
        fi
        echo "[Vault] Waiting for PostgreSQL to be ready... ($i/30)"
        sleep 2
    done

    if [ "$pg_ready" = false ]; then
        echo "[Vault] Warning: PostgreSQL did not become ready, skipping password sync"
    else
        # Connect with OLD password to ALTER USER to NEW password
        export PGPASSWORD="${OLD_POSTGRES_PASSWORD:-admin}"
        echo "[Vault] Updating PostgreSQL admin password to match Vault secret..."
        psql -U "${POSTGRES_USER:-admin}" -h 127.0.0.1 -d "${POSTGRES_DATABASE:-webui}" \
            -Atc "ALTER USER ${POSTGRES_USER:-admin} WITH PASSWORD '${VAULT_PASS}';" 2> /tmp/pg_sync.log && \
            echo "[Vault] Password updated successfully" && \
            echo "[Vault] PostgreSQL will restart with new password"
    fi

    echo "[Vault] Stopping temporary PostgreSQL instance..."
    pg_ctl -D "$PGDATA" stop -m fast

    # Restore original password for the official entrypoint
    POSTGRES_PASSWORD="${OLD_POSTGRES_PASSWORD:-admin}"
    export POSTGRES_PASSWORD

    echo "[Vault] Starting PostgreSQL with official entrypoint..."
    echo ""
else
    # Fresh start: ensure POSTGRES_PASSWORD is set for initdb
    if [ -n "$VAULT_PASS" ]; then
        echo "[Vault] Fresh start detected. Setting POSTGRES_PASSWORD from Vault secret."
        export POSTGRES_PASSWORD="$VAULT_PASS"
    fi
fi

# Delegate to the official docker-entrypoint.sh which handles initdb or startup.
# If we started postgres above, it was stopped — this will start it fresh.
exec "$PG_ENTRYPOINT" "$@"
