#!/usr/bin/env bash
#
# Vault rekey command - Rotate unseal keys and re-encrypt to .security/vault-keys.gpg
# Part of AIXCL CLI: ./aixcl vault rekey
#
# Uses vault operator rekey to generate a new set of unseal key shares,
# then GPG-encrypts them to .security/vault-keys.gpg. The previous key file
# is replaced atomically. Use after GPG key rotation or when key shares may
# have been exposed.
#
# Vault must be unsealed and reachable. The current root token must be
# available (via .security/vault-root-token.gpg or VAULT_TOKEN env var).
#

set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)}"

if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -o allexport
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/.env"
    set +o allexport
fi

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

SECURITY_DIR="${SCRIPT_DIR}/.security"
VAULT_KEYS_FILE="${SECURITY_DIR}/vault-keys.gpg"
VAULT_KEYS_FILE_NEW="${SECURITY_DIR}/vault-keys.gpg.new"

log_info()  { echo "[INFO] $1"; }
log_warn()  { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }

export VAULT_ADDR

is_vault_sealed() {
    local sealed
    sealed=$(curl -s "${VAULT_ADDR}/v1/sys/seal-status" \
        2>/dev/null | jq -r '.sealed // "unknown"')
    [ "$sealed" = "true" ]
}

load_vault_token() {
    if [ -n "$VAULT_TOKEN" ]; then
        return 0
    fi
    local token_file="${SECURITY_DIR}/vault-root-token.gpg"
    if [ ! -f "$token_file" ]; then
        log_error "No VAULT_TOKEN in environment and no token file at ${token_file}"
        return 1
    fi
    if [ -z "${GPG_TTY:-}" ]; then
        GPG_TTY=$(tty 2>/dev/null || true)
        export GPG_TTY
    fi
    local token
    token=$(gpg --quiet --decrypt "$token_file" 2>/dev/null) || {
        log_error "Failed to decrypt Vault root token."
        log_error "  Is your GPG key available? Check: gpg --list-secret-keys"
        return 1
    }
    VAULT_TOKEN="$token"
    export VAULT_TOKEN
}

