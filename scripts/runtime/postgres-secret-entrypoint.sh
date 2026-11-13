#!/bin/sh
# postgres-secret-entrypoint.sh — PostgreSQL entrypoint wrapper
# Ensures the admin password is always synced from Vault-generated secret.
#
# Problem: The official PostgreSQL docker-entrypoint.sh only runs initdb on
# the first volume creation. On subsequent restarts, the database exists but
# the password may have changed (Vault generates new dynamic passwords).
#
# Solution: Start postgres temporarily via pg_ctl with no TCP listener and a
# trust-only pg_hba on a private socket directory, ALTER ROLE the password to
# the Vault secret, then start normally via the official docker-entrypoint.sh.
# This needs no knowledge of the previous password, so it also recovers a
# Vault-only reinit against existing data (#2059). The official image uses
# the same no-TCP temporary-server technique during initdb.
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
    for i in $(seq 1 60); do
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

    # Private socket dir and hba file, readable only by the postgres user.
    # listen_addresses='' means no TCP at all, so trust auth is reachable
    # only through this 0700 directory for the lifetime of the sync.
    SYNC_DIR=$(mktemp -d /tmp/pg-sync.XXXXXX)
    chmod 700 "$SYNC_DIR"
    echo "local all all trust" > "$SYNC_DIR/pg_hba.conf"

    echo "[Vault] Starting PostgreSQL temporarily for password sync..."
    pg_ctl -D "$PGDATA" -w -t 60 -l "$SYNC_DIR/pg_sync.log" start \
        -o "-c listen_addresses='' -c unix_socket_directories=$SYNC_DIR -c hba_file=$SYNC_DIR/pg_hba.conf" || {
        echo "[Vault] ERROR: temporary PostgreSQL failed to start"
        cat "$SYNC_DIR/pg_sync.log"
        exit 1
    }

    # Pass the password via stdin (not argv) with single quotes doubled for
    # SQL; the role name is double-quoted as an identifier.
    ESCAPED_PASS=$(printf '%s' "$VAULT_PASS" | sed "s/'/''/g")
    if printf 'ALTER ROLE "%s" WITH PASSWORD '"'"'%s'"'"';\n' "$POSTGRES_USER" "$ESCAPED_PASS" | \
        psql -X -q -v ON_ERROR_STOP=1 -h "$SYNC_DIR" -U "$POSTGRES_USER" -d postgres \
            > /dev/null 2>> "$SYNC_DIR/pg_sync.log"; then
        echo "[Vault] PostgreSQL admin password synced to Vault secret"
    else
        echo "[Vault] Warning: password sync failed, see log below"
        cat "$SYNC_DIR/pg_sync.log"
    fi

    echo "[Vault] Stopping temporary PostgreSQL instance..."
    pg_ctl -D "$PGDATA" -w stop -m fast
    rm -rf "$SYNC_DIR"
    unset ESCAPED_PASS

    export POSTGRES_PASSWORD="$VAULT_PASS"

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
