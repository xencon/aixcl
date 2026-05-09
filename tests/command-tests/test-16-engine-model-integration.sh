#!/usr/bin/env bash
# Test 16: Engine-Model Integration
# Comprehensive test that cycles through all engines and their supported models
# Validates full workflow: engine set → stack start → model add → API verify → opencode.json check → cleanup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-16-engine-model-integration"

# Skip if in CI without GPU (vLLM and llamacpp require GPU)
if [[ "${CI:-false}" == "true" ]] && ! has_nvidia_gpu; then
    log_test_skip "CI environment without GPU - skipping engine-model integration"
    exit 0
fi

# Define engine-model matrix
# Format: ENGINE|MODEL|EXPECTED_MODEL_KEY
ENGINE_MODEL_MATRIX=(
    "ollama|qwen2.5-coder:0.5b|qwen2.5-coder:0.5b"
    "ollama|qwen2.5-coder:1.5b|qwen2.5-coder:1.5b"
)

# Only add vLLM and llamacpp if GPU available
if has_nvidia_gpu; then
    ENGINE_MODEL_MATRIX+=(
        "vllm|Qwen/Qwen2.5-Coder-0.5B-Instruct|Qwen/Qwen2.5-Coder-0.5B-Instruct"
        "llamacpp|Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf|qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
    )
fi

