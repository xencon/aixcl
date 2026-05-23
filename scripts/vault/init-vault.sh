#!/usr/bin/env bash
# init-vault.sh - Full Vault bootstrap for scorched-earth deployment
#
# Sequence:
#   1. Start Vault container
#   2. vault operator init  -> ~/.aixcl-vault-init.json  (chmod 600)
#   3. vault operator unseal
#   4. Write root token     -> ~/.aixcl-vault-token      (chmod 600)
#   5. Enable KV v2, write bootstrap passwords
#   6. Start bootstrap containers (populate vault-secrets volume)
#   7. Start PostgreSQL, wait until healthy
#   8. Configure Vault database engine + create aixcl-app role
#   9. Start all remaining services
#
# Usage (from repo root):
#   ./scripts/vault/init-vault.sh [--postgres-email EMAIL] [--pgadmin-email EMAIL]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/services/docker-compose.yml"

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_INIT_FILE="${HOME}/.aixcl-vault-init.json"
VAULT_TOKEN_FILE="${HOME}/.aixcl-vault-token"
POSTGRES_EMAIL="${POSTGRES_EMAIL:-admin@localhost}"
PGADMIN_EMAIL="${PGADMIN_EMAIL:-admin@localhost}"
POSTGRES_USER="${POSTGRES_USER:-admin}"
POSTGRES_DATABASE="${POSTGRES_DATABASE:-webui}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --postgres-email) POSTGRES_EMAIL="$2"; shift 2;;
        --pgadmin-email)  PGADMIN_EMAIL="$2";  shift 2;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] INIT | $*"; }
die()  { log "ERROR: $*"; exit 1; }
gen_pass() { openssl rand -hex 20; }

DC="docker compose -f ${COMPOSE_FILE}"

# ── 1. Start Vault ─────────────────────────────────────────────────────────────
# ── 0. Create external volumes ────────────────────────────────────────────────
log "Creating external Docker volumes..."
VOLUMES=(
    aixcl-ollama-data
    aixcl-hf-cache
    aixcl-vllm-data
    aixcl-llamacpp-data
    aixcl-open-webui-main
    aixcl-open-webui-data
    aixcl-pgdata
    aixcl-prometheus
    aixcl-grafana
    aixcl-loki
    aixcl-alertmanager-data
    aixcl-pgadmin-storage
    aixcl-pgadmin-main
    aixcl-pgadmin-config
    aixcl-vault-data
    aixcl-vault-logs
    aixcl-vault-secrets
)
for vol in "${VOLUMES[@]}"; do
    docker volume create "$vol" > /dev/null 2>&1 \
        && log "  Created $vol" \
        || log "  $vol already exists — skipping"
done

log "Starting Vault container..."
$DC up -d vault

log "Waiting for Vault API (up to 60s)..."
for i in $(seq 1 30); do
    curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1 && break || true
    sleep 2
done
curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1 || die "Vault not reachable after 60s"
log "Vault is reachable"

# ── 2. Initialize ──────────────────────────────────────────────────────────────
INIT_STATUS=$(curl -sf "${VAULT_ADDR}/v1/sys/init" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['initialized'])")

if [ "$INIT_STATUS" = "False" ]; then
    log "Initializing Vault (1 key share)..."
    docker exec vault vault operator init \
        -key-shares=1 -key-threshold=1 -format=json > "$VAULT_INIT_FILE"
    chmod 600 "$VAULT_INIT_FILE"
    log "Vault initialized. Keys -> ${VAULT_INIT_FILE}"
else
    log "Vault already initialized"
    [ -f "$VAULT_INIT_FILE" ] || die "${VAULT_INIT_FILE} missing. Manual intervention required."
fi

UNSEAL_KEY=$(python3 -c "import json; d=json.load(open('${VAULT_INIT_FILE}')); print(d['unseal_keys_b64'][0])")
ROOT_TOKEN=$(python3 -c "import json; d=json.load(open('${VAULT_INIT_FILE}')); print(d['root_token'])")

# ── 3. Unseal ──────────────────────────────────────────────────────────────────
SEALED=$(curl -sf "${VAULT_ADDR}/v1/sys/seal-status" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])")
if [ "$SEALED" = "True" ]; then
    log "Unsealing Vault..."
    docker exec -e VAULT_ADDR="$VAULT_ADDR" vault vault operator unseal "$UNSEAL_KEY" > /dev/null
    sleep 2
fi
log "Vault unsealed"

# ── 4. Token file ──────────────────────────────────────────────────────────────
# Write root token to secure file — mounted read-only into all vault agent containers.
# Root token never expires. Treat this file with the same care as the init JSON.
log "Writing Vault token -> ${VAULT_TOKEN_FILE}"
echo "$ROOT_TOKEN" > "$VAULT_TOKEN_FILE"
chmod 600 "$VAULT_TOKEN_FILE"
VAULT_TOKEN="$ROOT_TOKEN"

# ── 5. KV v2 + bootstrap passwords ────────────────────────────────────────────
log "Enabling KV v2 secrets engine..."
curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/kv" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"type":"kv","options":{"version":"2"}}' > /dev/null \
    || log "KV engine already enabled — continuing"

