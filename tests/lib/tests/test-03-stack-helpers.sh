#!/usr/bin/env bash
# Test 03: internal stack.sh helper functions
# No running stack required -- tests pure helper functions only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/core/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/cli/profile.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/aixcl/commands/stack.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-03-stack-helpers"

# ---------------------------------------------------------------------------
# _print_stopped_status
# ---------------------------------------------------------------------------

bld_output="$(_print_stopped_status bld)"
assert_string_contains "$bld_output" "AIXCL Stack Stopped" \
    "_print_stopped_status outputs header"
assert_string_contains "$bld_output" "Profile: bld" \
    "_print_stopped_status includes profile name"
assert_string_contains "$bld_output" "vault" \
    "_print_stopped_status bld includes vault"
assert_string_contains "$bld_output" "postgres" \
    "_print_stopped_status bld includes postgres"
assert_string_not_contains "$bld_output" "open-webui" \
    "_print_stopped_status bld excludes open-webui"
assert_string_not_contains "$bld_output" "pgadmin" \
    "_print_stopped_status bld excludes pgadmin"

sys_output="$(_print_stopped_status sys)"
assert_string_contains "$sys_output" "Profile: sys" \
    "_print_stopped_status sys includes profile name"
assert_string_contains "$sys_output" "open-webui" \
    "_print_stopped_status sys includes open-webui"
assert_string_contains "$sys_output" "pgadmin" \
    "_print_stopped_status sys includes pgadmin"

# ---------------------------------------------------------------------------
# _load_vault_token_for_stack -- env var shortcut (no GPG, no file I/O)
# ---------------------------------------------------------------------------

VAULT_TOKEN="test-token-abc123"
export VAULT_TOKEN

set +e
token_output="$(_load_vault_token_for_stack 2>&1)"
token_exit=$?
set -e

assert_string_contains "$token_output" "VAULT_TOKEN" \
    "_load_vault_token_for_stack uses env var when set"
[ "$token_exit" -eq 0 ] \
    && log_success "_load_vault_token_for_stack env var path returns 0" \
    || { log_error "_load_vault_token_for_stack env var path returned non-zero ($token_exit)"; false; }

unset VAULT_TOKEN

# ---------------------------------------------------------------------------
# _load_vault_token_for_stack -- missing token file returns error
# Use a temp SCRIPT_DIR so the real .security/vault-root-token.gpg is not used.
# ---------------------------------------------------------------------------

_tmp_dir="$(mktemp -d)"
_real_script_dir="$SCRIPT_DIR"
SCRIPT_DIR="$_tmp_dir"

set +e
missing_output="$(_load_vault_token_for_stack 2>&1)"
missing_exit=$?
set -e

SCRIPT_DIR="$_real_script_dir"
rm -rf "$_tmp_dir"

assert_string_contains "$missing_output" "Error" \
    "_load_vault_token_for_stack missing file outputs error"
[ "$missing_exit" -ne 0 ] \
    && log_success "_load_vault_token_for_stack missing file returns non-zero" \
    || { log_error "_load_vault_token_for_stack missing file should return non-zero"; false; }

log_test_pass "Stack helper functions work correctly"
