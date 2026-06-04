#!/usr/bin/env bash
#
# Vault initialization command - Idempotent and safe to run multiple times
# Part of AIXCL CLI: ./aixcl vault init
#
# First run: performs `vault operator init`, GPG-encrypts unseal keys and root
# token to .security/, then unseals and configures all secrets engines.
# Subsequent runs: loads the existing token, unseals if needed, and skips
# any configuration steps that are already in place.
#

set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)}"

# Load .env file if available (for config like POSTGRES_USER, PROFILE)
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -o allexport
    source "${SCRIPT_DIR}/.env"
    set +o allexport
fi

# Load admin identity from .aixcl.initialized if available
# This file is created by `stack init` and stores admin identity securely.
# It takes priority over .env to prevent credential leaks in config files.
if [ -f "${SCRIPT_DIR}/.aixcl.initialized" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            username) AIXCL_ADMIN_USER="${value:-${AIXCL_ADMIN_USER:-}}" ;;
            email)    AIXCL_ADMIN_EMAIL="${value:-${AIXCL_ADMIN_EMAIL:-}}" ;;
        esac
    done < "${SCRIPT_DIR}/.aixcl.initialized"
fi

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
AIXCL_VERBOSE="${AIXCL_VERBOSE:-0}"

SECURITY_DIR="${SCRIPT_DIR}/.security"
VAULT_KEYS_FILE="${SECURITY_DIR}/vault-keys.gpg"
VAULT_TOKEN_FILE="${SECURITY_DIR}/vault-root-token.gpg"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }
log_verbose() { [ "$AIXCL_VERBOSE" -eq 1 ] && echo "[DEBUG] $1" || true; }

export VAULT_ADDR

# ---------------------------------------------------------------------------
# Token helpers
# ---------------------------------------------------------------------------

# Load and decrypt the root token from .security/
load_vault_token() {
    if [ -n "${VAULT_TOKEN:-}" ]; then
        log_verbose "Using VAULT_TOKEN from environment"
        return 0
    fi
    if [ ! -f "$VAULT_TOKEN_FILE" ]; then
        return 1
    fi
    # Ensure GPG_TTY is set so passphrase prompts work (fixes #1169)
    if [ -z "${GPG_TTY:-}" ]; then
        GPG_TTY=$(tty 2>/dev/null || true)
        export GPG_TTY
    fi
    local token
    token=$(gpg --quiet --decrypt "$VAULT_TOKEN_FILE" 2>/dev/null) || {
        log_error "Failed to decrypt Vault root token from ${VAULT_TOKEN_FILE}"
        log_error "  Is your GPG key available? Check: gpg --list-secret-keys"
        log_error "  Try: export GPG_TTY=\$(tty)"
        return 1
    }
    if [ -z "$token" ]; then
        log_error "Decrypted token is empty — ${VAULT_TOKEN_FILE} may be corrupted"
        return 1
    fi
    VAULT_TOKEN="$token"
    export VAULT_TOKEN
}

# ---------------------------------------------------------------------------
# Container / API health checks
# ---------------------------------------------------------------------------

is_vault_running() {
    local bin="${DOCKER_BIN:-}"
    if [ -z "$bin" ]; then
        if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
            bin="podman"
        elif command -v docker >/dev/null 2>&1; then
            bin="docker"
        else
            return 1
        fi
    fi
    "$bin" ps --format "{{.Names}}" | grep -q "^vault$"
}

# Returns true if the Vault HTTP API is responding (even when sealed/uninitialized)
is_vault_api_ready() {
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" \
        "${VAULT_ADDR}/v1/sys/seal-status" 2>/dev/null || echo "000")
    [ "$code" = "200" ]
}

# Returns true if Vault has been operator-init'd
is_vault_initialized() {
    local initialized
    initialized=$(curl -sf "${VAULT_ADDR}/v1/sys/init" 2>/dev/null | jq -r '.initialized // false')
    [ "$initialized" = "true" ]
}

# Returns true if Vault is currently sealed
is_vault_sealed() {
    local sealed
    sealed=$(curl -s "${VAULT_ADDR}/v1/sys/seal-status" \
        2>/dev/null | jq -r '.sealed // "unknown"')
    [ "$sealed" = "true" ]
}

# Wait for the Vault API to respond (allows sealed/uninitialized)
wait_for_vault_api() {
    log_info "Waiting for Vault API to respond..."
    local retries=60
    while [ $retries -gt 0 ]; do
        if is_vault_api_ready; then
            log_verbose "Vault API is ready"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    log_error "Vault API did not respond within 120 seconds"
    return 1
}

