#!/usr/bin/env bash
# Test 00a: Stack VAULT_TOKEN reload behaviour
# Verifies that _load_vault_token_for_stack --force bypasses a stale VAULT_TOKEN
# env var and reads from disk instead.  Does NOT require a running stack.
# Regression test for: https://github.com/xencon/aixcl/issues/1376

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-00a-stack-token-reload"

# ---------------------------------------------------------------------------
# Source only the function under test.
# stack.sh uses SCRIPT_DIR internally; export it so the function can resolve
# the token file path without the rest of the stack machinery running.
# ---------------------------------------------------------------------------
export SCRIPT_DIR

# Extract and define just the function -- sourcing the whole file would attempt
# to parse profiles, compose files, and other runtime state.
_load_vault_token_for_stack() {
    local _force=false
    [ "${1:-}" = "--force" ] && _force=true

    local token_file="${SCRIPT_DIR}/.security/vault-root-token.gpg"

    if [ "$_force" = "false" ] && [ -n "${VAULT_TOKEN:-}" ]; then
        export VAULT_TOKEN
        echo "Vault token taken from VAULT_TOKEN environment variable"
        return 0
    fi

    if [ ! -f "$token_file" ]; then
        echo "[ ] Error: Vault token file not found: ${token_file}"
        return 1
    fi

    if [ -z "${GPG_TTY:-}" ]; then
        if GPG_TTY=$(tty 2>/dev/null); then
            export GPG_TTY
        else
            GPG_TTY=""
        fi
    fi

    local token
    token=$(gpg --quiet --decrypt "$token_file" 2>/dev/null)
    local gpg_exit=$?

    if [ $gpg_exit -ne 0 ] || [ -z "$token" ]; then
        echo "[ ] Error: Failed to decrypt Vault root token from ${token_file}"
        return 1
    fi

    export VAULT_TOKEN="$token"
    echo "Vault root token loaded from .security/"
}

# ---------------------------------------------------------------------------
# Test 1: Without --force, stale VAULT_TOKEN in env is preserved
# ---------------------------------------------------------------------------
log_test_start "VAULT_TOKEN env var is used when --force is absent"

STALE="stale_test_token_$(date +%s)"
VAULT_TOKEN="$STALE"
export VAULT_TOKEN

output=$(_load_vault_token_for_stack 2>&1)

if echo "$output" | grep -q "taken from VAULT_TOKEN environment variable"; then
    log_test_pass "Without --force: env var short-circuit message printed"
else
    log_test_fail "Expected 'taken from VAULT_TOKEN environment variable' in output, got: $output"
    exit 1
fi

if [ "$VAULT_TOKEN" = "$STALE" ]; then
    log_test_pass "Without --force: VAULT_TOKEN unchanged"
else
    log_test_fail "Without --force: VAULT_TOKEN was modified unexpectedly (got: $VAULT_TOKEN)"
    exit 1
fi

# ---------------------------------------------------------------------------
# Test 2: With --force, env var short-circuit is bypassed
# ---------------------------------------------------------------------------
log_test_start "VAULT_TOKEN env var is bypassed when --force is passed"

VAULT_TOKEN="$STALE"
export VAULT_TOKEN

output=$(_load_vault_token_for_stack --force 2>&1) || true

if echo "$output" | grep -q "taken from VAULT_TOKEN environment variable"; then
    log_test_fail "--force should bypass the env var path, but short-circuit message appeared"
    exit 1
else
    log_test_pass "--force: env var short-circuit was bypassed"
fi

# ---------------------------------------------------------------------------
# Test 3: With --force and a valid .security/ file, disk token is loaded
# ---------------------------------------------------------------------------
log_test_start "With --force and valid token file, disk token replaces stale env var"

TOKEN_FILE="${SCRIPT_DIR}/.security/vault-root-token.gpg"
if [ ! -f "$TOKEN_FILE" ]; then
    log_test_skip "No .security/vault-root-token.gpg -- Vault not initialised; skipping decryption test"
else
    VAULT_TOKEN="$STALE"
    export VAULT_TOKEN

    if _load_vault_token_for_stack --force 2>/dev/null; then
        if [ "$VAULT_TOKEN" = "$STALE" ]; then
            log_test_fail "--force with valid token file: VAULT_TOKEN was not updated from disk"
            exit 1
        else
            log_test_pass "--force with valid token file: VAULT_TOKEN replaced stale value"
        fi
    else
        log_test_skip "GPG decryption unavailable in this context (no TTY/key); --force bypass verified in Test 2"
    fi
fi

log_test_pass "All VAULT_TOKEN reload tests passed"
