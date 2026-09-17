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
    sealed=$(curl -s "${VAULT_ADDR}/v1/sys/seal-status" \
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
    local last_response
    last_response=""
    for i in 0 1 2; do
        local key resp_file
        key=$(echo "$keys_json" | jq -r ".unseal_keys_b64[$i]")
        resp_file=$(mktemp)
        curl -s -o "$resp_file" -X PUT "${VAULT_ADDR}/v1/sys/unseal" \
            -H "Content-Type: application/json" \
            -d "{\"key\": \"${key}\"}" 2>/dev/null || true
        last_response=$(cat "$resp_file" 2>/dev/null)
        rm -f "$resp_file"
    done

    if is_vault_sealed; then
        # Vault's own response at the failing threshold submission distinguishes
        # "these keys do not belong to this instance's data" from other sealed
        # states -- surface that instead of a generic retry-suggesting message
        # (#2051: a stale .security/vault-keys.gpg vs. a reset/restored
        # aixcl-vault-data volume produces exactly this signature).
        if echo "$last_response" | grep -q "cipher: message authentication failed"; then
            log_error "These unseal keys do not match this Vault instance's data."
            log_error "  ${VAULT_KEYS_FILE} was likely generated for a different"
            log_error "  initialization of the aixcl-vault-data volume."
            log_error "  Recovery: ./aixcl vault init will wipe and reinitialize Vault (destructive)."
        else
            log_error "Vault is still sealed after submitting 3 key shares"
            log_error "  Check: ${DOCKER_BIN:-docker} logs vault | tail -20"
        fi
        return 1
    fi

    log_info "Vault unsealed successfully"
}

main "$@"
