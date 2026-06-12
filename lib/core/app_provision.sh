#!/usr/bin/env bash
# App provisioning for AIXCL
# Implements the declarative `provision:` contract from apps/<name>/app.yaml.
#
# The platform owns Vault, Postgres, and the per-app secrets volume. Apps
# declare what they need; the platform creates it idempotently on app start.
# Apps never hold Vault tokens and never mount the shared platform secrets
# volume (aixcl-vault-secrets).
#
# Manifest contract:
#
#   provision:
#     secrets:                  # generated if absent, stored in Vault KV
#       - db-password           #   kv/data/apps/<app> (field per secret)
#       - auth-password         # rendered to volume aixcl-app-<app>-secrets
#     postgres:                 # optional
#       database: myapp         # database created if absent
#       owner: myapp            # role created/synced with LOGIN
#       password_secret: db-password   # which secret is the role password
#
# Each secret is rendered to /run/secrets/<app>-<secret> inside the volume
# aixcl-app-<app>-secrets, which the app's compose file mounts read-only.
#
# Dependencies: app_parser.sh (manifest already loaded), python3,
#               _load_vault_token_for_stack (lib/aixcl/commands/stack.sh)

# Vault KV v2 mount used for app secrets
_APP_PROVISION_KV_BASE="kv/data/apps"

# -- Helpers --------------------------------------------------------------------

# Validate an identifier used for postgres roles/databases (injection guard)
_app_provision_valid_ident() {
    [[ "$1" =~ ^[a-z][a-z0-9_]{0,62}$ ]]
}

# Validate a secret name from the manifest (used in file names and KV fields)
_app_provision_valid_secret_name() {
    [[ "$1" =~ ^[a-z][a-z0-9-]{0,62}$ ]]
}

# Generate a random alphanumeric secret (32 chars).
# python3 is already a hard dependency (app_parser.sh); avoids the
# tr </dev/urandom | head SIGPIPE that trips pipefail.
_app_provision_generate_secret() {
    python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32)))"
}

# Collect declared secret names from loaded manifest variables.
# Prints one name per line.
_app_provision_secret_names() {
    local i=0
    while true; do
        local name
        name="$(eval "echo \${APP_PROVISION_SECRETS_${i}:-}" 2>/dev/null || true)"
        if [ -z "$name" ]; then
            break
        fi
        echo "$name"
        i=$((i + 1))
    done
}

# True if the loaded manifest declares anything to provision
_app_provision_required() {
    [ -n "${APP_PROVISION_SECRETS_0:-}" ] || [ -n "${APP_PROVISION_POSTGRES_DATABASE:-}" ]
}

# Ensure VAULT_ADDR/VAULT_TOKEN are available in this process.
_app_provision_ensure_vault() {
    export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
    if [ -z "${VAULT_TOKEN:-}" ]; then
        # Note: must run in this shell (it exports VAULT_TOKEN); piping or
        # command substitution would subshell it and lose the export.
        if command -v _load_vault_token_for_stack >/dev/null 2>&1; then
            _load_vault_token_for_stack || true
        fi
    fi
    if [ -z "${VAULT_TOKEN:-}" ]; then
        echo "  ${ICON_ERROR:-[ ]} Vault token unavailable. Run: ./aixcl vault init" >&2
        return 1
    fi
    return 0
}

# -- Vault KV -------------------------------------------------------------------

# Read the app's KV entry and print "field<TAB>value" lines (empty if absent)
_app_provision_kv_read() {
    local app_name="$1"
    local response
    response="$(curl -sf "${VAULT_ADDR}/v1/${_APP_PROVISION_KV_BASE}/${app_name}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || true)"
    [ -z "$response" ] && return 0
    printf '%s' "$response" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin).get("data", {}).get("data", {})
except Exception:
    sys.exit(0)
for k, v in data.items():
    print(f"{k}\t{v}")
'
}

# Write fields to the app's KV entry. Reads "field<TAB>value" lines on stdin.
_app_provision_kv_write() {
    local app_name="$1"
    local payload
    payload="$(python3 -c '
import json, sys
data = {}
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    k, _, v = line.partition("\t")
    data[k] = v
print(json.dumps({"data": data}))
')"
    curl -sf -X POST "${VAULT_ADDR}/v1/${_APP_PROVISION_KV_BASE}/${app_name}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$payload" >/dev/null
}

# -- Secrets volume -------------------------------------------------------------

_app_provision_volume_name() {
    echo "aixcl-app-${1}-secrets"
}

# Write one secret value (stdin) to a file inside the app secrets volume.
# The value never appears in argv or the environment of the helper container.
_app_provision_render_secret() {
    local volume="$1"
    local filename="$2"
    "${DOCKER_BIN:-docker}" run --rm -i --network none \
        -v "${volume}:/secrets" \
        docker.io/library/alpine:latest \
        sh -c "umask 077 && cat > /secrets/${filename}"
}

# -- Postgres -------------------------------------------------------------------

