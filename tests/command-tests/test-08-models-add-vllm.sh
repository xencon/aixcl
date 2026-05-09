#!/usr/bin/env bash
# Test 08: Models Add - vLLM
# Tests adding a model via vLLM (skips if no GPU or model not cached)
# NOTE: This test may take 5+ minutes on first run due to model download

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

# Configuration
VLLM_MODEL="Qwen/Qwen2.5-Coder-0.5B-Instruct"
HF_CACHE_DIR="${HOME}/.cache/huggingface/hub"
CONTAINER_WAIT_TIMEOUT=120  # 2 minutes for container
API_WAIT_TIMEOUT=600          # 10 minutes for API (includes model download)

# Check if model is already cached (skip if CI environment and not cached)
MODEL_CACHED=false
if [[ -d "${HF_CACHE_DIR}/models--Qwen--Qwen2.5-Coder-0.5B-Instruct" ]]; then
    MODEL_CACHED=true
    log_info "Model found in HuggingFace cache - test will be faster"
fi

# For CI environments, skip if model not cached (prevents timeouts)
if [[ "${CI:-false}" == "true" ]] && [[ "$MODEL_CACHED" == "false" ]]; then
    log_test_skip "CI environment: Skipping vLLM test (model not cached)"
    log_info "Run manually first to cache model: ./aixcl models add ${VLLM_MODEL}"
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
if [[ "$MODEL_CACHED" == "false" ]]; then
    log_warn "Model not cached - first download may take 5+ minutes"
fi
"${SCRIPT_DIR}/aixcl" engine set vllm > /dev/null 2>&1 || true
"${SCRIPT_DIR}/aixcl" stack start --profile sys > /dev/null 2>&1 || {
    log_warn "Stack start returned error, checking if already running..."
    docker ps | grep -q "vllm" || {
        log_error "vLLM container not running after start attempt"
        exit 1
    }
}

# Wait for container with extended timeout
log_info "Waiting for vLLM container (max ${CONTAINER_WAIT_TIMEOUT}s)..."
wait_for_container "vllm" "$CONTAINER_WAIT_TIMEOUT"

# Wait for API with extended timeout
log_info "Waiting for vLLM API (max ${API_WAIT_TIMEOUT}s)..."
log_info "This includes: container startup + model download + model loading"
wait_for_api "http://localhost:11434/v1/models" "$API_WAIT_TIMEOUT"

# Test: Add model
log_info "Adding model for vLLM..."
assert_command_success "${SCRIPT_DIR}/aixcl models add ${VLLM_MODEL}" "vLLM model add command succeeds"

log_test_pass "vLLM model add works"
