#!/usr/bin/env bash
# Test 07: Models Add - Ollama
# Tests adding a model via ollama

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-07-models-add-ollama"

# Capture state before test
BACKUP_DIR=$(capture_state "test-07-models-add-ollama")
export BACKUP_DIR

# Cleanup function - runs on exit
cleanup() {
    local exit_code=$?
    # Only cleanup if we actually ran some test steps
    if [[ -n "$TEST_STARTED" ]]; then
        source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
        restore_state "$BACKUP_DIR" || true
        cleanup_test_containers || true
    fi
    exit $exit_code
}
trap cleanup EXIT

# Setup: Stop any existing containers first
log_info "Stopping any existing containers..."
"${SCRIPT_DIR}/aixcl" stack stop > /dev/null 2>&1 || true
sleep 2

# Setup: Start stack and set engine
log_info "Starting stack with ollama..."
"${SCRIPT_DIR}/aixcl" engine set ollama > /dev/null 2>&1 || true
"${SCRIPT_DIR}/aixcl" stack start --profile sys > /dev/null 2>&1

# Mark that test has started
TEST_STARTED=1

wait_for_container "ollama"
wait_for_api "http://localhost:11434/v1/models" 60

# Test: Add model
log_info "Adding model (this may take 2-3 minutes)..."
assert_command_success "${SCRIPT_DIR}/aixcl models add qwen2.5-coder:0.5b" "Model added successfully"

# Test: Model appears in list
log_info "Verifying model in list..."
if "${SCRIPT_DIR}/aixcl" models list 2>/dev/null | grep -q "qwen2.5-coder"; then
    log_success "Model appears in models list"
else
    log_error "Model not found in list"
    exit 1
fi

log_test_pass "Ollama model added and verified"