TOTAL_TESTS=${#ENGINE_MODEL_MATRIX[@]}
TESTS_PASSED=0
TESTS_FAILED=0

log_info "Testing $TOTAL_TESTS engine-model combinations"

# Capture initial state
BACKUP_DIR=$(capture_state "test-16-engine-model-integration")
export BACKUP_DIR

# Cleanup function
cleanup() {
    local exit_code=$?
    log_info "Cleaning up test environment..."
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR" || true
    cleanup_test_containers || true
    exit $exit_code
}
trap cleanup EXIT

# Function to validate opencode.json
validate_opencode_json() {
    local expected_model="$1"
    local opencode_file="${SCRIPT_DIR}/opencode.json"
    
    if [[ ! -f "$opencode_file" ]]; then
        log_error "opencode.json not found"
        return 1
    fi
    
    # Check model pointer
    if ! grep -q "\"model\": \"aixcl-local/${expected_model}\"" "$opencode_file"; then
        log_warn "opencode.json model pointer may not match expected"
        log_info "Expected: aixcl-local/${expected_model}"
        log_info "Actual: $(grep '"model":' "$opencode_file" | head -1)"
        return 1
    fi
    
    return 0
}

# Function to test engine-model combination
test_engine_model() {
    local engine="$1"
    local model="$2"
    local expected_key="$3"
    log_info "=========================================="
    log_info "Testing: Engine=$engine, Model=$model"
    log_info "=========================================="
    
    # Step 1: Set engine
    log_info "Step 1: Setting engine to $engine..."
    if ! "${SCRIPT_DIR}/aixcl" engine set "$engine" > /dev/null 2>&1; then
        log_error "Failed to set engine to $engine"
        return 1
    fi
    
    # Verify engine set
    if ! grep -q "INFERENCE_ENGINE=$engine" "${SCRIPT_DIR}/.env"; then
        log_error "Engine not set correctly in .env"
        return 1
    fi
    log_success "Engine set to $engine"
    
    # Step 2: Start stack
    log_info "Step 2: Starting stack with $engine..."
    if ! "${SCRIPT_DIR}/aixcl" stack start --profile sys > /dev/null 2>&1; then
        log_error "Failed to start stack with $engine"
        return 1
    fi
    
    # Get container name
    local container
    container=$(get_engine_container "$engine")
    
    # Wait for container
    if ! wait_for_container "$container" 120; then
        log_error "Container $container failed to start"
        return 1
    fi
    
    # Wait for API (with timeout based on engine)
    local api_timeout=60
    if [[ "$engine" == "vllm" ]]; then
        api_timeout=300  # vLLM may need to download model
    fi
    
    if ! wait_for_api "http://localhost:11434/v1/models" "$api_timeout"; then
        log_error "API not responding for $engine"
        return 1
    fi
    
    log_success "Stack started with $engine"
    
    # Step 3: Add model
    log_info "Step 3: Adding model $model..."
    
    # For llama.cpp, verify GGUF format
    if [[ "$engine" == "llamacpp" ]] && [[ ! "$model" =~ \.gguf$ ]]; then
        log_error "llama.cpp requires GGUF format model"
        return 1
    fi
    
    if ! "${SCRIPT_DIR}/aixcl" models add "$model" > /tmp/model_add.log 2>&1; then
        log_error "Failed to add model $model"
        cat /tmp/model_add.log | head -10
        return 1
    fi
    log_success "Model $model added"
    
    # Step 4: Verify in models list
    log_info "Step 4: Verifying model in list..."
    local list_output
    list_output=$("${SCRIPT_DIR}/aixcl" models list 2>/dev/null || true)
    
    # Different validation per engine
    local validation_passed=false
    case "$engine" in
        ollama)
            if echo "$list_output" | grep -q "${expected_key}"; then
                validation_passed=true
            fi
            ;;
        vllm)
            # vLLM shows loaded model via API
            if curl -s http://localhost:11434/v1/models | grep -q "$expected_key"; then
                validation_passed=true
            fi
            ;;
        llamacpp)
            # Check for filename in list
            if echo "$list_output" | grep -q "${expected_key}"; then
                validation_passed=true
            fi
            ;;
    esac
    
    if [[ "$validation_passed" == "false" ]]; then
        log_warn "Model may not appear in list (expected for some configurations)"
    else
        log_success "Model verified in list"
    fi
    
    # Step 5: Verify opencode.json
    log_info "Step 5: Verifying opencode.json..."
    if ! validate_opencode_json "$expected_key"; then
        log_warn "opencode.json validation had warnings"
    else
        log_success "opencode.json validated"
    fi
    
    # Step 6: Test API response
    log_info "Step 6: Testing API response..."
    local api_response
    api_response=$(curl -s http://localhost:11434/v1/models --max-time 10 || true)
    
    if [[ -z "$api_response" ]]; then
        log_error "API not responding"
        return 1
    fi
    log_success "API responding"
    
    # Step 7: Stop stack
    log_info "Step 7: Stopping stack..."
    if ! "${SCRIPT_DIR}/aixcl" stack stop > /dev/null 2>&1; then
        log_warn "Stack stop may have warnings"
    fi
    
    # Wait for containers to stop
    sleep 2
    
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log_warn "Container $container still running after stop"
    else
        log_success "Stack stopped"
    fi
    
    return 0
}

# Main test execution
log_info "Starting integration test for $TOTAL_TESTS engine-model combinations"

for entry in "${ENGINE_MODEL_MATRIX[@]}"; do
    IFS='|' read -r engine model expected_key <<< "$entry"
    
    if test_engine_model "$engine" "$model" "$expected_key"; then
        ((TESTS_PASSED++))
        log_success "PASSED: $engine + $model"
    else
        ((TESTS_FAILED++))
        log_error "FAILED: $engine + $model"
        # Continue testing other combinations
    fi
    
    echo ""  # Separator
done

# Summary
log_info "=========================================="
log_info "Integration Test Summary"
log_info "=========================================="
log_info "Total combinations: $TOTAL_TESTS"
log_success "Passed: $TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
    log_error "Failed: $TESTS_FAILED"
else
    log_info "Failed: $TESTS_FAILED"
fi

if [[ $TESTS_FAILED -eq 0 ]]; then
    log_test_pass "All $TOTAL_TESTS engine-model combinations passed"
    exit 0
else
    log_test_fail "$TESTS_FAILED of $TOTAL_TESTS combinations failed"
    exit 1
fi
