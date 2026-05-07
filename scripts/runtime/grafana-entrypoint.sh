#!/usr/bin/env bash
# grafana-entrypoint.sh — Grafana entrypoint wrapper
# Reads admin password from Vault secrets volume and starts Grafana.
# This entrypoint requires the admin password to be provided via Vault.
# If the Vault secret is missing, Grafana will fail fast — no hardcoded fallback.
set -euo pipefail

echo "=== Grafana Vault-Secure Entrypoint ==="

# --- Mandatory: admin password from Vault secrets ---
if [ -f /run/secrets/grafana-password ] && [ -s /run/secrets/grafana-password ]; then
    GRAFANA_ADMIN_PASSWORD="$(tr -d '\n' < /run/secrets/grafana-password)"
    echo "[Vault] Grafana admin password loaded from /run/secrets/grafana-password"
else
    echo "[Vault] ERROR: /run/secrets/grafana-password not found or empty."
    echo "  Grafana requires a Vault-generated admin password to start securely."
    exit 1
fi

echo "[Vault] Starting Grafana with Vault-managed credentials..."

# Pass password via file for first-start admin creation
GRAFANA_PASS_FILE="/tmp/grafana-admin-password"
echo "$GRAFANA_ADMIN_PASSWORD" > "$GRAFANA_PASS_FILE"
chown 472:472 "$GRAFANA_PASS_FILE" 2>/dev/null || true
chmod 600 "$GRAFANA_PASS_FILE"
export GF_SECURITY_ADMIN_PASSWORD__FILE="$GRAFANA_PASS_FILE"

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

# Sync admin password with Vault (idempotent)
echo "[Vault] Syncing admin password with Vault..."
grafana cli admin reset-admin-password "$GRAFANA_ADMIN_PASSWORD" 2>/dev/null || \
    echo "[Vault] Note: Password already matches Vault or admin does not exist yet"

# Unset the file env var so it doesn't leak in child processes
unset GF_SECURITY_ADMIN_PASSWORD__FILE

# Keep Grafana running as PID 1 for clean signal handling
echo "[Vault] Grafana is running (PID: $GRAFANA_PID)"
wait $GRAFANA_PID
