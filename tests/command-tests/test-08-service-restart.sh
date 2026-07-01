#!/usr/bin/env bash
# Test 08: Service Restart
# Tests restarting a service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-08-service-restart"

# Capture state before test
BACKUP_DIR=$(capture_state "test-08-service-restart")
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
    "${SCRIPT_DIR}/aixcl" stack start --profile sys > /dev/null 2>&1
    wait_for_container "ollama"
fi

# Test: Service restart command works
assert_command_success "${SCRIPT_DIR}/aixcl service restart ollama" "Service restart succeeds"

# Test: Service is running after restart
wait_for_container "ollama"
sleep 3
assert_container_running "ollama"

log_test_pass "Service restart works correctly"
