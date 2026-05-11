#!/usr/bin/env bash
#
# Vault unseal command - Unseals a sealed Vault using GPG-encrypted key shares
# Part of AIXCL CLI: ./aixcl vault unseal
#
# No-op if Vault is already unsealed. Fails clearly if keys are missing or
# the GPG key is not available in the keyring.
#

set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)}"

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
SECURITY_DIR="${SCRIPT_DIR}/.security"
VAULT_KEYS_FILE="${SECURITY_DIR}/vault-keys.gpg"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }

export VAULT_ADDR

is_vault_api_ready() {
    local code
    code=$(curl -sf -o /dev/null -w "%{http_code}" \
        "${VAULT_ADDR}/v1/sys/health?sealedok=true&uninitok=true" 2>/dev/null || echo "000")
    [ "$code" != "000" ]
}

is_vault_sealed() {
    local sealed
    sealed=$(curl -sf "${VAULT_ADDR}/v1/sys/health?sealedok=true" \
        2>/dev/null | jq -r '.sealed // "unknown"')
    [ "$sealed" = "true" ]
}

main() {
    if ! is_vault_api_ready; then
        log_error "Vault API is not responding at ${VAULT_ADDR}"
        log_error "  Is the stack running? Try: ./aixcl stack start --profile sys"
        return 1
    fi

    if ! is_vault_sealed; then
        log_info "Vault is already unsealed — nothing to do"
        return 0
    fi

    if [ ! -f "$VAULT_KEYS_FILE" ]; then
        log_error "Vault is sealed but no key file found at ${VAULT_KEYS_FILE}"
        log_error "  Run './aixcl vault init' to initialize Vault (first-time setup)"
        return 1
    fi

    log_info "Vault is sealed — decrypting key shares..."
    local keys_json
    keys_json=$(gpg --quiet --decrypt "$VAULT_KEYS_FILE" 2>/dev/null) || {
        log_error "Failed to decrypt unseal keys."
        log_error "  Is your GPG key available? Check: gpg --list-secret-keys"
        log_error "  If the key is on a card or YubiKey, ensure it is inserted."
        return 1
    }

    log_info "Submitting key shares 1, 2, 3..."
    for i in 0 1 2; do
        local key
        key=$(echo "$keys_json" | jq -r ".unseal_keys_b64[$i]")
        curl -sf -X PUT "${VAULT_ADDR}/v1/sys/unseal" \
            -H "Content-Type: application/json" \
            -d "{\"key\": \"${key}\"}" >/dev/null 2>&1 || true
    done

    if is_vault_sealed; then
        log_error "Vault is still sealed after submitting 3 key shares"
        log_error "  Check: podman logs vault | tail -20"
        return 1
    fi

    log_info "Vault unsealed successfully"
}

main "$@"
