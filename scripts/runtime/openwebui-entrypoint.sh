#!/usr/bin/env bash
# Open WebUI Non-Root Entrypoint
# Reads all credentials from Vault-mounted secrets; no hardcoded defaults.
# UID/GID configurable via USER_ID/GROUP_ID (default 5051 to avoid pgAdmin UID 5050
# and work correctly in rootless Podman subordinate UID mapping).

set -euo pipefail

# Default user/group IDs (1000 maps correctly in rootless Podman user namespace)
# Using OPENWEBUI_ prefix to avoid conflict with upstream image's default USER_ID/GROUP_ID=1000
USER_ID="${OPENWEBUI_USER_ID:-${USER_ID:-1000}}"
GROUP_ID="${OPENWEBUI_GROUP_ID:-${GROUP_ID:-1000}}"

echo "=== Open WebUI Non-Root Entrypoint ==="
echo "Target UID: $USER_ID"
echo "Target GID: $GROUP_ID"

# --- Mandatory database identity ---
# POSTGRES_USER and POSTGRES_DATABASE must be provided by docker-compose or .env.
if [ -z "${POSTGRES_USER:-}" ]; then
    echo "[ERROR] POSTGRES_USER is not set. Provide it in docker-compose or .env."
    exit 1
fi
if [ -z "${POSTGRES_DATABASE:-}" ]; then
    echo "[ERROR] POSTGRES_DATABASE is not set. Provide it in docker-compose or .env."
    exit 1
fi

# --- Read PostgreSQL password from Vault secrets volume ---
POSTGRES_PASSWORD=""
for i in $(seq 1 60); do
    if [ -f /run/secrets/postgres-password ] && [ -s /run/secrets/postgres-password ]; then
        POSTGRES_PASSWORD="$(tr -d '\n' < /run/secrets/postgres-password)"
        export POSTGRES_PASSWORD
        echo "[Vault] PostgreSQL password loaded from /run/secrets/postgres-password"
        break
    fi
    echo "[Vault] Waiting for postgres-password secret... ($i/30)"
    sleep 2
done

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "[Vault] ERROR: /run/secrets/postgres-password not found or empty after 60 seconds"
    exit 1
fi

# --- Build DATABASE_URL ---
export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:5432/${POSTGRES_DATABASE}"
echo "[Vault] DATABASE_URL configured (password redacted)"

# --- Wait for PostgreSQL ---
echo "Waiting for PostgreSQL to be ready..."
pg_host="127.0.0.1"
pg_port="5432"

pg_ready=false
for i in {1..60}; do
    if timeout 2 bash -c "echo > /dev/tcp/$pg_host/$pg_port" 2>/dev/null; then
        pg_ready=true
        echo "PostgreSQL is ready!"
        break
    fi
    echo "Waiting for PostgreSQL... ($i/30)"
    sleep 2
done

if [ "$pg_ready" = false ]; then
    echo "Warning: PostgreSQL did not become ready, Open WebUI may fall back to SQLite"
fi

