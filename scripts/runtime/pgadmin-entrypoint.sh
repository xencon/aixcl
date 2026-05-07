#!/usr/bin/env bash
# pgAdmin entrypoint wrapper
# On first start: creates initial admin from Vault secrets
# On restart: skips all admin creation, preserves user changes
# Never falls back to hardcoded defaults; fails fast if secrets missing
set -euo pipefail

echo "=== pgAdmin Non-Root Entrypoint ==="

# --- Detect first-start vs restart ---
PGADMIN_CONFIG_DB="/var/lib/pgadmin/pgadmin4.db"
if [ -f "$PGADMIN_CONFIG_DB" ] && [ -s "$PGADMIN_CONFIG_DB" ]; then
    IS_FIRST_START=false
    echo "pgAdmin config DB found ($PGADMIN_CONFIG_DB) — restart mode, skipping admin setup"
else
    IS_FIRST_START=true
    echo "No pgAdmin config DB found — first-start mode"
fi

# --- On restart: just start pgAdmin with existing data ---
if [ "$IS_FIRST_START" = false ]; then
    # Still need to set up directories and permissions
    USER_ID="${PGADMIN_USER_ID:-5050}"
    GROUP_ID="${PGADMIN_GROUP_ID:-5050}"
    
    if [ "$(id -u)" = "0" ]; then
        echo "Running as root — setting up permissions for restart..."
        
        mkdir -p /var/lib/pgadmin/sessions /var/lib/pgadmin/storage
        
        if ! getent group pgadmin >/dev/null 2>&1; then
            groupadd -g "$GROUP_ID" pgadmin 2>/dev/null || groupadd pgadmin 2>/dev/null || true
        fi
        
        if ! id pgadmin >/dev/null 2>&1; then
            useradd -u "$USER_ID" -g "$GROUP_ID" -s /bin/false -M pgadmin 2>/dev/null || true
        fi
        
        chown -R "$USER_ID:$GROUP_ID" /var/lib/pgadmin 2>/dev/null || true
        chown -R "$USER_ID:$GROUP_ID" /var/log/pgadmin 2>/dev/null || true
        chown "$USER_ID:$GROUP_ID" /pgadmin4/servers.json 2>/dev/null || true
        chmod +x /entrypoint.sh 2>/dev/null || true
        
        # Stop postfix if running
        if [ -f /usr/libexec/postfix/master ]; then
            pkill -f "postfix/master" 2>/dev/null || true
        fi
        
        echo "Switching to pgadmin user (UID: $USER_ID)..."
        export PGADMIN_LISTEN_PORT PGADMIN_LISTEN_ADDRESS PGADMIN_SERVER_JSON_FILE PGADMIN_REPLACE_SERVERS_ON_STARTUP
        exec su -m -s /bin/bash pgadmin -c 'exec /usr/local/bin/pgadmin-entrypoint.sh'
    fi
    
    # Non-root restart: just start
    echo "Running as user: $(id -u):$(id -g)"
    echo "Starting pgAdmin (restart) — admin credentials unchanged"
    exec /entrypoint.sh
fi

# --- First-start: require admin identity and Vault secrets ---

# Admin email: env var (from compose), .env, or Vault secrets mount
if [ -n "${PGADMIN_DEFAULT_EMAIL:-}" ]; then
    echo "[Env] PGADMIN_DEFAULT_EMAIL set from environment"
else
    if [ -f /run/secrets/pgadmin-email ] && [ -s /run/secrets/pgadmin-email ]; then
        PGADMIN_DEFAULT_EMAIL="$(tr -d '\n' < /run/secrets/pgadmin-email)"
        export PGADMIN_DEFAULT_EMAIL
        echo "[Vault] Admin email loaded from /run/secrets/pgadmin-email"
    fi
fi

if [ -z "${PGADMIN_DEFAULT_EMAIL:-}" ]; then
    echo "[ERROR] PGADMIN_DEFAULT_EMAIL is not set."
    echo "  Set it via one of:"
    echo "    - .env (PGADMIN_DEFAULT_EMAIL=...)"
    echo "    - Vault secrets mount (/run/secrets/pgadmin-email)"
    exit 1
fi

