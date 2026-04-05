#!/usr/bin/env bash
# Test 05: Engine Set - llama.cpp
# Tests setting engine to llama.cpp

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-05-engine-set-llamacpp"

# Capture state before test
BACKUP_DIR=$(capture_state "test-05-engine-set-llamacpp")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
}
trap cleanup EXIT

# Ensure .env exists
if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
    touch "${SCRIPT_DIR}/.env"
fi

# Test: Engine set command works
assert_command_success "${SCRIPT_DIR}/aixcl engine set llamacpp" "Engine set to llamacpp"

# Test: .env is updated
assert_env_equals "INFERENCE_ENGINE" "llamacpp"

log_test_pass "Engine set to llamacpp correctly"