# Wait for Vault to be fully unsealed (after operator init + unseal)
wait_for_vault() {
    log_info "Waiting for Vault to be unsealed..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if ! is_vault_sealed; then
            log_verbose "Vault is unsealed"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    log_error "Vault is still sealed after 60 seconds"
    return 1
}

# Wait for PostgreSQL container to accept connections before configuring Vault DB engine
wait_for_postgres() {
    log_info "Waiting for PostgreSQL to be ready..."
    local docker_bin=""
    if command -v podman >/dev/null 2>&1; then
        docker_bin="podman"
    elif command -v docker >/dev/null 2>&1; then
        docker_bin="docker"
    else
        log_warn "No container runtime found; skipping PostgreSQL readiness check"
        return 0
    fi

    local retries=30
    while [ $retries -gt 0 ]; do
        if $docker_bin exec postgres pg_isready -U "${POSTGRES_USER:-admin}" >/dev/null 2>&1; then
            log_info "PostgreSQL is ready"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    log_error "PostgreSQL is not ready after 60 seconds"
    return 1
}

# ---------------------------------------------------------------------------
# One-time operator init: generates unseal keys + root token, GPG-encrypts both
# ---------------------------------------------------------------------------

vault_operator_init() {
    log_info "Performing one-time Vault operator init..."

    # Ensure .security/ exists with restrictive permissions
    mkdir -p "$SECURITY_DIR"
    chmod 700 "$SECURITY_DIR"

    # Discover GPG signing key from git config first, then keyring
    local gpg_id
    gpg_id=$(git -C "${SCRIPT_DIR}" config --get user.signingkey 2>/dev/null || true)
    if [ -z "$gpg_id" ]; then
        gpg_id=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
            | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2 || true)
    fi
    if [ -z "$gpg_id" ]; then
        log_error "No GPG key found. A GPG key is required to encrypt the Vault unseal keys."
        log_error "  See: gpg --list-secret-keys"
        log_error "  Or:  gpg --gen-key"
        return 1
    fi
    log_info "Encrypting Vault secrets with GPG key: ${gpg_id}"

    # Call the Vault init API
    local init_output
    init_output=$(curl -sf -X PUT "${VAULT_ADDR}/v1/sys/init" \
        -H "Content-Type: application/json" \
        -d '{"secret_shares": 5, "secret_threshold": 3}' 2>/dev/null) || {
        log_error "vault operator init API call failed"
        return 1
    }

    local root_token
    root_token=$(echo "$init_output" | jq -r '.root_token // empty')
    if [ -z "$root_token" ]; then
        log_error "operator init response did not contain a root_token"
        return 1
    fi

    # Encrypt and persist unseal key shares
    echo "$init_output" | jq '{unseal_keys_b64: .keys_base64, unseal_threshold: 3}' \
        | gpg --quiet --encrypt --recipient "$gpg_id" --armor \
        > "$VAULT_KEYS_FILE" || {
        log_error "Failed to GPG-encrypt unseal keys"
        return 1
    }
    chmod 600 "$VAULT_KEYS_FILE"

    # Encrypt and persist root token
    printf '%s' "$root_token" \
        | gpg --quiet --encrypt --recipient "$gpg_id" --armor \
        > "$VAULT_TOKEN_FILE" || {
        log_error "Failed to GPG-encrypt root token"
        return 1
    }
    chmod 600 "$VAULT_TOKEN_FILE"

    log_info "Unseal keys saved to:  ${VAULT_KEYS_FILE}"
    log_info "Root token saved to:   ${VAULT_TOKEN_FILE}"
    log_warn "IMPORTANT: Back up ${VAULT_KEYS_FILE} to a secure location."
    log_warn "           Loss of all key shares means permanent data loss."

    # Set token for the rest of this init run
    VAULT_TOKEN="$root_token"
    export VAULT_TOKEN

    # Unseal immediately using the first 3 key shares
    log_info "Unsealing Vault with key shares 1, 2, 3..."
    for i in 0 1 2; do
        local key
        key=$(echo "$init_output" | jq -r ".keys_base64[$i]")
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/unseal" \
            -H "Content-Type: application/json" \
            -d "{\"key\": \"${key}\"}" >/dev/null 2>&1 || {
            log_error "Failed to submit unseal key $((i+1))"
            return 1
        }
    done

    if is_vault_sealed; then
        log_error "Vault is still sealed after submitting 3 key shares"
        return 1
    fi
    log_info "Vault unsealed successfully"
}

