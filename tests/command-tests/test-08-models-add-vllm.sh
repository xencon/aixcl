#!/usr/bin/env bash
# Test 08: Models Add - vLLM
# Tests adding a model via vLLM (skips if no GPU)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-08-models-add-vllm"

# Skip if no GPU
if ! has_nvidia_gpu; then
    log_test_skip "No NVIDIA GPU detected - vLLM requires GPU"
    exit 0
fi

# Capture state before test
BACKUP_DIR=$(capture_state "test-08-models-add-vllm")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
    cleanup_test_containers
}
trap cleanup EXIT

# Setup: Start stack and set engine
log_info "Starting stack with vLLM..."
"${SCRIPT_DIR}/aixcl" engine set vllm > /dev/null 2>&1 || true
"${SCRIPT_DIR}/aixcl" stack start --profile usr > /dev/null 2>&1

wait_for_container "vllm"
wait_for_api "http://localhost:11434/v1/models" 90

# Test: Add model (vLLM may need pre-downloaded model, just verify command works)
log_info "Adding model for vLLM..."
assert_command_success "${SCRIPT_DIR}/aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct" "vLLM model add command succeeds"

log_test_pass "vLLM model add works"
