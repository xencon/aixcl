#!/usr/bin/env bash
# Open WebUI Non-Root Entrypoint
# This script sets up proper permissions and then runs Open WebUI as non-root user

set -e

# Default user/group IDs
USER_ID="${USER_ID:-1000}"
GROUP_ID="${GROUP_ID:-1000}"

echo "=== Open WebUI Non-Root Entrypoint ==="
echo "Target UID: $USER_ID"
echo "Target GID: $GROUP_ID"

# Read PostgreSQL password from Vault secrets volume if available
# This overrides any stale .env password with the Vault-generated secret
if [ -f /run/secrets/postgres-password ]; then
    POSTGRES_PASSWORD=$(cat /run/secrets/postgres-password)
    export POSTGRES_PASSWORD
    echo "[Vault] PostgreSQL password loaded from /run/secrets/postgres-password"
fi

# Build DATABASE_URL from env vars or defaults, using Vault password if available
POSTGRES_USER="${POSTGRES_USER:-admin}"
POSTGRES_DATABASE="${POSTGRES_DATABASE:-webui}"
export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:5432/${POSTGRES_DATABASE}"

# Note: Open WebUI uses this DATABASE_URL for its database connection.
# We reconstruct it here to ensure POSTGRES_PASSWORD reflects the Vault secret.

# Wait for PostgreSQL to be ready before starting Open WebUI
# This prevents Open WebUI from falling back to SQLite
if [ -n "${DATABASE_URL:-}" ]; then
    echo "Waiting for PostgreSQL to be ready..."
    # Extract host and port from DATABASE_URL
    # Format: postgresql://user:pass@host:port/dbname
    # Use '#' as delimiter to avoid conflict with '/' in URL
    pg_host=$(echo "$DATABASE_URL" | sed -n 's#.*@\([^:]*\):.*#\1#p')
    pg_port=$(echo "$DATABASE_URL" | sed -n 's#.*:\([0-9]*\)/.*#\1#p')
    pg_host="${pg_host:-127.0.0.1}"
    pg_port="${pg_port:-5432}"

    # Wait for PostgreSQL with timeout (60 seconds)
    pg_ready=false
    for i in {1..30}; do
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
fi

# Check if running as root (required for permission setup)
if [ "$(id -u)" = "0" ]; then
    echo "Running as root - setting up permissions..."
    
    # Create non-root user if it doesn't exist
    if ! id "webui" &>/dev/null; then
        groupadd -g "$GROUP_ID" -o webui 2>/dev/null || true
        useradd -u "$USER_ID" -g "$GROUP_ID" -o -m -s /bin/bash webui 2>/dev/null || true
    fi
    
    # Ensure data directories exist and have correct ownership
    # These are the volumes mounted from docker-compose
    for dir in /app/backend/data /app/data /app/backend/data/static; do
        if [ -d "$dir" ]; then
            echo "Setting ownership of $dir to $USER_ID:$GROUP_ID"
            chown -R "$USER_ID:$GROUP_ID" "$dir" 2>/dev/null || true
            chmod 755 "$dir" 2>/dev/null || true
        else
            echo "Creating directory $dir"
            mkdir -p "$dir" 2>/dev/null || true
            chown -R "$USER_ID:$GROUP_ID" "$dir" 2>/dev/null || true
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
    
    # Open WebUI also uses /app/backend/open_webui for static files
    # This directory must be writable by the non-root user
    for dir in /app/backend/open_webui /app/backend/open_webui/static; do
        if [ -d "$dir" ]; then
            echo "Setting ownership of $dir to $USER_ID:$GROUP_ID"
            chown -R "$USER_ID:$GROUP_ID" "$dir" 2>/dev/null || true
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
    
    # Ensure the startup script is executable (ignore errors if read-only mount)
    if [ -f "/app/backend/openwebui.sh" ]; then
        chmod +x /app/backend/openwebui.sh 2>/dev/null || true
        chown "$USER_ID:$GROUP_ID" /app/backend/openwebui.sh 2>/dev/null || true
    fi
    
    # Ensure the entrypoint can write to /tmp (uvicorn needs this)
    chown -R "$USER_ID:$GROUP_ID" /tmp 2>/dev/null || true
    chmod 1777 /tmp
    
    echo "Switching to webui user (UID: $USER_ID)..."
    # Re-run this script as the non-root user using su
    # Preserve environment variables needed by OpenWebUI (DATABASE_URL, etc.)
    # Using 'su' (not 'su -') preserves the environment
    export -n USER_ID GROUP_ID  # Don't export these to avoid confusion
    exec su webui -c 'exec /usr/local/bin/openwebui-entrypoint.sh'
fi

# At this point, we should be running as non-root
CURRENT_UID="$(id -u)"
CURRENT_GID="$(id -g)"
echo "Running as user: $CURRENT_UID:$CURRENT_GID"

# Ensure data directory exists and is writable
DATA_DIR="/app/backend/data"
if [ ! -d "$DATA_DIR" ]; then
    echo "Error: Data directory $DATA_DIR does not exist"
    exit 1
fi

# Change to data directory where the secret key will be stored
cd "$DATA_DIR" || exit 1
echo "Working directory: $(pwd)"

# Execute the original Open WebUI startup script
echo "Starting Open WebUI..."
exec bash /app/backend/openwebui.sh "$@"
