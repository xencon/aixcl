#!/usr/bin/env bash
# Test 05: Engine Auto
# Tests auto-detecting optimal engine

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-05-engine-auto"

# Capture state before test
BACKUP_DIR=$(capture_state "test-05-engine-auto")
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

# Test: Engine auto command works
assert_command_success "${SCRIPT_DIR}/aixcl engine auto" "Engine auto-detect succeeds"

# Test: .env is updated with some engine value
assert_file_contains "${SCRIPT_DIR}/.env" "INFERENCE_ENGINE=" "Engine is set in .env"

log_test_pass "Engine auto-detect works"
