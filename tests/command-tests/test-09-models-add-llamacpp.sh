#!/usr/bin/env bash
# Test 09: Models Add - llama.cpp
# Tests adding a GGUF model via llama.cpp

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-09-models-add-llamacpp"

# Capture state before test
BACKUP_DIR=$(capture_state "test-09-models-add-llamacpp")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
    cleanup_test_containers
}
trap cleanup EXIT

# Setup: Start stack and set engine
log_info "Starting stack with llama.cpp..."
"${SCRIPT_DIR}/aixcl" engine set llamacpp > /dev/null 2>&1 || true
"${SCRIPT_DIR}/aixcl" stack start --profile sys > /dev/null 2>&1

wait_for_container "llamacpp"

# Test: Add GGUF model
log_info "Adding GGUF model (this may take 2-3 minutes)..."
assert_command_success "${SCRIPT_DIR}/aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf" "GGUF model added successfully"

# Test: INFERENCE_MODEL is set
assert_env_equals "INFERENCE_MODEL" "qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"

log_test_pass "llama.cpp GGUF model added and INFERENCE_MODEL set"