# Unseal an already-initialized Vault using the stored GPG-encrypted key shares
vault_unseal_if_needed() {
    if ! is_vault_sealed; then
        log_info "Vault is already unsealed"
        return 0
    fi

    if [ ! -f "$VAULT_KEYS_FILE" ]; then
        log_error "Vault is sealed and no key file found at ${VAULT_KEYS_FILE}"
        log_error "  Run: ./aixcl vault init"
        return 1
    fi

    log_info "Vault is sealed — decrypting key shares and unsealing..."
    local keys_json
    keys_json=$(gpg --quiet --decrypt "$VAULT_KEYS_FILE" 2>/dev/null) || {
        log_error "Failed to decrypt unseal keys. Is your GPG key available?"
        log_error "  Check: gpg --list-secret-keys"
        return 1
    }

    for i in 0 1 2; do
        local key
        key=$(echo "$keys_json" | jq -r ".unseal_keys_b64[$i]")
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/unseal" \
            -H "Content-Type: application/json" \
            -d "{\"key\": \"${key}\"}" >/dev/null 2>&1 || true
    done

    if is_vault_sealed; then
        log_error "Vault is still sealed after submitting 3 key shares"
        return 1
    fi
    log_info "Vault unsealed successfully"
}

# ---------------------------------------------------------------------------
# Secrets engine and configuration helpers (all idempotent)
# ---------------------------------------------------------------------------

generate_password() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c "${length}"
}

is_kv_enabled() {
    local secrets
    secrets=$(curl -sf "${VAULT_ADDR}/v1/sys/mounts" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    echo "$secrets" | grep -q "^kv/"
}

enable_kv_engine() {
    if is_kv_enabled; then
        log_info "KV secrets engine already enabled (skipping)"
        return 0
    fi
    log_info "Enabling KV secrets engine v2..."
    curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/kv" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"type": "kv", "options": {"version": "2"}}' >/dev/null 2>&1 || true
    log_info "KV secrets engine v2 enabled"
}

bootstrap_password_exists() {
    local service="$1"
    local password_data
    password_data=$(curl -sf "${VAULT_ADDR}/v1/kv/data/bootstrap/${service}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    [ -n "$password_data" ] && echo "$password_data" | jq -e '.data.data.password' >/dev/null 2>&1
}

store_bootstrap_password() {
    local service="$1" password="$2" description="$3" email="$4" username="$5"
    log_info "Storing bootstrap password for ${service}..."
    curl -sf -X POST "${VAULT_ADDR}/v1/kv/data/bootstrap/${service}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"password\": \"${password}\", \"email\": \"${email}\", \"username\": \"${username}\", \"description\": \"${description}\", \"created\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" >/dev/null 2>&1 || {
        log_warn "Failed to store bootstrap password for ${service}"
        return 1
    }
    log_info "Bootstrap password for ${service} stored in Vault KV"
}

clear_bootstrap_artifacts() {
    log_info "Clearing old bootstrap password artifacts..."
    local files="/run/secrets/postgres-password /run/secrets/openwebui-password /run/secrets/pgadmin-password /run/secrets/grafana-password"
    for f in $files; do
        if [ -f "$f" ]; then
            rm -f "$f"
            log_info "Cleared old artifact: $f"
        fi
    done
}

init_bootstrap_passwords() {
    log_info "Initializing bootstrap passwords..."
    clear_bootstrap_artifacts

    local admin_email="${AIXCL_ADMIN_EMAIL:-}"
    local admin_user="${AIXCL_ADMIN_USER:-}"
    if [ -z "$admin_email" ] || [ -z "$admin_user" ]; then
        log_error "AIXCL_ADMIN_USER and AIXCL_ADMIN_EMAIL must be set before running vault init."
        log_error "  Set them in .env or via environment variables."
        exit 1
    fi
    if ! echo "$admin_email" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
        log_error "AIXCL_ADMIN_EMAIL (${admin_email}) does not appear valid."
        exit 1
    fi
    log_info "Admin identity: ${admin_user} / ${admin_email}"

    # PostgreSQL: sync from container if it already has a password
    local postgres_password=""
    if [ -f /run/secrets/postgres-password ] && [ -s /run/secrets/postgres-password ]; then
        postgres_password=$(cat /run/secrets/postgres-password | tr -d '\n')
        log_info "Read existing PostgreSQL password from shared volume"
    fi
    if [ -z "$postgres_password" ] && command -v podman >/dev/null 2>&1; then
        postgres_password=$(podman exec postgres cat /run/secrets/postgres-password 2>/dev/null | tr -d '\n' || true)
        [ -n "$postgres_password" ] && log_info "Read existing PostgreSQL password from container"
    fi
    if [ -z "$postgres_password" ] && command -v docker >/dev/null 2>&1; then
        postgres_password=$(docker exec postgres cat /run/secrets/postgres-password 2>/dev/null | tr -d '\n' || true)
        [ -n "$postgres_password" ] && log_info "Read existing PostgreSQL password from container"
    fi
    [ -z "$postgres_password" ] && postgres_password=$(generate_password 32)
    store_bootstrap_password "postgres" "$postgres_password" "PostgreSQL admin/bootstrap password" "$admin_email" "$admin_user"

    for service in openwebui pgadmin grafana; do
        if ! bootstrap_password_exists "$service"; then
            local pw
            pw=$(generate_password 32)
            local desc
            case "$service" in
                openwebui) desc="Open WebUI admin password" ;;
                pgadmin)   desc="pgAdmin admin password" ;;
                grafana)   desc="Grafana admin password" ;;
            esac
            store_bootstrap_password "$service" "$pw" "$desc" "$admin_email" "$admin_user"
            log_info "Generated ${service} bootstrap password"
        else
            log_info "${service} bootstrap password already exists (skipping)"
        fi
    done
    log_info "Bootstrap passwords initialized"
}

