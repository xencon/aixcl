#!/usr/bin/env bash
# grafana-entrypoint.sh — Grafana entrypoint wrapper
# On first start: waits for Vault secret, then sets initial admin password
# On restart: skips password reset, respecting user changes
# Never falls back to hardcoded defaults; waits up to 60s for Vault secret
set -euo pipefail

echo "=== Grafana Vault-Secure Entrypoint ==="

# --- Detect first-start vs restart ---
GRAFANA_DB="/var/lib/grafana/grafana.db"
if [ -f "$GRAFANA_DB" ] && [ -s "$GRAFANA_DB" ]; then
    IS_FIRST_START=false
    echo "Grafana database found ($GRAFANA_DB) — restart mode, skipping password reset"
else
    IS_FIRST_START=true
    echo "No Grafana database found — first-start mode"
fi

# --- On restart: just start Grafana and exit ---
if [ "$IS_FIRST_START" = false ]; then
    echo "Starting Grafana (restart) — admin password unchanged"
    exec /run.sh
fi

# --- First-start: wait for Vault password ---
GRAFANA_ADMIN_PASSWORD=""
for i in $(seq 1 60); do
    if [ -f /run/secrets/grafana-password ] && [ -s /run/secrets/grafana-password ]; then
        GRAFANA_ADMIN_PASSWORD="$(tr -d '\n' < /run/secrets/grafana-password)"
        echo "[Vault] Grafana admin password loaded from /run/secrets/grafana-password"
        break
    fi
    echo "[Vault] Waiting for grafana-password secret... ($i/30)"
    sleep 2
done

if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
    echo "[Vault] ERROR: /run/secrets/grafana-password not found or empty after 60 seconds."
    echo "  Cannot create initial admin on first start without Vault-generated password."
    echo "  Ensure Vault is initialized and bootstrap has run."
    exit 1
fi

# --- Use Vault password for first-start admin creation ---
echo "[Vault] Configuring Grafana with initial admin password..."
GRAFANA_PASS_FILE="/tmp/grafana-admin-password"
echo "$GRAFANA_ADMIN_PASSWORD" > "$GRAFANA_PASS_FILE"
chown 472:472 "$GRAFANA_PASS_FILE" \
    || echo "[WARN] chown of $GRAFANA_PASS_FILE failed (no CAP_CHOWN); continuing — chmod 600 below still applies"
chmod 600 "$GRAFANA_PASS_FILE"
export GF_SECURITY_ADMIN_PASSWORD__FILE="$GRAFANA_PASS_FILE"

# Start Grafana in background
/run.sh &
GRAFANA_PID=$!

# Wait for Grafana to be ready
echo "[Vault] Waiting for Grafana to be ready..."
for _ in {1..60}; do
    if curl -sf http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
        echo "[Vault] Grafana is ready (first start)"
        break
    fi
    sleep 1
done

# Verify admin was created (optional sanity check)
if curl -sf http://127.0.0.1:3000/api/admin/settings \
    -u "admin:${GRAFANA_ADMIN_PASSWORD}" >/dev/null 2>&1; then
    echo "[Vault] Initial admin verified"
else
    echo "[Vault] Warning: Could not verify initial admin (may need manual setup)"
fi

# Unset password file env var for security
unset GF_SECURITY_ADMIN_PASSWORD__FILE
rm -f "$GRAFANA_PASS_FILE"

# Keep Grafana running as PID 1 for clean signal handling
echo "[Vault] Grafana is running (PID: $GRAFANA_PID)"
wait $GRAFANA_PID
