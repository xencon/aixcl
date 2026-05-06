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

# Pass password via file for first-start admin creation fallback
echo "$GRAFANA_ADMIN_PASSWORD" > /tmp/grafana-admin-password
chown 472:472 /tmp/grafana-admin-password 2>/dev/null || true
chmod 600 /tmp/grafana-admin-password
export GF_SECURITY_ADMIN_PASSWORD__FILE=/tmp/grafana-admin-password

# Start Grafana in background
/run.sh &
GRAFANA_PID=$!

# Wait for Grafana to be ready
echo "[Vault] Waiting for Grafana to be ready..."
for _ in {1..60}; do
    if curl -sf http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
        echo "[Vault] Grafana is ready"
        break
    fi
    sleep 1
done

# Always reset admin password to current Vault password
# (This ensures Vault remains the single source of truth even if the user changed the password in the UI)
echo "[Vault] Syncing admin password with Vault..."
grafana cli admin reset-admin-password "$GRAFANA_ADMIN_PASSWORD" 2>/dev/null || echo "[Vault] Note: Password already matches Vault or admin does not exist yet"

unset GF_SECURITY_ADMIN_PASSWORD__FILE

# Keep Grafana running as PID 1 for clean signal handling
echo "[Vault] Grafana is running (PID: $GRAFANA_PID)"
wait $GRAFANA_PID