is_database_enabled() {
    local secrets
    secrets=$(curl -sf "${VAULT_ADDR}/v1/sys/mounts" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    echo "$secrets" | grep -q "^database/"
}

enable_database_engine() {
    if is_database_enabled; then
        log_info "Database secrets engine already enabled (skipping)"
        return 0
    fi
    log_info "Enabling database secrets engine..."
    curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/database" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"type": "database"}' >/dev/null 2>&1 || {
        log_error "Failed to enable database secrets engine"
        return 1
    }
    log_info "Database secrets engine enabled"
}

delete_broken_postgres_config() {
    local config
    config=$(curl -sf "${VAULT_ADDR}/v1/database/config/postgresql" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    if [ -n "$config" ] && ! echo "$config" | jq -e '.data.connection_details.connection_url' >/dev/null 2>&1; then
        log_warn "Found stale PostgreSQL config without connection_url — deleting..."
        curl -sf -X DELETE "${VAULT_ADDR}/v1/database/config/postgresql" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" >/dev/null 2>&1 || true
        log_info "Stale config deleted"
    fi
}

is_postgres_configured() {
    local config
    config=$(curl -sf "${VAULT_ADDR}/v1/database/config/postgresql" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    [ -n "$config" ] && echo "$config" | jq -e '.data.connection_details.connection_url' >/dev/null 2>&1
}

configure_postgres_connection() {
    delete_broken_postgres_config

    local postgres_password=""
    local postgres_user="${POSTGRES_USER:-admin}"

    # Always read the current password from Vault KV (authoritative) or the secrets volume
    postgres_password=$(curl -sf "${VAULT_ADDR}/v1/kv/data/bootstrap/postgres" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data.data.password // empty')
    if [ -z "$postgres_password" ] && command -v podman >/dev/null 2>&1; then
        postgres_password=$(podman exec postgres cat /run/secrets/postgres-password 2>/dev/null | tr -d '\n' || true)
    fi
    if [ -z "$postgres_password" ] && command -v docker >/dev/null 2>&1; then
        postgres_password=$(docker exec postgres cat /run/secrets/postgres-password 2>/dev/null | tr -d '\n' || true)
    fi
    if [ -z "$postgres_password" ]; then
        log_warn "Could not retrieve PostgreSQL password; connection config may fail"
        postgres_password="admin"
    fi

    # Always (re)configure — idempotent POST updates credentials if already present.
    # This ensures the stored password stays in sync after postgres password rotations.
    log_info "Configuring PostgreSQL connection (syncing credentials)..."
    curl -sf -X POST "${VAULT_ADDR}/v1/database/config/postgresql" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"plugin_name\": \"postgresql-database-plugin\",
            \"allowed_roles\": \"aixcl-app,aixcl-admin,aixcl-readonly\",
            \"connection_url\": \"postgresql://{{username}}:{{password}}@127.0.0.1:5432/webui?sslmode=disable\",
            \"username\": \"${postgres_user}\",
            \"password\": \"${postgres_password}\"
        }" >/dev/null 2>&1 || {
        log_error "Failed to configure PostgreSQL connection"
        return 1
    }
    log_info "PostgreSQL connection configured"
}

create_app_role() {
    role_exists "aixcl-app" && { log_info "Application role already exists (skipping)"; return 0; }
    log_info "Creating application role..."
    curl -sf -X POST "${VAULT_ADDR}/v1/database/roles/aixcl-app" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "db_name": "postgresql",
            "creation_statements": "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT USAGE, CREATE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
            "revocation_statements": "REASSIGN OWNED BY \"{{name}}\" TO CURRENT_USER; DROP OWNED BY \"{{name}}\"; DROP ROLE IF EXISTS \"{{name}}\";",
            "default_ttl": "1h",
            "max_ttl": "24h"
        }' >/dev/null 2>&1 || true
}

