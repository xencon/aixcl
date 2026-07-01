#!/usr/bin/env bash
# Test 02: Stack Start
# Tests starting the stack with sys profile

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-02-stack-start"

# Capture state before test
BACKUP_DIR=$(capture_state "test-01-stack-start")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
    cleanup_test_containers
}
trap cleanup EXIT

# Pre-cleanup: Stop any existing containers and set engine
log_info "Stopping any existing containers..."
"${SCRIPT_DIR}/aixcl" stack stop > /dev/null 2>&1 || true
sleep 2

# Ensure engine is set to ollama for this test
log_info "Setting engine to ollama..."
"${SCRIPT_DIR}/aixcl" engine set ollama > /dev/null 2>&1 || true

# Test: Stack starts successfully
assert_command_success "${SCRIPT_DIR}/aixcl stack start --profile sys" "Stack starts with sys profile"

# Test: Core containers are running
wait_for_container "ollama"
wait_for_container "postgres"
wait_for_container "open-webui"

# Test: Containers are healthy
sleep 5 # Give health checks time to run
assert_container_running "ollama"
assert_container_running "postgres"
assert_container_running "open-webui"

# Test: API is accessible
wait_for_api "http://localhost:11434/v1/models" 60

log_test_pass "Stack started successfully with all services"
