#!/usr/bin/env bash
# grafana-entrypoint.sh — Grafana entrypoint wrapper
# Reads admin password from Vault secrets volume and starts Grafana

set -e

echo "=== Grafana Vault-Secure Entrypoint ==="

# Read admin password from Vault secret
if [ -f /run/secrets/grafana-password ]; then
    GRAFANA_ADMIN_PASSWORD=$(cat /run/secrets/grafana-password | tr -d '\n')
    export GRAFANA_ADMIN_PASSWORD
    echo "[Vault] Grafana admin password loaded from /run/secrets/grafana-password"
else
    echo "[Vault] Warning: /run/secrets/grafana-password not found, using fallback"
    GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
    export GRAFANA_ADMIN_PASSWORD
fi

# Export to Grafana's expected env var
export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"

echo "[Vault] Starting Grafana with Vault-managed credentials..."

echo "$GRAFANA_ADMIN_PASSWORD" > /tmp/grafana-admin-password
chown 472:472 /tmp/grafana-admin-password 2>/dev/null || true
chmod 600 /tmp/grafana-admin-password

# Pass env var to Grafana so it reads the password file
export GF_SECURITY_ADMIN_PASSWORD__FILE=/tmp/grafana-admin-password
unset GRAFANA_ADMIN_PASSWORD

# Start Grafana official entrypoint
exec /run.sh
