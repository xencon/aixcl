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

# Regression #1788: the phased bring-up must not recreate running containers.
# podman-compose force-recreates a service's whole dependency closure when the
# compose model hash changes mid-start; these signatures indicate that storm.
# /tmp/test_output.log still holds the stack start output captured above.
START_OUTPUT=$(cat /tmp/test_output.log 2>/dev/null || true)
assert_string_not_contains "$START_OUTPUT" "is already in use" \
    "No container name collisions during phased start"
assert_string_not_contains "$START_OUTPUT" "has dependent containers" \
    "No dependent-container removal failures during phased start"
UNSEAL_COUNT=$(grep -c "Vault unsealed successfully" /tmp/test_output.log 2>/dev/null || true)
if [ "${UNSEAL_COUNT:-0}" -le 1 ]; then
    log_success "Vault unsealed at most once during start (count: ${UNSEAL_COUNT:-0})"
else
    log_error "Vault resealed during start (unseal count: ${UNSEAL_COUNT})"
    exit 1
fi

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