create_admin_role() {
    role_exists "aixcl-admin" && { log_info "Admin role already exists (skipping)"; return 0; }
    log_info "Creating admin role..."
    curl -sf -X POST "${VAULT_ADDR}/v1/database/roles/aixcl-admin" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "db_name": "postgresql",
            "creation_statements": "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
            "default_ttl": "15m",
            "max_ttl": "1h"
        }' >/dev/null 2>&1 || log_warn "Failed to create admin role"
}

create_readonly_role() {
    role_exists "aixcl-readonly" && { log_info "Readonly role already exists (skipping)"; return 0; }
    log_info "Creating readonly role..."
    curl -sf -X POST "${VAULT_ADDR}/v1/database/roles/aixcl-readonly" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "db_name": "postgresql",
            "creation_statements": "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '"'"'{{password}}'"'"' VALID UNTIL '"'"'{{expiration}}'"'"'; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
            "default_ttl": "1h",
            "max_ttl": "24h"
        }' >/dev/null 2>&1 || log_warn "Failed to create readonly role"
}

policy_exists() {
    local policy_name="$1"
    local policy_data
    policy_data=$(curl -sf "${VAULT_ADDR}/v1/sys/policy/$policy_name" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    [ -n "$policy_data" ] && echo "$policy_data" | jq -e '.data' >/dev/null 2>&1
}

create_policies() {
    if ! policy_exists "aixcl-app"; then
        log_info "Creating aixcl-app policy..."
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policy/aixcl-app" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"policy": "path \"database/creds/aixcl-app\" { capabilities = [\"read\"] }\npath \"database/creds/aixcl-readonly\" { capabilities = [\"read\"] }\npath \"database/creds/aixcl-admin\" { capabilities = [\"deny\"] }"}' >/dev/null 2>&1 || log_warn "Failed to create aixcl-app policy"
    else
        log_info "aixcl-app policy already exists (skipping)"
    fi

    if ! policy_exists "aixcl-admin"; then
        log_info "Creating aixcl-admin policy..."
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policy/aixcl-admin" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"policy": "path \"database/creds/*\" { capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"] }\npath \"database/roles/*\" { capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"] }\npath \"database/config/*\" { capabilities = [\"read\"] }"}' >/dev/null 2>&1 || log_warn "Failed to create aixcl-admin policy"
    else
        log_info "aixcl-admin policy already exists (skipping)"
    fi

    if ! policy_exists "aixcl-readonly"; then
        log_info "Creating aixcl-readonly policy..."
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policy/aixcl-readonly" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"policy": "path \"database/creds/aixcl-readonly\" { capabilities = [\"read\"] }"}' >/dev/null 2>&1 || log_warn "Failed to create aixcl-readonly policy"
    else
        log_info "aixcl-readonly policy already exists (skipping)"
    fi
}

is_approle_enabled() {
    local auths
    auths=$(curl -sf "${VAULT_ADDR}/v1/sys/auth" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    echo "$auths" | grep -q "^approle/"
}

enable_approle_auth() {
    if is_approle_enabled; then
        log_info "AppRole authentication already enabled (skipping)"
    else
        log_info "Enabling AppRole authentication..."
        curl -sf -X POST "${VAULT_ADDR}/v1/sys/auth/approle" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"type": "approle"}' >/dev/null 2>&1 || log_warn "AppRole may already be enabled"
    fi

    log_info "Configuring AppRoles for services..."
    curl -sf -X POST "${VAULT_ADDR}/v1/auth/approle/role/aixcl-open-webui" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"token_policies": "aixcl-app", "token_ttl": "1h", "token_max_ttl": "24h"}' >/dev/null 2>&1 || true
    curl -sf -X POST "${VAULT_ADDR}/v1/auth/approle/role/aixcl-postgres-exporter" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"token_policies": "aixcl-readonly", "token_ttl": "1h", "token_max_ttl": "24h"}' >/dev/null 2>&1 || true
}

