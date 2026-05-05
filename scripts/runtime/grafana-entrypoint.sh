#!/usr/bin/env bash
# grafana-entrypoint.sh — Grafana entrypoint wrapper
# Reads admin password from Vault secrets volume and starts Grafana

set -e

echo "=== Grafana Vault-Secure Entrypoint ==="

# Read admin password from Vault secret
if [ -f /run/secrets/grafana-password ]; then
    GRAFANA_ADMIN_PASSWORD=$(cat /run/secrets/grafana-password | tr -d '\n')
    echo "[Vault] Grafana admin password loaded from /run/secrets/grafana-password"
else
    echo "[Vault] Warning: /run/secrets/grafana-password not found, using fallback"
    GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
fi

echo "[Vault] Starting Grafana with Vault-managed credentials..."

echo "$GRAFANA_ADMIN_PASSWORD" > /tmp/grafana-admin-password
chown 472:472 /tmp/grafana-admin-password 2>/dev/null || true
chmod 600 /tmp/grafana-admin-password

# Pass password via file (avoids leaking in env and avoids conflict with direct var)
export GF_SECURITY_ADMIN_PASSWORD__FILE=/tmp/grafana-admin-password
unset GRAFANA_ADMIN_PASSWORD

# Ensure GF_SECURITY_ADMIN_PASSWORD is not set (Grafana rejects both)
unset GF_SECURITY_ADMIN_PASSWORD

# Start Grafana official entrypoint
exec /run.sh