main() {
    log_info "Starting Vault rekey..."
    log_info "Vault address: ${VAULT_ADDR}"

    if is_vault_sealed; then
        log_error "Vault is sealed. Unseal before rekeying."
        log_error "  Run: ./aixcl vault unseal"
        return 1
    fi

    load_vault_token || return 1

    # Discover GPG key
    local gpg_id
    gpg_id=$(git -C "${SCRIPT_DIR}" config --get user.signingkey 2>/dev/null || true)
    if [ -z "$gpg_id" ]; then
        gpg_id=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
            | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2 || true)
    fi
    if [ -z "$gpg_id" ]; then
        log_error "No GPG key found. Check: gpg --list-secret-keys"
        return 1
    fi
    log_info "Will encrypt new keys with GPG key: ${gpg_id}"

    # Cancel any in-progress rekey before starting
    curl -sf -X DELETE "${VAULT_ADDR}/v1/sys/rekey/init" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" >/dev/null 2>&1 || true

    # Initialise rekey: 5 shares, threshold 3
    log_info "Initializing rekey (5 shares, threshold 3)..."
    local init_response
    init_response=$(curl -sf -X PUT "${VAULT_ADDR}/v1/sys/rekey/init" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"secret_shares": 5, "secret_threshold": 3}' 2>/dev/null) || {
        log_error "Failed to initialize rekey operation."
        return 1
    }

    local nonce required
    nonce=$(echo "$init_response" | jq -r '.nonce // empty')
    required=$(echo "$init_response" | jq -r '.required // empty')

    if [ -z "$nonce" ] || [ -z "$required" ]; then
        log_error "Unexpected rekey init response: ${init_response}"
        return 1
    fi
    log_info "Rekey initialized. Nonce: ${nonce}. Need ${required} key share(s)."

    # Decrypt current key shares
    log_info "Decrypting current unseal keys..."
    if [ ! -f "$VAULT_KEYS_FILE" ]; then
        log_error "Current key file not found at ${VAULT_KEYS_FILE}"
        log_error "  Cannot rekey without the existing unseal keys."
        return 1
    fi
    if [ -z "${GPG_TTY:-}" ]; then
        GPG_TTY=$(tty 2>/dev/null || true)
        export GPG_TTY
    fi
    local keys_json
    keys_json=$(gpg --quiet --decrypt "$VAULT_KEYS_FILE" 2>/dev/null) || {
        log_error "Failed to decrypt current unseal keys."
        log_error "  Is your GPG key available? Check: gpg --list-secret-keys"
        return 1
    }

    local key_count
    key_count=$(echo "$keys_json" | jq '.unseal_keys_b64 | length' 2>/dev/null || echo "0")
    if [ "$key_count" -lt "$required" ]; then
        log_error "Need ${required} key shares but only found ${key_count} in ${VAULT_KEYS_FILE}"
        return 1
    fi

    # Submit key shares to complete rekey
    local rekey_response=""
    for i in $(seq 0 $((required - 1))); do
        local key
        key=$(echo "$keys_json" | jq -r ".unseal_keys_b64[$i]")
        log_info "Submitting key share $((i + 1)) of ${required}..."
        rekey_response=$(curl -sf -X PUT "${VAULT_ADDR}/v1/sys/rekey/update" \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"key\": \"${key}\", \"nonce\": \"${nonce}\"}" 2>/dev/null) || {
            log_error "Failed to submit key share $((i + 1))."
            return 1
        }

        local complete
        complete=$(echo "$rekey_response" | jq -r '.complete // false')
        if [ "$complete" = "true" ]; then
            break
        fi
    done

    local new_key_count
    new_key_count=$(echo "$rekey_response" | jq '.keys_base64 | length' 2>/dev/null || echo "0")
    if [ "$new_key_count" -lt 3 ]; then
        log_error "Rekey response did not contain new key shares (got ${new_key_count})."
        log_error "  Response: ${rekey_response}"
        return 1
    fi

    # GPG-encrypt new key shares to a temp file, then replace atomically
    log_info "Encrypting new key shares..."
    echo "$rekey_response" | jq '{unseal_keys_b64: .keys_base64, unseal_threshold: 3}' \
        | gpg --quiet --encrypt --recipient "$gpg_id" --armor \
        > "$VAULT_KEYS_FILE_NEW" || {
        log_error "Failed to GPG-encrypt new unseal keys."
        rm -f "$VAULT_KEYS_FILE_NEW"
        return 1
    }
    chmod 600 "$VAULT_KEYS_FILE_NEW"

    # Atomic replacement
    mv "$VAULT_KEYS_FILE_NEW" "$VAULT_KEYS_FILE"
    log_info "New unseal keys written to ${VAULT_KEYS_FILE}"

    # Verify the new keys work by attempting an unseal cycle on a sealed vault is not
    # practical here without sealing first -- just verify the file decrypts cleanly.
    log_info "Verifying new key file decrypts cleanly..."
    local verify_json
    verify_json=$(gpg --quiet --decrypt "$VAULT_KEYS_FILE" 2>/dev/null) || {
        log_error "New key file failed decrypt verification. The old keys may be gone."
        log_error "  CRITICAL: keep the stack running until you verify the new keys work."
        return 1
    }
    local verify_count
    verify_count=$(echo "$verify_json" | jq '.unseal_keys_b64 | length' 2>/dev/null || echo "0")
    if [ "$verify_count" -lt 3 ]; then
        log_error "Verification failed: decrypted file contains fewer than 3 key shares."
        return 1
    fi

    log_info ""
    log_info "Vault rekey complete."
    log_info "  New key shares: ${VAULT_KEYS_FILE}"
    log_info "  BACKUP REMINDER: Copy ${VAULT_KEYS_FILE} to a secure location."
    log_info "  The previous key shares are no longer valid."
}

main "$@"
