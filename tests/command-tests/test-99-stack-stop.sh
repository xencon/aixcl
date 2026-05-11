#!/usr/bin/env bash
# Test 99: Stack Stop
# Tests stopping the stack (cleanup test)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-99-stack-stop"

# Capture state before test
BACKUP_DIR=$(capture_state "test-99-stack-stop")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
}
trap cleanup EXIT

# Setup: Ensure stack is running
if ! docker ps | grep -q "ollama"; then
    log_info "Starting stack for stop test..."
    "${SCRIPT_DIR}/aixcl" stack start --profile sys > /dev/null 2>&1
    wait_for_container "ollama" 30
fi

# Test: Stack stop command works
assert_command_success "${SCRIPT_DIR}/aixcl stack stop" "Stack stops successfully"

# Test: Containers are stopped
sleep 3
if docker ps | grep -qE "ollama|open-webui|postgres"; then
    log_error "Some containers still running after stop"
    exit 1
else
    log_success "All containers stopped"
fi

log_test_pass "Stack stops correctly"