log "Generating bootstrap passwords..."
PG_PASS=$(gen_pass)
OW_PASS=$(gen_pass)
PA_PASS=$(gen_pass)
GF_PASS=$(gen_pass)

log "Writing bootstrap secrets to Vault KV..."
python3 -c "
import json, urllib.request, sys

addr  = '${VAULT_ADDR}'
token = '${VAULT_TOKEN}'

def kv_write(path, data):
    payload = json.dumps({'data': data}).encode()
    req = urllib.request.Request(
        addr + '/v1/kv/data/' + path,
        data=payload,
        headers={'X-Vault-Token': token, 'Content-Type': 'application/json'},
        method='POST'
    )
    with urllib.request.urlopen(req) as r:
        if r.status not in (200, 204):
            print('KV write failed for ' + path + ': ' + str(r.status))
            sys.exit(1)

kv_write('bootstrap/postgres',  {'password': '${PG_PASS}',  'email': '${POSTGRES_EMAIL}', 'username': '${POSTGRES_USER}'})
kv_write('bootstrap/openwebui', {'password': '${OW_PASS}'})
kv_write('bootstrap/pgadmin',   {'password': '${PA_PASS}',  'email': '${PGADMIN_EMAIL}'})
kv_write('bootstrap/grafana',   {'password': '${GF_PASS}'})
print('All bootstrap secrets written')
"

# ── 6. Start bootstrap containers ─────────────────────────────────────────────
log "Starting Vault bootstrap containers..."
$DC up -d \
    vault-agent-postgres-bootstrap \
    vault-agent-openwebui-bootstrap \
    vault-agent-pgadmin-bootstrap \
    vault-agent-grafana-bootstrap

log "Waiting for postgres-password to appear in vault-secrets volume (up to 120s)..."
for i in $(seq 1 60); do
    PW=$(docker run --rm -v aixcl-vault-secrets:/s busybox \
        cat /s/postgres-password 2>/dev/null || true)
    [ -n "$PW" ] && { log "Bootstrap secrets are ready"; break; }
    [ "$i" -eq 60 ] && die "Timed out waiting for vault-secrets volume"
    sleep 2
done

# ── 7. Start PostgreSQL ────────────────────────────────────────────────────────
log "Starting PostgreSQL..."
$DC up -d postgres

log "Waiting for PostgreSQL to become healthy (up to 120s)..."
for i in $(seq 1 60); do
    docker exec postgres pg_isready -U "$POSTGRES_USER" -h 127.0.0.1 > /dev/null 2>&1 \
        && { log "PostgreSQL is ready"; break; }
    [ "$i" -eq 60 ] && die "PostgreSQL not ready after 120s"
    sleep 2
done

# ── 8. Configure Vault database engine ────────────────────────────────────────
log "Configuring Vault database secrets engine..."
python3 -c "
import json, urllib.request, sys

addr    = '${VAULT_ADDR}'
token   = '${VAULT_TOKEN}'
pg_user = '${POSTGRES_USER}'
pg_pass = '${PG_PASS}'
pg_db   = '${POSTGRES_DATABASE}'

def vault_post(path, data):
    payload = json.dumps(data).encode()
    req = urllib.request.Request(
        addr + '/v1/' + path,
        data=payload,
        headers={'X-Vault-Token': token, 'Content-Type': 'application/json'},
        method='POST'
    )
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        if e.code in (400, 204):
            return e.code
        raise

vault_post('sys/mounts/database', {'type': 'database'})

vault_post('database/config/postgresql', {
    'plugin_name': 'postgresql-database-plugin',
    'allowed_roles': 'aixcl-app',
    'connection_url': 'postgresql://{{username}}:{{password}}@127.0.0.1:5432/' + pg_db + '?sslmode=disable',
    'username': pg_user,
    'password': pg_pass
})

creation_sql = (
    'CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD' + \"'\" + '{{password}}' + \"'\" +
    ' VALID UNTIL ' + \"'\" + '{{expiration}}' + \"'\" + '; '
    'GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; '
    'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";'
)
vault_post('database/roles/aixcl-app', {
    'db_name': 'postgresql',
    'creation_statements': [creation_sql],
    'default_ttl': '1h',
    'max_ttl': '24h'
})
print('Database engine configured successfully')
"

log "Testing Vault credential generation..."
docker exec \
    -e VAULT_TOKEN="$VAULT_TOKEN" \
    -e VAULT_ADDR="$VAULT_ADDR" \
    vault vault read database/creds/aixcl-app > /dev/null \
    && log "Credential generation: PASSED" \
    || log "WARNING: Credential test failed — check vault and postgres logs"

# ── 9. Start full stack ────────────────────────────────────────────────────────
log "Starting all remaining services..."
$DC up -d

log ""
log "=========================================================="
log "  Scorched start complete. All services coming up."
log ""
log "  KEEP THESE FILES SAFE — never commit to git:"
log "    ${VAULT_INIT_FILE}"
log "    ${VAULT_TOKEN_FILE}"
log "=========================================================="