# Admin password: only from Vault (no env, no fallback)
PGADMIN_DEFAULT_PASSWORD=""
if [ -f /run/secrets/pgadmin-password ] && [ -s /run/secrets/pgadmin-password ]; then
    PGADMIN_DEFAULT_PASSWORD="$(tr -d '\n' < /run/secrets/pgadmin-password)"
    export PGADMIN_DEFAULT_PASSWORD
    echo "[Vault] pgAdmin password loaded from /run/secrets/pgadmin-password"
else
    echo "[Vault] ERROR: /run/secrets/pgadmin-password not found or empty"
    echo "  Cannot create initial admin on first start without Vault-generated password."
    exit 1
fi

# PostgreSQL connection password
PG_CONNECT_PASSWORD=""
if [ -f /run/secrets/postgres-password ] && [ -s /run/secrets/postgres-password ]; then
    PG_CONNECT_PASSWORD="$(tr -d '\n' < /run/secrets/postgres-password)"
    echo "[Vault] PostgreSQL connection password loaded"
else
    echo "[Vault] Warning: /run/secrets/postgres-password not found — servers.json will not have a password"
fi

# Persist passwords for pgadmin user after su
mkdir -p /var/lib/pgadmin
echo "$PGADMIN_DEFAULT_PASSWORD" > /var/lib/pgadmin/.pgadmin-passwd
echo "$PG_CONNECT_PASSWORD" > /var/lib/pgadmin/.pg-connect-passwd
chmod 600 /var/lib/pgadmin/.pgadmin-passwd /var/lib/pgadmin/.pg-connect-passwd

# --- Root setup block (only on first start) ---
if [ "$(id -u)" = "0" ]; then
    echo "Running as root — setting up permissions for first start..."
    
    mkdir -p /var/lib/pgadmin/sessions /var/lib/pgadmin/storage
    
    if ! getent group pgadmin >/dev/null 2>&1; then
        groupadd -g "${PGADMIN_GROUP_ID:-5050}" pgadmin 2>/dev/null || groupadd pgadmin 2>/dev/null || true
    fi
    
    if ! id pgadmin >/dev/null 2>&1; then
        useradd -u "${PGADMIN_USER_ID:-5050}" -g "${PGADMIN_GROUP_ID:-5050}" -s /bin/false -M pgadmin 2>/dev/null || true
    fi
    
    chown -R "${PGADMIN_USER_ID:-5050}:${PGADMIN_GROUP_ID:-5050}" /var/lib/pgadmin 2>/dev/null || true
    chown -R "${PGADMIN_USER_ID:-5050}:${PGADMIN_GROUP_ID:-5050}" /var/log/pgadmin 2>/dev/null || true
    chown "${PGADMIN_USER_ID:-5050}:${PGADMIN_GROUP_ID:-5050}" /pgadmin4/servers.json 2>/dev/null || true
    chmod +x /entrypoint.sh 2>/dev/null || true
    
    if [ -f /usr/libexec/postfix/master ]; then
        pkill -f "postfix/master" 2>/dev/null || true
    fi
    
    # Create servers.json with Vault password
    cat > /pgadmin4/servers.json << EOF
{
  "Servers": {
    "1": {
      "Group": "Servers",
      "Name": "AIXCL",
      "Host": "localhost",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "${POSTGRES_USER:-admin}",
      "Password": "${PG_CONNECT_PASSWORD}",
      "SSLMode": "prefer",
      "Favorite": true
    }
  }
}
EOF
    chmod 644 /pgadmin4/servers.json
    
    echo "Switching to pgadmin user (UID: ${PGADMIN_USER_ID:-5050})..."
    export PGADMIN_DEFAULT_EMAIL PGADMIN_DEFAULT_PASSWORD PGADMIN_LISTEN_PORT PGADMIN_LISTEN_ADDRESS PGADMIN_SERVER_JSON_FILE PGADMIN_REPLACE_SERVERS_ON_STARTUP
    exec su -m -s /bin/bash pgadmin -c 'exec /usr/local/bin/pgadmin-entrypoint.sh'
fi

# --- Non-root first start ---
echo "Running as user: $(id -u):$(id -g)"

if [ -w "/var/lib/pgadmin" ]; then
    echo "pgAdmin directories are writable"
else
    echo "Warning: pgAdmin directories may not be writable"
fi

echo "Starting pgAdmin (first start) — admin created with Vault credentials"
exec /entrypoint.sh