# Ensure role + database exist in the platform postgres container.
# Args: <database> <owner> <password>
_app_provision_postgres() {
    local database="$1"
    local owner="$2"
    local password="$3"

    if ! _app_provision_valid_ident "$database" || ! _app_provision_valid_ident "$owner"; then
        echo "  ${ICON_ERROR:-[ ]} Invalid postgres identifier in manifest (lowercase alnum/underscore only)" >&2
        return 1
    fi

    if ! "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" 2>/dev/null | grep -q "^postgres$"; then
        echo "  ${ICON_ERROR:-[ ]} Platform postgres container is not running. Run: ./aixcl stack start" >&2
        return 1
    fi

    # Escape single quotes for the SQL string literal (password is generated
    # alphanumeric, but a manually rotated Vault value may contain anything)
    local pw_sql="${password//\'/\'\'}"

    "${DOCKER_BIN:-docker}" exec -i postgres sh -c \
        'PGPASSWORD="$(cat /run/secrets/postgres-password)" psql -q -U "${POSTGRES_USER}" -d postgres -v ON_ERROR_STOP=1' << SQL
DO \$do\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${owner}') THEN
        CREATE ROLE ${owner} LOGIN PASSWORD '${pw_sql}';
    ELSE
        ALTER ROLE ${owner} WITH LOGIN PASSWORD '${pw_sql}';
    END IF;
END
\$do\$;
SELECT 'CREATE DATABASE ${database} OWNER ${owner}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${database}')\gexec
SQL
}

# -- Entry point ----------------------------------------------------------------

# Provision everything the loaded manifest declares. Idempotent.
# Requires _app_load_manifest to have been called for this app.
# Usage: _app_provision <app_name>
_app_provision() {
    local app_name="$1"

    if ! _app_provision_required; then
        return 0
    fi

    echo "  Provisioning ${app_name}..."

    _app_provision_ensure_vault || return 1

    # 1. Ensure all declared secrets exist in Vault KV (generate missing)
    local kv_state
    kv_state="$(_app_provision_kv_read "$app_name")"

    local names changed=false
    names="$(_app_provision_secret_names)"
    local name
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        if ! _app_provision_valid_secret_name "$name"; then
            echo "  ${ICON_ERROR:-[ ]} Invalid secret name in manifest: ${name}" >&2
            return 1
        fi
        if ! printf '%s\n' "$kv_state" | grep -q "^${name}	"; then
            local value
            value="$(_app_provision_generate_secret)"
            kv_state="$(printf '%s\n%s\t%s' "$kv_state" "$name" "$value")"
            changed=true
        fi
    done <<< "$names"

    if [ "$changed" = true ]; then
        if ! printf '%s\n' "$kv_state" | _app_provision_kv_write "$app_name"; then
            echo "  ${ICON_ERROR:-[ ]} Failed to write secrets to Vault KV" >&2
            return 1
        fi
    fi

    # 2. Render secrets into the per-app volume
    local volume
    volume="$(_app_provision_volume_name "$app_name")"
    "${DOCKER_BIN:-docker}" volume create "$volume" >/dev/null 2>&1 || true

    while IFS= read -r name; do
        [ -z "$name" ] && continue
        local value
        value="$(printf '%s\n' "$kv_state" | grep "^${name}	" | head -1 | cut -f2-)"
        if [ -z "$value" ]; then
            echo "  ${ICON_ERROR:-[ ]} Secret ${name} missing after Vault sync" >&2
            return 1
        fi
        if ! printf '%s\n' "$value" | _app_provision_render_secret "$volume" "${app_name}-${name}"; then
            echo "  ${ICON_ERROR:-[ ]} Failed to render secret ${app_name}-${name}" >&2
            return 1
        fi
    done <<< "$names"

    # 3. Ensure postgres role + database if declared
    if [ -n "${APP_PROVISION_POSTGRES_DATABASE:-}" ]; then
        local database owner pw_secret password
        database="${APP_PROVISION_POSTGRES_DATABASE}"
        owner="${APP_PROVISION_POSTGRES_OWNER:-$database}"
        pw_secret="${APP_PROVISION_POSTGRES_PASSWORD_SECRET:-db-password}"
        password="$(printf '%s\n' "$kv_state" | grep "^${pw_secret}	" | head -1 | cut -f2-)"
        if [ -z "$password" ]; then
            echo "  ${ICON_ERROR:-[ ]} provision.postgres.password_secret '${pw_secret}' is not a declared secret" >&2
            return 1
        fi
        if ! _app_provision_postgres "$database" "$owner" "$password" >/dev/null; then
            echo "  ${ICON_ERROR:-[ ]} Postgres provisioning failed for ${app_name}" >&2
            return 1
        fi
    fi

    echo "  ${ICON_SUCCESS:-[x]} Provisioned (vault secrets, app volume$([ -n "${APP_PROVISION_POSTGRES_DATABASE:-}" ] && echo ", postgres"))"
    return 0
}

# Print the app's provisioned secrets (developer convenience; local stack only).
# Usage: _app_provision_show_secrets <app_name>
_app_provision_show_secrets() {
    local app_name="$1"

    if [ -z "${APP_PROVISION_SECRETS_0:-}" ]; then
        echo "No provisioned secrets declared for ${app_name}."
        return 0
    fi

    _app_provision_ensure_vault || return 1

    local kv_state
    kv_state="$(_app_provision_kv_read "$app_name")"
    if [ -z "$kv_state" ]; then
        echo "No secrets found in Vault for ${app_name}. Run: ./aixcl app start ${app_name}"
        return 1
    fi

    echo ""
    echo "Secrets for ${app_name} (kv/apps/${app_name})"
    echo "--------------------------------------------------"
    local name
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        local value
        value="$(printf '%s\n' "$kv_state" | grep "^${name}	" | head -1 | cut -f2-)"
        printf "  %-20s %s\n" "$name" "${value:-<missing>}"
    done <<< "$(_app_provision_secret_names)"
    echo ""
}

export -f _app_provision _app_provision_required _app_provision_show_secrets
export -f _app_provision_secret_names _app_provision_valid_ident _app_provision_valid_secret_name
export -f _app_provision_generate_secret _app_provision_ensure_vault
export -f _app_provision_kv_read _app_provision_kv_write
export -f _app_provision_volume_name _app_provision_render_secret _app_provision_postgres