# If running as root, set up permissions and re-exec as non-root
if [ "$(id -u)" = "0" ]; then
    echo "Running as root - setting up permissions..."

    if ! id "webui" &>/dev/null; then
        groupadd -g "$GROUP_ID" -o webui 2>/dev/null || true
        useradd -u "$USER_ID" -g "$GROUP_ID" -o -m -s /bin/bash webui 2>/dev/null || true
    fi

    # setpriv below works with numeric IDs, so a missing user is not fatal,
    # but surface it: HOME=/home/webui will not exist without useradd -m
    if ! id webui >/dev/null 2>&1; then
        echo "[WARN] webui user could not be created; continuing with numeric IDs ($USER_ID:$GROUP_ID), /home/webui may be missing"
    fi

    # Create missing directories BEFORE chowning their parents: on a fresh
    # volume the parent is still root-owned so mkdir needs no extra
    # capability, and the recursive chown below covers the new children.
    # Root has no CAP_DAC_OVERRIDE here, so it cannot mkdir inside a
    # directory already owned by $USER_ID -- that case is deferred to the
    # non-root phase, which owns the parent by then.
    for dir in /app/backend/data /app/data /app/backend/data/static; do
        if [ ! -d "$dir" ]; then
            echo "Creating directory $dir"
            mkdir -p "$dir" || echo "[WARN] mkdir $dir failed as root; deferring to non-root phase"
        fi
    done

    # Data directories are written to after privileges drop: a failed chown
    # here guarantees a later crash, so fail fast instead of hiding it.
    for dir in /app/backend/data /app/data; do
        echo "Setting ownership of $dir to $USER_ID:$GROUP_ID"
        if ! chown -R "$USER_ID:$GROUP_ID" "$dir"; then
            echo "[ERROR] chown of $dir failed -- container likely lacks CAP_CHOWN (check cap_add in docker-compose.yml)"
            exit 1
        fi
        chmod 755 "$dir"
    done

    for dir in /app/backend/open_webui /app/backend/open_webui/static; do
        if [ -d "$dir" ]; then
            echo "Setting ownership of $dir to $USER_ID:$GROUP_ID"
            chown -R "$USER_ID:$GROUP_ID" "$dir" || echo "[WARN] chown of $dir failed; static asset writes may not work"
            chmod 755 "$dir" || true
        fi
    done

    if [ -f "/app/backend/openwebui.sh" ]; then
        chmod +x /app/backend/openwebui.sh \
            || echo "[WARN] chmod +x /app/backend/openwebui.sh failed; launcher script may not be executable"
        chown "$USER_ID:$GROUP_ID" /app/backend/openwebui.sh \
            || echo "[WARN] chown of /app/backend/openwebui.sh failed (CAP_CHOWN?); launcher stays image-owned"
    fi

    chown -R "$USER_ID:$GROUP_ID" /tmp \
        || echo "[WARN] chown of /tmp failed; sticky-bit world-writable /tmp below is sufficient"
    chmod 1777 /tmp

    echo "Switching to webui user (UID: $USER_ID)..."
    export HOME=/home/webui
    # setpriv execs directly (unlike su which forks), so PID 1 becomes the non-root process
    exec setpriv --reuid="$USER_ID" --regid="$GROUP_ID" --clear-groups -- \
        /usr/local/bin/openwebui-entrypoint.sh
fi

# Running as non-root
CURRENT_UID="$(id -u)"
CURRENT_GID="$(id -g)"
echo "Running as user: $CURRENT_UID:$CURRENT_GID"

DATA_DIR="/app/backend/data"

# Ensure data directories exist now that this user owns the parents; the
# root phase cannot create children inside an already-chowned directory
# (no CAP_DAC_OVERRIDE).
for dir in "$DATA_DIR" /app/data "$DATA_DIR/static"; do
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir"; then
            echo "[ERROR] cannot create $dir as UID $CURRENT_UID -- volume ownership is wrong (root-phase chown failed?)"
            exit 1
        fi
    fi
done

echo "Data directory: $DATA_DIR"

# Generate secret key if not present
KEY_FILE="$DATA_DIR/.webui_secret_key"
if [ ! -e "$KEY_FILE" ]; then
    echo "Generating WEBUI_SECRET_KEY"
    head -c 12 /dev/random | base64 > "$KEY_FILE"
fi
WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
export WEBUI_SECRET_KEY
PORT="${PORT:-8080}"
HOST="${HOST:-127.0.0.1}"

# Change to the app directory where open_webui module is located
cd /app/backend || exit 1
echo "Working directory: $(pwd)"

echo "Starting Open WebUI..."
# NOTE: Admin user (and password) must be created manually via the web UI.
# There is no auto-creation. Use "./aixcl vault passwords" to view the Vault-generated password.
exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*'