is_audit_enabled() {
    local audits
    audits=$(curl -sf "${VAULT_ADDR}/v1/sys/audit" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null | jq -r '.data | keys[]' 2>/dev/null || true)
    echo "$audits" | grep -q "^file/"
}

enable_audit_logging() {
    if is_audit_enabled; then
        log_info "Audit logging already enabled (skipping)"
        return 0
    fi
    log_info "Enabling audit logging..."
    curl -sf -X PUT "${VAULT_ADDR}/v1/sys/audit/file" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"type": "file", "options": {"file_path": "/vault/logs/audit.log"}}' >/dev/null 2>&1 || log_warn "Audit may already be enabled"
    log_info "Audit logs: /vault/logs/audit.log"
}

test_credentials() {
    log_info "Testing credential generation..."
    local creds
    creds=$(curl -sf "${VAULT_ADDR}/v1/database/creds/aixcl-app" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)
    if [ -z "$creds" ] || ! echo "$creds" | jq -e '.data' >/dev/null 2>&1; then
        log_warn "Failed to generate test credentials (PostgreSQL may not be ready yet)"
        return 0
    fi
    local username
    username=$(echo "$creds" | jq -r '.data.username')
    log_info "Generated test credentials successfully (username: ${username})"
    # Revoke test credentials immediately
    local lease_id
    lease_id=$(echo "$creds" | jq -r '.lease_id // empty')
    if [ -n "$lease_id" ]; then
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/leases/revoke" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"lease_id\": \"$lease_id\"}" >/dev/null 2>&1 || true
    fi
}

show_summary() {
    log_info ""
    log_info "=========================================="
    log_info "  Vault Initialization Complete"
    log_info "=========================================="
    log_info ""
    log_info "Unseal keys:  ${VAULT_KEYS_FILE}"
    log_info "Root token:   ${VAULT_TOKEN_FILE}"
    log_info ""
    log_info "BACKUP REMINDER: Copy ${VAULT_KEYS_FILE} to a secure"
    log_info "  location (e.g. encrypted USB). Loss of all key shares"
    log_info "  means permanent loss of Vault data."
    log_info ""
    log_info "Dynamic credentials:  ./aixcl vault credentials"
    log_info "Bootstrap passwords:  ./aixcl vault passwords"
    log_info "Unseal after restart: ./aixcl vault unseal  (done automatically by stack start)"
    log_info ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    log_info "Starting Vault initialization..."
    log_info "Vault address: ${VAULT_ADDR}"

    if ! is_vault_running; then
        log_error "Vault container is not running."
        log_error "  Start the stack first: ./aixcl stack start --profile sys"
        return 1
    fi

    # Wait for the API to respond (may be sealed or uninitialized)
    wait_for_vault_api || return 1

    if ! is_vault_initialized; then
        # First-time init: generate unseal keys and root token
        vault_operator_init || return 1
    else
        log_info "Vault is already initialized — loading token and checking seal state..."
        if ! load_vault_token; then
            log_info "No token found in .security/ — re-running operator init to recover keys..."
            vault_operator_init || return 1
        else
            vault_unseal_if_needed || return 1
        fi
    fi

    # Confirm unsealed before proceeding
    wait_for_vault || return 1

    # Configure secrets engines and roles (all idempotent)
    # NOTE: KV engine and bootstrap passwords must be set up first
    #       so that bootstrap agents can populate secrets before PostgreSQL
    #       finishes starting (fixes circular dependency with Podman rootless).
    # NOTE: PostgreSQL must be ready before the database engine tries to connect.
    enable_kv_engine || return 1
    init_bootstrap_passwords || return 1
    wait_for_postgres || return 1
    enable_database_engine || return 1
    configure_postgres_connection || return 1
    create_app_role || return 1
    create_admin_role || return 1
    create_readonly_role || return 1
    create_policies || return 1
    enable_approle_auth || return 1
    enable_audit_logging || return 1
    test_credentials

    show_summary
    return 0
}

main "$@"
