#!/usr/bin/env bash
# Test 12: Logs
# Tests viewing service logs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-12-logs"

# Capture state before test
BACKUP_DIR=$(capture_state "test-12-logs")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
    cleanup_test_containers
}
trap cleanup EXIT

# Setup: Ensure stack is running
if ! docker ps | grep -q "ollama"; then
    log_info "Starting stack..."
    "${SCRIPT_DIR}/aixcl" stack start --profile usr > /dev/null 2>&1
    wait_for_container "ollama"
fi

# Test: Logs command works
assert_command_success "${SCRIPT_DIR}/aixcl stack logs ollama 10" "Logs command succeeds"

log_test_pass "Logs command works"
